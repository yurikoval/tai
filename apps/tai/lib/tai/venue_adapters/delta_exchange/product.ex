defmodule Tai.VenueAdapters.DeltaExchange.Product do
  @type venue :: Tai.Venue.id()
  @type product :: Tai.Venues.Product.t()
  @type venue_product :: ExDeltaExchange.Product.t()

  @vanilla_option_contract_types ~w[call_options put_options]
  @binary_option_contract_types ~w[binary_call_options binary_put_options]
  @option_contract_types @vanilla_option_contract_types ++ @binary_option_contract_types

  @spec build(venue_product, venue) :: product
  def build(%ExDeltaExchange.Product{} = venue_product, venue_id) do
    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: venue_product.symbol |> to_symbol,
      venue_symbol: venue_product.symbol,
      alias: nil,
      base: venue_product.contract_unit_currency |> downcase_and_atom(),
      quote: venue_product.quoting_asset.symbol |> downcase_and_atom(),
      venue_base: venue_product.contract_unit_currency,
      venue_quote: venue_product.quoting_asset.symbol,
      status: venue_product |> status(),
      type: venue_product |> type(),
      payoff_type: venue_product.contract_type |> payoff_type(),
      collateral: false,
      price_increment: venue_product.tick_size |> Decimal.new(),
      size_increment: venue_product.tick_size |> Decimal.new(),
      min_price: venue_product.tick_size |> Decimal.new(),
      min_size: venue_product.tick_size |> Decimal.new(),
      value: venue_product.contract_value |> Decimal.new(),
      value_side: :base,
      maker_fee: venue_product.maker_commission_rate |> Decimal.new(),
      taker_fee: venue_product.taker_commission_rate |> Decimal.new(),
      is_quanto: venue_product.is_quanto,
      is_inverse: false
    }
  end

  def to_symbol(venue_product_name), do: venue_product_name |> downcase_and_atom()

  def status(venue_product) do
    case venue_product.trading_status do
      "operational" -> :trading
      _ -> :unknown
    end
  end

  defp type(venue_product) do
    cond do
      venue_product.contract_type in @option_contract_types -> :option
      venue_product.contract_type == "futures" -> :future
      venue_product.contract_type == "perpetual_futures" -> :swap
      venue_product.contract_type == "interest_rate_swaps" -> :swap
      venue_product.contract_type == "spreads" -> :swap
      venue_product.contract_type == "spot" -> :spot
      venue_product.contract_type == "move_options" -> :move
      String.starts_with?(venue_product.symbol, "MV-") -> :move
      true -> :unknown
    end
  end

  defp payoff_type(contract_type) when contract_type in @vanilla_option_contract_types,
    do: :vanilla

  defp payoff_type(contract_type) when contract_type in @binary_option_contract_types,
    do: :binary

  defp payoff_type(_contract_type), do: nil

  defp downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()
end
