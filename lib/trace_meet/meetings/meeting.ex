defmodule TraceMeet.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.Accounts.User
  alias TraceMeet.Clients.Client

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(scheduled in_progress completed cancelled)

  schema "meetings" do
    field :title, :string
    field :description, :string
    field :scheduled_at, :utc_datetime_usec
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :time_zone, :string, default: "Etc/UTC"
    field :status, :string, default: "scheduled"
    field :meeting_at, :naive_datetime_usec, virtual: true
    field :archived_at, :utc_datetime_usec

    belongs_to :user, User
    belongs_to :client, Client

    timestamps(type: :utc_datetime_usec)
  end

  def statuses, do: @statuses

  def changeset(meeting, attrs) do
    meeting =
      if is_nil(meeting.meeting_at) do
        local_meeting_at =
          case meeting.scheduled_at || meeting.started_at do
            %DateTime{} = value ->
              case DateTime.shift_zone(value, meeting.time_zone || "Etc/UTC", Tzdata.TimeZoneDatabase) do
                {:ok, local_value} -> DateTime.to_naive(local_value)
                _ -> nil
              end

            _ ->
              nil
          end

        %{meeting | meeting_at: local_meeting_at}
      else
        meeting
      end

    changeset =
      meeting
      |> cast(attrs, [:title, :description, :status, :meeting_at, :time_zone])
      |> update_change(:title, &String.trim/1)
      |> validate_required([:title, :status, :time_zone])
      |> validate_inclusion(:status, @statuses)
      |> validate_length(:title, max: 180)
      |> validate_length(:description, max: 5_000)
      |> validate_time_zone()
      |> apply_meeting_time()
      |> validate_time_fields()
      |> validate_status_against_current_time()

    changeset
  end

  defp validate_time_zone(changeset) do
    case get_field(changeset, :time_zone) do
      zone when is_binary(zone) ->
        if zone == "Etc/UTC" or zone in Tzdata.zone_list(),
          do: changeset,
          else: add_error(changeset, :time_zone, "is not a valid timezone")

      _ ->
        changeset
    end
  end

  defp apply_meeting_time(changeset) do
    status = get_field(changeset, :status)
    meeting_at = get_field(changeset, :meeting_at)
    time_zone = get_field(changeset, :time_zone)

    case {status, meeting_at, time_zone} do
      {status, %NaiveDateTime{} = value, zone}
      when status in ["scheduled", "in_progress", "completed", "cancelled"] and is_binary(zone) ->
        case DateTime.from_naive(value, zone, Tzdata.TimeZoneDatabase) do
          {:ok, local_value} ->
            {:ok, utc_value} =
              DateTime.shift_zone(local_value, "Etc/UTC", Tzdata.TimeZoneDatabase)

            case status do
              "scheduled" ->
                changeset
                |> put_change(:scheduled_at, utc_value)
                |> put_change(:started_at, nil)
                |> put_change(:ended_at, nil)

              "in_progress" ->
                changeset
                |> put_change(:started_at, utc_value)
                |> put_change(:scheduled_at, nil)
                |> put_change(:ended_at, nil)

              "completed" ->
                changeset
                |> put_change(:started_at, utc_value)
                |> put_change(:scheduled_at, nil)

              "cancelled" ->
                put_change(changeset, :scheduled_at, utc_value)
            end

          {:ambiguous, _first, _second} ->
            add_error(changeset, :meeting_at, "is ambiguous in the selected timezone")

          {:gap, _before, _after} ->
            add_error(changeset, :meeting_at, "does not exist in the selected timezone")

          {:error, _reason} ->
            add_error(changeset, :time_zone, "could not interpret the meeting time")
        end

      _ ->
        changeset
    end
  end

  defp validate_time_fields(changeset) do
    case get_field(changeset, :status) do
      "scheduled" -> validate_required(changeset, [:scheduled_at])
      "in_progress" -> validate_required(changeset, [:started_at])
      "completed" -> validate_required(changeset, [:started_at])
      "cancelled" -> changeset
      _ -> changeset
    end
  end

  defp validate_status_against_current_time(changeset) do
    status = get_field(changeset, :status)
    meeting_at = get_field(changeset, :meeting_at)
    time_zone = get_field(changeset, :time_zone)

    with %NaiveDateTime{} <- meeting_at,
         zone when is_binary(zone) <- time_zone,
         {:ok, meeting_instant} <- DateTime.from_naive(meeting_at, zone, Tzdata.TimeZoneDatabase) do
      comparison = DateTime.compare(meeting_instant, DateTime.utc_now())

      case {status, comparison} do
        {"completed", :gt} ->
          add_error(changeset, :status, "cannot be completed before the meeting time")

        {"in_progress", :gt} ->
          add_error(changeset, :status, "cannot be in progress before the meeting time")

        {"scheduled", :lt} ->
          add_error(changeset, :status, "a past meeting cannot be scheduled")

        _ ->
          changeset
      end
    else
      _ -> changeset
    end
  end
end
