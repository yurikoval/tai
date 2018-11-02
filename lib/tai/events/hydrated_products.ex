defmodule Tai.Events.HydratedProducts do
  @type t :: %Tai.Events.HydratedProducts{
          venue_id: atom,
          total: non_neg_integer,
          filtered: non_neg_integer
        }

  @enforce_keys [:venue_id, :total, :filtered]
  defstruct [:venue_id, :total, :filtered]
end

defimpl Poison.Encoder, for: Tai.Events.HydratedProducts do
  def encode(event, options) do
    %{
      type: "Tai.HydratedProducts",
      data: %{
        venue_id: event.venue_id,
        total: event.total,
        filtered: event.filtered
      }
    }
    |> Poison.encode!()
  end
end
