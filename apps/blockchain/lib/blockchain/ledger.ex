defmodule Blockchain.Ledger do
  @moduledoc false
  alias Blockchain.{Chain, Transaction}

  def get_balance(owner_id) do
    Chain.get_all_blocks()
    |> Enum.flat_map(& &1.data)
    |> Enum.filter(&(is_struct(&1, Transaction) and &1.owner_id == owner_id))
    |> Enum.reduce(0, &apply_transaction/2)
  end

  def has_balance?(owner_id, required_amount), do: get_balance(owner_id) >= required_amount

  def get_all_balances do
    Chain.get_all_blocks()
    |> Enum.flat_map(& &1.data)
    |> Enum.filter(&is_struct(&1, Transaction))
    |> Enum.group_by(& &1.owner_id)
    |> Enum.map(fn {owner_id, txs} ->
      {owner_id, Enum.reduce(txs, 0, &apply_transaction/2)}
    end)
  end

  defp apply_transaction(%Transaction{type: :mint, amount: amount}, acc), do: acc + amount
  defp apply_transaction(%Transaction{type: :debit, amount: amount}, acc), do: acc - amount
end
