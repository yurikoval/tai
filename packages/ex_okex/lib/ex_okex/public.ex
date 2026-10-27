defmodule ExOkex.Public do
  @moduledoc """
  Public OKX V5 instruments API for SPOT, SWAP, and FUTURES.

  Instrument rows that cannot be safely normalized are omitted from successful responses.

  https://www.okx.com/docs-v5/en/#public-data-rest-api-get-instruments
  """

  alias ExOkex.{Api, Config}
  alias ExOkex.Public.Instrument

  @instrument_types ~w(SPOT SWAP FUTURES)
  @instruments_path "/api/v5/public/instruments"

  @type instrument_type :: String.t()
  @type error_reason :: term

  @spec instruments(instrument_type) :: {:ok, [Instrument.t()]} | {:error, error_reason}
  def instruments(instrument_type), do: instruments(instrument_type, %{}, nil)

  @spec instruments(instrument_type, map | Config.t() | nil) ::
          {:ok, [Instrument.t()]} | {:error, error_reason}
  def instruments(instrument_type, nil), do: instruments(instrument_type)

  def instruments(instrument_type, %Config{} = config),
    do: instruments(instrument_type, %{}, config)

  def instruments(instrument_type, params) when is_map(params),
    do: instruments(instrument_type, params, nil)

  @spec instruments(instrument_type, map, Config.t() | nil) ::
          {:ok, [Instrument.t()]} | {:error, error_reason}
  def instruments(instrument_type, params, config) when instrument_type in @instrument_types do
    params = Map.put(params, :instType, instrument_type)
    config = config || %Config{api_url: Config.public_api_url()}

    @instruments_path
    |> Api.Public.get(params, config)
    |> parse_response()
  end

  def instruments(instrument_type, _params, _config),
    do: {:error, {:invalid_instrument_type, instrument_type}}

  defp parse_response({:ok, %{"code" => "0", "data" => data}}) when is_list(data) do
    instruments =
      Enum.reduce(data, [], fn attrs, instruments ->
        case Instrument.new(attrs) do
          {:ok, instrument} -> [instrument | instruments]
          {:error, _} -> instruments
        end
      end)

    {:ok, Enum.reverse(instruments)}
  end

  defp parse_response({:ok, %{"code" => code, "msg" => message}}),
    do: {:error, {code, message}}

  defp parse_response({:ok, response}), do: {:error, {:invalid_response, response}}
  defp parse_response({:error, _} = error), do: error
  defp parse_response({:error, _, _} = error), do: error
end
