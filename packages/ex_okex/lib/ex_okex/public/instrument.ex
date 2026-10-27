defmodule ExOkex.Public.Instrument do
  @moduledoc """
  OKX V5 public instrument metadata.

  https://www.okx.com/docs-v5/en/#public-data-rest-api-get-instruments
  """

  alias __MODULE__

  @type optional_string :: String.t() | nil

  @type t :: %Instrument{
          alias: optional_string,
          base_currency: optional_string,
          contract_type: optional_string,
          contract_value: optional_string,
          contract_value_currency: optional_string,
          expiry_time: optional_string,
          instrument_family: optional_string,
          instrument_id: String.t(),
          instrument_type: String.t(),
          listing_time: String.t(),
          lot_size: String.t(),
          minimum_size: String.t(),
          quote_currency: optional_string,
          settlement_currency: optional_string,
          state: String.t(),
          tick_size: String.t(),
          underlying: optional_string
        }

  @enforce_keys ~w[
    instrument_id
    instrument_type
    lot_size
    minimum_size
    state
    tick_size
  ]a
  defstruct ~w[
    alias
    base_currency
    contract_type
    contract_value
    contract_value_currency
    expiry_time
    instrument_family
    instrument_id
    instrument_type
    listing_time
    lot_size
    minimum_size
    quote_currency
    settlement_currency
    state
    tick_size
    underlying
  ]a

  @decimal ~r/\A\d+(?:\.\d+)?\z/
  @timestamp ~r/\A\d+\z/

  @spec new(map) :: {:ok, t} | {:error, {:invalid_instrument, map}}
  def new(data) when is_map(data) do
    with :ok <- validate_common(data),
         :ok <- validate_type(data) do
      {:ok,
       %Instrument{
         alias: data["alias"],
         base_currency: data["baseCcy"],
         contract_type: data["ctType"],
         contract_value: data["ctVal"],
         contract_value_currency: data["ctValCcy"],
         expiry_time: data["expTime"],
         instrument_family: data["instFamily"],
         instrument_id: data["instId"],
         instrument_type: data["instType"],
         listing_time: data["listTime"],
         lot_size: data["lotSz"],
         minimum_size: data["minSz"],
         quote_currency: data["quoteCcy"],
         settlement_currency: data["settleCcy"],
         state: data["state"],
         tick_size: data["tickSz"],
         underlying: data["uly"]
       }}
    else
      :error -> {:error, {:invalid_instrument, data}}
    end
  end

  def new(data), do: {:error, {:invalid_instrument, data}}

  defp validate_common(data) do
    if non_empty?(data["instId"]) and non_empty?(data["state"]) and
         decimal?(data["lotSz"]) and decimal?(data["minSz"]) and decimal?(data["tickSz"]) and
         timestamp?(data["listTime"]) and optional_timestamp?(data["expTime"]),
       do: :ok,
       else: :error
  end

  defp validate_type(%{"instType" => "SPOT"} = data) do
    if non_empty?(data["baseCcy"]) and non_empty?(data["quoteCcy"]), do: :ok, else: :error
  end

  defp validate_type(%{"instType" => type} = data) when type in ["SWAP", "FUTURES"] do
    with true <- data["ctType"] in ["linear", "inverse"],
         true <- decimal?(data["ctVal"]),
         true <- non_empty?(data["ctValCcy"]),
         {:ok, {base, quote}} <- underlying(data),
         true <- data["ctValCcy"] in [base, quote] do
      :ok
    else
      _ -> :error
    end
  end

  defp validate_type(_data), do: :error

  defp underlying(data) do
    value = present(data["uly"]) || present(data["instFamily"])

    case value && String.split(value, "-", parts: 2) do
      [base, quote] when base != "" and quote != "" -> {:ok, {base, quote}}
      _ -> :error
    end
  end

  defp decimal?(value), do: is_binary(value) and Regex.match?(@decimal, value)
  defp timestamp?(value), do: is_binary(value) and Regex.match?(@timestamp, value)
  defp optional_timestamp?(value), do: value in [nil, ""] or timestamp?(value)
  defp non_empty?(value), do: is_binary(value) and value != ""
  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_value), do: nil
end
