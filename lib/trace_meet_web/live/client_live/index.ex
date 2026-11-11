defmodule TraceMeetWeb.ClientLive.Index do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Clients

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_clients(socket, 1, "")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = Map.get(params, "page", "1")
    search = Map.get(params, "search", "")

    {:noreply, load_clients(socket, page, search)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, socket |> assign(:search, search) |> load_clients(1, search)}
  end

  @impl true
  def handle_event("archive", %{"id" => id}, socket) do
    case Clients.archive_client(socket.assigns.current_user.id, id) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client archived.")
         |> load_clients(socket.assigns.pagination.page, socket.assigns.search)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "That client could not be found.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={:clients}>
      <div class="mb-8 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="text-sm font-medium tracking-wide text-[#087C43]">CLIENT RELATIONSHIPS</p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
            Clients
          </h1>
          <p class="mt-2 text-sm leading-6 text-[#68756C] sm:text-base">
            Keep your client records organized in one place.
          </p>
        </div>
        <.link
          navigate={~p"/clients/new"}
          class="inline-flex items-center justify-center gap-2 rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-[#066B39] focus:outline-none focus-visible:ring-4 focus-visible:ring-[#087C43]/20"
        >
          <span class="text-lg leading-none">+</span> Add client
        </.link>
      </div>

      <section class="overflow-hidden rounded-2xl border border-[#E5EBE6] bg-white shadow-sm">
        <div class="flex flex-col gap-4 border-b border-[#EEF2EF] p-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div>
            <h2 class="font-semibold text-[#26352B]">All clients</h2>
            <p class="mt-1 text-xs text-[#87938A]">
              {ngettext("%{count} client", "%{count} clients", @pagination.total_entries)}
            </p>
          </div>
          <form phx-change="search" class="w-full sm:max-w-xs">
            <label for="client-search" class="sr-only">Search clients</label>
            <div class="relative">
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="1.7"
                class="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#98A39A]"
                aria-hidden="true"
              >
                <circle cx="11" cy="11" r="7" />
                <path stroke-linecap="round" d="m16 16 4 4" />
              </svg>
              <input
                id="client-search"
                type="search"
                name="search"
                value={@search}
                placeholder="Search name, email or company"
                phx-debounce="250"
                class="w-full rounded-lg border border-[#DCE5DE] bg-white py-2.5 pl-9 pr-3 text-sm text-[#17231C] outline-none transition placeholder:text-[#9AA69D] focus:border-[#087C43] focus:ring-4 focus:ring-[#087C43]/10"
              />
            </div>
          </form>
        </div>

        <div
          :if={@clients == []}
          class="flex min-h-[300px] flex-col items-center justify-center px-6 py-12 text-center"
        >
          <div class="flex h-14 w-14 items-center justify-center rounded-2xl bg-[#EAF5EE] text-[#087C43]">
            <Layouts.nav_icon name="clients" class="h-7 w-7" />
          </div>
          <h3 class="mt-5 text-lg font-semibold text-[#26352B]">
            {if @search == "", do: "No clients yet", else: "No matching clients"}
          </h3>
          <p class="mt-2 max-w-md text-sm leading-6 text-[#68756C]">
            {if @search == "",
              do: "Add your first client to start organizing meetings and follow-ups.",
              else: "Try another name, email address or company."}
          </p>
          <.link
            :if={@search == ""}
            navigate={~p"/clients/new"}
            class="mt-5 inline-flex items-center rounded-lg bg-[#087C43] px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-[#066B39]"
          >
            Add your first client
          </.link>
        </div>

        <div :if={@clients != []} class="divide-y divide-[#EEF2EF]">
          <article
            :for={client <- @clients}
            class="flex flex-col gap-4 px-4 py-4 transition hover:bg-[#FBFCFB] sm:flex-row sm:items-center sm:px-6"
          >
            <div class="flex min-w-0 flex-1 items-center gap-3">
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-[#EAF5EE] text-sm font-semibold text-[#087C43]">
                {client_initials(client.name)}
              </div>
              <div class="min-w-0">
                <.link
                  navigate={~p"/clients/#{client.id}"}
                  class="block truncate text-sm font-semibold text-[#26352B] hover:text-[#087C43]"
                >
                  {client.name}
                </.link>
                <p class="mt-1 truncate text-xs text-[#87938A]">
                  {client.company || client.email || client.phone || "No additional details"}
                </p>
              </div>
            </div>
            <div class="flex items-center justify-between gap-3 sm:justify-end">
              <p class="text-xs text-[#87938A]">
                Added {Calendar.strftime(client.inserted_at, "%b %d, %Y")}
              </p>
              <.link
                navigate={~p"/clients/#{client.id}"}
                class="rounded-md px-2.5 py-1.5 text-xs font-semibold text-[#087C43] hover:bg-[#EAF5EE]"
              >
                View
              </.link>
            </div>
          </article>
        </div>

        <div
          :if={@pagination.total_pages > 1}
          class="flex items-center justify-between border-t border-[#EEF2EF] px-4 py-3 sm:px-6"
        >
          <p class="text-xs text-[#87938A]">Page {@pagination.page} of {@pagination.total_pages}</p>
          <div class="flex gap-2">
            <.link
              patch={client_page_path(@pagination.page - 1, @search)}
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
              patch={client_page_path(@pagination.page + 1, @search)}
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

  defp load_clients(socket, page, search) do
    pagination =
      Clients.list_clients(socket.assigns.current_user.id,
        page: page,
        per_page: 10,
        search: search
      )

    assign(socket,
      page_title: "Clients",
      clients: pagination.entries,
      pagination: pagination,
      search: search
    )
  end

  defp client_page_path(page, search) do
    query = URI.encode_query(%{page: page, search: search})
    "/clients?#{query}"
  end

  defp client_initials(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
