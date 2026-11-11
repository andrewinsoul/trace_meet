defmodule TraceMeet.AI do
  def clean_transcript(content, prompt_snapshot, guardrails_snapshot, model)
      when is_binary(content) and is_map(prompt_snapshot) and is_map(guardrails_snapshot) and
             is_binary(model) do
    provider = Application.get_env(:trace_meet, :ai_provider, TraceMeet.AI.MockProvider)

    provider.clean_transcript(
      content,
      %{system_prompt: prompt_snapshot.content, guardrails_snapshot: guardrails_snapshot},
      model
    )
  end

  def extract_chunk(content, run) when is_binary(content) do
    provider = Application.get_env(:trace_meet, :ai_provider, TraceMeet.AI.MockProvider)

    provider.extract_chunk(
      content,
      %{
        system_prompt: stage_prompt(run, "chunk extraction"),
        guardrails_snapshot: run.guardrails_snapshot
      },
      run.model
    )
  end

  def consolidate(extractions, run) when is_list(extractions) do
    provider = Application.get_env(:trace_meet, :ai_provider, TraceMeet.AI.MockProvider)

    provider.consolidate(
      extractions,
      %{
        system_prompt: stage_prompt(run, "meeting-level consolidation"),
        guardrails_snapshot: run.guardrails_snapshot
      },
      run.model
    )
  end

  defp stage_prompt(run, stage) do
    guardrails = Map.get(run.guardrails_snapshot, "guardrails", [])

    guardrail_text =
      Enum.map_join(guardrails, "\n", fn guardrail ->
        instruction = Map.get(guardrail, "instruction", Map.get(guardrail, :instruction, ""))
        "- " <> instruction
      end)

    """
    You are TraceMeet's #{stage} engine. Follow the platform guardrails exactly.

    ADVISOR CONTEXT AND EMPHASIS:
    #{run.advisor_prompt_snapshot || "No additional advisor instructions."}

    PLATFORM GUARDRAILS (MANDATORY):
    #{guardrail_text}
    """
  end
end
