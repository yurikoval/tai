defmodule Tai.VenueAdapters.Deribit.Product do
  @time_unit :millisecond
  @inverse_currencies ~w(BTC ETH)
  @months ~w(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC)
          |> Enum.with_index(1)
          |> Map.new()
  @perpetual_name ~r/^(BTC|ETH)-PERPETUAL$/
  @future_name ~r/^(BTC|ETH)-(\d{1,2})(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(\d{2})$/
  @option_name ~r/^(BTC|ETH)-(\d{1,2})(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(\d{2})-([\d.]+)-([CP])$/

  @spec build(ExDeribit.Instrument.t(), Tai.Venue.id()) ::
          {:ok, Tai.Venues.Product.t()} | {:error, term}
  def build(%ExDeribit.Instrument{} = instrument, venue_id) do
    with :ok <- validate_contract(instrument),
         :ok <- validate_string(:base_currency, instrument.base_currency),
         :ok <- validate_string(:quote_currency, instrument.quote_currency),
         {:ok, status} <- to_status(instrument.is_active, instrument.state),
         {:ok, type, expiry} <- type_and_expiry(instrument),
         {:ok, payoff_type, option_type, strike} <- option_details(instrument),
         {:ok, listing} <- timestamp(:creation_timestamp, instrument.creation_timestamp),
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
         value_side: value_side(instrument.kind),
         is_quanto: false,
         is_inverse: true,
         maker_fee: maker_fee,
         taker_fee: taker_fee,
         payoff_type: payoff_type,
         option_type: option_type,
         strike: strike
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

  defp validate_contract(%ExDeribit.Instrument{kind: kind})
       when kind not in ["future", "option"] do
    {:error, {:unsupported_instrument, {:kind, kind}}}
  end

  defp validate_contract(%ExDeribit.Instrument{
         kind: "future",
         instrument_type: "reversed",
         base_currency: base,
         quote_currency: "USD",
         settlement_currency: base
       })
       when base in @inverse_currencies,
       do: :ok

  defp validate_contract(%ExDeribit.Instrument{
         kind: "option",
         instrument_type: "reversed",
         base_currency: base,
         quote_currency: base,
         settlement_currency: base
       })
       when base in @inverse_currencies,
       do: :ok

  defp validate_contract(%ExDeribit.Instrument{} = instrument) do
    {:error,
     {:unsupported_instrument,
      {:contract, instrument.instrument_type, instrument.base_currency, instrument.quote_currency,
       instrument.settlement_currency}}}
  end

  defp validate_string(_field, value) when is_binary(value) and byte_size(value) > 0, do: :ok
  defp validate_string(field, value), do: {:error, {:invalid_instrument, {field, value}}}

  defp to_status(true, "open"), do: {:ok, :trading}

  defp to_status(active, state)
       when is_boolean(active) and is_binary(state) and byte_size(state) > 0,
       do: {:ok, :halt}

  defp to_status(value, _state) when not is_boolean(value),
    do: {:error, {:invalid_instrument, {:is_active, value}}}

  defp to_status(_active, state), do: {:error, {:invalid_instrument, {:state, state}}}

  defp type_and_expiry(%ExDeribit.Instrument{kind: "future"} = instrument),
    do: future_expiry(instrument)

  defp type_and_expiry(%ExDeribit.Instrument{kind: "option"} = instrument) do
    with {:ok, expiry} <- dated_expiry(instrument, @option_name), do: {:ok, :option, expiry}
  end

  defp future_expiry(
         %ExDeribit.Instrument{instrument_name: name, base_currency: base} = instrument
       )
       when is_binary(name) and is_binary(base) do
    case Regex.run(@perpetual_name, name, capture: :all_but_first) do
      [currency] when currency == base ->
        {:ok, :swap, nil}

      _ ->
        with {:ok, expiry} <- dated_expiry(instrument, @future_name), do: {:ok, :future, expiry}
    end
  end

  defp future_expiry(%ExDeribit.Instrument{instrument_name: name}),
    do: {:error, {:invalid_instrument, {:instrument_name, name}}}

  defp dated_expiry(
         %ExDeribit.Instrument{
           instrument_name: name,
           base_currency: base,
           expiration_timestamp: expiration_timestamp
         },
         regex
       )
       when is_binary(name) and is_binary(base) do
    with [currency, day, month, year | _details] <-
           Regex.run(regex, name, capture: :all_but_first),
         true <- currency == base,
         {day, ""} <- Integer.parse(day),
         {year, ""} <- Integer.parse(year),
         {:ok, date} <- Date.new(year + 2000, Map.fetch!(@months, month), day) do
      expected_expiry = DateTime.new!(date, ~T[08:00:00], "Etc/UTC")

      with {:ok, expiry} <- timestamp(:expiration_timestamp, expiration_timestamp),
           :eq <- DateTime.compare(expiry, expected_expiry) do
        {:ok, expiry}
      else
        {:error, _reason} = error -> error
        _ -> {:error, {:invalid_instrument, {:expiration_timestamp, expiration_timestamp}}}
      end
    else
      _ -> {:error, {:invalid_instrument, {:instrument_name, name}}}
    end
  end

  defp dated_expiry(%ExDeribit.Instrument{instrument_name: name}, _regex),
    do: {:error, {:invalid_instrument, {:instrument_name, name}}}

  defp option_details(%ExDeribit.Instrument{kind: "future"}), do: {:ok, nil, nil, nil}

  defp option_details(%ExDeribit.Instrument{
         instrument_name: name,
         option_type: option_type,
         strike: strike
       }) do
    with {:ok, symbol_option_type, symbol_strike} <- option_symbol_details(name),
         {:ok, parsed_option_type} <- option_type(option_type),
         :ok <- validate_option_type(parsed_option_type, symbol_option_type, option_type),
         {:ok, parsed_strike} <- positive_decimal(:strike, strike),
         :ok <- validate_strike(parsed_strike, symbol_strike, strike) do
      {:ok, :vanilla, parsed_option_type, parsed_strike}
    end
  end

  defp option_symbol_details(name) do
    case Regex.run(@option_name, name, capture: :all_but_first) do
      [_currency, _day, _month, _year, strike, "C"] ->
        {:ok, :call, Decimal.new(strike)}

      [_currency, _day, _month, _year, strike, "P"] ->
        {:ok, :put, Decimal.new(strike)}

      _ ->
        {:error, {:invalid_instrument, {:instrument_name, name}}}
    end
  end

  defp option_type("call"), do: {:ok, :call}
  defp option_type("put"), do: {:ok, :put}
  defp option_type(value), do: {:error, {:invalid_instrument, {:option_type, value}}}

  defp validate_option_type(value, value, _raw_value), do: :ok

  defp validate_option_type(_value, _expected, raw_value),
    do: {:error, {:invalid_instrument, {:option_type, raw_value}}}

  defp validate_strike(value, expected, raw_value) do
    if Decimal.equal?(value, expected),
      do: :ok,
      else: {:error, {:invalid_instrument, {:strike, raw_value}}}
  end

  defp value_side("future"), do: :quote
  defp value_side("option"), do: :base

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
