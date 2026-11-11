defmodule TraceMeetWeb.DashboardLive do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_dashboard(socket)}
  end

  defp load_dashboard(socket) do
    user = socket.assigns.current_user
    data = Dashboard.overview(user.id)

    assign(socket,
      page_title: "Dashboard",
      active_page: :dashboard,
      client_count: data.client_count,
      meeting_count: data.meeting_count,
      completed_meeting_count: data.completed_meeting_count,
      pending_action_count: data.pending_action_count,
      recent_meetings: data.recent_meetings,
      upcoming_meetings: data.upcoming_meetings,
      time_zone: user.time_zone || "Etc/UTC"
    )
  end

  defp meeting_time(%DateTime{} = datetime, time_zone) do
    case DateTime.shift_zone(datetime, time_zone, Tzdata.TimeZoneDatabase) do
      {:ok, local_datetime} -> Calendar.strftime(local_datetime, "%b %d, %Y · %I:%M %p")
      _ -> Calendar.strftime(datetime, "%b %d, %Y · %I:%M %p")
    end
  end

  defp meeting_time(_, _), do: "Not scheduled"

  defp status_label("scheduled"), do: "Scheduled"
  defp status_label("in_progress"), do: "In progress"
  defp status_label("completed"), do: "Completed"
  defp status_label("cancelled"), do: "Cancelled"
  defp status_label(status), do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_user={@current_user}
      active_page={@active_page}
    >
      <div class="mb-7 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="text-sm font-medium text-[#087C43]">YOUR WORKSPACE</p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
            Good to see you
          </h1>
          <p class="mt-2 text-sm leading-6 text-[#68756C]">
            Here’s your workspace at a glance.
          </p>
        </div>
        <.link
          navigate={~p"/meetings/new"}
          class="inline-flex items-center justify-center rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-[#066B39]"
        >
          Schedule a meeting
        </.link>
      </div>

      <section aria-label="Workspace summary" class="mb-8 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <.summary_card label="Total clients" value={@client_count} />
        <.summary_card label="Total meetings" value={@meeting_count} />
        <.summary_card label="Pending action items" value={@pending_action_count} />
        <.summary_card label="Completed meetings" value={@completed_meeting_count} />
      </section>

      <div class="grid grid-cols-1 gap-6 xl:grid-cols-5">
        <section class="overflow-hidden rounded-xl border border-[#E4EAE5] bg-white xl:col-span-3">
          <div class="flex items-center justify-between border-b border-[#EEF2EF] px-5 py-4">
            <div>
              <h2 class="text-base font-semibold text-[#17231C]">Recent meetings</h2>
              <p class="mt-1 text-sm text-[#87938A]">Your latest client conversations</p>
            </div>
            <.link navigate={~p"/meetings"} class="text-sm font-semibold text-[#087C43] hover:underline">
              View all
            </.link>
          </div>
          <div :if={@recent_meetings == []} class="px-5 py-10 text-center">
            <p class="text-sm font-medium text-[#526057]">No meetings yet</p>
            <p class="mt-1 text-sm text-[#87938A]">Your recent meetings will appear here.</p>
            <.link navigate={~p"/meetings/new"} class="mt-4 inline-flex text-sm font-semibold text-[#087C43] hover:underline">
              Create your first meeting
            </.link>
          </div>
          <div :if={@recent_meetings != []} class="divide-y divide-[#EEF2EF]">
            <.link
              :for={meeting <- @recent_meetings}
              navigate={~p"/meetings/#{meeting.id}"}
              class="flex flex-col gap-1 px-5 py-4 transition hover:bg-[#FAFCFA] sm:flex-row sm:items-center sm:justify-between"
            >
              <div class="min-w-0">
                <p class="truncate text-sm font-semibold text-[#26352B]">{meeting.title}</p>
                <p class="mt-1 truncate text-xs text-[#87938A]">{meeting.client.name}</p>
              </div>
              <div class="flex shrink-0 items-center gap-3">
                <span class="text-xs text-[#68756C]">
                  {meeting_time(meeting.started_at || meeting.scheduled_at, @time_zone)}
                </span>
                <span class={[
                  "rounded-full px-2.5 py-1 text-xs font-medium",
                  meeting.status == "completed" && "bg-[#EAF5EE] text-[#087C43]",
                  meeting.status != "completed" && "bg-[#F2F5F2] text-[#59665D]"
                ]}>
                  {status_label(meeting.status)}
                </span>
              </div>
            </.link>
          </div>
        </section>

        <section class="overflow-hidden rounded-xl border border-[#E4EAE5] bg-white xl:col-span-2">
          <div class="flex items-center justify-between border-b border-[#EEF2EF] px-5 py-4">
            <div>
              <h2 class="text-base font-semibold text-[#17231C]">Upcoming meetings</h2>
              <p class="mt-1 text-sm text-[#87938A]">What’s next on your calendar</p>
            </div>
            <.link navigate={~p"/meetings"} class="text-sm font-semibold text-[#087C43] hover:underline">
              View all
            </.link>
          </div>
          <div :if={@upcoming_meetings == []} class="px-5 py-10 text-center">
            <p class="text-sm font-medium text-[#526057]">Nothing scheduled</p>
            <p class="mt-1 text-sm text-[#87938A]">Upcoming meetings will appear here.</p>
            <.link navigate={~p"/meetings/new"} class="mt-4 inline-flex text-sm font-semibold text-[#087C43] hover:underline">
              Schedule a meeting
            </.link>
          </div>
          <div :if={@upcoming_meetings != []} class="divide-y divide-[#EEF2EF]">
            <.link
              :for={meeting <- @upcoming_meetings}
              navigate={~p"/meetings/#{meeting.id}"}
              class="block px-5 py-4 transition hover:bg-[#FAFCFA]"
            >
              <p class="truncate text-sm font-semibold text-[#26352B]">{meeting.title}</p>
              <p class="mt-1 truncate text-xs text-[#68756C]">{meeting.client.name}</p>
              <p class="mt-2 text-xs font-medium text-[#087C43]">
                {meeting_time(meeting.scheduled_at, @time_zone)}
              </p>
            </.link>
          </div>
        </section>
      </div>

      <section class="mt-6 rounded-xl border border-[#E4EAE5] bg-white px-5 py-4">
        <h2 class="text-sm font-semibold text-[#26352B]">Quick actions</h2>
        <div class="mt-3 flex flex-wrap gap-3">
          <.link navigate={~p"/clients/new"} class="rounded-lg border border-[#DCE5DE] px-3.5 py-2 text-sm font-medium text-[#526057] transition hover:border-[#087C43] hover:text-[#087C43]">
            Add a client
          </.link>
          <.link navigate={~p"/meetings/new"} class="rounded-lg border border-[#DCE5DE] px-3.5 py-2 text-sm font-medium text-[#526057] transition hover:border-[#087C43] hover:text-[#087C43]">
            Schedule a meeting
          </.link>
          <.link navigate={~p"/actions"} class="rounded-lg border border-[#DCE5DE] px-3.5 py-2 text-sm font-medium text-[#526057] transition hover:border-[#087C43] hover:text-[#087C43]">
            Review action items
          </.link>
        </div>
      </section>
    </Layouts.workspace>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp summary_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-[#E4EAE5] bg-white px-5 py-4">
      <p class="text-sm font-medium text-[#68756C]">{@label}</p>
      <p class="mt-3 text-3xl font-semibold tracking-tight text-[#17231C] tabular-nums">{@value}</p>
    </div>
    """
  end
end
