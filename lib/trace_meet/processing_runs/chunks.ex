defmodule TraceMeet.ProcessingRuns.Chunks do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TraceMeet.Repo
  alias TraceMeet.ProcessingRuns.{ProcessingRun, ProcessingRunChunk}
  alias TraceMeet.Extractions.ChunkExtraction

  def create_for_run(%ProcessingRun{} = run, chunks) when is_list(chunks) do
    Multi.new()
    |> Multi.run(:chunks, fn repo, _changes ->
      case repo.one(from(r in ProcessingRun, where: r.id == ^run.id, lock: "FOR UPDATE")) do
        nil ->
          {:error, :processing_run_not_found}

        _run ->
          existing =
        repo.all(
          from(c in ProcessingRunChunk,
            where: c.processing_run_id == ^run.id,
            order_by: c.sequence
          )
        )

          if existing != [] do
            {:ok, existing}
          else
            Enum.reduce_while(Enum.with_index(chunks, 1), {:ok, []}, fn {attrs, sequence}, {:ok, acc} ->
              attrs = Map.put(attrs, :sequence, sequence)
              changeset = ProcessingRunChunk.changeset(%ProcessingRunChunk{processing_run_id: run.id}, attrs)

              case repo.insert(changeset) do
                {:ok, chunk} -> {:cont, {:ok, [chunk | acc]}}
                {:error, reason} -> {:halt, {:error, reason}}
              end
            end)
            |> case do
              {:ok, inserted} -> {:ok, Enum.reverse(inserted)}
              error -> error
            end
          end
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{chunks: chunks}} -> {:ok, chunks}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def list_for_run(advisor_id, run_id) do
    Repo.all(
      from(c in ProcessingRunChunk,
        join: r in ProcessingRun,
        on: r.id == c.processing_run_id,
        where: r.id == ^run_id and r.advisor_id == ^advisor_id,
        order_by: c.sequence
      )
    )
  end

  def get_for_run(advisor_id, run_id, chunk_id) do
    Repo.one(
      from(c in ProcessingRunChunk,
        join: r in ProcessingRun,
        on: r.id == c.processing_run_id,
        where: c.id == ^chunk_id and r.id == ^run_id and r.advisor_id == ^advisor_id
      )
    )
  end

  def mark_processing(%ProcessingRunChunk{status: status} = chunk)
      when status in ["pending", "failed", "processing"] do
    chunk
    |> ProcessingRunChunk.changeset(%{
      status: "processing",
      attempt_count: chunk.attempt_count + 1,
      started_at: DateTime.utc_now(),
      completed_at: nil,
      error_message: nil
    })
    |> Repo.update()
  end

  def mark_processing(%ProcessingRunChunk{}), do: {:error, :invalid_chunk_transition}

  def mark_failed(%ProcessingRunChunk{status: "processing"} = chunk, reason) do
    chunk
    |> ProcessingRunChunk.changeset(%{
      status: "failed",
      error_message: inspect(reason, limit: 10, printable_limit: 500),
      completed_at: nil
    })
    |> Repo.update()
  end

  def mark_failed(%ProcessingRunChunk{}, _reason), do: {:error, :invalid_chunk_transition}

  def save_extraction_result(%ProcessingRunChunk{status: status} = chunk, %{items: items} = result)
      when status in ["processing", "failed"] and is_list(items) do
    Multi.new()
    |> Multi.run(:clear_previous, fn repo, _changes ->
      repo.delete_all(from(e in ChunkExtraction, where: e.processing_run_chunk_id == ^chunk.id))
      {:ok, :cleared}
    end)
    |> Multi.run(:extractions, fn repo, _changes ->
      Enum.reduce_while(items, {:ok, []}, fn attrs, {:ok, acc} ->
        changeset = ChunkExtraction.changeset(%ChunkExtraction{processing_run_chunk_id: chunk.id}, attrs)
        case repo.insert(changeset) do
          {:ok, extraction} -> {:cont, {:ok, [extraction | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, extractions} -> {:ok, Enum.reverse(extractions)}
        error -> error
      end
    end)
    |> Multi.update(:chunk, ProcessingRunChunk.changeset(chunk, %{
      status: "completed", extraction_result: result, error_message: nil,
      completed_at: DateTime.utc_now()
    }))
    |> Repo.transaction()
    |> case do
      {:ok, %{chunk: updated}} -> {:ok, updated}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def save_extraction_result(%ProcessingRunChunk{}, _result), do: {:error, :invalid_chunk_transition}

  def list_extractions_for_run(run_id) do
    Repo.all(
      from(e in ChunkExtraction,
        join: c in ProcessingRunChunk, on: c.id == e.processing_run_chunk_id,
        where: c.processing_run_id == ^run_id,
        order_by: [asc: c.sequence, asc: e.inserted_at]
      )
    )
  end
end
