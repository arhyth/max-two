defmodule MaxTwo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    common = [
      # Start the Telemetry supervisor
      MaxTwoWeb.Telemetry,
      # Start the Ecto repository
      MaxTwo.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: MaxTwo.PubSub},
      # Start the Endpoint (http/https)
      MaxTwoWeb.Endpoint,
      # Start a worker by calling: MaxTwo.Worker.start_link(arg)
      # {MaxTwo.Worker, arg}
    ]
    env = Application.get_env(:max_two, MaxTwo)[:environment]
    children = if env == :test, do: common, else: common ++ [{MaxTwo.Sidecar, []}]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MaxTwo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MaxTwoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
