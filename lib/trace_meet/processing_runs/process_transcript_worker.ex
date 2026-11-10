defmodule TraceMeet.ProcessingRuns.ProcessTranscriptWorker do
  use Oban.Worker,
    queue: :transcript_processing,
    max_attempts: 5

  alias TraceMeet.AI
  alias TraceMeet.Extractions
  alias TraceMeet.ProcessingRuns
  alias TraceMeet.ProcessingRuns.{Chunker, Chunks, ProcessingRun}
  alias TraceMeet.Repo
  alias TraceMeet.Transcripts.Transcript

  import Ecto.Query

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(15)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"processing_run_id" => run_id, "advisor_id" => advisor_id, "transcript_id" => transcript_id}} = job) do
    case ProcessingRuns.get_run(advisor_id, run_id) do
      %ProcessingRun{status: status} when status in ["completed", "failed", "cancelled"] -> :ok
      %ProcessingRun{transcript_id: ^transcript_id} = run ->
        with {:ok, run} <- ProcessingRuns.mark_processing(run, job.attempt),
             :ok <- broadcast_update(run),
             %Transcript{} = transcript <- get_transcript(advisor_id, transcript_id),
             {:ok, run, segments} <- ensure_cleaned(run, transcript),
             {:ok, chunks} <- ensure_chunks(run, segments),
             :ok <- extract_all_chunks(run, chunks),
             :ok <- consolidate(run, segments),
             {:ok, _completed} <- ProcessingRuns.mark_completed(Repo.get!(ProcessingRun, run.id)) do
          broadcast_update(run)
          :ok
        else
          nil -> {:discard, :transcript_not_found}
          {:error, {:chunk_failed, chunk_id, reason}} ->
            fail_run(run_id, advisor_id, "Chunk #{chunk_id} exhausted its retry policy: #{inspect(reason)}")
            {:discard, :chunk_retry_exhausted}
          {:error, reason} -> handle_failure(run_id, advisor_id, job, reason)
          _ -> handle_failure(run_id, advisor_id, job, :processing_failed)
        end
      nil -> {:discard, :processing_run_not_found}
      _ -> {:discard, :processing_run_transcript_mismatch}
    end
  rescue
    error -> handle_failure(run_id, advisor_id, job, {:worker_exception, error})
  end

  defp ensure_cleaned(%ProcessingRun{cleaned_content: content, cleaned_segments: %{"segments" => segments}} = run, _transcript)
       when is_binary(content) and is_list(segments) and segments != [] do
    {:ok, run, Enum.map(segments, &normalize_segment/1)}
  end

  defp ensure_cleaned(run, transcript) do
    with {:ok, cleaned} <- AI.clean_transcript(
           transcript.content,
           %{version: run.prompt_version, content: run.prompt_snapshot, sha256: run.prompt_sha256},
           run.guardrails_snapshot,
           run.model
         ),
         {:ok, segments} <- build_source_segments(transcript.content, cleaned),
         {:ok, updated} <- persist_cleaned(run, cleaned, segments) do
      {:ok, updated, segments}
    end
  end

  defp build_source_segments(original, cleaned) do
    if not cleaned_segments_map_to_output?(cleaned.cleaned_content, cleaned.segments) do
      {:error, :invalid_cleaned_segment_mapping}
    else
    {segments, _clean_cursor, _source_byte_cursor} =
      cleaned.segments
      |> Enum.with_index(1)
      |> Enum.reduce({[], 0, 0}, fn {segment, index}, {acc, clean_cursor, source_cursor} ->
        quote = segment.source_quote
        text = segment.cleaned_text
        source_byte_start = find_binary(original, quote, source_cursor)
        source_start = if is_nil(source_byte_start), do: nil, else: String.length(binary_part(original, 0, source_byte_start))
        source_end = if source_start, do: source_start + String.length(quote), else: nil
        clean_start = find_binary(cleaned.cleaned_content, text, clean_cursor)
        clean_end = clean_start + byte_size(text)
        item = %{
          id: "segment_#{String.pad_leading(Integer.to_string(index), 5, "0")}",
          source_quote: quote, cleaned_text: text,
          cleaned_start: clean_start, cleaned_end: clean_end,
          source_start: source_start, source_end: source_end,
          speaker: Map.get(segment, :speaker), timestamp: Map.get(segment, :timestamp)
        }
        source_byte_end = if source_byte_start, do: source_byte_start + byte_size(quote), else: source_cursor
        {[item | acc], clean_end, source_byte_end}
      end)

    {:ok, Enum.reverse(segments)}
    end
  end

  defp cleaned_segments_map_to_output?(cleaned_content, segments) do
    Enum.reduce_while(segments, 0, fn segment, cursor ->
      case find_binary(cleaned_content, segment.cleaned_text, cursor) do
        nil -> {:halt, false}
        start -> {:cont, start + byte_size(segment.cleaned_text)}
      end
    end) != false
  end

  defp find_binary(content, needle, start) when is_binary(needle) and needle != "" do
    if start <= byte_size(content) do
      case :binary.match(content, needle, scope: {start, byte_size(content) - start}) do
        {index, _length} -> index
        :nomatch -> nil
      end
    else
      nil
    end
  end

  defp find_binary(_content, _needle, _start), do: nil

  defp normalize_segment(segment) do
    Enum.reduce([:id, :source_quote, :cleaned_text, :cleaned_start, :cleaned_end, :source_start, :source_end, :speaker, :timestamp], %{}, fn key, acc ->
      value = Map.get(segment, Atom.to_string(key), Map.get(segment, key))
      if is_nil(value), do: acc, else: Map.put(acc, key, value)
    end)
  end

  defp persist_cleaned(run, cleaned, segments) do
    run
    |> ProcessingRun.transition_changeset(%{
      cleaned_content: cleaned.cleaned_content,
      cleaned_segments: %{"segments" => segments}
    })
    |> Repo.update()
  end

  defp ensure_chunks(run, segments) do
    existing = Repo.all(from(c in TraceMeet.ProcessingRuns.ProcessingRunChunk, where: c.processing_run_id == ^run.id, order_by: c.sequence))
    if existing != [] do
      {:ok, existing}
    else
      with {:ok, chunks} <- Chunker.split(run.cleaned_content, segments,
             target_tokens: Application.get_env(:trace_meet, :chunk_target_tokens, 6_000),
             max_tokens: Application.get_env(:trace_meet, :chunk_max_tokens, 7_000),
             overlap_tokens: Application.get_env(:trace_meet, :chunk_overlap_tokens, 300)),
           {:ok, persisted} <- Chunks.create_for_run(run, chunks) do
        {:ok, persisted}
      end
    end
  end

  defp extract_all_chunks(run, chunks) do
    max_attempts = Application.get_env(:trace_meet, :chunk_max_attempts, 3)

    Enum.reduce_while(chunks, :ok, fn chunk, :ok ->
      case extract_chunk_with_retries(run, chunk, max_attempts) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:chunk_failed, chunk.id, reason}}}
      end
    end)
  end

  defp extract_chunk_with_retries(_run, %{status: "completed"}, _max_attempts), do: :ok
  defp extract_chunk_with_retries(run, chunk, max_attempts) do
    attempt_chunk(run, chunk, max_attempts)
  end

  defp attempt_chunk(run, chunk, max_attempts) do
    with {:ok, processing} <- Chunks.mark_processing(Repo.get!(TraceMeet.ProcessingRuns.ProcessingRunChunk, chunk.id)),
         {:ok, %{items: items} = result} <- AI.extract_chunk(processing.content, run),
         {:ok, enriched_items} <- attach_evidence_segments(processing, items, segments_for_run(run)),
         {:ok, _saved} <- Chunks.save_extraction_result(processing, %{result | items: enriched_items}) do
      :ok
    else
      {:error, reason} ->
        current = Repo.get!(TraceMeet.ProcessingRuns.ProcessingRunChunk, chunk.id)
        _ = Chunks.mark_failed(current, reason)
        if current.attempt_count < max_attempts and retryable?(reason) do
          Process.sleep(backoff(current.attempt_count))
          attempt_chunk(run, Repo.get!(TraceMeet.ProcessingRuns.ProcessingRunChunk, chunk.id), max_attempts)
        else
          {:error, reason}
        end
      other ->
        current = Repo.get!(TraceMeet.ProcessingRuns.ProcessingRunChunk, chunk.id)
        _ = if current.status == "processing", do: Chunks.mark_failed(current, {:unexpected_chunk_result, other})
        {:error, {:unexpected_chunk_result, other}}
    end
  end

  defp segments_for_run(run) do
    case run.cleaned_segments do
      %{"segments" => segments} -> Enum.map(segments, &normalize_segment/1)
      _ -> []
    end
  end

  defp attach_evidence_segments(chunk, items, segments) do
    chunk_segment_ids = get_in(chunk.source_references || %{}, ["segment_ids"]) || []

    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      quotes = item[:evidence_quotes] || []

      segment_ids =
        Enum.flat_map(quotes, fn quote ->
          if is_binary(quote) and quote != "" do
            case :binary.match(chunk.content, quote) do
              {relative_start, length} ->
                evidence_start = chunk.cleaned_start + relative_start
                evidence_end = evidence_start + length

                segments
                |> Enum.filter(fn segment ->
                  segment.id in chunk_segment_ids and
                    segment[:cleaned_end] > evidence_start and
                    segment[:cleaned_start] < evidence_end
                end)
                |> Enum.map(& &1.id)

              :nomatch -> []
            end
          else
            []
          end
        end)
        |> Enum.uniq()

      if quotes != [] and segment_ids != [] do
        {:cont, {:ok, [Map.put(item, :source_segment_ids, segment_ids) | acc]}}
      else
        {:halt, {:error, :extraction_evidence_not_mapped_to_source_segments}}
      end
    end)
    |> case do
      {:ok, enriched} -> {:ok, Enum.reverse(enriched)}
      error -> error
    end
  end

  defp consolidate(run, segments) do
    extractions = Chunks.list_extractions_for_run(run.id)
    if extractions == [] do
      Extractions.create_proposals(run, [], [], segments) |> case do
        {:ok, _} -> :ok
        error -> error
      end
    else
    payload = Enum.map(extractions, fn extraction ->
      %{categories: extraction.categories, description: extraction.description, owner: extraction.owner,
        deadline: extraction.deadline, confidence: extraction.confidence, uncertainties: extraction.uncertainties,
        evidence_quotes: extraction.evidence_quotes}
    end)

    token_count = Chunker.estimated_tokens(Jason.encode!(payload))
    limit = Application.get_env(:trace_meet, :consolidation_max_tokens, 12_000)

    if token_count > limit do
      {:error, :consolidation_input_exceeds_token_limit}
    else
      with {:ok, %{proposals: proposals}} <- AI.consolidate(payload, run),
           :ok <- validate_consolidated_sources(proposals, length(extractions)),
           {:ok, _proposals} <- Extractions.create_proposals(run, proposals, extractions, segments) do
        :ok
      end
    end
    end
  end

  defp validate_consolidated_sources(proposals, extraction_count) do
    valid = Enum.all?(proposals, fn proposal ->
      indexes = proposal[:source_extraction_indexes] || []
      indexes != [] and Enum.all?(indexes, fn index -> is_integer(index) and index >= 0 and index < extraction_count end)
    end)
    if valid, do: :ok, else: {:error, :invalid_consolidation_source_reference}
  end

  defp retryable?({:groq_http_error, status, _}) when status in [408, 425, 429], do: true
  defp retryable?({:groq_http_error, status, _}) when status >= 500, do: true
  defp retryable?({:groq_request_failed, _}), do: true
  defp retryable?({:worker_exception, _}), do: true
  defp retryable?(_), do: false

  defp backoff(attempt), do: min(round(:math.pow(2, attempt) * 1_000), 15_000)

  defp get_transcript(advisor_id, transcript_id) do
    Repo.one(from(t in Transcript, where: t.id == ^transcript_id and t.advisor_id == ^advisor_id))
  end

  defp fail_run(run_id, advisor_id, message) do
    case ProcessingRuns.get_run(advisor_id, run_id) do
      %ProcessingRun{status: "processing"} = run ->
        ProcessingRuns.mark_failed(run, message)
        broadcast_update(run)
      _ -> :ok
    end
  end

  defp broadcast_update(run) do
    Phoenix.PubSub.broadcast(TraceMeet.PubSub, "advisor:#{run.advisor_id}:processing", {:processing_run_updated, run.transcript_id})
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
      _ -> :ok
    end
    {:error, reason}
  end
end
