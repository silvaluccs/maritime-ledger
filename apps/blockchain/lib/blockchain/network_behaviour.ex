defmodule Blockchain.NetworkBehaviour do
  @callback broadcast(term()) :: :ok | {:error, any()}
  @callback connected_hosts() :: [String.t()]
end
