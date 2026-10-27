defmodule Tai.Venues.Instances do
  @type venue :: Tai.Venue.t()

  @spec find(venue) :: {:ok, pid} | {:error, :not_found}
  def find(venue) do
    venue.id
    |> Tai.Venues.Start.to_name()
    |> Process.whereis()
    |> case do
      nil -> {:error, :not_found}
      pid -> {:ok, pid}
    end
  end

  @spec find_stream(venue) :: {:ok, pid} | {:error, :not_found}
  def find_stream(venue) do
    adapter = venue.adapter

    Tai.Venues.StreamsSupervisor.which_children()
    |> Enum.find(fn {:undefined, _pid, :supervisor, [mod]} ->
      mod == adapter.stream_supervisor()
    end)
    |> case do
      nil -> {:error, :not_found}
      {:undefined, pid, _, _} -> {:ok, pid}
    end
  end

  @spec stop(venue) :: :ok | {:error, :already_stopped}
  def stop(venue) do
    stream_result = stop_stream(venue)
    start_result = stop_start(venue)

    if :ok in [stream_result, start_result], do: :ok, else: {:error, :already_stopped}
  end

  defp stop_stream(venue) do
    with {:ok, pid} <- find_stream(venue), do: Tai.Venues.StreamsSupervisor.stop(pid)
  end

  defp stop_start(venue) do
    with {:ok, pid} <- find(venue), do: Tai.Venues.Supervisor.stop(pid)
  end
end
