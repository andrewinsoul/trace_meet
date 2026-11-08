defmodule TraceMeet.Meetings do
  import Ecto.Query, warn: false

  alias TraceMeet.Clients.Client
  alias TraceMeet.Meetings.Meeting
  alias TraceMeet.Repo

  @default_page_size 10
  @max_page_size 50

  def list_meetings(user_id, opts \\ []) do
    page = opts |> Keyword.get(:page, 1) |> positive_integer(1)
    per_page =
      opts
      |> Keyword.get(:per_page, @default_page_size)
      |> positive_integer(@default_page_size)
      |> min(@max_page_size)
    client_id = Keyword.get(opts, :client_id)

    query =
      from(m in Meeting,
        join: c in assoc(m, :client),
        where: m.user_id == ^user_id and c.user_id == ^user_id and is_nil(m.archived_at) and is_nil(c.archived_at),
        preload: [client: c],
        order_by: [desc: coalesce(m.started_at, m.scheduled_at), desc: m.inserted_at]
      )
      |> maybe_filter_client(client_id)

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

  def get_meeting(user_id, meeting_id) do
    case Ecto.UUID.cast(meeting_id) do
      {:ok, id} ->
        from(m in Meeting,
          join: c in assoc(m, :client),
          where:
            m.id == ^id and m.user_id == ^user_id and
              is_nil(m.archived_at) and is_nil(c.archived_at),
          preload: [client: c]
        )
        |> Repo.one()

      :error ->
        nil
    end
  end

  def change_meeting(%Meeting{} = meeting, attrs \\ %{}) do
    Meeting.changeset(meeting, attrs)
  end

  def create_meeting(user_id, client_id, attrs) do
    case get_active_client(user_id, client_id) do
      %Client{} = client ->
        %Meeting{user_id: user_id, client_id: client.id}
        |> Meeting.changeset(attrs)
        |> Repo.insert()

      nil ->
        {:error, :client_not_found}
    end
  end

  def update_meeting(user_id, meeting_id, attrs) do
    case get_meeting(user_id, meeting_id) do
      %Meeting{} = meeting ->
        meeting
        |> Meeting.changeset(attrs)
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

  def archive_meeting(user_id, meeting_id) do
    case get_meeting(user_id, meeting_id) do
      %Meeting{} = meeting ->
        meeting
        |> Ecto.Changeset.change(archived_at: DateTime.utc_now())
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

  defp get_active_client(user_id, client_id) do
    case Ecto.UUID.cast(client_id) do
      {:ok, id} ->
        Repo.one(
          from(c in Client,
            where: c.id == ^id and c.user_id == ^user_id and is_nil(c.archived_at)
          )
        )

      :error ->
        nil
    end
  end

  defp maybe_filter_client(query, nil), do: query
  defp maybe_filter_client(query, ""), do: query
  defp maybe_filter_client(query, client_id) do
    case Ecto.UUID.cast(client_id) do
      {:ok, id} -> from(m in query, where: m.client_id == ^id)
      :error -> from(m in query, where: false)
    end
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
