defmodule ExDeltaExchange.Index do
  @type t :: %__MODULE__{
    id: non_neg_integer,
    config: map,
    constituent_exchanges: list,
    constituent_indices: list,
    description: String.t(),
    health_interval: non_neg_integer,
    impact_size: String.t(),
    index_type: String.t(),
    is_composite: boolean,
    price_method: String.t(),
    quoting_asset_id: non_neg_integer(),
    symbol: String.t(),
    tick_size: String.t(),
    underlying_asset_id: non_neg_integer
  }

  defstruct ~w[
    id
    config
    constituent_exchanges
    constituent_indices
    description
    health_interval
    impact_size
    index_type
    is_composite
    price_method
    quoting_asset_id
    symbol
    tick_size
    underlying_asset_id
  ]a
end
