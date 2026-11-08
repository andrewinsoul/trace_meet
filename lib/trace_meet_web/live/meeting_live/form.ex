defmodule TraceMeetWeb.MeetingLive.Form do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Clients
  alias TraceMeet.Meetings
  alias TraceMeet.Meetings.Meeting

  @impl true
  def mount(params, _session, socket) do
    user_id = socket.assigns.current_user.id

    case socket.assigns.live_action do
      :new ->
        client_id = params["client_id"]
        selected_client = if client_id, do: Clients.get_client(user_id, client_id)

        if client_id && is_nil(selected_client) do
          {:ok,
           socket
           |> put_flash(:error, "That client could not be found.")
           |> push_navigate(to: ~p"/meetings")}
        else
          meeting = %Meeting{}
          changeset = Meetings.change_meeting(meeting)

          {:ok,
           assign(socket,
             meeting: meeting,
             form: to_form(changeset),
             selected_client: selected_client,
             selected_client_id: client_id,
             client_search: "",
             client_results: [],
             client_selector_open: is_nil(selected_client),
             page_title: "Add meeting"
           )}
        end

      :edit ->
        case Meetings.get_meeting(user_id, params["id"]) do
          %Meeting{} = meeting ->
            changeset = Meetings.change_meeting(meeting)

            {:ok,
             assign(socket,
               meeting: meeting,
               form: to_form(changeset),
               selected_client: meeting.client,
               selected_client_id: meeting.client_id,
               client_search: "",
               client_results: [],
               client_selector_open: false,
               page_title: "Edit meeting"
             )}

          nil ->
            {:ok,
             socket
             |> put_flash(:error, "That meeting could not be found.")
             |> push_navigate(to: ~p"/meetings")}
        end
    end
  end

  @impl true
  def handle_event("validate", %{"meeting" => attrs} = params, socket) do
    attrs =
      if meeting_at_changed?(
           params["_target"],
           attrs["meeting_at"],
           socket.assigns.form[:meeting_at].value
         ) do
        case suggested_status(attrs["meeting_at"], socket.assigns.current_user.time_zone) do
          nil -> attrs
          status -> Map.put(attrs, "status", status)
        end
      else
        attrs
      end

    changeset =
      socket.assigns.meeting
      |> Meetings.change_meeting(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("search_clients", params, socket) do
    search = Map.get(params, "client_search", Map.get(params, "value", ""))

    results =
      Clients.search_clients_for_selection(socket.assigns.current_user.id, search)

    {:noreply,
     socket
     |> assign(:client_search, search)
     |> assign(:client_results, results)}
  end

  @impl true
  def handle_event("select_client", %{"client_id" => client_id}, socket) do
    selected_client = Enum.find(socket.assigns.client_results, &(&1.id == client_id))

    if selected_client do
      {:noreply,
       socket
       |> assign(:selected_client, selected_client)
       |> assign(:selected_client_id, selected_client.id)
       |> assign(:client_search, "")
       |> assign(:client_results, [])
       |> assign(:client_selector_open, false)}
    else
      {:noreply, put_flash(socket, :error, "Choose a client from the search results.")}
    end
  end

  @impl true
  def handle_event("change_client", _params, socket) do
    {:noreply,
     socket
     |> assign(:client_selector_open, true)
     |> assign(:client_search, "")
     |> assign(:client_results, [])}
  end

  @impl true
  def handle_event("save", %{"meeting" => attrs}, socket) do
    save_meeting(socket, attrs)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={:meetings}>
      <div class="mx-auto max-w-3xl">
        <div class="mb-8">
          <.link navigate={back_path(@selected_client_id)} class="text-sm font-medium text-[#68756C] hover:text-[#087C43]">
            ← Back
          </.link>
          <p class="mt-6 text-sm font-medium tracking-wide text-[#087C43]">CLIENT CONVERSATIONS</p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">{@page_title}</h1>
          <p class="mt-2 text-sm leading-6 text-[#68756C]">
            Schedule a future conversation or record one that has already happened. A transcript can be added later.
          </p>
        </div>

        <section class="w-full rounded-2xl border border-[#E5EBE6] bg-white p-5 shadow-sm sm:p-8">
          <.form for={@form} id="meeting-form" phx-change="validate" phx-submit="save" class="space-y-6">
            <input type="hidden" name="meeting[time_zone]" value={@current_user.time_zone || "Etc/UTC"} />
            <div :if={@live_action == :new} class="space-y-2">
              <label for="meeting-client-search" class="block text-sm font-medium text-[#26352B]">Client</label>
              <input
                type="hidden"
                name="meeting[client_id]"
                value={@selected_client_id || ""}
              />
              <div :if={@selected_client && !@client_selector_open} class="flex items-center justify-between gap-3 rounded-lg border border-[#DCE5DE] bg-[#F8FBF8] px-3.5 py-3">
                <div class="min-w-0">
                  <p class="truncate text-sm font-semibold text-[#17231C]">{@selected_client.name}</p>
                  <p :if={@selected_client.email || @selected_client.company} class="mt-0.5 truncate text-xs text-[#748178]">
                    {Enum.filter([@selected_client.email, @selected_client.company], & &1) |> Enum.join(" · ")}
                  </p>
                </div>
                <button type="button" phx-click="change_client" class="shrink-0 text-sm font-semibold text-[#087C43] hover:text-[#066B39]">
                  Change
                </button>
              </div>
              <div :if={is_nil(@selected_client) || @client_selector_open} class="relative space-y-2">
                <input
                  id="meeting-client-search"
                  type="search"
                  name="client_search"
                  value={@client_search}
                  placeholder="Search clients by name, email, or company..."
                  autocomplete="off"
                  phx-change="search_clients"
                  phx-debounce="250"
                  class="w-full rounded-lg border border-[#DCE5DE] bg-white px-3.5 py-3 text-sm text-[#17231C] outline-none transition placeholder:text-[#9AA69D] focus:border-[#087C43] focus:ring-4 focus:ring-[#087C43]/10"
                />
                <div :if={String.length(String.trim(@client_search)) < 2} class="rounded-lg border border-dashed border-[#DCE5DE] px-3.5 py-3 text-xs text-[#87938A]">
                  Type at least two characters to search your clients.
                </div>
                <div :if={String.length(String.trim(@client_search)) >= 2 && @client_results == []} class="rounded-lg border border-[#E5EBE6] px-3.5 py-3 text-sm text-[#748178]">
                  No matching clients found.
                </div>
                <div :if={@client_results != []} class="max-h-60 overflow-y-auto rounded-lg border border-[#E5EBE6] bg-white shadow-lg">
                  <button
                    :for={client <- @client_results}
                    type="button"
                    phx-click="select_client"
                    phx-value-client_id={client.id}
                    class="flex w-full items-center justify-between gap-3 border-b border-[#EEF2EF] px-3.5 py-3 text-left last:border-0 hover:bg-[#F5F9F6] focus:bg-[#F5F9F6] focus:outline-none"
                  >
                    <span class="min-w-0">
                      <span class="block truncate text-sm font-medium text-[#26352B]">{client.name}</span>
                      <span :if={client.email || client.company} class="mt-0.5 block truncate text-xs text-[#87938A]">
                        {Enum.filter([client.email, client.company], & &1) |> Enum.join(" · ")}
                      </span>
                    </span>
                    <span class="shrink-0 text-xs font-semibold text-[#087C43]">Select</span>
                  </button>
                </div>
              </div>
            </div>

            <div>
              <h2 class="text-base font-semibold text-[#26352B]">Meeting details</h2>
              <p class="mt-1 text-xs text-[#87938A]">Choose whether this is planned or already happened.</p>
            </div>
            <.input field={@form[:title]} label="Meeting title" placeholder="e.g. Quarterly business review" required />
            <.textarea field={@form[:description]} label="Agenda or notes" placeholder="What will you discuss? Add context if the meeting has already happened." rows={4} />
            <div class="grid gap-5 sm:grid-cols-2">
              <.input field={@form[:meeting_at]} type="datetime-local" label="Meeting date and time" />
              <div class="space-y-1.5">
                <label for="meeting-status" class="block text-sm font-medium text-[#26352B]">Meeting status</label>
                <select id="meeting-status" name="meeting[status]" class="block w-full rounded-lg border border-[#DCE5DE] bg-white px-3.5 py-3 text-sm text-[#17231C] outline-none focus:border-[#087C43] focus:ring-4 focus:ring-[#087C43]/10">
                  <option value="scheduled" selected={@form[:status].value == "scheduled"}>Scheduled</option>
                  <option value="in_progress" selected={@form[:status].value == "in_progress"}>In progress</option>
                  <option value="completed" selected={@form[:status].value == "completed"}>Completed (already happened)</option>
                  <option value="cancelled" selected={@form[:status].value == "cancelled"}>Cancelled</option>
                </select>
              </div>
            </div>
            <p class="text-xs leading-5 text-[#87938A]">
              The status is suggested from the selected date and time: future meetings are scheduled, while past meetings are completed. You can change it manually when needed.
            </p>
            <div class="flex flex-col-reverse gap-3 border-t border-[#EEF2EF] pt-5 sm:flex-row sm:justify-end">
              <.link navigate={back_path(@selected_client_id)} class="inline-flex items-center justify-center rounded-lg border border-[#DCE5DE] bg-white px-4 py-2.5 text-sm font-semibold text-[#526057] transition hover:bg-[#F5F8F5]">Cancel</.link>
              <.button
                type="submit"
                class="sm:w-auto"
                disabled={@live_action == :new && is_nil(@selected_client_id)}
                loading_text="Saving meeting..."
              >
                {if @live_action == :new, do: "Create meeting", else: "Save changes"}
              </.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.workspace>
    """
  end

  defp save_meeting(socket, attrs) do
    result =
      case socket.assigns.live_action do
        :new ->
          Meetings.create_meeting(
            socket.assigns.current_user.id,
            attrs["client_id"] || socket.assigns.selected_client_id,
            Map.drop(attrs, ["client_id"])
          )

        :edit ->
          Meetings.update_meeting(
            socket.assigns.current_user.id,
            socket.assigns.meeting.id,
            attrs
          )
      end

    case result do
      {:ok, _meeting} ->
        {:noreply,
         socket
         |> put_flash(:info, if(socket.assigns.live_action == :new, do: "Meeting created.", else: "Meeting updated."))
         |> push_navigate(to: ~p"/meetings")}

      {:error, :client_not_found} ->
        {:noreply, put_flash(socket, :error, "Choose one of your active clients.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "That meeting could not be found.")
         |> push_navigate(to: ~p"/meetings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp meeting_at_changed?(target, incoming_value, current_value) do
    meeting_at_target?(target) or
      comparable_meeting_time(incoming_value) != comparable_meeting_time(current_value)
  end

  defp meeting_at_target?(target) when is_list(target), do: List.last(target) == "meeting_at"

  defp meeting_at_target?(target) when is_binary(target) do
    String.ends_with?(target, "meeting_at")
  end

  defp meeting_at_target?(_target), do: false

  defp comparable_meeting_time(value) do
    case parse_meeting_time(value) do
      {:ok, meeting_at} -> meeting_at
      :error -> value
    end
  end

  defp parse_meeting_time(%NaiveDateTime{} = value), do: {:ok, value}
  defp parse_meeting_time(nil), do: :error
  defp parse_meeting_time(""), do: :error

  defp parse_meeting_time(value) when is_binary(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, meeting_at} ->
        {:ok, meeting_at}

      {:error, _reason} ->
        case NaiveDateTime.from_iso8601(value <> ":00") do
          {:ok, meeting_at} -> {:ok, meeting_at}
          {:error, _reason} -> :error
        end
    end
  end

  defp parse_meeting_time(_value), do: :error

  defp suggested_status(value, time_zone) do
    with {:ok, meeting_at} <- parse_meeting_time(value),
         {:ok, meeting_instant} <-
           DateTime.from_naive(meeting_at, time_zone || "Etc/UTC", Tzdata.TimeZoneDatabase) do
      case DateTime.compare(meeting_instant, DateTime.utc_now()) do
        :gt -> "scheduled"
        :eq -> "in_progress"
        :lt -> "completed"
      end
    else
      _ -> nil
    end
  end

  defp back_path(nil), do: ~p"/meetings"
  defp back_path(client_id), do: ~p"/clients/#{client_id}"
end
