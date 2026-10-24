base_formatters = [ExUnit.CLIFormatter]
formatters = if System.get_env("CI") == "true", do: base_formatters, else: base_formatters ++ [ExUnitNotifier]
ExUnit.configure(formatters: formatters)
{:ok, _} = Application.ensure_all_started(:tai)
Ecto.Adapters.SQL.Sandbox.mode(Tai.Orders.OrderRepo, :manual)
ExUnit.start()
