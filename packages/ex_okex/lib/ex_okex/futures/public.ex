defmodule ExOkex.Futures.Public do
  @moduledoc """
  Public OKX V5 futures client.

  https://www.okx.com/docs-v5/en/#public-data-rest-api-get-instruments
  """

  alias ExOkex.Futures.Public

  defdelegate instruments, to: Public.Instruments
  defdelegate instruments(config), to: Public.Instruments
end
