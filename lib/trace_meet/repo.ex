defmodule TraceMeet.Repo do
  use Ecto.Repo,
    otp_app: :trace_meet,
    adapter: Ecto.Adapters.Postgres
end
