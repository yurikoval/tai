defmodule Tai.Trading.OrderStore.Actions.AmendError do
  @moduledoc """
  There was an error amending the order on the venue
  """

  @type client_id :: Tai.Trading.Order.client_id()
  @type t :: %__MODULE__{
          client_id: client_id,
          reason: term,
          last_received_at: integer
        }

  @enforce_keys ~w[client_id reason last_received_at]a
  defstruct ~w[client_id reason last_received_at]a
end

defimpl Tai.Trading.OrderStore.Action, for: Tai.Trading.OrderStore.Actions.AmendError do
  def required(_), do: :pending_amend

  def attrs(action) do
    {:ok, last_received_at} = Tai.Time.monotonic_to_date_time(action.last_received_at)

    %{
      status: :amend_error,
      error_reason: action.reason,
      last_received_at: last_received_at,
    }
  end
end
