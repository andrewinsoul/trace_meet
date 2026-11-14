defmodule TraceMeetWeb.PreferencesLive.Index do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Accounts

  @impl true
  def mount(_params, _session, socket) do
    time_zones =
      (["Etc/UTC"] ++ Tzdata.zone_list())
      |> Enum.uniq()
      |> Enum.sort()

    current_time_zone = socket.assigns.current_user.time_zone || "Etc/UTC"

    {:ok,
     assign(socket,
       page_title: "Preferences",
       active_page: :settings_preferences,
       time_zones: time_zones,
       selected_time_zone: current_time_zone,
       time_zone_search: "",
       time_zone_results: [],
       time_zone_selector_open: false,
       selected_retention_days: socket.assigns.current_user.processing_data_retention_days || 30,
       retention_options: Accounts.processing_data_retention_options()
     )}
  end

  @impl true
  def handle_event("search_time_zones", params, socket) do
    search = Map.get(params, "time_zone_search", Map.get(params, "value", "")) |> String.trim()
    normalized_search = String.downcase(search)

    results =
      if String.length(normalized_search) < 2 do
        []
      else
        socket.assigns.time_zones
        |> Enum.filter(&String.contains?(String.downcase(&1), normalized_search))
        |> Enum.take(30)
      end

    {:noreply,
     socket
     |> assign(:time_zone_search, search)
     |> assign(:time_zone_results, results)}
  end

  def handle_event("select_time_zone", %{"time_zone" => time_zone}, socket) do
    if time_zone in socket.assigns.time_zones do
      {:noreply,
       socket
       |> assign(:selected_time_zone, time_zone)
       |> assign(:time_zone_search, "")
       |> assign(:time_zone_results, [])
       |> assign(:time_zone_selector_open, false)}
    else
      {:noreply, put_flash(socket, :error, "Choose a timezone from the search results.")}
    end
  end

  def handle_event("change_time_zone", _params, socket) do
    {:noreply,
     socket
     |> assign(:time_zone_selector_open, true)
     |> assign(:time_zone_search, "")
     |> assign(:time_zone_results, [])}
  end

  def handle_event("cancel_time_zone", _params, socket) do
    {:noreply,
     socket
     |> assign(:time_zone_selector_open, false)
     |> assign(:time_zone_search, "")
     |> assign(:time_zone_results, [])}
  end

  def handle_event("save", _params, socket) do
    case Accounts.update_user_time_zone(
           socket.assigns.current_user,
           socket.assigns.selected_time_zone
         ) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(current_user: user, selected_time_zone: user.time_zone)
         |> put_flash(:info, "Your timezone preference has been updated.")}

      {:error, :invalid_time_zone} ->
        {:noreply, put_flash(socket, :error, "Select a valid timezone.")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Your preferences could not be saved. Please try again.")}
    end
  end

  def handle_event("save_retention", %{"retention" => %{"days" => days}}, socket) do
    case Integer.parse(days) do
      {days, ""} ->
        case Accounts.update_processing_data_retention(socket.assigns.current_user, days) do
          {:ok, user} ->
            {:noreply,
             socket
             |> assign(
               current_user: user,
               selected_retention_days: user.processing_data_retention_days
             )
             |> put_flash(:info, "Processing data retention preference updated.")}

          {:error, :invalid_retention_period} ->
            {:noreply, put_flash(socket, :error, "Choose a valid retention period.")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Your retention preference could not be saved.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Choose a valid retention period.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_user={@current_user}
      active_page={@active_page}
    >
      <div class="mb-8">
        <p class="text-sm font-medium tracking-wide text-[#087C43]">PERSONAL PREFERENCES</p>
        <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
          Preferences
        </h1>
        <p class="mt-2 max-w-2xl text-sm leading-6 text-[#68756C]">
          Set how TraceMeet interprets and displays meeting dates and times for your account.
        </p>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <section class="rounded-2xl border border-[#E5EBE6] bg-white p-5 sm:p-7">
          <div class="flex items-start gap-3 border-b border-[#EEF2EF] pb-5">
            <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#EAF5EE] text-[#087C43]">
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.8"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="h-5 w-5"
                aria-hidden="true"
              >
                <circle cx="12" cy="12" r="9" />
                <path d="M3 12h18M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18" />
              </svg>
            </div>
            <div>
              <h2 class="text-base font-semibold text-[#26352B]">Regional settings</h2>
              <p class="mt-1 text-sm leading-6 text-[#68756C]">
                Choose the timezone used when displaying meeting dates and times.
              </p>
            </div>
          </div>

          <.form
            for={to_form(%{"time_zone" => @selected_time_zone}, as: :preferences)}
            phx-submit="save"
            class="pt-6"
          >
            <label class="mb-2 block text-sm font-medium text-[#26352B]">
              Timezone
            </label>
            <input
              type="hidden"
              name="preferences[time_zone]"
              value={@selected_time_zone}
            />
            <div
              :if={!@time_zone_selector_open}
              class="flex items-center justify-between gap-3 rounded-lg border border-[#DCE5DE] bg-[#F8FBF8] px-3.5 py-3"
            >
              <span class="min-w-0 truncate text-sm font-medium text-[#17231C]">
                {@selected_time_zone}
              </span>
              <button
                type="button"
                phx-click="change_time_zone"
                class="shrink-0 text-sm font-semibold text-[#087C43] hover:text-[#066B39]"
              >
                Change
              </button>
            </div>
            <div :if={@time_zone_selector_open} class="relative space-y-2">
              <input
                id="preferences-time-zone-search"
                type="search"
                name="time_zone_search"
                value={@time_zone_search}
                placeholder="Search timezone by region or city..."
                autocomplete="off"
                phx-change="search_time_zones"
                phx-debounce="200"
                class="w-full rounded-lg border border-[#DCE5DE] bg-white px-3.5 py-3 text-sm text-[#17231C] outline-none transition placeholder:text-[#9AA69D] focus:border-[#087C43] focus:ring-4 focus:ring-[#087C43]/10"
              />
              <div
                :if={String.length(String.trim(@time_zone_search)) < 2}
                class="rounded-lg border border-dashed border-[#DCE5DE] px-3.5 py-3 text-xs text-[#87938A]"
              >
                Type at least two characters to search timezones.
              </div>
              <div
                :if={String.length(String.trim(@time_zone_search)) >= 2 && @time_zone_results == []}
                class="rounded-lg border border-[#E5EBE6] px-3.5 py-3 text-sm text-[#748178]"
              >
                No matching timezones found.
              </div>
              <div
                :if={@time_zone_results != []}
                class="max-h-60 overflow-y-auto rounded-lg border border-[#E5EBE6] bg-white shadow-lg"
              >
                <button
                  :for={time_zone <- @time_zone_results}
                  type="button"
                  phx-click="select_time_zone"
                  phx-value-time_zone={time_zone}
                  class="flex w-full items-center justify-between gap-3 border-b border-[#EEF2EF] px-3.5 py-3 text-left last:border-0 hover:bg-[#F5F9F6] focus:bg-[#F5F9F6] focus:outline-none"
                >
                  <span class="min-w-0 truncate text-sm font-medium text-[#26352B]">
                    {time_zone}
                  </span>
                  <span class="shrink-0 text-xs font-semibold text-[#087C43]">Select</span>
                </button>
              </div>
              <button
                type="button"
                phx-click="cancel_time_zone"
                class="text-sm font-medium text-[#68756C] hover:text-[#26352B]"
              >
                Cancel
              </button>
            </div>
            <p class="mt-2 text-xs leading-5 text-[#87938A]">
              This timezone is used as the default when you create meetings. Existing meetings keep the timezone recorded when they were created.
            </p>

            <div class="mt-6 flex flex-col-reverse gap-3 border-t border-[#EEF2EF] pt-5 sm:flex-row sm:items-center sm:justify-between">
              <p class="text-xs text-[#87938A]">
                Selected timezone:
                <span class="font-medium text-[#526057]">{@selected_time_zone}</span>
              </p>
              <button
                type="submit"
                phx-disable-with="Saving..."
                class="inline-flex items-center justify-center rounded-lg bg-[#087C43] px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-[#066B39] focus:outline-none focus:ring-4 focus:ring-[#087C43]/20 disabled:cursor-not-allowed disabled:opacity-60"
              >
                Save preferences
              </button>
            </div>
          </.form>
        </section>

        <aside class="h-fit rounded-2xl border border-[#E5EBE6] bg-white p-5">
          <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-[#F0F4F1] text-[#526057]">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.8"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="h-5 w-5"
              aria-hidden="true"
            >
              <circle cx="12" cy="12" r="9" />
              <path d="M12 7v5l3 2" />
            </svg>
          </div>
          <h2 class="mt-4 text-sm font-semibold text-[#26352B]">Why timezone matters</h2>
          <p class="mt-1.5 text-sm leading-6 text-[#68756C]">
            TraceMeet uses this timezone when suggesting the status of a new meeting and as the default timezone for its date and time. Each meeting retains its own recorded timezone.
          </p>
        </aside>
      </div>

      <section class="mt-6 rounded-2xl border border-[#E5EBE6] bg-white p-5 sm:p-7">
        <div class="border-b border-[#EEF2EF] pb-5">
          <h2 class="text-base font-semibold text-[#26352B]">Processing data retention</h2>
          <p class="mt-1 max-w-3xl text-sm leading-6 text-[#68756C]">
            Choose how long TraceMeet keeps temporary transcript-processing data after you have reviewed all extracted proposals. This includes processing chunks and intermediate extraction results. Your original transcript, approved records, rejected proposals, review history, and processing history are not deleted by this cleanup.
          </p>
          <p class="mt-2 text-sm leading-6 text-[#68756C]">
            The retention period starts from the time you finish reviewing the proposals. Changing this setting also applies to existing, uncleaned processing data. If you shorten the period, data that is already older than the new period becomes eligible for the next cleanup.
          </p>
          <p class="mt-2 text-xs leading-5 text-[#87938A]">
            TraceMeet checks for expired data once per day. Actual deletion may happen later if the application is asleep or a cleanup attempt needs to be retried.
          </p>
        </div>

        <.form
          for={to_form(%{"days" => @selected_retention_days}, as: :retention)}
          phx-submit="save_retention"
          class="pt-6"
        >
          <label for="processing-data-retention" class="mb-2 block text-sm font-medium text-[#26352B]">
            Keep temporary processing data for
          </label>
          <select
            id="processing-data-retention"
            name="retention[days]"
            class="w-full max-w-sm rounded-lg border border-[#DCE5DE] bg-white px-3.5 py-3 text-sm text-[#17231C] outline-none focus:border-[#087C43] focus:ring-4 focus:ring-[#087C43]/10"
          >
            <option
              :for={days <- @retention_options}
              value={days}
              selected={days == @selected_retention_days}
            >
              {days} days
            </option>
          </select>
          <div class="mt-6 border-t border-[#EEF2EF] pt-5 flex justify-end">
            <button
              type="submit"
              phx-disable-with="Saving..."
              class="inline-flex items-center justify-center rounded-lg bg-[#087C43] px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-[#066B39] focus:outline-none focus:ring-4 focus:ring-[#087C43]/20 disabled:cursor-not-allowed disabled:opacity-60"
            >
              Save retention preference
            </button>
          </div>
        </.form>
      </section>
    </Layouts.workspace>
    """
  end
end
