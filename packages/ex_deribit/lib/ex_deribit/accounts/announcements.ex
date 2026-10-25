defmodule ExDeribit.Accounts.Announcements do
  alias ExDeribit.HTTPClient

  @type opts :: %{
          optional(:start_timestamp) => pos_integer,
          optional(:count) => pos_integer
        }
  @type announcement :: ExDeribit.Announcement.t()
  @type result :: {:ok, [announcement]} | {:error, term}

  @path "/public/get_announcements"

  @spec get :: result
  @spec get(opts) :: result
  def get(opts \\ %{}) do
    @path
    |> HTTPClient.non_auth_get(opts)
    |> parse_response()
  end

  defp parse_response({:ok, %ExDeribit.JsonRpcResponse{result: venue_announcements}}) do
    venue_announcements
    |> Enum.map(&Mapail.map_to_struct(&1, ExDeribit.Announcement))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, a}, {:ok, acc} -> {:ok, [a | acc]}
        _, _acc -> {:error, :parse_result_item}
      end
    )
  end
end
