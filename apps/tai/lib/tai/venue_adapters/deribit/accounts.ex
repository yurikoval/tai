defmodule Tai.VenueAdapters.Deribit.Accounts do
  def accounts(venue_id, credential_id, credentials) do
    venue_credentials = credentials |> to_venue_credentials()

    with {:ok, currencies} <- ExDeribit.MarketData.Currencies.get(),
         {:ok, summaries} <- fetch_summaries(currencies, venue_credentials) do
      accounts = summaries |> Enum.map(&build(&1, venue_id, credential_id))

      {:ok, accounts}
    end
  end

  @zero Decimal.new(0)

  def build(account_summary, venue_id, credential_id) do
    equity = account_summary.equity |> Tai.Utils.Decimal.cast!()
    asset = account_summary.currency |> String.downcase() |> String.to_atom()

    %Tai.Venues.Account{
      venue_id: venue_id,
      credential_id: credential_id,
      asset: asset,
      type: "default",
      equity: equity,
      free: @zero,
      locked: equity
    }
  end

  defdelegate to_venue_credentials(credentials),
    to: Tai.VenueAdapters.Deribit.Credentials,
    as: :from

  defp fetch_summaries(currencies, venue_credentials) do
    Enum.reduce_while(currencies, {:ok, []}, fn currency, {:ok, summaries} ->
      case ExDeribit.Accounts.Summary.get(venue_credentials, currency.currency) do
        {:ok, summary} -> {:cont, {:ok, summaries ++ [summary]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end
end
