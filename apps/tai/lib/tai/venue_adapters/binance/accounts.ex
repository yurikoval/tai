defmodule Tai.VenueAdapters.Binance.Accounts do
  alias Tai.VenueAdapters.Binance.{Error, Market}

  def accounts(venue_id, credential_id, credentials, market \\ :spot) do
    venue_credentials = struct!(ExBinance.Credentials, credentials)
    client = Market.rest_client(market)

    case client.get(Market.account_path(market), %{}, venue_credentials) do
      {:ok, response} ->
        {:ok, build_accounts(response, venue_id, credential_id, market)}

      {:error, _} = error ->
        Error.normalize(error)
    end
  end

  defp build_accounts(%{"balances" => balances}, venue_id, credential_id, :spot) do
    Enum.map(balances, fn %{"asset" => asset, "free" => free, "locked" => locked} ->
      free = decimal(free)
      locked = decimal(locked)

      account(venue_id, credential_id, asset, "default", Decimal.add(free, locked), free, locked)
    end)
  end

  defp build_accounts(%{"assets" => assets}, venue_id, credential_id, market) do
    Enum.map(assets, fn asset ->
      equity = decimal(asset["marginBalance"] || asset["walletBalance"])
      free = decimal(asset["availableBalance"] || 0)
      locked = max_decimal(Decimal.sub(equity, free), Decimal.new(0))

      account(
        venue_id,
        credential_id,
        Map.fetch!(asset, "asset"),
        Atom.to_string(market),
        equity,
        free,
        locked
      )
    end)
  end

  defp account(venue_id, credential_id, raw_asset, type, equity, free, locked) do
    %Tai.Venues.Account{
      venue_id: venue_id,
      credential_id: credential_id,
      asset: raw_asset |> String.downcase() |> String.to_atom(),
      type: type,
      equity: Decimal.normalize(equity),
      free: Decimal.normalize(free),
      locked: Decimal.normalize(locked)
    }
  end

  defp decimal(value), do: value |> to_string() |> Decimal.new()

  defp max_decimal(left, right) do
    case Decimal.compare(left, right) do
      :lt -> right
      _ -> left
    end
  end
end
