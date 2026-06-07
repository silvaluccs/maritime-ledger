defmodule Blockchain.Consensus do
  @moduledoc false
  require Logger
  alias Blockchain.{Block, Chain}

  def propose(block) do
    case commit(block) do
      {:ok, committed_block} ->
        broadcast_to_peers(committed_block)
        {:ok, committed_block}

      error ->
        error
    end
  end

  def receive_proposal(block_map) when is_map(block_map) do
    block = Blockchain.Chain.decode_block_from_map(block_map)
    last = Chain.get_last_block()

    if validate(block, last) do
      Logger.info("[CONSENSUS] Bloco #{block.index} recebido de peer — commitando")
      Chain.add_block(block)
      :approved
    else
      Logger.warning("[CONSENSUS] Bloco #{block.index} de peer REJEITADO")
      :rejected
    end
  end

  defp broadcast_to_peers(block) do
    case Process.whereis(Sector.TcpClient) do
      nil ->
        Logger.debug("[CONSENSUS] TcpClient não disponível — sem propagação")
        :ok

      _pid ->
        peers = Sector.TcpClient.connected_hosts()

        if Enum.empty?(peers) do
          Logger.debug("[CONSENSUS] Sem peers para propagar bloco #{block.index}")
        else
          Logger.info("[CONSENSUS] Propagando bloco #{block.index} para #{length(peers)} peer(s)")

          msg = %{
            "type" => "block_proposal",
            "from" => node_id(),
            "block" => JSON.decode!(JSON.encode!(block))
          }

          Sector.TcpClient.broadcast(msg)
        end
    end
  end

  defp validate(block, last_block) do
    block.previous_hash == last_block.hash &&
      block.hash == Block.calculate_hash(block)
  end

  defp commit(block) do
    case Chain.add_block(block) do
      :ok ->
        Logger.info("[CONSENSUS] Bloco #{block.index} commitado ✓")
        {:ok, block}

      {:error, reason} ->
        Logger.warning("[CONSENSUS] Falha ao commitar: #{reason}")
        {:error, reason}
    end
  end

  defp node_id do
    System.get_env("NODE_NAME", "unknown") <> ":" <> System.get_env("TCP_PORT", "5050")
  end
end
