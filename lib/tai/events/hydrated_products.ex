defmodule Tai.Events.HydratedProducts do
  @type t :: %Tai.Events.HydratedProducts{
          venue_id: atom,
          total: non_neg_integer,
          filtered: non_neg_integer
        }

  @enforce_keys [:venue_id, :total, :filtered]
  defstruct [:venue_id, :total, :filtered]
end
