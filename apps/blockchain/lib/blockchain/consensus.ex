defmodule Blockchain.Consensus do
  @moduledoc false
  require Logger

  alias Blockchain.{Block, Chain}

  def propose(block) do
    peers = get_peers()

    if Enum.empty?(peers) do
      Logger.info("[CONSENSUS] Sem peers — commit local direto")
      commit(block)
    else
      Logger.info("[CONSENSUS] Propondo bloco #{block.index} para #{length(peers)} peer(s)")
      collect_votes_and_commit(block, peers)
    end
  end

  def receive_proposal(block) do
    last = Chain.get_last_block()

    if validate(block, last) do
      Logger.info("[CONSENSUS] Bloco #{block.index} validado — commitando")
      commit(block)
      :approved
    else
      Logger.warning("[CONSENSUS] Bloco #{block.index} inválido — rejeitado")
      :rejected
    end
  end

  defp collect_votes_and_commit(block, peers) do
    total = length(peers) + 1
    majority = div(total, 2) + 1

    # Por ora coleta votos localmente     # Cada peer vai chamar receive_proposal via TCP
    # meu próprio voto
    votes_approved = 1

    if votes_approved >= majority do
      commit(block)
    else
      Logger.warning("[CONSENSUS] Bloco #{block.index} não atingiu maioria — descartado")
      {:error, :no_majority}
    end
  end

  defp validate(block, last_block) do
    block.previous_hash == last_block.hash &&
      block.hash == Block.calculate_hash(block)
  end

  defp commit(block) do
    case Chain.add_block(block) do
      :ok ->
        Logger.info("[CONSENSUS] Bloco #{block.index} commitado na chain ✓")
        {:ok, block}

      {:error, reason} ->
        Logger.warning("[CONSENSUS] Falha ao commitar bloco #{block.index}: #{reason}")
        {:error, reason}
    end
  end

  defp get_peers do
    Application.get_env(:blockchain, :peers, [])
  end
end
