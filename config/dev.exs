import Config

config :trace_meet, TraceMeet.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "trace_meet_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :trace_meet, TraceMeetWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "swph3XdTSHIYBc9p8LKpURanFk36hefSgATa8FOEBKvh3niu7Sh2zAIbBSjPZqMr",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:trace_meet, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:trace_meet, ~w(--watch)]}
  ]

config :trace_meet, TraceMeetWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
      ~r"priv/gettext/.*\.po$"E,
      ~r"lib/trace_meet_web/router\.ex$"E,
      ~r"lib/trace_meet_web/(controllers|live|components)/.*\.(ex|heex)$"E
    ]
  ]

config :trace_meet, dev_routes: true
config :logger, :default_formatter, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

config :swoosh, :api_client, false
