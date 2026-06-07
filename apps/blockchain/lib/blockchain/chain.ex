defmodule Blockchain.Chain do
  @moduledoc """

  This module implements a GenServer that manages the blockchain. It handles adding new blocks, retrieving the chain, and validating the integrity of the chain. The blockchain is persisted to disk in a JSON file, allowing it to be loaded on startup.


  """
  use GenServer
  require Logger

  defp chain_file do
    Application.get_env(:blockchain, :chain_file, "chain.json")
  end

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def get_all_blocks, do: GenServer.call(__MODULE__, :get_all)
  def get_last_block, do: GenServer.call(__MODULE__, :get_last)
  def add_block(block), do: GenServer.call(__MODULE__, {:add_block, block})
  def valid_chain?, do: GenServer.call(__MODULE__, :valid_chain)
  def decode_block_from_map(map), do: decode_block(map)

  @impl true
  def init(_opts) do
    chain = load_chain_from_disk()
    Logger.info("[CHAIN] Iniciada — #{length(chain)} bloco(s) carregado(s)")
    {:ok, chain}
  end

  @impl true
  def handle_call(:get_all, _from, chain) do
    {:reply, Enum.reverse(chain), chain}
  end

  @impl true
  def handle_call(:get_last, _from, [head | _] = chain) do
    {:reply, head, chain}
  end

  @impl true
  def handle_call({:add_block, block}, _from, [last | _] = chain) do
    if Blockchain.Block.validate_block(block, last) do
      new_chain = [block | chain]

      save_chain_to_disk(new_chain)

      Logger.info("[CHAIN] Bloco #{block.index} adicionado e salvo — hash: #{block.hash}")
      {:reply, :ok, new_chain}
    else
      Logger.warning("[CHAIN] Bloco #{block.index} REJEITADO — hash inválido")
      {:reply, {:error, :invalid_block}, chain}
    end
  end

  @impl true
  def handle_call(:valid_chain, _from, chain) do
    valid =
      chain
      |> Enum.reverse()
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [prev, curr] ->
        Blockchain.Block.validate_block(curr, prev)
      end)

    {:reply, valid, chain}
  end

  defp save_chain_to_disk(chain) do
    json =
      chain
      |> Enum.reverse()
      |> JSON.encode!()

    file = chain_file()
    File.write!(file, json)
    Logger.debug("[CHAIN] Chain salva em #{file}")
  end

  defp load_chain_from_disk do
    file = chain_file()

    if File.exists?(file) do
      Logger.info("[CHAIN] Arquivo encontrado — carregando do disco...")

      file
      |> File.read!()
      |> JSON.decode!()
      |> Enum.map(&decode_block/1)
      |> Enum.reverse()
    else
      Logger.info("[CHAIN] Nenhum arquivo encontrado — criando bloco gênese...")
      genesis = create_genesis_block()
      save_chain_to_disk([genesis])
      [genesis]
    end
  end

  defp decode_block(map) do
    %Blockchain.Block{
      index: map["index"],
      previous_hash: map["previous_hash"],
      timestamp: map["timestamp"],
      hash: map["hash"],
      data: Enum.map(map["data"], &decode_entry/1)
    }
  end

  defp decode_entry(%{"type" => type} = map) when type in ["mint", "debit"] do
    %Blockchain.Transaction{
      id: map["id"],
      owner_id: map["owner_id"],
      amount: map["amount"],
      type: String.to_atom(map["type"]),
      mission_reason: map["mission_reason"],
      timestamp: map["timestamp"],
      signature: map["signature"]
    }
  end

  defp decode_entry(map) do
    %Blockchain.MissionLog{
      id: map["id"],
      drone_id: map["drone_id"],
      sector_id: map["sector_id"],
      reason: map["reason"],
      result: String.to_atom(map["result"]),
      timestamp: map["timestamp"],
      signature: map["signature"]
    }
  end

  defp create_genesis_block do
    sectors = Application.get_env(:blockchain, :sectors, default_sectors())

    transactions =
      Enum.map(sectors, fn {sector_id, initial_balance} ->
        %Blockchain.Transaction{
          id: UUIDv7.generate(),
          owner_id: sector_id,
          amount: initial_balance,
          type: :mint,
          mission_reason: "genesis",
          timestamp: System.os_time(:second),
          signature: "genesis"
        }
      end)

    block = %Blockchain.Block{
      index: 0,
      previous_hash: "0000000000000000",
      timestamp: System.os_time(:second),
      data: transactions
    }

    %{block | hash: Blockchain.Block.calculate_hash(block)}
  end

  defp default_sectors do
    case System.get_env("BLOCKCHAIN_SECTORS") do
      nil ->
        [{"sector_1", 100}, {"sector_2", 100}, {"sector_3", 100}]

      raw ->
        raw
        |> String.split(",")
        |> Enum.map(&{&1, 100})
    end
  end
end
