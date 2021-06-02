defmodule Tai.NewOrders.Transitions.PartialFill do
  @moduledoc """
  An order has been partially filled. This is a self transition and does not
  update the status attribute.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @behaviour Tai.NewOrders.Transition

  @type t :: %__MODULE__{}

  @primary_key false

  embedded_schema do
    field(:cumulative_qty, :decimal)
    field(:leaves_qty, :decimal)
    field(:last_received_at, :utc_datetime_usec)
    field(:last_venue_timestamp, :utc_datetime_usec)
  end

  def changeset(transition, params) do
    transition
    |> cast(params, [:leaves_qty, :last_received_at, :last_venue_timestamp])
    |> validate_required([:leaves_qty, :last_received_at])
  end

  def from, do: ~w[open pending_cancel cancel_accepted pending_amend amend_accepted]a

  def attrs(transition) do
    [
      cumulative_qty: transition.cumulative_qty,
      leaves_qty: transition.leaves_qty,
      qty: Decimal.add(transition.cumulative_qty, transition.leaves_qty),
      last_received_at: transition.last_received_at,
      last_venue_timestamp: transition.last_venue_timestamp
    ]
  end
end