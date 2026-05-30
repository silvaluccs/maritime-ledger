defmodule BlockTest do
  use ExUnit.Case

  alias Blockchain.Block

  describe "struct" do
    test "creates a block with all fields" do
      block = %Block{
        index: 1,
        timestamp: 1_234_567_890,
        data: "some data",
        previous_hash: "0",
        hash: "abc123"
      }

      assert block.index == 1
      assert block.timestamp == 1_234_567_890
      assert block.data == "some data"
      assert block.previous_hash == "0"
      assert block.hash == "abc123"
    end
  end

  describe "calculate_hash/1" do
    test "returns a 64-character hex string" do
      block = %Block{
        index: 1,
        previous_hash: "0",
        timestamp: 1_234_567_890,
        data: "test",
        hash: nil
      }

      hash = Block.calculate_hash(block)

      assert is_binary(hash)
      assert String.length(hash) == 64
      assert String.match?(hash, ~r/^[0-9a-f]+$/)
    end

    test "is deterministic (same input -> same hash)" do
      block = %Block{index: 2, previous_hash: "abc", timestamp: 123, data: "x", hash: nil}

      assert Block.calculate_hash(block) == Block.calculate_hash(block)
    end

    test "different data produces different hash" do
      block1 = %Block{index: 1, previous_hash: "0", timestamp: 123, data: "a", hash: nil}
      block2 = %Block{index: 1, previous_hash: "0", timestamp: 123, data: "b", hash: nil}

      refute Block.calculate_hash(block1) == Block.calculate_hash(block2)
    end
  end

  describe "validate_block/2" do
    setup do
      genesis = %Block{
        index: 0,
        previous_hash: "0",
        timestamp: 1_000,
        data: "genesis",
        hash: nil
      }

      genesis = %{genesis | hash: Block.calculate_hash(genesis)}

      valid_block = %Block{
        index: 1,
        previous_hash: genesis.hash,
        timestamp: 2_000,
        data: "second",
        hash: nil
      }

      valid_block = %{valid_block | hash: Block.calculate_hash(valid_block)}

      %{genesis: genesis, valid_block: valid_block}
    end

    test "returns true for a valid block", %{genesis: genesis, valid_block: valid_block} do
      assert Block.validate_block(valid_block, genesis) == true
    end

    test "returns false if previous_hash does not match", %{
      genesis: genesis,
      valid_block: valid_block
    } do
      tampered = %{valid_block | previous_hash: "wrong"}
      refute Block.validate_block(tampered, genesis)
    end

    test "returns false if the block's own hash is incorrect", %{
      genesis: genesis,
      valid_block: valid_block
    } do
      tampered = %{valid_block | hash: "deadbeef"}
      refute Block.validate_block(tampered, genesis)
    end

    test "returns true for genesis block when previous_block is nil" do
      block = %Block{
        index: 0,
        previous_hash: "0",
        timestamp: 1,
        data: "first",
        hash: nil
      }

      block = %{block | hash: Block.calculate_hash(block)}

      assert Block.validate_block(block, nil) == true
    end
  end
end
