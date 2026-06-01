defmodule Sector.BalanceTest do
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

    Enum.each([Sector.Node, Sector.TcpServer, Sector.TcpClient], fn mod ->
      case Process.whereis(mod) do
        nil ->
          :ok

        pid ->
          try do
            GenServer.stop(pid)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    System.delete_env("HOSTS")
    :ok
  end

  test "verifica saldo disponível com node_id sector1:5050" do
    node_id = "sector1:5050"
    required_balance = 10
    result = Blockchain.Ledger.has_balance?(node_id, required_balance)
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

