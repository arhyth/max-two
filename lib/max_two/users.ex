defmodule MaxTwo.Users do
  @moduledoc """
  Users module
  """

  import Ecto.Query
  require Flow
  require Logger

  alias MaxTwo.Users.User, as: User

  @doc """
  Retrieve 2 random* users based on a random minimum number.

  *In practice, the users returned are usually the same set especially
  when calls are made in succession. This is likely due to caching in the DB.
  """
  def get_users(min) do
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
end
