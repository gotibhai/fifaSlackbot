defmodule Messi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    import Supervisor.Spec
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, Messi.Router, [], port: 8080),
      worker(Messi.ScoreData,[]),
      worker(Messi.Poll, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Messi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
