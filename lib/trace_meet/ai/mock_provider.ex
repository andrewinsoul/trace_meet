defmodule TraceMeet.AI.MockProvider do
  def clean_transcript(content) when is_binary(content) do
    Process.sleep(Enum.random(120_000..240_000))

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
