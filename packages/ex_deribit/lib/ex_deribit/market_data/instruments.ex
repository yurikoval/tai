defmodule ExDeribit.MarketData.Instruments do
  require Logger

  alias ExDeribit.HTTPClient

  @type currency :: String.t()
  @type kind :: :future | :option
  @type opts :: %{
          optional(:kind) => kind,
          optional(:expired) => boolean
        }
  @type instrument :: ExDeribit.Instrument.t()
  @type result :: {:ok, [instrument]} | {:error, term}

  @path "/public/get_instruments"
  @currencies ~w(BTC ETH any)
  @query_kinds ~w(future option)a
  @instrument_kinds ~w(future option spot future_combo option_combo)

  @spec get(currency) :: result
  @spec get(currency, opts) :: result
  def get(currency, opts \\ %{})

  def get(currency, %{kind: kind})
      when currency in @currencies and kind not in @query_kinds do
    {:error, {:invalid_option, :kind, kind}}
  end

  def get(currency, opts) when currency in @currencies do
    opts
    |> Map.put(:currency, currency)
    |> then(&HTTPClient.non_auth_get(@path, &1))
    |> parse_response()
  end

  def get(currency, _opts), do: {:error, {:invalid_currency, currency}}

  defp parse_response({:ok, %ExDeribit.JsonRpcResponse{result: venue_instruments}})
       when is_list(venue_instruments) do
    instruments =
      venue_instruments
      |> Enum.with_index()
      |> Enum.reduce([], fn
        {item, index}, acc when is_map(item) ->
          with {:ok, instrument} <- Mapail.map_to_struct(item, ExDeribit.Instrument),
               true <- valid_instrument?(instrument) do
            [instrument | acc]
          else
            _error ->
              Logger.warning("Deribit ignored malformed instrument at index #{index}")
              acc
          end

        {_item, index}, acc ->
          Logger.warning("Deribit ignored malformed instrument at index #{index}")
          acc
      end)
      |> Enum.reverse()

    {:ok, instruments}
  end

  defp parse_response({:ok, %ExDeribit.JsonRpcResponse{result: result}}) do
    {:error, {:invalid_result, result}}
  end

  defp parse_response({:error, _reason} = error), do: error

  defp valid_instrument?(%ExDeribit.Instrument{} = instrument) do
    strings = [
      instrument.instrument_name,
      instrument.base_currency,
      instrument.quote_currency,
      instrument.settlement_currency,
      instrument.instrument_type,
      instrument.state
    ]

    timestamps = [instrument.creation_timestamp, instrument.expiration_timestamp]

    positive_numbers = [
      instrument.min_trade_amount,
      instrument.tick_size,
      instrument.contract_size
    ]

    instrument.kind in @instrument_kinds and
      is_boolean(instrument.is_active) and
      Enum.all?(strings, &valid_string?/1) and
      Enum.all?(timestamps, &valid_timestamp?/1) and
      Enum.all?(positive_numbers, &positive_number?/1) and
      is_number(instrument.maker_commission) and
      is_number(instrument.taker_commission)
  end

  defp valid_string?(value), do: is_binary(value) and byte_size(value) > 0
  defp valid_timestamp?(value), do: is_integer(value) and value > 0
  defp positive_number?(value), do: is_number(value) and value > 0
end
