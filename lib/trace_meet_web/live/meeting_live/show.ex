defmodule TraceMeetWeb.MeetingLive.Show do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Meetings

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Meetings.get_meeting(socket.assigns.current_user.id, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That meeting could not be found.")
         |> push_navigate(to: ~p"/meetings")}

      meeting ->
        {:ok, assign(socket, meeting: meeting, page_title: meeting.title)}
    end
  end

  @impl true
  def handle_event("archive", _params, socket) do
    case Meetings.archive_meeting(socket.assigns.current_user.id, socket.assigns.meeting.id) do
      {:ok, _meeting} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meeting archived.")
         |> push_navigate(to: ~p"/meetings")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "That meeting could not be found.")
         |> push_navigate(to: ~p"/meetings")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={:meetings}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <.link navigate={~p"/meetings"} class="text-sm font-medium text-[#68756C] hover:text-[#087C43]">← Back to meetings</.link>
        </div>

        <section class="w-full overflow-hidden rounded-2xl border border-[#E5EBE6] bg-white shadow-sm">
          <div class="flex flex-col gap-5 border-b border-[#EEF2EF] p-5 sm:flex-row sm:items-start sm:justify-between sm:p-8">
            <div class="min-w-0">
              <p class="text-xs font-semibold uppercase tracking-wide text-[#087C43]">MEETING RECORD</p>
              <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C]">{@meeting.title}</h1>
              <p class="mt-2 text-sm text-[#68756C]">
                Client:
                <.link navigate={~p"/clients/#{@meeting.client_id}"} class="font-semibold text-[#087C43] hover:underline">{@meeting.client.name}</.link>
              </p>
            </div>
            <div class="flex flex-wrap gap-2">
              <.link navigate={~p"/meetings/#{@meeting.id}/edit"} class="inline-flex items-center justify-center rounded-lg border border-[#DCE5DE] bg-white px-3.5 py-2 text-sm font-semibold text-[#526057] transition hover:bg-[#F5F8F5]">Edit meeting</.link>
              <button type="button" phx-click="archive" phx-confirm="Archive this meeting? It will be removed from your active meeting list." class="inline-flex items-center justify-center rounded-lg border border-[#F0D7D4] bg-white px-3.5 py-2 text-sm font-semibold text-[#A33B32] transition hover:bg-[#FFF7F6]">Archive</button>
            </div>
          </div>

          <div class="grid gap-8 p-5 sm:grid-cols-2 sm:p-8">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">Status</p>
              <p class="mt-2 text-sm font-medium text-[#26352B]">{status_label(@meeting.status)}</p>
            </div>
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">Meeting date and time</p>
              <p class="mt-2 text-sm text-[#26352B]">{meeting_time(@meeting)}</p>
            </div>
            <div class="sm:col-span-2">
              <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">Agenda or notes</p>
              <p class="mt-2 whitespace-pre-wrap text-sm leading-6 text-[#526057]">{description(@meeting.description)}</p>
            </div>
          </div>

          <div class="border-t border-[#EEF2EF] bg-[#FBFCFB] px-5 py-5 sm:px-8">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="text-sm font-semibold text-[#26352B]">Transcript</h2>
                <p class="mt-1 text-xs leading-5 text-[#87938A]">You can add the transcript after creating this meeting. Transcript submission is not required to save the meeting.</p>
              </div>
              <span class="inline-flex w-fit rounded-full bg-[#F1F4F1] px-3 py-1 text-xs font-medium text-[#68756C]">Not added yet</span>
            </div>
          </div>
        </section>
      </div>
    </Layouts.workspace>
    """
  end

  defp status_label("in_progress"), do: "In progress"
  defp status_label(status), do: status |> String.replace("_", " ") |> String.capitalize()

  defp meeting_time(%{status: "scheduled", scheduled_at: %DateTime{} = value} = meeting),
    do: format_meeting_time(value, meeting.time_zone)

  defp meeting_time(%{started_at: %DateTime{} = value} = meeting),
    do: format_meeting_time(value, meeting.time_zone)
  defp meeting_time(_meeting), do: "Not provided"

  defp format_meeting_time(value, time_zone) do
    case DateTime.shift_zone(value, time_zone || "Etc/UTC", Tzdata.TimeZoneDatabase) do
      {:ok, local_value} -> Calendar.strftime(local_value, "%B %d, %Y at %I:%M %p")
      _ -> Calendar.strftime(value, "%B %d, %Y at %I:%M %p UTC")
    end
  end

  defp description(value) when is_binary(value) do
    case String.trim(value) do
      "" -> "No agenda or notes have been added."
      text -> text
    end
  end

  defp description(_), do: "No agenda or notes have been added."
end
