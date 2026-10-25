defmodule ExDeribit.Announcement do
  alias __MODULE__

  @type t :: %Announcement{
          title: String.t(),
          publication_timestamp: pos_integer(),
          important: boolean,
          id: pos_integer,
          body: String.t()
        }

  @enforce_keys ~w(
    title
    publication_timestamp
    important
    id
    body
  )a
  defstruct ~w(
    title
    publication_timestamp
    important
    id
    body
  )a
end
