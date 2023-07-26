defmodule MaxTwo.Sidecar do
  @moduledoc """
  Implements a sidecar genserver for the MaxTwo User repository,
  periodically updating users' points with randomly generated numbers and
  keeping pertinent state (eg. current minimum number, time of last query).
  """

  use GenServer
  require Logger

  @update_interval_ms 60_000
  @page_limit 20_000
  @trigger_interval 4_000
  @min_cooldown_ms 10_000

  @impl GenServer
  def init(_opts) do
    rnd = MaxTwo.Utils.rand_less_one()
    conf = Application.get_env(:max_two, MaxTwo)

    state = %{
      min: rnd,
      query_ts: nil,
      update_ts: nil,
      config: %{
        update_interval: Keyword.get(conf, :update_interval_ms, @update_interval_ms),
        page_limit: Keyword.get(conf, :page_limit, @page_limit),
        trigger_interval: Keyword.get(conf, :trigger_interval, @trigger_interval),
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
    Process.spawn(fn -> update_users_stream(cfg.trigger_interval, cfg.page_limit) end, [:monitor])
    {:noreply, %{state | min: new_min, update_ts: NaiveDateTime.utc_now()}}
  end

  # callback for signal of successful update process and for setting next update
  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, :normal}, %{config: cfg} = state) do
    Process.demonitor(ref, [:flush])

    elapsed = NaiveDateTime.diff(NaiveDateTime.utc_now(), state.update_ts, :millisecond)
    msg = {:update, MaxTwo.Utils.rand_less_one()}

    # send message to trigger next update round; cooldown if DB is overloaded
    after_t = next(cfg.update_interval, elapsed, cfg.min_cooldown)
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
  def handle_call(:get, _from, %{min: min, update_ts: ts} = state) do
    {
      :reply,
      {MaxTwo.Users.get_users(min), ts},
      %{state | min: min, update_ts: NaiveDateTime.utc_now()}
    }
  end

  # update all users' `points` field via streaming; this is a non-transactional operation
  def update_users_stream(trigger_interval, page_size) do
    stream =
      Stream.resource(
        fn -> {:start, page_size} end,
        fn
          {:start, page_size} ->
            MaxTwo.Users.cursor_paginate([id: :asc], page_size)
          %{after: cur, page_size: ps} when not is_nil(cur) ->
            MaxTwo.Users.cursor_paginate([id: :asc], ps, [after: cur])
          %{after: nil} ->
            {:halt, nil}
        end,
        fn _ -> nil end
      )

    window = Flow.Window.trigger_every(Flow.Window.global(), trigger_interval)

    stream
    |> Stream.map(fn u -> {u.id, MaxTwo.Utils.rand_less_one()} end)
    |> Flow.from_enumerable()
    # partition updates via their random number so they can be batched
    |> Flow.partition(key: {:elem, 1}, window: window, stages: 20)
    # since partitions cannot be pinned to stages 1to1,
    # a map accumulator is used with random numbers as keys
    # and list of ids as corresponding values
    |> Flow.reduce(
      fn -> %{} end,
      fn {uid, randn}, all_ids ->
        Map.update(all_ids, randn, [], fn ids -> [uid | ids] end)
      end
    )
    # run actual repo update on trigger using the accumulated ids
    |> Flow.on_trigger(fn acc ->
      Enum.each(acc, fn {rand, ids} ->
        MaxTwo.Users.set_points(ids, rand)
      end)

      # this is only a placeholder to satisfy `on_trigger` signature
      # instead of passing around heavy data we no longer care about
      {[1], %{}}
    end)
    |> Flow.run()
  end

  # determine next call while respecting cooldown
  defp next_call(target_interval, elapsed, min_cooldown) do
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
