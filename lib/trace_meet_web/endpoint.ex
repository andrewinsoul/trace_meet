defmodule TraceMeetWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :trace_meet

  @session_options [
    store: :cookie,
    key: "_trace_meet_key",
    signing_salt: "LgrAqS8f",
    encryption_salt: "trace-meet-cookie-encryption",
    same_site: "Lax",
    http_only: true,
    max_age: 60 * 24 * 60 * 60,
    secure: Application.compile_env(:trace_meet, :cookie_secure, false)
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :trace_meet,
    gzip: not code_reloading?,
    only: TraceMeetWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :trace_meet
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug TraceMeetWeb.Router
end
