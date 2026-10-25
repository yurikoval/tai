defmodule Tai.Test.ExVCRHackneyTest do
  use ExUnit.Case

  test "filters recorded Hackney 4 responses without changing the live response" do
    previous_filters = ExVCR.Setting.get(:filter_sensitive_data)
    ExVCR.Setting.set(:filter_sensitive_data, [{"secret", "[FILTERED]"}])
    on_exit(fn -> ExVCR.Setting.set(:filter_sensitive_data, previous_filters) end)

    request = [:get, "https://example.test", [], "", []]
    response = {:ok, 200, [], "secret"}

    assert ^response = live_response = Tai.Test.ExVCRHackney.hook_response_from_server(response)

    assert %{response: %ExVCR.Response{body: "[FILTERED]"}} =
             Tai.Test.ExVCRHackney.convert_to_string(request, live_response)
  end
end
