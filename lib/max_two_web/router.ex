defmodule MaxTwoWeb.Router do
  use MaxTwoWeb, :router
  use Plug.ErrorHandler

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MaxTwoWeb do
    pipe_through :api

    get "/", RootController, :get
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{reason: %Phoenix.Router.NoRouteError{}}) do
    conn
    |> put_resp_content_type("application/json")
    |> json(%{error: "not found"})
  end

  # callback for handling genserver timeout
  #
  # This is a weird place to handle this error but handling it "properly" at the
  # call site, eg. controller, likely requires more sophisticated (complicated?)
  # logic to distinguish the reply that might arrive later to the controller's
  # process mailbox from other more current replies.
  # This is more in the spirit of Erlang's "let it crash" philosophy.
  @impl Plug.ErrorHandler
  def handle_errors(conn, %{
        reason: {:timeout, {GenServer, :call, [MaxTwo.Sidecar, :get, _timeout]}}
      }) do
    conn
    |> put_resp_content_type("application/json")
    |> put_status(503)
    |> json(%{error: "server busy; try again later"})
  end
end
