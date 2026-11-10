defmodule TraceMeet.AI.MockProvider do
  def clean_transcript(
        content,
        %{system_prompt: _system_prompt, guardrails_snapshot: _guardrails_snapshot},
        _model
      )
      when is_binary(content) do
    Process.sleep(Enum.random(10_000..60_000))

    cleaned_content =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    {:ok,
     %{
       cleaned_content: cleaned_content,
       segments: [
         %{
           source_quote: content,
           cleaned_text: cleaned_content
         }
       ]
     }}
  end
end
