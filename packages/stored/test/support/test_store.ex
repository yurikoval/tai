defmodule Stored.TestItem do
  defstruct [:id, :value]
end

defimpl Stored.Item, for: Stored.TestItem do
  def key(item), do: item.id
end

defmodule Stored.TestStore do
  use Stored.Store
end
