defmodule Blockchain.ChainTest do
  use ExUnit.Case, async: false
  require Logger

  setup do
    # Para o GenServer se estiver rodando
    case Process.whereis(Blockchain.Chain) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    File.rm("chain.json")

    # Inicia instância limpa — ignora se já estiver rodando
    case Blockchain.Chain.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  describe "inicialização" do
    test "inicia com o bloco gênese" do
      blocks = Blockchain.Chain.get_all_blocks()
      assert length(blocks) == 1
    end

    test "bloco gênese tem index 0" do
      genesis = Blockchain.Chain.get_last_block()
      assert genesis.index == 0
    end

    test "bloco gênese tem previous_hash zerado" do
      genesis = Blockchain.Chain.get_last_block()
      assert genesis.previous_hash == "0000000000000000"
    end

    test "bloco gênese tem hash calculado (não nulo)" do
      genesis = Blockchain.Chain.get_last_block()
      assert genesis.hash != nil
      assert String.length(genesis.hash) == 64
    end

    test "bloco gênese contém transações mint para cada setor" do
      genesis = Blockchain.Chain.get_last_block()

      owner_ids = Enum.map(genesis.data, & &1.owner_id)

      assert "sector_1" in owner_ids
      assert "sector_2" in owner_ids
      assert "sector_3" in owner_ids
    end

    test "todas as transações do gênese são do tipo mint" do
      genesis = Blockchain.Chain.get_last_block()

      Enum.each(genesis.data, fn tx ->
        assert tx.type == :mint
      end)
    end

    test "saldo inicial de cada setor é 100" do
      genesis = Blockchain.Chain.get_last_block()

      Enum.each(genesis.data, fn tx ->
        assert tx.amount == 100
      end)
    end
  end

  describe "add_block/1" do
    test "adiciona um bloco válido com sucesso" do
      last = Blockchain.Chain.get_last_block()

      new_block = build_block(last, [build_transaction("sector_1", :debit, 10)])

      assert Blockchain.Chain.add_block(new_block) == :ok
    end

    test "chain tem 2 blocos após adicionar um bloco válido" do
      last = Blockchain.Chain.get_last_block()
      new_block = build_block(last, [build_transaction("sector_1", :debit, 10)])

      Blockchain.Chain.add_block(new_block)

      assert length(Blockchain.Chain.get_all_blocks()) == 2
    end

    test "rejeita bloco com previous_hash errado" do
      last = Blockchain.Chain.get_last_block()

      bloco_invalido = %Blockchain.Block{
        index: last.index + 1,
        previous_hash: "hash_errado_qualquer",
        timestamp: System.os_time(:second),
        data: []
      }

      bloco_invalido = %{bloco_invalido | hash: Blockchain.Block.calculate_hash(bloco_invalido)}

      assert Blockchain.Chain.add_block(bloco_invalido) == {:error, :invalid_block}
    end

    test "rejeita bloco com hash adulterado" do
      last = Blockchain.Chain.get_last_block()

      bloco_adulterado = %Blockchain.Block{
        index: last.index + 1,
        previous_hash: last.hash,
        timestamp: System.os_time(:second),
        data: [],
        hash: "hash_falso_adulterado_000000000000000000000000000000000000000000"
      }

      assert Blockchain.Chain.add_block(bloco_adulterado) == {:error, :invalid_block}
    end

    test "chain não cresce após rejeição de bloco inválido" do
      last = Blockchain.Chain.get_last_block()

      bloco_invalido = %Blockchain.Block{
        index: last.index + 1,
        previous_hash: "errado",
        timestamp: System.os_time(:second),
        data: [],
        hash: "hash_errado_00000000000000000000000000000000000000000000000000000"
      }

      Blockchain.Chain.add_block(bloco_invalido)

      assert length(Blockchain.Chain.get_all_blocks()) == 1
    end

    test "adiciona múltiplos blocos em sequência" do
      Enum.reduce(1..5, Blockchain.Chain.get_last_block(), fn _i, last ->
        block = build_block(last, [build_transaction("sector_1", :debit, 10)])
        assert Blockchain.Chain.add_block(block) == :ok
        Blockchain.Chain.get_last_block()
      end)

      assert length(Blockchain.Chain.get_all_blocks()) == 6
    end

    test "blocos são retornados em ordem cronológica (get_all_blocks)" do
      last = Blockchain.Chain.get_last_block()
      b1 = build_block(last, [])
      Blockchain.Chain.add_block(b1)
      last2 = Blockchain.Chain.get_last_block()
      b2 = build_block(last2, [])
      Blockchain.Chain.add_block(b2)

      [g, bloco1, bloco2] = Blockchain.Chain.get_all_blocks()

      assert g.index == 0
      assert bloco1.index == 1
      assert bloco2.index == 2
    end
  end

  describe "valid_chain?/0" do
    test "chain com apenas gênese é válida" do
      assert Blockchain.Chain.valid_chain?() == true
    end

    test "chain com múltiplos blocos válidos é válida" do
      Enum.reduce(1..3, Blockchain.Chain.get_last_block(), fn _i, last ->
        block = build_block(last, [])
        Blockchain.Chain.add_block(block)
        Blockchain.Chain.get_last_block()
      end)

      assert Blockchain.Chain.valid_chain?() == true
    end
  end

  describe "persistência em disco" do
    test "arquivo chain.json é criado ao iniciar" do
      assert File.exists?("chain.json")
    end

    test "arquivo chain.json é atualizado ao adicionar bloco" do
      last = Blockchain.Chain.get_last_block()
      block = build_block(last, [build_transaction("sector_1", :debit, 10)])
      Blockchain.Chain.add_block(block)

      json = File.read!("chain.json")
      assert String.contains?(json, "sector_1")
    end

    test "chain é carregada do disco ao reiniciar" do
      last = Blockchain.Chain.get_last_block()
      block = build_block(last, [build_transaction("sector_2", :debit, 20)])
      Blockchain.Chain.add_block(block)

      hash_salvo = Blockchain.Chain.get_last_block().hash

      GenServer.stop(Blockchain.Chain)
      {:ok, _} = Blockchain.Chain.start_link()

      assert length(Blockchain.Chain.get_all_blocks()) == 2
      assert Blockchain.Chain.get_last_block().hash == hash_salvo
    end

    test "chain carregada do disco é válida" do
      last = Blockchain.Chain.get_last_block()
      block = build_block(last, [])
      Blockchain.Chain.add_block(block)

      GenServer.stop(Blockchain.Chain)
      {:ok, _} = Blockchain.Chain.start_link()

      assert Blockchain.Chain.valid_chain?() == true
    end

    test "gênese não é recriado se arquivo já existe" do
      genesis_original = hd(Blockchain.Chain.get_all_blocks())

      GenServer.stop(Blockchain.Chain)
      {:ok, _} = Blockchain.Chain.start_link()

      genesis_recarregado = hd(Blockchain.Chain.get_all_blocks())

      assert genesis_original.timestamp == genesis_recarregado.timestamp
      assert genesis_original.hash == genesis_recarregado.hash
    end
  end

  describe "blocos com MissionLog" do
    test "aceita bloco contendo MissionLog" do
      last = Blockchain.Chain.get_last_block()

      log = %Blockchain.MissionLog{
        id: UUIDv7.generate(),
        drone_id: "drone_alpha",
        sector_id: "sector_1",
        reason: "Ataque pirata",
        result: :completed,
        timestamp: System.os_time(:second),
        signature: "sig_test"
      }

      block = build_block(last, [log])
      assert Blockchain.Chain.add_block(block) == :ok
    end

    test "MissionLog é persistido e recarregado corretamente" do
      last = Blockchain.Chain.get_last_block()

      log = %Blockchain.MissionLog{
        id: UUIDv7.generate(),
        drone_id: "drone_beta",
        sector_id: "sector_2",
        reason: "Incêndio no convés",
        result: :completed,
        timestamp: System.os_time(:second),
        signature: "sig_test"
      }

      block = build_block(last, [log])
      Blockchain.Chain.add_block(block)

      GenServer.stop(Blockchain.Chain)
      {:ok, _} = Blockchain.Chain.start_link()

      blocks = Blockchain.Chain.get_all_blocks()
      ultimo = List.last(blocks)

      assert length(ultimo.data) == 1
      assert hd(ultimo.data).drone_id == "drone_beta"
      assert hd(ultimo.data).result == :completed
    end
  end

  defp build_block(previous_block, data) do
    block = %Blockchain.Block{
      index: previous_block.index + 1,
      previous_hash: previous_block.hash,
      timestamp: System.os_time(:second),
      data: data
    }

    %{block | hash: Blockchain.Block.calculate_hash(block)}
  end

  defp build_transaction(owner_id, type, amount) do
    %Blockchain.Transaction{
      id: UUIDv7.generate(),
      owner_id: owner_id,
      amount: amount,
      type: type,
      mission_reason: "teste",
      timestamp: System.os_time(:second),
      signature: "sig_teste"
    }
  end
end
