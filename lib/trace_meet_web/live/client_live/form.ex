defmodule TraceMeetWeb.ClientLive.Form do
  use TraceMeetWeb, :live_view

  alias TraceMeet.Clients
  alias TraceMeet.Clients.Client

  @impl true
  def mount(params, _session, socket) do
    {client, title} =
      case socket.assigns.live_action do
        :new ->
          {%Client{}, "Add client"}

        :edit ->
          case Clients.get_client(socket.assigns.current_user.id, params["id"]) do
            %Client{} = client -> {client, "Edit client"}
            nil -> {nil, "Edit client"}
          end
      end

    if client do
      changeset = Clients.change_client(client)

      {:ok,
       assign(socket,
         client: client,
         form: to_form(changeset),
         page_title: title
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "That client could not be found.")
       |> push_navigate(to: ~p"/clients")}
    end
  end

  @impl true
  def handle_event("validate", %{"client" => attrs}, socket) do
    changeset =
      socket.assigns.client
      |> Clients.change_client(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"client" => attrs}, socket) do
    save_client(socket, attrs)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_user={@current_user} active_page={:clients}>
      <div class="mx-auto max-w-3xl">
        <div class="mb-8">
          <.link
            navigate={~p"/clients"}
            class="text-sm font-medium text-[#68756C] hover:text-[#087C43]"
          >
            ← Back to clients
          </.link>
          <p class="mt-6 text-sm font-medium tracking-wide text-[#087C43]">
            CLIENT RELATIONSHIPS
          </p>
          <h1 class="mt-2 text-2xl font-semibold tracking-tight text-[#17231C] sm:text-3xl">
            {@page_title}
          </h1>
          <p class="mt-2 text-sm leading-6 text-[#68756C]">
            Add the details you need to identify and manage this client. You can update them later.
          </p>
        </div>

        <section class="w-full rounded-2xl border border-[#E5EBE6] bg-white p-5 shadow-sm sm:p-8">
          <.form
            for={@form}
            id="client-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-6"
          >
            <div>
              <h2 class="text-base font-semibold text-[#26352B]">Client details</h2>
              <p class="mt-1 text-xs text-[#87938A]">Name is the only required field.</p>
            </div>
            <div class="grid gap-5 sm:grid-cols-2">
              <.input
                field={@form[:name]}
                label="Full name"
                placeholder="e.g. Jordan Smith"
                required
              />
              <.input
                field={@form[:email]}
                type="email"
                label="Email address"
                placeholder="jordan@example.com"
              />
              <.input
                field={@form[:phone]}
                type="tel"
                label="Phone number"
                placeholder="e.g. +1 555 0100"
              />
              <.input
                field={@form[:company]}
                label="Company"
                placeholder="Company or organization"
              />
            </div>
            <.textarea
              field={@form[:notes]}
              label="Notes"
              placeholder="Optional background or context about this client"
              rows={4}
            />
            <div class="flex flex-col-reverse gap-3 border-t border-[#EEF2EF] pt-5 sm:flex-row sm:justify-end">
              <.link
                navigate={~p"/clients"}
                class="inline-flex items-center justify-center rounded-lg border border-[#DCE5DE] bg-white px-4 py-2.5 text-sm font-semibold text-[#526057] transition hover:bg-[#F5F8F5]"
              >
                Cancel
              </.link>
              <.button type="submit" class="sm:w-auto" loading_text="Saving client...">
                {if @live_action == :new, do: "Create client", else: "Save changes"}
              </.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.workspace>
    """
  end

  defp save_client(socket, attrs) do
    result =
      case socket.assigns.live_action do
        :new ->
          Clients.create_client(socket.assigns.current_user.id, attrs)

        :edit ->
          Clients.update_client(socket.assigns.current_user.id, socket.assigns.client.id, attrs)
      end

    case result do
      {:ok, client} ->
        message = if socket.assigns.live_action == :new, do: "Client created.", else: "Client updated."

        destination =
          if socket.assigns.live_action == :new,
            do: ~p"/clients",
            else: ~p"/clients/#{client.id}"

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> push_navigate(to: destination)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "That client could not be found.")
         |> push_navigate(to: ~p"/clients")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
