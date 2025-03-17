defmodule Midwork.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MidworkWeb.Telemetry,
      Midwork.Repo,
      {DNSCluster, query: Application.get_env(:midwork, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Midwork.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Midwork.Finch},
      # Start a worker by calling: Midwork.Worker.start_link(arg)
      # {Midwork.Worker, arg},
      # Start to serve requests, typically the last entry
      MidworkWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Midwork.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MidworkWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
