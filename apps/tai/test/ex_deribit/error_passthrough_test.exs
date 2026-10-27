defmodule ExDeribit.ErrorPassthroughTest do
  use ExUnit.Case, async: false

  import Mock

  @error {:error, {:http_error, 503, "unavailable"}}

  test "currencies preserves HTTP client errors" do
    with_mock ExDeribit.HTTPClient,
      non_auth_get: fn "/public/get_currencies" -> @error end do
      assert ExDeribit.MarketData.Currencies.get() == @error
    end
  end

  test "announcements preserves HTTP client errors" do
    with_mock ExDeribit.HTTPClient,
      non_auth_get: fn "/public/get_announcements", %{} -> @error end do
      assert ExDeribit.Accounts.Announcements.get() == @error
    end
  end

  test "private account APIs preserve HTTP client errors" do
    credentials = %ExDeribit.Credentials{client_id: "test", client_secret: "test"}

    with_mock ExDeribit.HTTPClient,
      auth_get: fn _path, ^credentials, _params -> @error end do
      assert ExDeribit.Accounts.Position.get(credentials, "BTC-PERPETUAL") == @error
      assert ExDeribit.Accounts.Positions.get(credentials, "BTC") == @error
      assert ExDeribit.Accounts.Summary.get(credentials, "BTC") == @error
    end
  end

  test "Tai account hydration halts on a typed summary error" do
    currencies = [%ExDeribit.Currency{currency: "BTC"}, %ExDeribit.Currency{currency: "ETH"}]

    with_mocks [
      {ExDeribit.MarketData.Currencies, [], get: fn -> {:ok, currencies} end},
      {ExDeribit.Accounts.Summary, [], get: fn _credentials, _currency -> @error end}
    ] do
      assert Tai.VenueAdapters.Deribit.Accounts.accounts(
               :deribit,
               :credential,
               %{client_id: "test", client_secret: "test"}
             ) == @error
    end
  end

  test "Tai position hydration halts on a typed positions error" do
    currencies = [%ExDeribit.Currency{currency: "BTC"}, %ExDeribit.Currency{currency: "ETH"}]

    with_mocks [
      {ExDeribit.MarketData.Currencies, [], get: fn -> {:ok, currencies} end},
      {ExDeribit.Accounts.Positions, [], get: fn _credentials, _currency -> @error end}
    ] do
      assert Tai.VenueAdapters.Deribit.Positions.positions(
               :deribit,
               :credential,
               %{client_id: "test", client_secret: "test"}
             ) == @error
    end
  end
end
