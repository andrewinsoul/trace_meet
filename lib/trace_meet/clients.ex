defmodule TraceMeet.Clients do
  import Ecto.Query, warn: false

  alias TraceMeet.Clients.Client
  alias TraceMeet.Repo

  @default_page_size 10
  @max_page_size 50

  def list_clients(user_id, opts \\ []) do
    page = opts |> Keyword.get(:page, 1) |> positive_integer(1)
    per_page = opts |> Keyword.get(:per_page, @default_page_size) |> positive_integer(@default_page_size) |> min(@max_page_size)
    search = opts |> Keyword.get(:search, "") |> String.trim()

    query =
      from(c in Client,
        where: c.user_id == ^user_id and is_nil(c.archived_at),
        order_by: [desc: c.inserted_at, desc: c.id]
      )
      |> apply_search(search)

    total_entries = Repo.aggregate(query, :count, :id)

    total_pages = max(ceil(total_entries / per_page), 1)
    page = min(page, total_pages)

    entries =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  def get_client(user_id, client_id) do
    case Ecto.UUID.cast(client_id) do
      {:ok, id} ->
        query =
          from(c in Client,
            where:
              c.id == ^id and
                c.user_id == ^user_id and
                is_nil(c.archived_at)
          )

        Repo.one(query)

      :error ->
        nil
    end
  end

  def change_client(%Client{} = client, attrs \\ %{}) do
    Client.changeset(client, attrs)
  end

  def create_client(user_id, attrs) do
    %Client{user_id: user_id}
    |> Client.changeset(attrs)
    |> Repo.insert()
  end

  def update_client(user_id, client_id, attrs) do
    case get_client(user_id, client_id) do
      %Client{} = client ->
        client
        |> Client.changeset(attrs)
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

  def archive_client(user_id, client_id) do
    case get_client(user_id, client_id) do
      %Client{} = client ->
        client
        |> Ecto.Changeset.change(archived_at: DateTime.utc_now())
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

  defp apply_search(query, ""), do: query

  defp apply_search(query, search) do
    pattern = "%#{escape_like(search)}%"

    from(c in query,
      where:
        ilike(c.name, ^pattern) or
          ilike(coalesce(c.email, ""), ^pattern) or
          ilike(coalesce(c.company, ""), ^pattern)
    )
  end

  defp escape_like(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _ -> default
    end
  end

  defp positive_integer(_, default), do: default
end
