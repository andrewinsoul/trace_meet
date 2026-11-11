defmodule TraceMeet.ProcessingRuns do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TraceMeet.Repo
  alias TraceMeet.ProcessingRuns.ProcessingRun
  alias TraceMeet.ProcessingRuns.ProcessTranscriptWorker
  alias TraceMeet.Meetings.Meeting
  alias TraceMeet.Transcripts.Transcript

  def enqueue(advisor_id, meeting_id, transcript_id) do
    advisor_prompt = TraceMeet.AI.Configuration.active_prompt_snapshot(advisor_id)

    if is_nil(advisor_prompt) do
      {:error, :default_prompt_required}
    else
      enqueue_with_configuration(advisor_id, meeting_id, transcript_id, advisor_prompt)
    end
  end

  defp enqueue_with_configuration(advisor_id, meeting_id, transcript_id, advisor_prompt) do
    meeting_type =
      Repo.one(
        from(m in Meeting,
          where: m.id == ^meeting_id and m.user_id == ^advisor_id,
          select: m.meeting_type
        )
      )

    guardrails = TraceMeet.AI.Configuration.guardrails_snapshot(meeting_type)

    resolved_prompt =
      [
        "ADVISOR TRANSCRIPT CLEANING INSTRUCTIONS:\n" <> advisor_prompt.instructions,
        "PLATFORM GUARDRAILS (MANDATORY):\n" <>
          Enum.map_join(guardrails, "\n", &("- " <> &1.instruction))
      ]
      |> Enum.join("\n\n")

    prompt_version = "advisor-prompt"

    model = Application.get_env(:trace_meet, :ai_model, "openai/gpt-oss-120b")

    Multi.new()
    |> Multi.run(:transcript, fn repo, _changes ->
      transcript =
        repo.one(
          from(t in Transcript,
            join: meeting in Meeting,
            on: meeting.id == t.meeting_id,
            where:
              t.id == ^transcript_id and t.meeting_id == ^meeting_id and
                t.advisor_id == ^advisor_id and meeting.user_id == ^advisor_id and
                meeting.status == "completed" and is_nil(meeting.archived_at) and
                not is_nil(t.selected_at),
            lock: "FOR UPDATE"
          )
        )

      case transcript do
        %Transcript{} -> {:ok, transcript}
        nil -> {:error, :transcript_not_selected}
      end
    end)
    |> Multi.insert(:processing_run, fn %{transcript: transcript} ->
      ProcessingRun.changeset(
        %ProcessingRun{
          transcript_id: transcript.id,
          advisor_id: advisor_id,
          advisor_prompt_id: advisor_prompt.id
        },
        %{
          status: "queued",
          attempt_count: 0,
          prompt_version: prompt_version,
          prompt_snapshot: resolved_prompt,
          prompt_sha256: :crypto.hash(:sha256, resolved_prompt) |> Base.encode16(case: :lower),
          model: model,
          guardrails_snapshot: %{"guardrails" => guardrails},
          advisor_prompt_snapshot: advisor_prompt.instructions,
          advisor_prompt_sha256: advisor_prompt.sha256
        }
      )
    end)
    |> Oban.insert(:processing_job, fn %{processing_run: run} ->
      ProcessTranscriptWorker.new(
        %{
          processing_run_id: run.id,
          advisor_id: advisor_id,
          transcript_id: run.transcript_id
        },
        max_attempts: Application.get_env(:trace_meet, :processing_max_attempts, 5)
      )
    end)
    |> Multi.update(:attach_job, fn %{processing_run: run, processing_job: job} ->
      Ecto.Changeset.change(run, oban_job_id: job.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{attach_job: run}} -> {:ok, run}
      {:error, _operation, reason, _changes} -> {:error, normalize_enqueue_error(reason)}
    end
  end

  defp normalize_enqueue_error(%Ecto.Changeset{} = changeset) do
    if Enum.any?(changeset.errors, fn {field, {_, opts}} ->
         field == :transcript_id and opts[:constraint] == :unique
       end) do
      :already_processing
    else
      changeset
    end
  end

  defp normalize_enqueue_error(%Postgrex.Error{postgres: %{code: :unique_violation}}),
    do: :already_processing

  defp normalize_enqueue_error(reason), do: reason

  def list_for_transcript(advisor_id, transcript_id) do
    Repo.all(
      from(run in ProcessingRun,
        where: run.advisor_id == ^advisor_id and run.transcript_id == ^transcript_id,
        order_by: [desc: run.inserted_at]
      )
    )
  end

  def get_run(advisor_id, run_id) do
    Repo.one(
      from(run in ProcessingRun,
        where: run.id == ^run_id and run.advisor_id == ^advisor_id
      )
    )
  end

  def mark_processing(%ProcessingRun{status: status} = run, attempt_count)
      when status in ["queued", "processing"] do
    run
    |> ProcessingRun.transition_changeset(%{
      status: "processing",
      attempt_count: attempt_count,
      started_at: run.started_at || DateTime.utc_now(),
      completed_at: nil,
      failed_at: nil,
      error_message: nil
    })
    |> Repo.update()
  end

  def mark_processing(%ProcessingRun{}), do: {:error, :invalid_transition}

  def mark_queued(%ProcessingRun{status: "processing"} = run) do
    run
    |> ProcessingRun.transition_changeset(%{
      status: "queued",
      completed_at: nil,
      failed_at: nil,
      error_message: nil
    })
    |> Repo.update()
  end

  def mark_queued(%ProcessingRun{}), do: {:error, :invalid_transition}

  def mark_completed(%ProcessingRun{status: "processing"} = run) do
    run
    |> ProcessingRun.transition_changeset(%{
      status: "completed",
      completed_at: DateTime.utc_now(),
      failed_at: nil,
      error_message: nil
    })
    |> Repo.update()
  end

  def mark_completed(%ProcessingRun{}), do: {:error, :invalid_transition}

  def mark_failed(%ProcessingRun{status: "processing"} = run, error_message) do
    run
    |> ProcessingRun.transition_changeset(%{
      status: "failed",
      failed_at: DateTime.utc_now(),
      completed_at: nil,
      error_message: error_message
    })
    |> Repo.update()
  end

  def mark_failed(%ProcessingRun{}, _error_message), do: {:error, :invalid_transition}

  def cancel(%ProcessingRun{status: "queued"} = run) do
    ProcessingRun.transition_changeset(run, %{status: "cancelled"})
    |> Repo.update()
  end

  def cancel(%ProcessingRun{}), do: {:error, :invalid_transition}
end
