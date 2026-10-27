defmodule ExDeribit.JsonRpcResponse do
  alias __MODULE__

  @type t :: %JsonRpcResponse{
          id: pos_integer,
          jsonrpc: String.t(),
          result: term,
          error: map | nil
        }

  defstruct ~w(id jsonrpc result error)a
end
