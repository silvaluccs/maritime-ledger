defmodule Blockchain.Block do
  @moduledoc """
  A struct representing a block in the blockchain.
  """

  @derive JSON.Encoder
  defstruct [
    :index,
    :previous_hash,
    :timestamp,
    :data,
    :hash
  ]

  @doc """

  Calculates the hash of a block based on its contents.

  ## Parameters

  - block: The block for which to calculate the hash.

  ## Example

      iex> block = %Blockchain.Block{
      ...>   index: 1,
      ...>   previous_hash: "0000000000000000",
      ...>   timestamp: 1625247600,
      ...>   data: "First block",
      ...>   hash: nil
      ...> }
      iex> Blockchain.Block.calculate_hash(block)
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  """
  def calculate_hash(block) do
    data =
      "#{block.index}#{block.previous_hash}#{block.timestamp}#{JSON.encode!(block.data)}"

    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  def validate_block(block, nil), do: block.hash == calculate_hash(block)

  @doc """

  Validates a block by comparing its hash with the calculated hash and ensuring it references the previous block correctly.

  ## Parameters
  - block: The block to validate.
  - previous_block: The previous block in the blockchain.

  ## Example

      iex> previous_block = %Blockchain.Block{
      ...>   index: 0,
      ...>   previous_hash: "0000000000000000",
      ...>   timestamp: 1625247600,
      ...>   data: "Genesis block",
      ...>   hash: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      ...> }
      iex> block = %Blockchain.Block{
      ...>   index: 1,
      ...>   previous_hash: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      ...>   timestamp: 1625247601,
      ...>   data: "First block",
      ...>   hash: "5d41402abc4b2a76b9719d911017c592"
      ...> }
      iex> Blockchain.Block.validate_block(block, previous_block)
      true
  """
  def validate_block(block, previous_block) do
    block.previous_hash == previous_block.hash &&
      block.hash == calculate_hash(block)
  end
end
