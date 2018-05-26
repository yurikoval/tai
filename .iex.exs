Application.put_env(:elixir, :ansi_enabled, true)

import Tai.Commands.Helper

IO.puts("===================================")
IO.puts("Welcome to tai! The trading toolkit")
dashboard()
