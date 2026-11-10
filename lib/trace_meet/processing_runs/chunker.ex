defmodule TraceMeet.ProcessingRuns.Chunker do
  @moduledoc false

  @target_tokens 6_000
  @max_tokens 7_000
  @overlap_tokens 300

  def split(content, segments, opts \\ []) when is_binary(content) and is_list(segments) do
    target = Keyword.get(opts, :target_tokens, @target_tokens)
    max_tokens = Keyword.get(opts, :max_tokens, @max_tokens)
    overlap = Keyword.get(opts, :overlap_tokens, @overlap_tokens)

    paragraphs =
      Regex.scan(~r/[^\n]+(?:\n+|$)/u, content, return: :index)
      |> Enum.map(fn [{start, length}] -> {start, start + length, binary_part(content, start, length)} end)
      |> Enum.reject(fn {_start, _end, text} -> String.trim(text) == "" end)
      |> Enum.flat_map(&split_oversized(&1, max_tokens))

    if paragraphs == [] do
      {:error, :empty_cleaned_transcript}
    else
      build_chunks(paragraphs, segments, target, max_tokens, overlap, [])
    end
  end

  def estimated_tokens(text) when is_binary(text) do
    # Conservative estimate until a tokenizer for the configured model is installed.
    words = Regex.scan(~r/[\p{L}\p{N}]+|[^\s\p{L}\p{N}]/u, text)
    max(length(words), div(byte_size(text) + 3, 4))
  end

  defp build_chunks([], _segments, _target, _max, _overlap, acc), do: {:ok, Enum.reverse(acc)}

  defp build_chunks(paragraphs, segments, target, max_tokens, overlap, acc) do
    case take_chunk(paragraphs, target, max_tokens, [], 0) do
      {:error, reason} -> {:error, reason}
      {selected, rest} ->
        [{start_offset, _first_end, _} | _] = selected
        end_offset = selected |> List.last() |> elem(1)
        text = Enum.map_join(selected, "", &elem(&1, 2))
        references =
          segments
          |> Enum.filter(fn segment ->
            segment_end = segment[:cleaned_end] || 0
            segment_start = segment[:cleaned_start] || 0
            segment_end > start_offset and segment_start < end_offset
          end)
          |> Enum.map(& &1.id)

        chunk = %{
          content: text,
          token_count: estimated_tokens(text),
          cleaned_start: start_offset,
          cleaned_end: end_offset,
          source_references: %{"segment_ids" => references}
        }

        next = overlap_tail(selected, overlap) ++ rest
        cond do
          rest == [] -> {:ok, Enum.reverse([chunk | acc])}
          next == paragraphs -> {:error, :chunker_no_progress}
          true -> build_chunks(next, segments, target, max_tokens, overlap, [chunk | acc])
        end
    end
  end


  defp split_oversized({start_offset, _end_offset, text}, max_tokens) do
    if estimated_tokens(text) <= max_tokens do
      [{start_offset, start_offset + byte_size(text), text}]
    else
      sentence_parts = indexed_parts(text, ~r/[^.!?]+[.!?]?(?:\s+|$)/u)
      sentence_parts = if sentence_parts == [], do: indexed_parts(text, ~r/\S+\s*/u), else: sentence_parts

      Enum.flat_map(sentence_parts, fn {relative_start, relative_end, sentence} ->
        if estimated_tokens(sentence) <= max_tokens do
          [{start_offset + relative_start, start_offset + relative_end, sentence}]
        else
          indexed_parts(sentence, ~r/\S+\s*/u)
          |> group_word_parts(start_offset + relative_start, max_tokens)
        end
      end)
    end
  end

  defp indexed_parts(text, regex) do
    Regex.scan(regex, text, return: :index)
    |> Enum.map(fn [{start, length}] -> {start, start + length, binary_part(text, start, length)} end)
    |> Enum.reject(fn {_start, _end, part} -> part == "" end)
  end

  defp group_word_parts(parts, base_offset, max_tokens) do
    {groups, current, _count, current_start, _last_end} =
      Enum.reduce(parts, {[], [], 0, nil, nil}, fn {start, finish, text}, {groups, current, count, current_start, _last_end} ->
        size = estimated_tokens(text)
        if current != [] and count + size > max_tokens do
          group_text = Enum.map_join(current, "", &elem(&1, 2))
          group_start = current_start
          group_end = elem(List.last(current), 1)
          {[{base_offset + group_start, base_offset + group_end, group_text} | groups], [{start, finish, text}], size, start, finish}
        else
          {groups, current ++ [{start, finish, text}], count + size, current_start || start, finish}
        end
      end)

    final =
      if current == [], do: groups, else: [{base_offset + current_start, base_offset + elem(List.last(current), 1), Enum.map_join(current, "", &elem(&1, 2))} | groups]

    Enum.reverse(final)
  end

  defp take_chunk([], _target, _max, [], _count), do: {:error, :empty_chunk}
  defp take_chunk([], _target, _max, selected, _count), do: {Enum.reverse(selected), []}
  defp take_chunk([{_s, _e, text} = paragraph | rest], target, max, selected, count) do
    size = estimated_tokens(text)
    cond do
      count + size > max and selected != [] -> {Enum.reverse(selected), [paragraph | rest]}
      count + size > max -> {:error, :paragraph_exceeds_max_chunk_size}
      count + size >= target -> {Enum.reverse([paragraph | selected]), rest}
      true -> take_chunk(rest, target, max, [paragraph | selected], count + size)
    end
  end

  defp overlap_tail(selected, overlap) do
    last = List.last(selected)

    if estimated_tokens(elem(last, 2)) > overlap do
      []
    else
      selected
    |> Enum.reverse()
    |> Enum.reduce_while({[], 0}, fn paragraph, {acc, count} ->
      size = estimated_tokens(elem(paragraph, 2))
      if count >= overlap, do: {:halt, {acc, count}}, else: {:cont, {[paragraph | acc], count + size}}
    end)
    |> elem(0)
    end
  end
end
