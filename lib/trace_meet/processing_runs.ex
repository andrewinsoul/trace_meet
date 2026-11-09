defmodule TraceMeet.ProcessingRuns do
  import Ecto.Query, warn: false

  alias TraceMeet.Repo
  alias TraceMeet.ProcessingRuns.ProcessingRun

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

  def mark_processing(%ProcessingRun{status: "queued"} = run, attempt_count) do
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
