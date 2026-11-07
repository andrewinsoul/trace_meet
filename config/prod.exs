import Config
config :trace_meet, TraceMeetWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"
config :trace_meet, TraceMeetWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  exclude: [
    hosts: ["localhost", "127.0.0.1"]
  ]
config :swoosh, api_client: Swoosh.ApiClient.Req
config :swoosh, local: false
config :logger, level: :info

config :trace_meet, :cookie_secure, true
