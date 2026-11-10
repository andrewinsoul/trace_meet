defmodule TraceMeet.ProcessingRuns.ProcessTranscriptWorker do
  use Oban.Worker,
    queue: :transcript_processing,
    max_attempts: 5

  alias TraceMeet.AI
  alias TraceMeet.ProcessingRuns
  alias TraceMeet.ProcessingRuns.ProcessingRun
  alias TraceMeet.Repo
  alias TraceMeet.Transcripts.Transcript

  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "processing_run_id" => run_id,
          "advisor_id" => advisor_id,
          "transcript_id" => transcript_id
        }
      } = job) do
    case ProcessingRuns.get_run(advisor_id, run_id) do
      %ProcessingRun{status: status} when status in ["completed", "failed", "cancelled"] ->
        :ok

      %ProcessingRun{transcript_id: ^transcript_id} = run ->
        with {:ok, run} <- ProcessingRuns.mark_processing(run, job.attempt),
             :ok <- broadcast_update(run),
             %Transcript{} = transcript <- get_transcript(advisor_id, transcript_id),
             {:ok, cleaned} <-
               AI.clean_transcript(
                 transcript.content,
                 %{
                   version: run.prompt_version,
                   content: run.prompt_snapshot,
                   sha256: run.prompt_sha256
                 },
                 run.guardrails_snapshot,
                 run.model
               ),
             :ok <- persist_result(run, cleaned) do
          :ok
        else
          nil ->
            {:discard, :transcript_not_found}

          {:error, reason} ->
            handle_failure(run_id, advisor_id, job, reason)

          _ ->
            handle_failure(run_id, advisor_id, job, :processing_failed)
        end

      nil ->
        {:discard, :processing_run_not_found}

      _ ->
        {:discard, :processing_run_transcript_mismatch}
    end
  rescue
    error ->
      handle_failure(run_id, advisor_id, job, {:worker_exception, error})
  end

  defp get_transcript(advisor_id, transcript_id) do
    Repo.one(
      from(t in Transcript,
        where: t.id == ^transcript_id and t.advisor_id == ^advisor_id
      )
    )
  end

  defp persist_result(run, cleaned) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:processing_run, fn repo, _changes ->
      run
      |> ProcessingRun.transition_changeset(%{
        status: "completed",
        completed_at: DateTime.utc_now(),
        failed_at: nil,
        error_message: nil,
        cleaned_content: cleaned.cleaned_content,
        cleaned_segments: %{"segments" => cleaned.segments}
      })
      |> repo.update()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _changes} ->
        broadcast_update(run)
        :ok
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  defp broadcast_update(run) do
    Phoenix.PubSub.broadcast(
      TraceMeet.PubSub,
      "advisor:#{run.advisor_id}:processing",
      {:processing_run_updated, run.transcript_id}
    )

    :ok
  end

  defp handle_failure(run_id, advisor_id, job, reason) do
    case ProcessingRuns.get_run(advisor_id, run_id) do
      %ProcessingRun{status: "processing"} = run ->
        if job.attempt >= job.max_attempts do
          ProcessingRuns.mark_failed(run, inspect(reason, limit: 10, printable_limit: 500))
        else
          ProcessingRuns.mark_queued(run)
        end

        broadcast_update(run)

      _ ->
        :ok
    end

    {:error, reason}
  end
end
