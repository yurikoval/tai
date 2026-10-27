defmodule ExOkex.Swap.Public do
  @moduledoc """
  Public OKX V5 swap client.

  https://www.okx.com/docs-v5/en/#public-data-rest-api-get-instruments
  """

  alias ExOkex.{Config, Public}
  alias ExOkex.Public.Instrument

  @type instrument :: Instrument.t()
  @type error_reason :: term

  @spec instruments(Config.t() | nil) :: {:ok, [instrument]} | {:error, error_reason}
  def instruments(config \\ nil), do: Public.instruments("SWAP", config)
end
