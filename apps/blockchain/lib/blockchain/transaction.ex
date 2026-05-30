defmodule Blockchain.Transaction do
  @moduledoc """
  A struct representing a transaction in the blockchain.
  """

  @derive JSON.Encoder
  defstruct [
    :id,
    :company_id,
    :amount,
    :type,
    :mission_reason,
    :timestamp,
    :signature
  ]
end
