defmodule TraceMeet.ProcessingRuns.CleanupExpiredDataWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 5

  import Ecto.Query, warn: false

  alias TraceMeet.Repo
  alias TraceMeet.Accounts.User
  alias TraceMeet.ProcessingRuns.{ProcessingRun, ProcessingRunChunk}
  alias TraceMeet.Extractions.{ExtractionProposal, ExtractionProposalSource, ChunkExtraction}

  @batch_size 100

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cleanup_batches()
    :ok
  end

  defp cleanup_batches do
    case expired_reviewed_run_ids() do
      [] ->
        :ok

      ids ->
        case Repo.transaction(fn ->
               chunk_ids =
                 from(chunk in ProcessingRunChunk,
                   where: chunk.processing_run_id in ^ids,
                   select: chunk.id
                 )

               extraction_ids =
                 from(extraction in ChunkExtraction,
                   where: extraction.processing_run_chunk_id in subquery(chunk_ids),
                   select: extraction.id
                 )

               Repo.delete_all(
                 from(source in ExtractionProposalSource,
                   where: source.chunk_extraction_id in subquery(extraction_ids)
                 )
               )

               Repo.delete_all(
                 from(extraction in ChunkExtraction,
                   where: extraction.id in subquery(extraction_ids)
                 )
               )

               Repo.delete_all(
                 from(chunk in ProcessingRunChunk,
                   where: chunk.id in subquery(chunk_ids)
                 )
               )
             end) do
          {:ok, _result} -> cleanup_batches()
          {:error, reason} -> raise "Processing data cleanup failed: #{inspect(reason)}"
        end
    end
  end

  defp expired_reviewed_run_ids do
    runs_with_chunks =
      from(chunk in ProcessingRunChunk,
        select: chunk.processing_run_id,
        distinct: true
      )

    Repo.all(
      from(run in ProcessingRun,
        join: advisor in User,
        on: advisor.id == run.advisor_id,
        left_join: proposal in ExtractionProposal,
        on: proposal.processing_run_id == run.id,
        where: run.status == "completed" and run.id in subquery(runs_with_chunks),
        group_by: [run.id, run.completed_at, advisor.processing_data_retention_days],
        having:
          fragment(
            "(count(?) = 0 OR bool_and(? <> 'pending')) AND coalesce(max(?), ?) + (? * interval '1 day') <= timezone('utc', now())",
            proposal.id,
            proposal.status,
            proposal.reviewed_at,
            run.completed_at,
            advisor.processing_data_retention_days
          ),
        order_by: [asc: run.id],
        limit: @batch_size,
        select: run.id
      )
    )
  end
end
