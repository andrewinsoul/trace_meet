defmodule TraceMeet.AI do
  def clean_transcript(content, prompt_snapshot, guardrails_snapshot, model)
      when is_binary(content) and is_map(prompt_snapshot) and is_map(guardrails_snapshot) and
             is_binary(model) do
    provider =
      Application.get_env(:trace_meet, :ai_provider, TraceMeet.AI.MockProvider)

    provider.clean_transcript(
      content,
      %{
        system_prompt: prompt_snapshot.content,
        guardrails_snapshot: guardrails_snapshot
      },
      model
    )
  end
end
