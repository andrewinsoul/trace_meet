defmodule TraceMeet.Meetings.Types do
  @types [
    {"General Consultation", "general_consultation"},
    {"Business Strategy", "business_strategy"},
    {"Financial Review", "financial_review"},
    {"Project Review", "project_review"},
    {"Performance Review", "performance_review"},
    {"Career Advisory", "career_advisory"},
    {"Planning & Goal Setting", "planning_goal_setting"},
    {"Other", "other"}
  ]

  def all, do: @types
  def values, do: Enum.map(@types, &elem(&1, 1))

  def label(value) do
    case(Enum.find(@types, &(elem(&1, 1) == value))) do
      {label, _} -> label
      _ -> value
    end
  end
end
