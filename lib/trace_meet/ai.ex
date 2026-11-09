defmodule TraceMeet.AI do
  def clean_transcript(content) when is_binary(content) do
    provider =
      Application.get_env(:trace_meet, :ai_provider, TraceMeet.AI.MockProvider)

    provider.clean_transcript(content)
  end
end
