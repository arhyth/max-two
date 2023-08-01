defmodule MaxTwo.Users.Sidecar do
  @moduledoc """
  Defines behaviour for Users sidecar/agent
  """

  @doc """
  Retrieves at most 2 users and NaiveDateTime of last query served
  """
  @callback get_users() :: {list(struct()), struct()}
end

defmodule MaxTwo.Users.GenSidecar do
  @moduledoc """
  Implements a sidecar genserver for the MaxTwo Users service,
  periodically updating users' points with randomly generated numbers and
  keeping pertinent state (eg. current minimum number, time of last query).
  """
  @behaviour MaxTwo.Users.Sidecar

  use GenServer
  require Logger

  @update_interval_ms 60_000
  @page_limit 20_000
  @trigger_interval 4_000
  @min_cooldown_ms 10_000

  @impl GenServer
  def init(opts) do
    rnd = MaxTwo.Utils.rand_less_one()
    conf = Application.get_env(:max_two, MaxTwo)
    users_service = Keyword.get(opts, :users_service, MaxTwo.Users)
    update_fun = Keyword.get(opts, :update_fun, :update_users_points)
    update_args = Keyword.get(opts, :update_args, [@trigger_interval, @page_limit])

    state = %{
      min: rnd,
      query_ts: nil,
      update_ts: nil,
      config: %{
        users_service: users_service,
        update_fun: update_fun,
        update_args: update_args,
        update_interval: Keyword.get(conf, :update_interval_ms, @update_interval_ms),
        min_cooldown: Keyword.get(conf, :min_cooldown_ms, @min_cooldown_ms)
      }
    }

    {:ok, state, {:continue, MaxTwo.Utils.rand_less_one()}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # callback for starting update loop immediately after init
  @impl GenServer
  def handle_continue(start_min, state) do
    Process.send(__MODULE__, {:update, start_min}, [])
    {:noreply, state}
  end

  # callback for starting an update process
  @impl GenServer
  def handle_info({:update, new_min}, %{config: cfg} = state) do
    Process.spawn(
      cfg.users_service,
      cfg.update_fun,
      cfg.update_args,
      [:monitor]
    )
    {:noreply, %{state | min: new_min, update_ts: NaiveDateTime.utc_now()}}
  end

  # callback for signal of successful update process and for setting next update
  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, :normal}, %{config: cfg} = state) do
    Process.demonitor(ref, [:flush])

    elapsed = NaiveDateTime.diff(NaiveDateTime.utc_now(), state.update_ts, :millisecond)
    msg = {:update, MaxTwo.Utils.rand_less_one()}

    # send message to trigger next update round; cooldown if DB is overloaded
    after_t = tick(cfg.update_interval, elapsed, cfg.min_cooldown)
    Process.send_after(__MODULE__, msg, after_t)

    Logger.info(%{
      scope: "MarkTwo.Server.handle_info",
      message: "User points successfully updated",
      time_ms: elapsed
    })

    {:noreply, state}
  end

  # callback for any other termination signal than normal
  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    elapsed = NaiveDateTime.diff(NaiveDateTime.utc_now(), state.update_ts, :millisecond)

    Logger.error(%{
      scope: "MarkTwo.Server.handle_info",
      message: "User points update failed",
      reason: reason,
      time_ms: elapsed
    })

    {:noreply, state}
  end

  # callback for serving context request get_users with timestamp for last served query
  @impl GenServer
  def handle_call(:get, _from, %{min: min, query_ts: ts, config: cfg} = state) do
    {
      :reply,
      {cfg.users_service.get_with_min_points(min), ts},
      %{state | min: min, query_ts: NaiveDateTime.utc_now()}
    }
  end

  @impl MaxTwo.Users.Sidecar
  def get_users(), do: GenServer.call(__MODULE__, :get)

  # determine next tick on target interval while respecting cooldown
  defp tick(target_interval, elapsed, min_cooldown) do
    cond do
      elapsed >= target_interval ->
        min_cooldown
      target_interval - elapsed <= min_cooldown ->
        min_cooldown - (target_interval - elapsed)
      target_interval - elapsed > min_cooldown ->
        target_interval - elapsed
    end
  end
end
