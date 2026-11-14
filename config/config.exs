import Config

config :trace_meet,
  ecto_repos: [TraceMeet.Repo],
  generators: [timestamp_type: :utc_datetime]

config :trace_meet, TraceMeetWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TraceMeetWeb.ErrorHTML, json: TraceMeetWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TraceMeet.PubSub,
  live_view: [signing_salt: "iAJaJeai"]

config :trace_meet, TraceMeet.Mailer, adapter: Swoosh.Adapters.Local

config :trace_meet, Oban,
  repo: TraceMeet.Repo,
  queues: [transcript_processing: 2, maintenance: 1],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [{"0 3 * * *", TraceMeet.ProcessingRuns.CleanupExpiredDataWorker}]}
  ]

config :nature_whistle,
  default_notifiers: if(config_env() == :dev, do: [:console], else: [:slack_primary]),
  retry: [
    max_attempts: 5,
    base_delay_ms: 1_000,
    max_delay_ms: 60_000
  ],
  notifiers_config: [
    %{name: :console, service: :console, config: %{}}
  ],
  alerts: [],
  packs: [
    {
      NatureWhistle.Packs.Beam,
      thresholds: [
        memory: 1_073_741_824,
        process_count: 50_000,
        run_queue: 4
      ]
    },
    {
      NatureWhistle.Packs.Ecto,
      repo: TraceMeet.Repo,
      thresholds: [
        slow_query: 1_000,
        slow_queue: 50
      ]
    },
    {
      NatureWhistle.Packs.Oban,
      thresholds: [
        slow_job: 5_000,
        slow_queue: 1_000
      ],
      failure_detection: [
        failures: 10,
        within_ms: 300_000
      ]
    }
  ]

config :trace_meet,
  ai_provider: TraceMeet.AI.MockProvider,
  ai_model: "openai/gpt-oss-120b",
  processing_max_attempts: 5,
  chunk_max_attempts: 3,
  chunk_target_tokens: 6_000,
  chunk_max_tokens: 7_000,
  chunk_overlap_tokens: 300,
  consolidation_max_tokens: 12_000

config :esbuild,
  version: "0.25.4",
  trace_meet: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.1.12",
  trace_meet: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason
import_config "#{config_env()}.exs"
