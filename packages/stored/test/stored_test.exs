defmodule StoredTest do
  use ExUnit.Case, async: true

  alias Stored.{TestItem, TestStore}

  setup do
    start_supervised!({TestStore, [id: :test]})
    :ok
  end

  test "puts, finds, lists, deletes, and clears" do
    first = %TestItem{id: 1, value: "one"}
    second = %TestItem{id: 2, value: "two"}

    assert {:ok, {1, ^first}} = TestStore.put(first, :test)
    assert {:ok, ^first} = TestStore.find(1, :test)
    assert [^first] = TestStore.all(:test)

    assert {:ok, {2, ^second}} = TestStore.put(second, :test)
    assert Enum.sort(TestStore.all(:test)) == Enum.sort([first, second])
    assert {:ok, 1} = TestStore.delete(1, :test)
    assert {:error, :not_found} = TestStore.find(1, :test)

    assert :ok = TestStore.clear(:test)
    assert [] = TestStore.all(:test)
  end
end
