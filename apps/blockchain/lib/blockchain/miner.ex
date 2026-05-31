defmodule Blockchain.Miner do
  @moduledoc """
  Represents a miner in the blockchain network.
  A miner is responsible for validating transactions and adding new blocks to the blockchain.
  """

  require Logger

  alias Blockchain.{Block, Chain, MissionLog, Transaction}

  @mission_cost 10

  @doc """
  Proposes a debit transaction for a sector.

  ## Parameters
  - owner_id: The ID of the owner of the sector.
  - reason: The reason for the debit (e.g., "mission_execution").

  ## Example
      iex> Blockchain.Miner.propose_debit("owner123", "mission_execution")
      :ok

  """
  def propose_debit(owner_id, reason) do
    tx = %Transaction{
      id: UUIDv7.generate(),
      owner_id: owner_id,
      amount: @mission_cost,
      type: :debit,
      mission_reason: reason,
      timestamp: System.os_time(:second),
      signature: sign(owner_id <> reason)
    }

    propose_block([tx])
  end

  def propose_mission_log(drone_id, sector_id, reason, result) do
    log = %MissionLog{
      id: UUIDv7.generate(),
      drone_id: drone_id,
      sector_id: sector_id,
      reason: reason,
      result: result,
      timestamp: System.os_time(:second),
      signature: sign(drone_id <> sector_id <> reason)
    }

    propose_block([log])
  end

  def propose_mint(owner_id, amount) do
    tx = %Transaction{
      id: UUIDv7.generate(),
      owner_id: owner_id,
      amount: amount,
      type: :mint,
      mission_reason: "regeneration",
      timestamp: System.os_time(:second),
      signature: sign(owner_id <> "regeneration")
    }

    propose_block([tx])
  end

  defp propose_block(data) do
    last = Chain.get_last_block()

    block = %Block{
      index: last.index + 1,
      previous_hash: last.hash,
      timestamp: System.os_time(:second),
      data: data
    }

    block = %{block | hash: Block.calculate_hash(block)}

    Logger.info("[MINER] Propondo bloco #{block.index} — hash: #{block.hash}")

    Blockchain.Consensus.propose(block)
  end

  defp sign(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
