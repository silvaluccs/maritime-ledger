defmodule Blockchain.LedgerTest do
  use ExUnit.Case, async: false

  setup do
    case Process.whereis(Blockchain.Chain) do
      nil ->
        :ok

      pid ->
        try do
          GenServer.stop(pid)
        catch
          :exit, _ -> :ok
        end
    end

    File.rm("/tmp/maritime_chain_test.json")

    case Blockchain.Chain.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    :ok
  end

  test "saldo inicial de um setor é 100" do
    assert Blockchain.Ledger.get_balance("sector_1") == 100
  end

  test "has_balance? retorna true quando saldo suficiente" do
    assert Blockchain.Ledger.has_balance?("sector_1", 10) == true
  end

  test "has_balance? retorna false quando saldo insuficiente" do
    assert Blockchain.Ledger.has_balance?("sector_1", 999) == false
  end

  test "saldo cai após débito" do
    add_debit("sector_1", 30)
    assert Blockchain.Ledger.get_balance("sector_1") == 70
  end

  test "saldo de setor inexistente é zero" do
    assert Blockchain.Ledger.get_balance("sector_inexistente") == 0
  end

  test "múltiplos débitos acumulam corretamente" do
    add_debit("sector_1", 10)
    add_debit("sector_1", 20)
    add_debit("sector_1", 30)
    assert Blockchain.Ledger.get_balance("sector_1") == 40
  end

  test "débito em sector_1 não afeta sector_2" do
    add_debit("sector_1", 50)
    assert Blockchain.Ledger.get_balance("sector_2") == 100
  end

  test "get_all_balances retorna todos os setores" do
    balances = Blockchain.Ledger.get_all_balances()
    ids = Enum.map(balances, fn {id, _} -> id end)

    assert "sector_1" in ids
    assert "sector_2" in ids
    assert "sector_3" in ids
  end

  test "get_all_balances reflete débitos corretamente" do
    add_debit("sector_2", 40)

    balances = Map.new(Blockchain.Ledger.get_all_balances())

    assert balances["sector_1"] == 100
    assert balances["sector_2"] == 60
    assert balances["sector_3"] == 100
  end

  # Helper
  defp add_debit(owner_id, amount) do
    last = Blockchain.Chain.get_last_block()

    tx = %Blockchain.Transaction{
      id: UUIDv7.generate(),
      owner_id: owner_id,
      amount: amount,
      type: :debit,
      mission_reason: "teste ledger",
      timestamp: System.os_time(:second),
      signature: "teste"
    }

    block = %Blockchain.Block{
      index: last.index + 1,
      previous_hash: last.hash,
      timestamp: System.os_time(:second),
      data: [tx]
    }

    block = %{block | hash: Blockchain.Block.calculate_hash(block)}
    Blockchain.Chain.add_block(block)
  end
end
