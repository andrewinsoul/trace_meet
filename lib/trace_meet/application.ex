defmodule TraceMeet.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ok = TraceMeet.AI.Tokenizer.initialize()

    children = [
      TraceMeetWeb.Telemetry,
      TraceMeet.Repo,
      {DNSCluster, query: Application.get_env(:trace_meet, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TraceMeet.PubSub},
      {Oban, Application.fetch_env!(:trace_meet, Oban)},
      TraceMeetWeb.Endpoint
    ]
    opts = [strategy: :one_for_one, name: TraceMeet.Supervisor]
    Supervisor.start_link(children, opts)
  end
  @impl true
  def config_change(changed, _new, removed) do
    TraceMeetWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
