defmodule Sector.BalanceTest do
  use ExUnit.Case, async: false

  setup do
    # Para os testes, precisa simular um node_id que corresponda ao chain.json
    :ok
  end

  test "verifica saldo disponível com node_id sector1:5050" do
    # Simula o que acontece no docker
    node_id = "sector1:5050"
    required_balance = 10

    result = Blockchain.Ledger.has_balance?(node_id, required_balance)

    # Se o chain.json está correto, deve retornar true
    IO.puts("\n✅ Node ID: #{node_id}")
    IO.puts("   Required: #{required_balance}")
    IO.puts("   Has balance: #{result}")
    IO.puts("   Balance: #{Blockchain.Ledger.get_balance(node_id)}")

    assert result == true
  end

  test "verifica saldo com node_id sector2:5050" do
    node_id = "sector2:5050"
    required_balance = 10

    result = Blockchain.Ledger.has_balance?(node_id, required_balance)

    IO.puts("\n✅ Node ID: #{node_id}")
    IO.puts("   Required: #{required_balance}")
    IO.puts("   Has balance: #{result}")
    IO.puts("   Balance: #{Blockchain.Ledger.get_balance(node_id)}")

    assert result == true
  end

  test "verifica saldo com node_id sector3:5050" do
    node_id = "sector3:5050"
    required_balance = 10

    result = Blockchain.Ledger.has_balance?(node_id, required_balance)

    IO.puts("\n✅ Node ID: #{node_id}")
    IO.puts("   Required: #{required_balance}")
    IO.puts("   Has balance: #{result}")
    IO.puts("   Balance: #{Blockchain.Ledger.get_balance(node_id)}")

    assert result == true
  end
end
