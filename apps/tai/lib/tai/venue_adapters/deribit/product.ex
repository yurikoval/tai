defmodule Tai.VenueAdapters.Deribit.Product do
  @time_unit :millisecond
  @legacy_inverse_currencies ~w(BTC ETH)
  @future_name ~r/^(BTC|ETH)-(?:PERPETUAL|\d{1,2}[A-Z]{3}\d{2})$/

  @spec build(ExDeribit.Instrument.t(), Tai.Venue.id()) ::
          {:ok, Tai.Venues.Product.t()} | {:error, term}
  def build(%ExDeribit.Instrument{} = instrument, venue_id) do
    with :ok <- validate_contract(instrument),
         :ok <- validate_instrument_name(instrument.instrument_name, instrument.base_currency),
         :ok <- validate_string(:base_currency, instrument.base_currency),
         :ok <- validate_string(:quote_currency, instrument.quote_currency),
         {:ok, status} <- to_status(instrument.is_active),
         {:ok, type} <- to_type(instrument),
         {:ok, listing} <- timestamp(:creation_timestamp, instrument.creation_timestamp),
         {:ok, expiry} <- timestamp(:expiration_timestamp, instrument.expiration_timestamp),
         {:ok, min_trade_amount} <-
           positive_decimal(:min_trade_amount, instrument.min_trade_amount),
         {:ok, tick_size} <- positive_decimal(:tick_size, instrument.tick_size),
         {:ok, contract_size} <- positive_decimal(:contract_size, instrument.contract_size),
         {:ok, maker_fee} <- decimal(:maker_commission, instrument.maker_commission),
         {:ok, taker_fee} <- decimal(:taker_commission, instrument.taker_commission) do
      {:ok,
       %Tai.Venues.Product{
         venue_id: venue_id,
         symbol: to_symbol(instrument.instrument_name),
         venue_symbol: instrument.instrument_name,
         base: downcase_and_atom(instrument.base_currency),
         quote: downcase_and_atom(instrument.quote_currency),
         venue_base: instrument.base_currency,
         venue_quote: instrument.quote_currency,
         status: status,
         type: type,
         listing: listing,
         expiry: expiry,
         collateral: false,
         price_increment: tick_size,
         size_increment: min_trade_amount,
         min_price: tick_size,
         min_size: min_trade_amount,
         value: contract_size,
         value_side: :quote,
         is_quanto: false,
         is_inverse: true,
         maker_fee: maker_fee,
         taker_fee: taker_fee,
         option_type: nil,
         strike: nil
       }}
    end
  end

  def build(instrument, _venue_id), do: {:error, {:invalid_instrument, instrument}}

  def to_symbol(venue_symbol) do
    venue_symbol
    |> String.replace("-", "_")
    |> downcase_and_atom()
  end

  def from_symbol(symbol) do
    symbol
    |> Atom.to_string()
    |> String.upcase()
  end

  defp validate_contract(%ExDeribit.Instrument{kind: kind}) when kind != "future" do
    {:error, {:unsupported_instrument, {:kind, kind}}}
  end

  defp validate_contract(%ExDeribit.Instrument{
         instrument_type: "reversed",
         base_currency: base,
         quote_currency: "USD",
         settlement_currency: base
       })
       when base in @legacy_inverse_currencies,
       do: :ok

  defp validate_contract(%ExDeribit.Instrument{
         instrument_type: nil,
         base_currency: base,
         quote_currency: "USD",
         settlement_currency: nil
       })
       when base in @legacy_inverse_currencies,
       do: :ok

  defp validate_contract(%ExDeribit.Instrument{} = instrument) do
    {:error,
     {:unsupported_instrument,
      {:contract, instrument.instrument_type, instrument.base_currency, instrument.quote_currency,
       instrument.settlement_currency}}}
  end

  defp validate_instrument_name(name, base) when is_binary(name) and is_binary(base) do
    case Regex.run(@future_name, name, capture: :all_but_first) do
      [currency] when currency == base -> :ok
      _ -> {:error, {:invalid_instrument, {:instrument_name, name}}}
    end
  end

  defp validate_instrument_name(name, _base) do
    {:error, {:invalid_instrument, {:instrument_name, name}}}
  end

  defp validate_string(_field, value) when is_binary(value) and byte_size(value) > 0, do: :ok
  defp validate_string(field, value), do: {:error, {:invalid_instrument, {field, value}}}

  defp to_status(true), do: {:ok, :trading}
  defp to_status(false), do: {:ok, :halt}
  defp to_status(value), do: {:error, {:invalid_instrument, {:is_active, value}}}

  defp to_type(%ExDeribit.Instrument{instrument_name: instrument_name}) do
    type = if String.ends_with?(instrument_name, "-PERPETUAL"), do: :swap, else: :future
    {:ok, type}
  end

  defp timestamp(field, value) when is_integer(value) and value > 0 do
    case DateTime.from_unix(value, @time_unit) do
      {:ok, timestamp} -> {:ok, timestamp}
      {:error, _reason} -> {:error, {:invalid_instrument, {field, value}}}
    end
  end

  defp timestamp(field, value), do: {:error, {:invalid_instrument, {field, value}}}

  defp positive_decimal(field, value) do
    with {:ok, decimal} <- decimal(field, value),
         :gt <- Decimal.compare(decimal, Decimal.new(0)) do
      {:ok, decimal}
    else
      {:error, _reason} = error -> error
      _ -> {:error, {:invalid_instrument, {field, value}}}
    end
  end

  defp decimal(field, value) do
    case Decimal.cast(value) do
      {:ok, decimal} -> {:ok, Decimal.normalize(decimal)}
      :error -> {:error, {:invalid_instrument, {field, value}}}
    end
  end

  defp downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()
end
