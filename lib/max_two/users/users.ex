defmodule MaxTwo.UsersService do
  @moduledoc """
  Defines behaviour for Users service.
  """

  @type dir() :: :asc | :desc

  @callback get_with_min_points(integer()) :: [struct()]
  @callback cursor_paginate(keyword(dir()), integer(), keyword()) :: {list(struct()), map()}

  @callback set_points([integer()] | integer(), integer()) :: {non_neg_integer(), nil | [term()]}
  @callback update_users_points(integer(), integer()) :: :ok
  @optional_callbacks set_points: 2, update_users_points: 2
end

defmodule MaxTwo.Users do
  @moduledoc """
  Users service implementation
  """
  @behaviour MaxTwo.UsersService

  import Ecto.Query
  require Flow
  require Logger

  alias MaxTwo.Users.User, as: User

  @doc """
  Retrieve 2 random* users based on a random minimum number.

  *In practice, the users returned are usually the same set especially
  when calls are made in succession. This is likely due to caching in the DB.
  """
  @impl MaxTwo.UsersService
  def get_with_min_points(min) do
    query = from(u in User, where: u.points > ^min, limit: 2)
    MaxTwo.Repo.all(query)
  end

  @doc """
  Paginate users via keyset/cursor

  Accepts the following arguments:
  `order_by` - fields to order the pagination by
    eg. `[id: :asc, points: :desc]`
  `fields` - fields to retrieve from the schema. Defaults to `[:id]`
  `cursor` - current position/index in the pagination
    eg. `[..., before|after: cursor_value, ...]`
  """
  @impl MaxTwo.UsersService
  def cursor_paginate(order_by, page_size, opts \\ []) do
    fields = Keyword.get(opts, :fields, [:id])
    query_order_by = Enum.map(order_by, fn {key, dir} -> {dir, key} end)
    query =
      User
      |> select(^fields)
      |> order_by([u], ^query_order_by)

    page_opts = [
      cursor_fields: order_by,
      limit: page_size,
      maximum_limit: page_size
    ]

    page_opts =
      cond do
        Keyword.has_key?(opts, :after) ->
          [{:after, Keyword.get(opts, :after)}| page_opts]
        Keyword.has_key?(opts, :before) ->
          [{:before, Keyword.get(opts, :before)}| page_opts]
        true ->
          page_opts
      end

    %{entries: entries, metadata: metadata} =
      MaxTwo.Repo.paginate(query, page_opts)

    {entries, %{
      before: metadata.before,
      after: metadata.after,
      page_size: page_size,
      }}
  end

  @doc """
  Sets points to provided integer
  """
  @impl MaxTwo.UsersService
  def set_points(ids, int) when is_list(ids) do
    now = NaiveDateTime.utc_now()
    User
    |> where([u], u.id in fragment("(?)", ^ids))
    |> update(set: [points: ^int, updated_at: ^now])
    |> MaxTwo.Repo.update_all([], log: false)
  end
  def set_points(id, int) when is_integer(id) do
    now = NaiveDateTime.utc_now()
    User
    |> where([u], u.id == ^id)
    |> update(set: [points: ^int, updated_at: ^now])
    |> MaxTwo.Repo.update_all([], log: false)
  end

  @doc """
  Update all users' `points` field via streaming; this is a non-transactional operation
  """
  @impl MaxTwo.UsersService
  def update_users_points(trigger_interval, page_size) do
    stream =
      Stream.resource(
        fn -> {:start, page_size} end,
        fn
          {:start, page_size} ->
            cursor_paginate([id: :asc], page_size)
          %{after: cur, page_size: ps} when not is_nil(cur) ->
            cursor_paginate([id: :asc], ps, [after: cur])
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
        set_points(ids, rand)
      end)

      # this is only a placeholder to satisfy `on_trigger` signature
      # instead of passing around heavy data we no longer care about
      {[1], %{}}
    end)
    |> Flow.run()
  end
end
