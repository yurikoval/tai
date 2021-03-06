defmodule Tai.NewOrders.Responses.Amend do
  @moduledoc """
  Return from venue adapters when amending an order
  """

  @type t :: %__MODULE__{
          id: String.t(),
          status: atom,
          price: Decimal.t(),
          leaves_qty: Decimal.t(),
          cumulative_qty: Decimal.t(),
          received_at: integer,
          venue_timestamp: DateTime.t()
        }

  @enforce_keys ~w[
    id
    status
    price
    leaves_qty
    cumulative_qty
    received_at
    venue_timestamp
  ]a
  defstruct ~w[
    id
    status
    price
    leaves_qty
    cumulative_qty
    received_at
    venue_timestamp
  ]a
end
