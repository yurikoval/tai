defmodule Tai.Markets.PricePoint do
  @type t :: %Tai.Markets.PricePoint{
          price: Decimal.t(),
          qty: Decimal.t(),
          received_at: DateTime.t(),
          sent_at: DateTime.t() | nil
        }

  defstruct [:price, :qty, :received_at, :sent_at]
end
