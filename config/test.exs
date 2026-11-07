import Config
config :trace_meet, TraceMeet.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "trace_meet_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
config :trace_meet, TraceMeetWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "dtHMteEvXBF+K7+DXWKn0EEXbDb5fEYpNlk+grEbYLyDak7BE0h9xGufDez7ZX06",
  server: false
config :trace_meet, TraceMeet.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false
config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
config :phoenix,
  sort_verified_routes_query_params: true
