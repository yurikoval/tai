defmodule Tai.Test.ExVCRHackney do
  use ExVCR.Adapter

  defmacro __using__(_opts) do
    quote do
      ExVCR.Adapter.Hackney.Store.start()
    end
  end

  defdelegate module_name(), to: ExVCR.Adapter.Hackney
  defdelegate target_methods(), to: ExVCR.Adapter.Hackney
  defdelegate target_methods(recorder), to: ExVCR.Adapter.Hackney
  defdelegate generate_keys_for_request(request), to: ExVCR.Adapter.Hackney
  defdelegate get_response_value_from_cache(response), to: ExVCR.Adapter.Hackney
  defdelegate convert_from_string(string), to: ExVCR.Adapter.Hackney

  def convert_to_string(request, {:ok, status, headers, body}) when is_binary(body) do
    response = {:ok, status, headers, ExVCR.Filter.filter_sensitive_data(body)}
    ExVCR.Adapter.Hackney.convert_to_string(request, response)
  end

  def convert_to_string(request, response) do
    ExVCR.Adapter.Hackney.convert_to_string(request, response)
  end

  defdelegate default_stub_params(name), to: ExVCR.Adapter.Hackney

  def hook_response_from_server({:ok, status, headers, body}) do
    headers = ExVCR.Filter.remove_blacklisted_headers(headers)
    {:ok, status, headers, body}
  end

  def hook_response_from_server(response) do
    ExVCR.Adapter.Hackney.hook_response_from_server(response)
  end

  # Hackney 4 returns response bodies directly instead of through hackney:body/1.
  def hook_response_from_cache(_request, response), do: response
end
