defmodule ExDeribit.Accounts.Position do
  alias ExDeribit.HTTPClient

  @type instrument_name :: ExDeribit.Instrument.name()
  @type opts :: %{optional(:kind) => String.t()}
  @type position :: ExDeribit.Position.t()
  @type credentials :: ExDeribit.Credentials.t()
  @type result :: {:ok, position} | {:error, term}

  @path "/private/get_position"

  @spec get(credentials, instrument_name) :: result
  def get(credentials, instrument_name) do
    @path
    |> HTTPClient.auth_get(credentials, %{instrument_name: instrument_name})
    |> parse_response()
  end

  defp parse_response({:ok, %ExDeribit.JsonRpcResponse{result: venue_position}}) do
    venue_position
    |> Mapail.map_to_struct(ExDeribit.Position)
  end
end
