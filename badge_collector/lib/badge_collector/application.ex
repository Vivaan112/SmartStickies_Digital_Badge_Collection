defmodule BadgeCollector.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BadgeCollectorWeb.Telemetry,
      BadgeCollector.Repo,
      {DNSCluster, query: Application.get_env(:badge_collector, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BadgeCollector.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BadgeCollector.Finch},
      # Start a worker by calling: BadgeCollector.Worker.start_link(arg)
      # {BadgeCollector.Worker, arg},
      # Start to serve requests, typically the last entry
      BadgeCollectorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BadgeCollector.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BadgeCollectorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
