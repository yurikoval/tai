defmodule ExDeribit.JsonRpcResponse do
  alias __MODULE__

  @type t :: %JsonRpcResponse{
          id: pos_integer,
          jsonrpc: String.t(),
          result: map | list
        }

  defstruct ~w(id jsonrpc result)a
end
