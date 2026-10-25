defmodule ExDeribit.Credentials do
  alias __MODULE__

  @type t :: %Credentials{
          client_id: String.t(),
          client_secret: String.t()
        }

  @enforce_keys ~w(client_id client_secret)a
  defstruct ~w(client_id client_secret)a
end
