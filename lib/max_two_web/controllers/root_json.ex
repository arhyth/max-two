defmodule MaxTwoWeb.RootJSON do
  def get(%{users: us, timestamp: nil}) do
    %{users: us, timestamp: nil}
  end
  def get(%{users: us, timestamp: ts}) do
    %{users: us, timestamp: Calendar.strftime(ts, "%c")}
  end
end
