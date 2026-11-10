defmodule TraceMeet.Extractions do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TraceMeet.Repo
  alias TraceMeet.ProcessingRuns.ProcessingRun
  alias TraceMeet.Extractions.{ExtractionProposal, ExtractionProposalReview}

  def create_proposals(%ProcessingRun{} = run, proposals) when is_list(proposals) do
    Multi.new()
    |> Multi.run(:chunks_ready, fn repo, _changes ->
      total =
        repo.aggregate(
          from(c in TraceMeet.ProcessingRuns.ProcessingRunChunk,
            where: c.processing_run_id == ^run.id
          ),
          :count
        )

      incomplete =
        repo.aggregate(
          from(c in TraceMeet.ProcessingRuns.ProcessingRunChunk,
            where: c.processing_run_id == ^run.id and c.status != "completed"
          ),
          :count
        )

      if total > 0 and incomplete == 0, do: {:ok, :ready}, else: {:error, :chunks_not_completed}
    end)
    |> Multi.run(:proposals, fn repo, _changes ->
      Enum.reduce_while(proposals, {:ok, []}, fn attrs, {:ok, acc} ->
        changeset =
          ExtractionProposal.changeset(%ExtractionProposal{processing_run_id: run.id}, attrs)

        case repo.insert(changeset,
               on_conflict: :nothing,
               conflict_target: [:processing_run_id, :fingerprint]
             ) do
          {:ok, _proposal} -> {:cont, {:ok, acc}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, _} ->
          persisted =
            repo.all(
              from(p in ExtractionProposal,
                where: p.processing_run_id == ^run.id,
                order_by: p.inserted_at
              )
            )

          {:ok, persisted}

        error ->
          error
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{proposals: proposals}} -> {:ok, proposals}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def list_proposals(advisor_id, run_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    query =
      from(p in ExtractionProposal,
        join: r in ProcessingRun,
        on: r.id == p.processing_run_id,
        where: r.id == ^run_id and r.advisor_id == ^advisor_id,
        order_by: [asc: p.inserted_at]
      )

    query = if status, do: where(query, [p, _r], p.status == ^status), else: query
    Repo.all(query)
  end

  def list_reviews(advisor_id, proposal_id) do
    Repo.all(
      from(review in ExtractionProposalReview,
        join: proposal in ExtractionProposal,
        on: proposal.id == review.extraction_proposal_id,
        join: run in ProcessingRun,
        on: run.id == proposal.processing_run_id,
        where: proposal.id == ^proposal_id and run.advisor_id == ^advisor_id,
        order_by: [asc: review.inserted_at]
      )
    )
  end

  def get_proposal(advisor_id, proposal_id) do
    Repo.one(
      from(p in ExtractionProposal,
        join: r in ProcessingRun,
        on: r.id == p.processing_run_id,
        where: p.id == ^proposal_id and r.advisor_id == ^advisor_id
      )
    )
  end

  def review_proposal(advisor_id, proposal_id, action, attrs \\ %{})

  def review_proposal(advisor_id, proposal_id, action, attrs)
      when action in ["approved", "rejected", "edited"] do
    Multi.new()
    |> Multi.run(:proposal, fn repo, _changes ->
      proposal =
        repo.one(
          from(p in ExtractionProposal,
            join: r in ProcessingRun,
            on: r.id == p.processing_run_id,
            where: p.id == ^proposal_id and r.advisor_id == ^advisor_id,
            lock: "FOR UPDATE"
          )
        )

      case proposal do
        %ExtractionProposal{status: "pending"} -> {:ok, proposal}
        %ExtractionProposal{} -> {:error, :proposal_already_reviewed}
        nil -> {:error, :not_found}
      end
    end)
    |> Multi.run(:updated_proposal, fn repo, %{proposal: proposal} ->
      changes =
        case action do
          "approved" -> %{status: "approved", reviewed_at: DateTime.utc_now()}
          "rejected" -> %{status: "rejected", reviewed_at: DateTime.utc_now()}
          "edited" -> Map.take(attrs, [:title, :description, :owner, :due_date, :evidence])
        end

      proposal
      |> ExtractionProposal.changeset(changes)
      |> repo.update()
    end)
    |> Multi.insert(:review, fn %{proposal: proposal, updated_proposal: updated} ->
      ExtractionProposalReview.changeset(
        %ExtractionProposalReview{
          extraction_proposal_id: proposal.id,
          advisor_id: advisor_id
        },
        %{
          action: action,
          previous_values: proposal_values(proposal),
          new_values: proposal_values(updated),
          notes: attrs[:notes]
        }
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{updated_proposal: proposal}} -> {:ok, proposal}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def review_proposal(_advisor_id, _proposal_id, _action, _attrs),
    do: {:error, :invalid_review_action}

  def bulk_approve(advisor_id, proposal_ids) when is_list(proposal_ids) do
    ids = Enum.uniq(proposal_ids)

    Multi.new()
    |> Multi.run(:proposals, fn repo, _changes ->
      proposals =
        repo.all(
          from(p in ExtractionProposal,
            join: r in ProcessingRun,
            on: r.id == p.processing_run_id,
            where: p.id in ^ids and r.advisor_id == ^advisor_id and p.status == "pending",
            lock: "FOR UPDATE"
          )
        )

      if length(proposals) == length(ids),
        do: {:ok, proposals},
        else: {:error, :proposals_not_found_or_already_reviewed}
    end)
    |> Multi.run(:approved, fn repo, %{proposals: proposals} ->
      Enum.reduce_while(proposals, {:ok, []}, fn proposal, {:ok, acc} ->
        changeset =
          ExtractionProposal.changeset(proposal, %{
            status: "approved",
            reviewed_at: DateTime.utc_now()
          })

        with {:ok, updated} <- repo.update(changeset),
             {:ok, _review} <-
               repo.insert(
                 ExtractionProposalReview.changeset(
                   %ExtractionProposalReview{
                     extraction_proposal_id: proposal.id,
                     advisor_id: advisor_id
                   },
                   %{
                     action: "approved",
                     previous_values: proposal_values(proposal),
                     new_values: proposal_values(updated)
                   }
                 )
               ) do
          {:cont, {:ok, [updated | acc]}}
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{approved: proposals}} -> {:ok, Enum.reverse(proposals)}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  defp proposal_values(proposal) do
    Map.take(proposal, [
      :category,
      :title,
      :description,
      :owner,
      :due_date,
      :confidence,
      :status,
      :evidence
    ])
  end
end
