defmodule ExOkex.Futures.Public.Instruments do
  alias ExOkex.{Config, Public}
  alias ExOkex.Public.Instrument

  @type instrument :: Instrument.t()
  @type error_reason :: term

  @spec instruments(Config.t() | nil) :: {:ok, [instrument]} | {:error, error_reason}
  def instruments(config \\ nil), do: Public.instruments("FUTURES", config)
end
