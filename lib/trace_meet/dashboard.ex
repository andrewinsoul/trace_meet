defmodule TraceMeet.Dashboard do
  import Ecto.Query, warn: false

  alias TraceMeet.Repo
  alias TraceMeet.Clients.Client
  alias TraceMeet.Meetings.Meeting
  alias TraceMeet.Extractions.ExtractionProposal
  alias TraceMeet.ProcessingRuns.ProcessingRun

  def overview(advisor_id) do
    now = DateTime.utc_now()

    active_meetings =
      from(m in Meeting,
        join: c in assoc(m, :client),
        where:
          m.user_id == ^advisor_id and c.user_id == ^advisor_id and
            is_nil(m.archived_at) and is_nil(c.archived_at)
      )

    %{
      client_count:
        Repo.aggregate(
          from(c in Client, where: c.user_id == ^advisor_id and is_nil(c.archived_at)),
          :count,
          :id
        ),
      meeting_count: Repo.aggregate(active_meetings, :count, :id),
      completed_meeting_count:
        Repo.aggregate(
          from(m in active_meetings, where: m.status == "completed"),
          :count,
          :id
        ),
      pending_action_count:
        Repo.aggregate(
          from(p in ExtractionProposal,
            join: r in ProcessingRun,
            on: r.id == p.processing_run_id,
            where:
              r.advisor_id == ^advisor_id and p.status == "pending" and
                p.category == "action_item"
          ),
          :count,
          :id
        ),
      recent_meetings:
        active_meetings
        |> preload(:client)
        |> order_by([m], desc: coalesce(m.started_at, m.scheduled_at), desc: m.inserted_at)
        |> limit(5)
        |> Repo.all(),
      upcoming_meetings:
        active_meetings
        |> where([m], m.status == "scheduled" and m.scheduled_at > ^now)
        |> preload(:client)
        |> order_by([m], asc: m.scheduled_at)
        |> limit(5)
        |> Repo.all()
    }
  end
end
