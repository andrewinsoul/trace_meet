defmodule TraceMeet.Extractions do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TraceMeet.Repo
  alias TraceMeet.ProcessingRuns.ProcessingRun
  alias TraceMeet.Extractions.{
    ExtractionProposal,
    ExtractionProposalReview,
    ExtractionProposalSource,
    ExtractionProposalEvidence,
    ChunkExtraction,
    Decision,
    ActionItem,
    Commitment,
    Risk,
    UnresolvedQuestion
  }

  def create_proposals(%ProcessingRun{} = run, proposals, extractions \\ [], segments \\ [])
      when is_list(proposals) and is_list(extractions) and is_list(segments) do
    Multi.new()
    |> Multi.run(:chunks_ready, fn repo, _changes ->
      total = repo.aggregate(from(c in TraceMeet.ProcessingRuns.ProcessingRunChunk, where: c.processing_run_id == ^run.id), :count)
      incomplete = repo.aggregate(from(c in TraceMeet.ProcessingRuns.ProcessingRunChunk, where: c.processing_run_id == ^run.id and c.status != "completed"), :count)
      if total > 0 and incomplete == 0, do: {:ok, :ready}, else: {:error, :chunks_not_completed}
    end)
    |> Multi.run(:proposals, fn repo, _changes ->
      Enum.reduce_while(proposals, {:ok, []}, fn attrs, {:ok, acc} ->
        categories = attrs[:categories] || []
        description = attrs[:description]
        fingerprint = :crypto.hash(:sha256, Enum.join(Enum.sort(categories), ",") <> ":" <> String.downcase(String.trim(description))) |> Base.encode16(case: :lower)
        category = List.first(categories)

        proposal_attrs = %{
          fingerprint: fingerprint, category: category, categories: categories,
          uncertainties: attrs[:uncertainties] || %{},
          title: String.slice(description, 0, 255), description: description,
          owner: attrs[:owner], due_date: attrs[:deadline], confidence: attrs[:confidence],
          status: "pending", evidence: %{"quotes" => attrs[:evidence_quotes] || []}
        }

        changeset = ExtractionProposal.changeset(%ExtractionProposal{processing_run_id: run.id}, proposal_attrs)
        case repo.insert(changeset, on_conflict: :nothing, conflict_target: [:processing_run_id, :fingerprint]) do
          {:ok, _proposal} ->
            persisted = repo.one!(from(p in ExtractionProposal, where: p.processing_run_id == ^run.id and p.fingerprint == ^fingerprint))
            {:cont, {:ok, [{persisted, attrs} | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, proposal_attrs} ->
          Enum.each(proposal_attrs, fn {proposal, attrs} ->
            source_extractions =
              attrs[:source_extraction_indexes]
              |> List.wrap()
              |> Enum.uniq()
              |> Enum.map(&Enum.at(extractions, &1))
              |> Enum.filter(&match?(%ChunkExtraction{}, &1))

            Enum.each(source_extractions, fn extraction ->
              repo.insert!(
                ExtractionProposalSource.changeset(
                  %ExtractionProposalSource{extraction_proposal_id: proposal.id, chunk_extraction_id: extraction.id}, %{}
                ), on_conflict: :nothing
              )

              Enum.each(extraction.source_segment_ids, fn segment_id ->
                case Enum.find(segments, &(&1.id == segment_id)) do
                  nil -> :ok
                  segment ->
                    repo.insert!(
                      ExtractionProposalEvidence.changeset(
                        %ExtractionProposalEvidence{extraction_proposal_id: proposal.id},
                        %{
                          segment_id: segment.id, source_start: segment[:source_start], source_end: segment[:source_end],
                          speaker: segment[:speaker], timestamp: segment[:timestamp], quote: segment[:source_quote]
                        }
                      ), on_conflict: :nothing
                    )
                end
              end)
            end)
          end)
          {:ok, Enum.map(proposal_attrs, &elem(&1, 0))}
        error -> error
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{proposals: proposals}} -> {:ok, proposals}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def list_advisor_proposals(advisor_id, opts \\ []) do
    status = Keyword.get(opts, :status, "pending")
    category = Keyword.get(opts, :category)
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = 10

    base_query =
      from(p in ExtractionProposal,
        join: r in ProcessingRun,
        on: r.id == p.processing_run_id,
        where: r.advisor_id == ^advisor_id
      )

    base_query =
      if status in ["pending", "approved", "rejected"],
        do: where(base_query, [p, _r], p.status == ^status),
        else: base_query

    base_query =
      if category in ["decision", "action_item", "commitment", "risk", "unresolved_question"],
        do: where(base_query, [p, _r], p.category == ^category),
        else: base_query

    total_count = Repo.aggregate(base_query, :count, :id)
    total_pages = max(ceil(total_count / page_size), 1)
    page = min(page, total_pages)

    evidence_query = from(e in ExtractionProposalEvidence, order_by: [asc: e.source_start])
    reviews_query = from(review in ExtractionProposalReview, order_by: [desc: review.inserted_at])

    entries =
      base_query
      |> order_by([p, _r], desc: p.inserted_at)
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> preload(
        [p, _r],
        processing_run: [transcript: [meeting: :client]],
        evidence_records: ^evidence_query,
        reviews: ^reviews_query
      )
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  def proposal_counts(advisor_id) do
    Repo.all(
      from(p in ExtractionProposal,
        join: r in ProcessingRun,
        on: r.id == p.processing_run_id,
        where: r.advisor_id == ^advisor_id,
        group_by: p.status,
        select: {p.status, count(p.id)}
      )
    )
    |> Map.new()
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
    if action == "rejected" and (not is_binary(attrs[:rejection_reason]) or String.trim(attrs[:rejection_reason]) == "") do
      {:error, :rejection_reason_required}
    else
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
          "rejected" -> %{status: "rejected", reviewed_at: DateTime.utc_now(), rejection_reason: attrs[:rejection_reason]}
          "edited" -> Map.take(attrs, [:title, :description, :owner, :due_date, :evidence])
        end

      proposal
      |> ExtractionProposal.changeset(changes)
      |> repo.update()
    end)
    |> Multi.run(:operational_record, fn repo, %{proposal: _proposal, updated_proposal: updated} ->
      if action == "approved" do
        create_operational_record(repo, updated, advisor_id)
      else
        {:ok, nil}
      end
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
             {:ok, _record} <- create_operational_record(repo, updated, advisor_id),
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

  defp create_operational_record(repo, proposal, advisor_id) do
    context =
      repo.one(
        from(r in ProcessingRun,
          join: t in assoc(r, :transcript),
          join: m in assoc(t, :meeting),
          join: c in assoc(m, :client),
          where: r.id == ^proposal.processing_run_id and r.advisor_id == ^advisor_id and
            t.advisor_id == ^advisor_id and m.user_id == ^advisor_id and c.user_id == ^advisor_id,
          select: %{client_id: c.id, meeting_id: m.id}
        )
      )

    case {operational_module(proposal.category), context} do
      {nil, _} ->
        {:error, :unsupported_proposal_category}

      {_module, nil} ->
        {:error, :meeting_context_not_found}

      {module, %{client_id: client_id, meeting_id: meeting_id}} ->
        attrs = %{
          advisor_id: advisor_id,
          client_id: client_id,
          meeting_id: meeting_id,
          extraction_proposal_id: proposal.id,
          title: proposal.title,
          description: proposal.description,
          owner: proposal.owner,
          due_date: proposal.due_date
        }

        repo.insert(module.changeset(struct(module), attrs))
    end
  end

  defp operational_module("decision"), do: Decision
  defp operational_module("action_item"), do: ActionItem
  defp operational_module("commitment"), do: Commitment
  defp operational_module("risk"), do: Risk
  defp operational_module("unresolved_question"), do: UnresolvedQuestion
  defp operational_module(_category), do: nil

  defp proposal_values(proposal) do
    Map.take(proposal, [
      :category,
      :categories,
      :uncertainties,
      :rejection_reason,
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
