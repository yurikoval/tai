defmodule Tai.Venues.Start do
  use GenServer
  require Logger

  defmodule State do
    @type status ::
            :init
            | {:wait, {:products, :accounts, :positions}}
            | {:wait, {:fees, :stream}}
            | :success
            | {:error, :timeout | term}

    @enforce_keys ~w[venue status]a
    defstruct ~w[
      venue
      status
      timer
      products_task
      accounts_task
      fees_task
      positions_task
      stream_task
      products_reply
      accounts_reply
      fees_reply
      positions_reply
      stream_reply
    ]a
  end

  @type venue :: Tai.Venue.t()
  @type venue_id :: Tai.Venue.id()

  @spec start_link(venue) :: GenServer.on_start()
  def start_link(venue) do
    name = to_name(venue.id)
    state = %State{venue: venue, status: :init}
    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue_id), do: :"#{__MODULE__}_#{venue_id}"

  @spec status(venue_id) :: State.status()
  def status(venue_id) do
    venue_id
    |> to_name
    |> GenServer.call(:status)
  end

  def init(state) do
    {
      :ok,
      state,
      {:continue, {:start, {:products, :accounts, :positions}}}
    }
  end

  def handle_continue({:start, {:products, :accounts, :positions} = group}, state) do
    t_products =
      start_task(state.venue, :products, Tai.Venues.Start.Products, :hydrate, [state.venue])

    t_accounts =
      start_task(state.venue, :accounts, Tai.Venues.Start.Accounts, :hydrate, [state.venue])

    t_positions =
      start_task(state.venue, :positions, Tai.Venues.Start.Positions, :hydrate, [state.venue])

    timer = Process.send_after(self(), :timeout, state.venue.timeout)

    state = %{
      state
      | status: {:wait, group},
        timer: timer,
        products_task: t_products.ref,
        accounts_task: t_accounts.ref,
        positions_task: t_positions.ref
    }

    {:noreply, state}
  end

  def handle_info(
        {ref, reply},
        %State{status: {:wait, {:products, :accounts, :positions} = group}} = state
      )
      when is_reference(ref) do
    state = state |> save_reply(ref, reply)
    replies = [state.products_reply, state.accounts_reply, state.positions_reply]

    cond do
      Enum.any?(replies, &awaiting_reply?/1) ->
        {:noreply, state}

      Enum.all?(replies, &reply_ok?/1) ->
        send(self(), {:start, {:fees, :stream}})
        {:noreply, state}

      Enum.any?(replies, &reply_error?/1) ->
        send(self(), {:error, group})
        {:noreply, state}
    end
  end

  def handle_info({:start, {:fees, :stream} = group}, state) do
    {:ok, products} = state.products_reply
    {:ok, accounts} = state.accounts_reply
    {:ok, positions} = state.positions_reply
    market_streams = products |> filter_market_streams(state.venue.market_streams)

    stream = %Tai.Venues.Stream{
      venue: state.venue,
      markets: market_streams,
      accounts: accounts,
      positions: positions
    }

    t_fees =
      start_task(state.venue, :fees, Tai.Venues.Start.Fees, :hydrate, [state.venue, products])

    t_stream = start_task(state.venue, :stream, Tai.Venues.Start.Stream, :start, [stream])

    state = %{
      state
      | status: {:wait, group},
        fees_task: t_fees.ref,
        stream_task: t_stream.ref
    }

    {:noreply, state}
  end

  def handle_info(
        {ref, reply},
        %State{status: {:wait, {:fees, :stream} = group}} = state
      )
      when is_reference(ref) do
    state = state |> save_reply(ref, reply)
    replies = [state.fees_reply, state.stream_reply]

    cond do
      Enum.any?(replies, &awaiting_reply?/1) ->
        {:noreply, state}

      Enum.all?(replies, &reply_ok?/1) ->
        send(self(), {:ok, group})
        {:noreply, state}

      Enum.any?(replies, &reply_error?/1) ->
        send(self(), {:error, group})
        {:noreply, state}
    end

    {:noreply, state}
  end

  @venue_start_topic {:venue, :start}
  def handle_info({:ok, {:fees, :stream}}, state) do
    Process.cancel_timer(state.timer)
    topic_msg = {@venue_start_topic, state.venue.id}
    :ok = Tai.SystemBus.broadcast(@venue_start_topic, topic_msg)

    %Tai.Events.VenueStart{
      venue: state.venue.id
    }
    |> TaiEvents.info()

    state = %{state | status: :success}
    {:noreply, state}
  end

  @venue_start_error_topic {:venue, :start_error}

  def handle_info({:error, {:products, :accounts, :positions}}, state) do
    Process.cancel_timer(state.timer)
    reasons = [:products, :accounts, :positions] |> collect_error_reasons(state)
    topic_msg = {@venue_start_error_topic, state.venue.id, reasons}
    :ok = Tai.SystemBus.broadcast(@venue_start_error_topic, topic_msg)

    %Tai.Events.VenueStartError{
      venue: state.venue.id,
      reason: reasons
    }
    |> TaiEvents.error()

    state = %{state | status: {:error, reasons}}
    {:noreply, state}
  end

  def handle_info({:error, {:fees, :stream}}, state) do
    Process.cancel_timer(state.timer)
    reasons = [:fees, :stream] |> collect_error_reasons(state)
    topic_msg = {@venue_start_error_topic, state.venue.id, reasons}
    :ok = Tai.SystemBus.broadcast(@venue_start_error_topic, topic_msg)

    %Tai.Events.VenueStartError{
      venue: state.venue.id,
      reason: reasons
    }
    |> TaiEvents.error()

    state = %{state | status: {:error, reasons}}
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    reason = :timeout
    topic_msg = {@venue_start_error_topic, state.venue.id, reason}
    :ok = Tai.SystemBus.broadcast(@venue_start_error_topic, topic_msg)

    %Tai.Events.VenueStartError{
      venue: state.venue.id,
      reason: reason
    }
    |> TaiEvents.error()

    state = %{state | status: {:error, :timeout}}
    {:noreply, state}
  end

  def handle_info(
        {ref, _reply},
        %State{status: {:error, :timeout}} = state
      )
      when is_reference(ref) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, _reason},
        %State{status: {:wait, _group}} = state
      ) do
    if task_ref?(state, ref) do
      send(self(), {ref, {:error, {:exit, :task_exit}}})
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  def handle_call(:status, _from, state) do
    {:reply, state.status, state}
  end

  defp start_task(venue, phase, module, function, args) do
    Task.Supervisor.async_nolink(Tai.Venues.Start.TaskSupervisor, fn ->
      guarded_task(venue, phase, module, function, args)
    end)
  end

  defp guarded_task(venue, phase, module, function, args) do
    module
    |> apply(function, args)
    |> normalize_result(venue, phase)
  rescue
    exception ->
      log_exception(venue, phase, exception, __STACKTRACE__)
      {:error, {:exception, exception.__struct__}}
  catch
    kind, _reason ->
      Logger.error("Venue startup task exited",
        venue: venue.id,
        phase: phase,
        exit: kind,
        stacktrace: Exception.format_stacktrace(__STACKTRACE__)
      )

      {:error, {kind, :task_exit}}
  end

  defp normalize_result(
         {:error, {%{__exception__: true} = exception, stacktrace}},
         venue,
         phase
       )
       when is_list(stacktrace) do
    log_exception(venue, phase, exception, stacktrace)
    {:error, {:exception, exception.__struct__}}
  end

  defp normalize_result(result, _venue, _phase), do: result

  defp log_exception(venue, phase, exception, stacktrace) do
    Logger.error("Venue startup task raised",
      venue: venue.id,
      phase: phase,
      exception: exception.__struct__,
      stacktrace: Exception.format_stacktrace(stacktrace)
    )
  end

  defp task_ref?(state, ref) do
    ref in [
      state.products_task,
      state.accounts_task,
      state.positions_task,
      state.fees_task,
      state.stream_task
    ]
  end

  defp save_reply(state, ref, reply) do
    cond do
      ref == state.products_task -> %{state | products_reply: reply}
      ref == state.accounts_task -> %{state | accounts_reply: reply}
      ref == state.positions_task -> %{state | positions_reply: reply}
      ref == state.fees_task -> %{state | fees_reply: reply}
      ref == state.stream_task -> %{state | stream_reply: reply}
    end
  end

  defp awaiting_reply?(nil), do: true
  defp awaiting_reply?(_), do: false

  defp reply_ok?({:ok, _data}), do: true
  defp reply_ok?(_), do: false

  defp reply_error?({:error, _reasons}), do: true
  defp reply_error?(_), do: false

  defp collect_error_reasons(types, state) do
    types
    |> Enum.map(&{&1, Map.get(state, :"#{&1}_reply")})
    |> Enum.reduce(
      [],
      fn
        {_task, {:ok, _}}, acc -> acc
        {task, {:error, reason}}, acc -> [{task, reason} | acc]
      end
    )
  end

  defp filter_market_streams(products, query) do
    products
    |> Enum.group_by(& &1.symbol)
    |> Juice.squeeze(query)
    |> Map.values()
    |> Enum.flat_map(& &1)
  end
end
