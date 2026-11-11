defmodule TraceMeet.AI.MockProvider do
  def clean_transcript(
        content,
        %{system_prompt: _system_prompt, guardrails_snapshot: _guardrails_snapshot},
        _model
      )
      when is_binary(content) do
    Process.sleep(Enum.random(10_000..60_000))

    segments =
      content
      |> String.split("\n")
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(fn line -> %{source_quote: line, cleaned_text: String.trim(line)} end)

    cleaned_content = Enum.map_join(segments, "\n", & &1.cleaned_text)

    {:ok, %{cleaned_content: cleaned_content, segments: segments}}
  end

  def extract_chunk(content, _context, _model) do
    Process.sleep(Enum.random(10_000..30_000))

    quote =
      content
      |> String.split("\n", trim: true)
      |> Enum.find(&(String.trim(&1) != ""))
      |> case do
        nil -> ""
        line -> String.slice(String.trim(line), 0, 120)
      end

    items =
      if quote == "" do
        []
      else
        [
          %{
            categories: ["action_item"],
            description: "Mock extraction based on: " <> quote,
            owner: nil,
            deadline: nil,
            confidence: nil,
            uncertainties: %{"items" => ["Synthetic MockProvider fixture; not a semantic assessment."]},
            evidence_quotes: [quote]
          }
        ]
      end

    {:ok, %{items: items}}
  end

  def consolidate(extractions, _context, _model) do
    Process.sleep(Enum.random(10_000..30_000))

    proposals =
      extractions
      |> Enum.with_index()
      |> Enum.map(fn {extraction, index} ->
        Map.put(extraction, :source_extraction_indexes, [index])
      end)

    {:ok, %{proposals: proposals}}
  end
end
