defmodule ExDeribit.MarketData.Instruments do
  require Logger

  alias ExDeribit.HTTPClient

  @type currency :: String.t()
  @type kind :: :future | :option | :spot | :future_combo | :option_combo
  @type opts :: %{
          optional(:kind) => kind,
          optional(:expired) => boolean
        }
  @type instrument :: ExDeribit.Instrument.t()
  @type result :: {:ok, [instrument]} | {:error, term}

  @path "/public/get_instruments"
  @kinds ~w(future option spot future_combo option_combo)a
  @instrument_kinds Enum.map(@kinds, &Atom.to_string/1)
  @option_keys ~w(kind expired)a

  @spec get(currency) :: result
  @spec get(currency, opts) :: result
  def get(currency, opts \\ %{}) do
    with :ok <- validate_currency(currency),
         :ok <- validate_opts(opts) do
      opts
      |> Map.put(:currency, currency)
      |> then(&HTTPClient.non_auth_get(@path, &1))
      |> parse_response()
    end
  end

  defp validate_currency(currency) when is_binary(currency) and byte_size(currency) > 0, do: :ok
  defp validate_currency(currency), do: {:error, {:invalid_currency, currency}}

  defp validate_opts(opts) when is_map(opts) do
    with [] <- Map.keys(opts) -- @option_keys,
         :ok <- validate_kind(Map.get(opts, :kind)),
         :ok <- validate_expired(Map.get(opts, :expired)) do
      :ok
    else
      [key | _] -> {:error, {:invalid_option, key, Map.get(opts, key)}}
      {:error, _reason} = error -> error
    end
  end

  defp validate_opts(opts), do: {:error, {:invalid_options, opts}}

  defp validate_kind(nil), do: :ok
  defp validate_kind(kind) when kind in @kinds, do: :ok
  defp validate_kind(kind), do: {:error, {:invalid_option, :kind, kind}}

  defp validate_expired(nil), do: :ok
  defp validate_expired(expired) when is_boolean(expired), do: :ok
  defp validate_expired(expired), do: {:error, {:invalid_option, :expired, expired}}

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
    instrument.kind in @instrument_kinds and
      valid_string?(instrument.instrument_name) and
      valid_string?(instrument.base_currency) and
      valid_string?(instrument.quote_currency) and
      valid_string?(instrument.settlement_currency) and
      valid_string?(instrument.instrument_type) and
      is_boolean(instrument.is_active) and
      valid_string?(instrument.state) and
      valid_timestamp?(instrument.creation_timestamp) and
      valid_timestamp?(instrument.expiration_timestamp) and
      positive_number?(instrument.min_trade_amount) and
      positive_number?(instrument.tick_size) and
      positive_number?(instrument.contract_size) and
      is_number(instrument.maker_commission) and
      is_number(instrument.taker_commission)
  end

  defp valid_string?(value), do: is_binary(value) and byte_size(value) > 0
  defp valid_timestamp?(value), do: is_integer(value) and value > 0
  defp positive_number?(value), do: is_number(value) and value > 0
end
