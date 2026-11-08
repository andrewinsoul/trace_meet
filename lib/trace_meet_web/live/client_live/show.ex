defmodule TraceMeetWeb.ClientLive.Show do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Clients
  alias TraceMeet.Meetings

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Clients.get_client(socket.assigns.current_user.id, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That client could not be found.")
         |> push_navigate(to: ~p"/clients")}

      client ->
        meetings = Meetings.list_meetings(socket.assigns.current_user.id, client_id: client.id, per_page: 10)

        {:ok, assign(socket,
          client: client,
          meetings: meetings.entries,
          page_title: client.name
        )}
    end
  end

  @impl true
  def handle_event("archive", _params, socket) do
    case Clients.archive_client(socket.assigns.current_user.id, socket.assigns.client.id) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client archived.")
         |> push_navigate(to: ~p"/clients")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "That client could not be found.")
         |> push_navigate(to: ~p"/clients")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={:clients}>
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <.link
            navigate={~p"/clients"}
            class="text-sm font-medium text-[#68756C] hover:text-[#087C43]"
          >
            ← Back to clients
          </.link>
        </div>

        <section class="w-full overflow-hidden rounded-2xl border border-[#E5EBE6] bg-white shadow-sm">
          <div class="flex flex-col gap-5 border-b border-[#EEF2EF] p-5 sm:flex-row sm:items-start sm:justify-between sm:p-8">
            <div class="flex min-w-0 items-center gap-4">
              <div class="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-[#EAF5EE] text-lg font-semibold text-[#087C43]">
                {client_initials(@client.name)}
              </div>
              <div class="min-w-0">
                <p class="text-xs font-semibold uppercase tracking-wide text-[#087C43]">
                  CLIENT PROFILE
                </p>
                <h1 class="mt-1 truncate text-2xl font-semibold tracking-tight text-[#17231C]">
                  {@client.name}
                </h1>
                <p :if={@client.company} class="mt-1 text-sm text-[#68756C]">
                  {@client.company}
                </p>
              </div>
            </div>
            <div class="flex gap-2">
              <.link
                navigate={~p"/clients/#{@client.id}/edit"}
                class="inline-flex items-center justify-center rounded-lg border border-[#DCE5DE] bg-white px-3.5 py-2 text-sm font-semibold text-[#526057] transition hover:bg-[#F5F8F5]"
              >
                Edit client
              </.link>
              <button
                type="button"
                phx-click="archive"
                phx-confirm="Archive this client? Their record will be hidden from your active client list."
                class="inline-flex items-center justify-center rounded-lg border border-[#F0D7D4] bg-white px-3.5 py-2 text-sm font-semibold text-[#A33B32] transition hover:bg-[#FFF7F6]"
              >
                Archive
              </button>
            </div>
          </div>

          <div class="grid gap-8 p-5 sm:grid-cols-2 sm:p-8">
            <div class="space-y-6">
              <div>
                <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">
                  Email address
                </p>
                <p class="mt-2 break-words text-sm text-[#26352B]">
                  {@client.email || "Not provided"}
                </p>
              </div>
              <div>
                <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">
                  Phone number
                </p>
                <p class="mt-2 text-sm text-[#26352B]">
                  {@client.phone || "Not provided"}
                </p>
              </div>
              <div>
                <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">
                  Company
                </p>
                <p class="mt-2 text-sm text-[#26352B]">
                  {@client.company || "Not provided"}
                </p>
              </div>
            </div>
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-[#87938A]">Notes</p>
              <p class="mt-2 text-left text-sm text-[#526057]">
                {client_notes(@client.notes)}
              </p>
            </div>
          </div>
          <div class="border-t border-[#EEF2EF] p-5 sm:px-8 sm:py-6">
            <div class="mb-4 flex items-center justify-between gap-3">
              <div>
                <h2 class="text-base font-semibold text-[#26352B]">Meetings</h2>
                <p class="mt-1 text-xs text-[#87938A]">Scheduled and completed conversations with this client.</p>
              </div>
              <.link navigate={~p"/clients/#{@client.id}/meetings/new"} class="inline-flex shrink-0 items-center rounded-lg bg-[#087C43] px-3.5 py-2 text-xs font-semibold text-white transition hover:bg-[#066B39]">
                Add meeting
              </.link>
            </div>
            <div :if={@meetings == []} class="rounded-xl border border-dashed border-[#DCE5DE] px-4 py-8 text-center">
              <p class="text-sm font-medium text-[#526057]">No meetings recorded</p>
              <p class="mt-1 text-xs text-[#87938A]">Create a meeting before or after your conversation.</p>
            </div>
            <div :if={@meetings != []} class="divide-y divide-[#EEF2EF]">
              <div :for={meeting <- @meetings} class="flex items-center justify-between gap-3 py-3">
                <div class="min-w-0">
                  <.link navigate={~p"/meetings/#{meeting.id}"} class="block truncate text-sm font-semibold text-[#26352B] hover:text-[#087C43]">{meeting.title}</.link>
                  <p class="mt-1 text-xs text-[#87938A]">{client_meeting_time(meeting)}</p>
                </div>
                <span class="shrink-0 rounded-full bg-[#F1F4F1] px-3 py-1 text-xs font-medium text-[#526057]">{meeting.status |> String.replace("_", " ") |> String.capitalize()}</span>
              </div>
            </div>
          </div>
          <div class="border-t border-[#EEF2EF] px-5 py-4 text-xs text-[#87938A] sm:px-8">
            Client record created {Calendar.strftime(@client.inserted_at, "%B %d, %Y")}.
          </div>
        </section>
      </div>
    </Layouts.workspace>
    """
  end

  defp client_meeting_time(%{status: "scheduled", scheduled_at: %NaiveDateTime{} = value}), do: "Scheduled " <> Calendar.strftime(value, "%b %d, %Y at %I:%M %p")
  defp client_meeting_time(%{started_at: %NaiveDateTime{} = value}), do: "Met " <> Calendar.strftime(value, "%b %d, %Y at %I:%M %p")
  defp client_meeting_time(_meeting), do: "Date not set"

  defp client_notes(notes) when is_binary(notes) do
    case String.trim(notes) do
      "" -> "No notes have been added."
      notes -> notes
    end
  end

  defp client_notes(_notes), do: "No notes have been added."

  defp client_initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
