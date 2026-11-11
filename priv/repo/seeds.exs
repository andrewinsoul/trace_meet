defmodule TraceMeet.AI.GuardrailSeeder do
  alias TraceMeet.AI.{Guardrail, GuardrailVersion}
  alias TraceMeet.Repo

  def seed_guardrail(key, name, instruction, scope, meeting_type) do
    guardrail =
      Repo.get_by(Guardrail, key: key) ||
        Repo.insert!(
          Guardrail.changeset(%Guardrail{}, %{
            key: key,
            name: name,
            active_version: 1,
            scope: scope,
            meeting_type: meeting_type
          })
        )

    hash = :crypto.hash(:sha256, instruction) |> Base.encode16(case: :lower)

    unless Repo.get_by(GuardrailVersion, guardrail_id: guardrail.id, version: 1) do
      Repo.insert!(
        GuardrailVersion.changeset(%GuardrailVersion{guardrail_id: guardrail.id}, %{
          version: 1,
          instruction: instruction,
          sha256: hash
        })
      )
    end

    guardrail
  end
end

alias TraceMeet.AI.GuardrailSeeder

global_guardrails = [
  {"evidence_required", "Evidence required",
   "Every extracted decision, action, commitment, risk, blocker, or unresolved question must be supported by identifiable evidence from the original transcript. Never fabricate quotations or source references."},
  {"no_fabrication", "No fabrication",
   "Never invent facts, events, decisions, agreements, context, or outcomes that are not supported by the transcript."},
  {"no_invented_owners", "No invented owners",
   "Never infer or invent an owner. If the transcript does not clearly identify the responsible person, leave the owner unset and flag the uncertainty."},
  {"no_invented_deadlines", "No invented deadlines",
   "Never invent, calculate, or assume a deadline. Preserve the exact date or time expression when stated; otherwise leave the deadline unset."},
  {"commitment_integrity", "Commitment integrity",
   "Do not convert suggestions, possibilities, intentions, or conditional statements into confirmed commitments. Preserve acceptance, rejection, and conditional language."},
  {"decision_history", "Decision history",
   "Preserve superseded decisions alongside the current decision when the change or its rationale matters. Do not present an obsolete decision as current."},
  {"uncertainty", "Preserve uncertainty",
   "When meaning, ownership, timing, or commitment status is ambiguous, retain the ambiguity and flag it. Do not guess to fill missing information."},
  {"speaker_attribution", "Speaker attribution",
   "Attribute statements only to speakers identified by the transcript. Never guess a speaker's identity."},
  {"original_immutable", "Original transcript integrity",
   "Treat the original transcript as immutable source material. Cleaning and analysis must not alter or replace it."}
]

meeting_type_guardrails = [
  {"business_strategy_targets", "Preserve strategic targets",
   "Distinguish current business targets from previous or superseded targets. Preserve material changes and the stated reasons for them.",
   "business_strategy"},
  {"financial_actuals_vs_estimates", "Distinguish actuals and estimates",
   "Clearly distinguish reported actual financial figures from forecasts, estimates, assumptions, and proposed budgets. Never present an estimate as an actual result.",
   "financial_review"},
  {"project_milestone_status", "Distinguish milestone status",
   "Distinguish completed, in-progress, blocked, and planned milestones. Do not describe a planned deliverable as completed.",
   "project_review"},
  {"performance_feedback_context", "Preserve performance feedback context",
   "Preserve the context of feedback, agreed improvement areas, and responses or disagreements. Do not turn subjective feedback into an established fact.",
   "performance_review"},
  {"career_advice_vs_commitment", "Distinguish career advice and commitments",
   "Distinguish career suggestions and options discussed from actions the client or advisor explicitly agreed to take.",
   "career_advisory"},
  {"planning_goals_and_actions", "Distinguish goals and actions",
   "Separate desired outcomes and aspirational goals from concrete actions, owners, and deadlines that were actually agreed.",
   "planning_goal_setting"}
]

Enum.each(global_guardrails, fn {key, name, instruction} ->
  GuardrailSeeder.seed_guardrail(key, name, instruction, "global", nil)
end)

Enum.each(meeting_type_guardrails, fn {key, name, instruction, meeting_type} ->
  GuardrailSeeder.seed_guardrail(key, name, instruction, "meeting_type", meeting_type)
end)
