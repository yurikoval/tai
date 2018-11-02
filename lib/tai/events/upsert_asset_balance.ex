defmodule Tai.Events.UpsertAssetBalance do
  @type t :: %Tai.Events.UpsertAssetBalance{
          balance: Tai.Exchanges.AssetBalance.t()
        }

  @enforce_keys [:balance]
  defstruct [:balance]
end

defimpl Poison.Encoder, for: Tai.Events.UpsertAssetBalance do
  def encode(event, options) do
    %{
      type: "Tai.UpsertAssetBalance",
      data: %{
        venue_id: event.balance.exchange_id,
        account_id: event.balance.account_id,
        asset: event.balance.asset,
        free: event.balance.free |> Decimal.to_string(:normal),
        locked: event.balance.locked |> Decimal.to_string(:normal)
      }
    }
    |> Poison.encode!()
  end
end
