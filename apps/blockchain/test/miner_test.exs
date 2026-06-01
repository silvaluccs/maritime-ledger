defmodule Blockchain.MinerTest do
  use ExUnit.Case, async: false

  alias Blockchain.{Chain, Ledger, Miner}

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

  describe "propose_debit/2" do
    test "retorna :ok com o bloco criado" do
      assert {:ok, block} = Miner.propose_debit("sector_1", "Ataque pirata")
      assert block.index == 1
    end

    test "bloco de débito contém a transação correta" do
      {:ok, block} = Miner.propose_debit("sector_1", "Ataque pirata")

      tx = hd(block.data)
      assert tx.owner_id == "sector_1"
      assert tx.amount == 10
      assert tx.type == :debit
      assert tx.mission_reason == "Ataque pirata"
    end

    test "saldo cai após débito" do
      Miner.propose_debit("sector_1", "Ataque pirata")
      assert Ledger.get_balance("sector_1") == 90
    end

    test "débito não afeta outros setores" do
      Miner.propose_debit("sector_1", "Ataque pirata")
      assert Ledger.get_balance("sector_2") == 100
    end

    test "múltiplos débitos acumulam corretamente" do
      Miner.propose_debit("sector_1", "Missão 1")
      Miner.propose_debit("sector_1", "Missão 2")
      Miner.propose_debit("sector_1", "Missão 3")
      assert Ledger.get_balance("sector_1") == 70
    end

    test "bloco tem hash encadeado corretamente" do
      last = Chain.get_last_block()
      {:ok, block} = Miner.propose_debit("sector_1", "Teste")
      assert block.previous_hash == last.hash
    end
  end

  describe "propose_mission_log/4" do
    test "retorna :ok com o bloco criado" do
      assert {:ok, block} =
               Miner.propose_mission_log(
                 "drone_alpha",
                 "sector_1",
                 "Ataque pirata",
                 :completed
               )

      assert block.index == 1
    end

    test "bloco contém o MissionLog correto" do
      {:ok, block} =
        Miner.propose_mission_log(
          "drone_alpha",
          "sector_1",
          "Incêndio no convés",
          :completed
        )

      log = hd(block.data)
      assert log.drone_id == "drone_alpha"
      assert log.sector_id == "sector_1"
      assert log.reason == "Incêndio no convés"
      assert log.result == :completed
    end

    test "MissionLog tem assinatura gerada" do
      {:ok, block} =
        Miner.propose_mission_log("drone_beta", "sector_2", "Homem ao mar", :aborted)

      log = hd(block.data)
      assert log.signature != nil
      assert String.length(log.signature) == 64
    end

    test "MissionLog não altera saldo do setor" do
      Miner.propose_mission_log("drone_alpha", "sector_1", "Teste", :completed)
      assert Ledger.get_balance("sector_1") == 100
    end
  end

  describe "propose_mint/2" do
    test "retorna :ok com o bloco criado" do
      assert {:ok, block} = Miner.propose_mint("sector_1", 5)
      assert block.index == 1
    end

    test "saldo aumenta após mint" do
      Miner.propose_debit("sector_1", "Missão")
      Miner.propose_mint("sector_1", 5)
      assert Ledger.get_balance("sector_1") == 95
    end

    test "mint tem mission_reason como regeneration" do
      {:ok, block} = Miner.propose_mint("sector_2", 10)
      tx = hd(block.data)
      assert tx.mission_reason == "regeneration"
      assert tx.type == :mint
    end
  end

  describe "integridade da chain após operações" do
    test "chain permanece válida após débito e laudo" do
      Miner.propose_debit("sector_1", "Ataque pirata")

      Miner.propose_mission_log(
        "drone_alpha",
        "sector_1",
        "Ataque pirata",
        :completed
      )

      assert Chain.valid_chain?() == true
    end

    test "chain tem índices sequenciais" do
      Miner.propose_debit("sector_1", "Missão 1")
      Miner.propose_debit("sector_2", "Missão 2")
      Miner.propose_mint("sector_3", 5)

      blocks = Chain.get_all_blocks()
      indices = Enum.map(blocks, & &1.index)
      assert indices == [0, 1, 2, 3]
    end
  end
end
