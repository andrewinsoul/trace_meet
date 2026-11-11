defmodule TraceMeetWeb.MeetingLive.Index do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Meetings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_meetings(socket, 1)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_meetings(socket, Map.get(params, "page", "1"))}
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    case Meetings.archive_meeting(socket.assigns.current_user.id, id) do
      {:ok, _meeting} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meeting archived.")
         |> load_meetings(socket.assigns.pagination.page)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That meeting could not be found.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={:meetings}>
      <div class="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="text-sm font-medium tracking-wide text-[#087C43]">CLIENT CONVERSATIONS</p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
            Meetings
          </h1>
          <p class="mt-2 text-sm leading-6 text-[#68756C] sm:text-base">
            Keep planned and completed client conversations in one place.
          </p>
        </div>
        <.link
          navigate={~p"/meetings/new"}
          class="inline-flex items-center justify-center gap-2 rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-[#066B39]"
        >
          <span class="text-lg leading-none">+</span> Add meeting
        </.link>
      </div>

      <section class="overflow-hidden rounded-2xl border border-[#E5EBE6] bg-white shadow-sm">
        <div class="border-b border-[#EEF2EF] px-5 py-4 sm:px-6">
          <h2 class="font-semibold text-[#26352B]">All meetings</h2>
          <p class="mt-1 text-xs text-[#87938A]">
            {ngettext("%{count} meeting", "%{count} meetings", @pagination.total_entries)}
          </p>
        </div>

        <div
          :if={@meetings == []}
          class="flex min-h-[280px] flex-col items-center justify-center px-6 py-12 text-center"
        >
          <div class="flex h-14 w-14 items-center justify-center rounded-2xl bg-[#EAF5EE] text-[#087C43]">
            <Layouts.nav_icon name="meetings" class="h-7 w-7" />
          </div>
          <h3 class="mt-5 text-lg font-semibold text-[#26352B]">No meetings yet</h3>
          <p class="mt-2 max-w-md text-sm leading-6 text-[#68756C]">
            Create a meeting before it happens, or record a conversation after you've had it.
          </p>
          <.link
            navigate={~p"/meetings/new"}
            class="mt-5 inline-flex items-center rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-[#066B39]"
          >
            Add your first meeting
          </.link>
        </div>

        <div :if={@meetings != []} class="divide-y divide-[#EEF2EF]">
          <article
            :for={meeting <- @meetings}
            class="flex flex-col gap-3 px-5 py-4 transition hover:bg-[#FBFCFB] sm:flex-row sm:items-center sm:px-6"
          >
            <div class="min-w-0 flex-1">
              <.link
                navigate={~p"/meetings/#{meeting.id}"}
                class="block truncate text-sm font-semibold text-[#26352B] hover:text-[#087C43]"
              >
                {meeting.title}
              </.link>
              <p class="mt-1 truncate text-xs text-[#87938A]">
                {meeting.client.name} · {meeting_time(meeting)}
              </p>
            </div>
            <div class="flex items-center justify-between gap-3 sm:justify-end">
              <span class={status_class(meeting.status)}>{status_label(meeting.status)}</span>
              <.link
                navigate={~p"/meetings/#{meeting.id}"}
                class="rounded-md px-2.5 py-1.5 text-xs font-semibold text-[#087C43] hover:bg-[#EAF5EE]"
              >
                View
              </.link>
              <button
                type="button"
                phx-click="archive"
                phx-value-id={meeting.id}
                phx-confirm="Archive this meeting?"
                class="rounded-md px-2.5 py-1.5 text-xs font-semibold text-[#A33B32] hover:bg-[#FFF7F6]"
              >
                Archive
              </button>
            </div>
          </article>
        </div>

        <div
          :if={@pagination.total_pages > 1}
          class="flex items-center justify-between border-t border-[#EEF2EF] px-5 py-3 sm:px-6"
        >
          <p class="text-xs text-[#87938A]">Page {@pagination.page} of {@pagination.total_pages}</p>
          <div class="flex gap-2">
            <.link
              patch={page_path(@pagination.page - 1)}
              aria-disabled={@pagination.page <= 1}
              class={[
                "rounded-lg border px-3 py-2 text-xs font-medium",
                @pagination.page <= 1 && "pointer-events-none opacity-40",
                @pagination.page > 1 && "border-[#DCE5DE] text-[#526057] hover:bg-[#F5F8F5]"
              ]}
            >
              Previous
            </.link>
            <.link
              patch={page_path(@pagination.page + 1)}
              aria-disabled={@pagination.page >= @pagination.total_pages}
              class={[
                "rounded-lg border px-3 py-2 text-xs font-medium",
                @pagination.page >= @pagination.total_pages && "pointer-events-none opacity-40",
                @pagination.page < @pagination.total_pages &&
                  "border-[#DCE5DE] text-[#526057] hover:bg-[#F5F8F5]"
              ]}
            >
              Next
            </.link>
          </div>
        </div>
      </section>
    </Layouts.workspace>
    """
  end

  defp load_meetings(socket, page) do
    pagination = Meetings.list_meetings(socket.assigns.current_user.id, page: page, per_page: 10)

    assign(socket,
      page_title: "Meetings",
      meetings: pagination.entries,
      pagination: pagination
    )
  end

  defp meeting_time(%{status: "scheduled", scheduled_at: %DateTime{} = value} = meeting),
    do: "Scheduled for " <> format_meeting_time(value, meeting.time_zone)

  defp meeting_time(%{started_at: %DateTime{} = value} = meeting),
    do: "Met " <> format_meeting_time(value, meeting.time_zone)

  defp meeting_time(_meeting), do: "Date not set"

  defp format_meeting_time(value, time_zone) do
    case DateTime.shift_zone(value, time_zone || "Etc/UTC", Tzdata.TimeZoneDatabase) do
      {:ok, local_value} -> Calendar.strftime(local_value, "%b %d, %Y at %I:%M %p")
      _ -> Calendar.strftime(value, "%b %d, %Y at %I:%M %p UTC")
    end
  end

  defp status_label("in_progress"), do: "In progress"
  defp status_label(status), do: status |> String.replace("_", " ") |> String.capitalize()

  defp status_class("completed"),
    do: "rounded-full bg-[#EAF5EE] px-3 py-1 text-xs font-medium text-[#087C43]"

  defp status_class("cancelled"),
    do: "rounded-full bg-[#F3F4F3] px-3 py-1 text-xs font-medium text-[#68756C]"

  defp status_class("in_progress"),
    do: "rounded-full bg-[#FFF4DF] px-3 py-1 text-xs font-medium text-[#93620A]"

  defp status_class(_),
    do: "rounded-full bg-[#EAF1FA] px-3 py-1 text-xs font-medium text-[#365D91]"

  defp page_path(page), do: "/meetings?#{URI.encode_query(%{page: page})}"
end
