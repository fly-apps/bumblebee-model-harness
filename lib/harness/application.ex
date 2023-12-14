defmodule Harness.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      HarnessWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Harness.PubSub},
      # Start Finch
      {Finch, name: Harness.Finch},
      # Start the Endpoint (http/https)
      HarnessWeb.Endpoint
      # Start a worker by calling: Harness.Worker.start_link(arg)
      # {Harness.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Harness.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HarnessWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
