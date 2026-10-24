defmodule Stored.Backend do
  @type table_name :: atom
  @type stored_record :: struct
  @type key :: term

  @callback create(table_name) :: :ok
  @callback put(struct, table_name) :: {:ok, {key, stored_record}}
  @callback find(key, table_name) :: {:ok, stored_record} | {:error, :not_found}
  @callback all(table_name) :: [stored_record]
  @callback delete(key, table_name) :: :ok
  @callback clear(table_name) :: :ok
end
