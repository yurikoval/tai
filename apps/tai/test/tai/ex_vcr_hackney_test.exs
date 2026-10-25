defmodule Tai.Test.ExVCRHackneyTest do
  use ExUnit.Case, async: true

  test "supports recording Hackney 4 responses without exposing filtered data" do
    previous_filters = ExVCR.Setting.get(:filter_sensitive_data)
    ExVCR.Setting.set(:filter_sensitive_data, [{"secret", "[FILTERED]"}])
    on_exit(fn -> ExVCR.Setting.set(:filter_sensitive_data, previous_filters) end)

    assert function_exported?(Tai.Test.ExVCRHackney, :convert_to_string, 2)

    assert {:ok, 200, [], "[FILTERED]"} =
             Tai.Test.ExVCRHackney.hook_response_from_server({:ok, 200, [], "secret"})
  end
end
