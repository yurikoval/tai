defmodule Tai.EventLogger do
  require Logger

  # @type event :: Tai.Event.t()

  # @spec info(event) :: :ok
  def info(event) do
    # msg = Tai.Event.json(event)
    # Logger.info(%{tid: event.tid, msg: msg})
  end
end
