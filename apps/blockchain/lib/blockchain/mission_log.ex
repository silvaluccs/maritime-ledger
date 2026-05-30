defmodule Blockchain.MissionLog do
  @moduledoc """
  A struct representing a mission log registed by drone in blockchain.
  """

  @derive JSON.Encoder
  defstruct [
    :id,
    :drone_id,
    :sector_id,
    :company_id,
    :reason,
    :result,
    :timestamp,
    :signature
  ]
end
