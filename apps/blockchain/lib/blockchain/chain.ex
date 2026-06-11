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

  def maybe_replace_chain(chain_as_maps) do
    GenServer.call(__MODULE__, {:maybe_replace_chain, chain_as_maps})
  end

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

  @impl true
  def handle_call({:maybe_replace_chain, []}, _from, chain) do
    Logger.warning("[CHAIN SYNC] Chain recebida está vazia — ignorando")
    {:reply, :rejected, chain}
  end

  @impl true
  def handle_call({:maybe_replace_chain, chain_as_maps}, _from, chain) do
    incoming = Enum.map(chain_as_maps, &decode_block/1) |> Enum.reverse()

    cond do
      not valid_incoming?(incoming) ->
        Logger.warning("[CHAIN SYNC] Chain recebida é inválida — ignorando")
        {:reply, :rejected, chain}

      local_corrupted?(chain) ->
        Logger.error(
          "[CHAIN SYNC]  DETECTADA CORRUPÇÃO/FRAUDE NA CHAIN LOCAL! Substituindo pelos dados íntegros da rede."
        )

        IO.puts(
          "=== [SHELL] [CHAIN SYNC] Dados locais corrompidos/editados! Restaurando integridade via rede... ==="
        )

        save_chain_to_disk(incoming)
        {:reply, :replaced, incoming}

      length(incoming) <= length(chain) ->
        Logger.info(
          "[CHAIN SYNC] Chain recebida não é maior — ignorando (local: #{length(chain)}, recebida: #{length(incoming)})"
        )

        {:reply, :ignored, chain}

      true ->
        Logger.info(
          "[CHAIN SYNC] Substituindo chain local por uma cadeia mais longa (#{length(chain)} → #{length(incoming)} blocos)"
        )

        IO.puts("=== [SHELL] [CHAIN SYNC] Chain atualizada com #{length(incoming)} blocos ===")
        save_chain_to_disk(incoming)
        {:reply, :replaced, incoming}
    end
  end

  defp valid_incoming?(incoming) do
    incoming
    |> Enum.reverse()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [prev, curr] ->
      Blockchain.Block.validate_block(curr, prev) and
        curr.hash == Blockchain.Block.calculate_hash(curr)
    end)
  end

  defp local_corrupted?(chain) do
    not valid_local?(chain)
  end

  defp valid_local?(chain) do
    chain
    |> Enum.reverse()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(&valid_pair?/1)
  end

  defp valid_pair?([prev, curr]) do
    curr.hash == Blockchain.Block.calculate_hash(curr) and
      curr.previous_hash == prev.hash and
      prev.hash == Blockchain.Block.calculate_hash(prev)
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

    if File.exists?(file) and File.stat!(file).size > 0 do
      Logger.info("[CHAIN] Arquivo encontrado — carregando do disco...")

      case File.read!(file) |> JSON.decode!() do
        [] ->
          Logger.info("[CHAIN] Arquivo com lista vazia [] — criando bloco gênese...")

          genesis = create_genesis_block()

          save_chain_to_disk([genesis])

          [genesis]

        decoded_list ->
          decoded_list
          |> Enum.map(&decode_block/1)
          |> Enum.reverse()
      end
    else
      Logger.info("[CHAIN] Nenhum arquivo ou arquivo vazio — criando bloco gênese...")

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

    # Removido UUID dinâmico e timestamps variáveis para congelar o hash do Gênese
    transactions =
      Enum.with_index(sectors)
      |> Enum.map(fn {{sector_id, initial_balance}, index} ->
        %Blockchain.Transaction{
          id: "00000000-0000-0000-0000-00000000000" <> to_string(index),
          owner_id: sector_id,
          amount: initial_balance,
          type: :mint,
          mission_reason: "genesis",
          timestamp: 1_718_110_000,
          signature: "genesis"
        }
      end)

    block = %Blockchain.Block{
      index: 0,
      previous_hash: "0000000000000000",
      timestamp: 1_718_110_000,
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
