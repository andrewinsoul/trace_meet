defmodule TraceMeet.AI.Configuration do
  import Ecto.Query

  alias TraceMeet.AI.{AdvisorPrompt, AdvisorPromptVersion, Guardrail, GuardrailVersion}
  alias TraceMeet.Repo

  def list_guardrails do
    Repo.all(
      from(g in Guardrail,
        order_by: g.name,
        preload: [versions: ^from(v in GuardrailVersion, order_by: [desc: v.version])]
      )
    )
  end

  def list_advisor_prompts(advisor_id) do
    Repo.all(
      from(p in AdvisorPrompt,
        where: p.advisor_id == ^advisor_id,
        order_by: [desc: p.is_default, asc: p.name],
        preload: [versions: ^from(v in AdvisorPromptVersion, order_by: [desc: v.version])]
      )
    )
  end

  def get_advisor_prompt(advisor_id, prompt_id) do
    Repo.one(
      from(p in AdvisorPrompt,
        where: p.id == ^prompt_id and p.advisor_id == ^advisor_id,
        preload: [versions: ^from(v in AdvisorPromptVersion, order_by: [desc: v.version])]
      )
    )
  end

  def create_advisor_prompt(advisor_id, attrs) do
    instructions = String.trim(attrs["instructions"] || "")

    Repo.transaction(fn ->
      first_prompt? = not advisor_has_prompts?(advisor_id)

      prompt_attrs = %{
        advisor_id: advisor_id,
        name: attrs["name"],
        meeting_type: attrs["meeting_type"] || "general_consultation",
        other_meeting_type: attrs["other_meeting_type"],
        active_version: 1,
        is_default: first_prompt? or attrs["is_default"] in ["true", true]
      }

      changeset = AdvisorPrompt.changeset(%AdvisorPrompt{}, prompt_attrs)
      prompt = Repo.insert!(changeset)

      if prompt.is_default do
        clear_default(advisor_id, prompt.id)
      end

      Repo.insert!(version_changeset(prompt.id, 1, instructions))
      prompt
    end)
  end

  def set_default(advisor_id, prompt_id) do
    case get_advisor_prompt(advisor_id, prompt_id) do
      nil -> {:error, :not_found}
      prompt ->
        Repo.transaction(fn ->
          clear_default(advisor_id, prompt.id)
          prompt |> AdvisorPrompt.changeset(%{is_default: true}) |> Repo.update!()
        end)
    end
  end

  def active_prompt_snapshot(advisor_id) do
    prompt =
      Repo.one(
        from(p in AdvisorPrompt,
          where: p.advisor_id == ^advisor_id and p.is_default,
          preload: [:versions]
        )
      )

    case prompt do
      nil -> nil
      prompt ->
        version = Enum.find(prompt.versions, &(&1.version == prompt.active_version))
        %{id: prompt.id, name: prompt.name, version: version.version,
          instructions: version.instructions, sha256: version.sha256}
    end
  end

  def guardrails_snapshot(meeting_type \\ nil) do
    Repo.all(
      from(g in Guardrail,
        join: v in GuardrailVersion,
        on: v.guardrail_id == g.id and v.version == g.active_version,
        where: g.active_version > 0 and (g.scope == "global" or g.meeting_type == ^meeting_type),
        order_by: g.key,
        select: %{id: g.id, key: g.key, version: v.version,
          name: g.name, instruction: v.instruction, sha256: v.sha256}
      )
    )
  end

  defp advisor_has_prompts?(advisor_id) do
    Repo.exists?(from(p in AdvisorPrompt, where: p.advisor_id == ^advisor_id))
  end

  defp clear_default(advisor_id, except_id) do
    query =
      from(p in AdvisorPrompt,
        where: p.advisor_id == ^advisor_id and p.is_default
      )

    query =
      if except_id do
        from(p in query, where: p.id != ^except_id)
      else
        query
      end

    Repo.update_all(query, set: [is_default: false, updated_at: DateTime.utc_now()])
  end

  defp version_changeset(prompt_id, version, instructions) do
    AdvisorPromptVersion.changeset(%AdvisorPromptVersion{}, %{
      advisor_prompt_id: prompt_id,
      version: version,
      instructions: instructions,
      sha256: hash(instructions)
    })
  end

  defp hash(content), do: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
end
