defmodule Sector.ChainSyncTest do
  use ExUnit.Case, async: false

  @passkey "08416EB34E46FD01C0E03B5E9B4AEACC06306F16D3E380559BBBAD8323C82A13"

  setup do
    case Process.whereis(Blockchain.Chain) do
      nil ->
        :ok

      pid ->
        try do
          GenServer.stop(pid)
        catch
          :exit, _ -> :ok
        end
    end

    File.rm("/tmp/maritime_chain_test.json")

    case Blockchain.Chain.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Enum.each([Sector.Node, Sector.TcpServer, Sector.TcpClient], fn mod ->
      case Process.whereis(mod) do
        nil ->
          :ok

        pid ->
          try do
            GenServer.stop(pid)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    Process.sleep(100)
    System.delete_env("HOSTS")
    :ok
  end

  defp connect_and_auth(port, id) do
    {:ok, socket} =
      :gen_tcp.connect(~c"127.0.0.1", port, [:binary, packet: :line, active: false])

    Process.sleep(30)
    auth = JSON.encode!(%{"type" => "auth", "id" => id, "passkey" => @passkey}) <> "\n"
    :ok = :gen_tcp.send(socket, auth)
    socket
  end

  defp add_block_to_chain(owner_id, amount, type) do
    last = Blockchain.Chain.get_last_block()

    tx = %Blockchain.Transaction{
      id: UUIDv7.generate(),
      owner_id: owner_id,
      amount: amount,
      type: type,
      mission_reason: "teste sync",
      timestamp: System.os_time(:second),
      signature: "sig_teste"
    }

    block = %Blockchain.Block{
      index: last.index + 1,
      previous_hash: last.hash,
      timestamp: System.os_time(:second),
      data: [tx]
    }

    block = %{block | hash: Blockchain.Block.calculate_hash(block)}
    Blockchain.Chain.add_block(block)
    block
  end

  defp recv_until_type(socket, type, timeout \\ 5000) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, data} ->
        msg = JSON.decode!(String.trim(data))
        if msg["type"] == type, do: msg, else: recv_until_type(socket, type, timeout)

      {:error, _} ->
        nil
    end
  end

  # -------------------------------------------------------
  # CENÁRIO 1: peer solicita sync e recebe chain mais longa
  # -------------------------------------------------------

  test "peer com chain desatualizada recebe blocos ao solicitar sync" do
    node_port = 7070

    # Adiciona 2 blocos extras na chain local antes de iniciar o setor
    add_block_to_chain("sector_1", 10, :debit)
    add_block_to_chain("sector_1", 5, :mint)

    assert length(Blockchain.Chain.get_all_blocks()) == 3

    {:ok, _pid} = Sector.Node.start_link(tcp_port: node_port)

    # Peer conecta simulando chain desatualizada (last_index: 0)
    peer_socket = connect_and_auth(node_port, "127.0.0.1:7071")

    sync_request = %{
      "type" => "chain_sync_request",
      "from" => "127.0.0.1:7071",
      "last_index" => 0
    }

    :ok = :gen_tcp.send(peer_socket, JSON.encode!(sync_request) <> "\n")

    # Deve receber chain_sync_response com 3 blocos
    response = recv_until_type(peer_socket, "chain_sync_response")

    assert response != nil
    assert response["type"] == "chain_sync_response"
    assert length(response["chain"]) == 3

    :gen_tcp.close(peer_socket)
  end

  # -------------------------------------------------------
  # CENÁRIO 2: peer atualizado não recebe resposta desnecessária
  # -------------------------------------------------------

  test "peer com chain igual não recebe sync_response" do
    node_port = 7072

    assert length(Blockchain.Chain.get_all_blocks()) == 1

    {:ok, _pid} = Sector.Node.start_link(tcp_port: node_port)

    peer_socket = connect_and_auth(node_port, "127.0.0.1:7073")

    # Peer já está atualizado (last_index igual ao local)
    sync_request = %{
      "type" => "chain_sync_request",
      "from" => "127.0.0.1:7073",
      "last_index" => 0
    }

    :ok = :gen_tcp.send(peer_socket, JSON.encode!(sync_request) <> "\n")

    # Não deve receber chain_sync_response (timeout esperado)
    result = :gen_tcp.recv(peer_socket, 0, 1000)
    assert result == {:error, :timeout}

    :gen_tcp.close(peer_socket)
  end

  # -------------------------------------------------------
  # CENÁRIO 3: maybe_replace_chain aceita chain maior e válida
  # -------------------------------------------------------

  test "maybe_replace_chain substitui chain local quando recebe chain maior e válida" do
    # Chain local tem só o gênese (1 bloco)
    assert length(Blockchain.Chain.get_all_blocks()) == 1

    # Constrói chain maior válida externamente
    genesis = hd(Blockchain.Chain.get_all_blocks())

    bloco1 = %Blockchain.Block{
      index: 1,
      previous_hash: genesis.hash,
      timestamp: System.os_time(:second),
      data: [
        %Blockchain.Transaction{
          id: UUIDv7.generate(),
          owner_id: "sector_1",
          amount: 10,
          type: :debit,
          mission_reason: "missão externa",
          timestamp: System.os_time(:second),
          signature: "sig"
        }
      ]
    }

    bloco1 = %{bloco1 | hash: Blockchain.Block.calculate_hash(bloco1)}

    bloco2 = %Blockchain.Block{
      index: 2,
      previous_hash: bloco1.hash,
      timestamp: System.os_time(:second),
      data: []
    }

    bloco2 = %{bloco2 | hash: Blockchain.Block.calculate_hash(bloco2)}

    chain_externa = [genesis, bloco1, bloco2]
    chain_as_maps = JSON.decode!(JSON.encode!(chain_externa))

    result = Blockchain.Chain.maybe_replace_chain(chain_as_maps)

    assert result == :replaced
    assert length(Blockchain.Chain.get_all_blocks()) == 3
    assert Blockchain.Chain.valid_chain?() == true
  end

  # -------------------------------------------------------
  # CENÁRIO 4: maybe_replace_chain rejeita chain inválida
  # -------------------------------------------------------

  test "maybe_replace_chain rejeita chain com hash adulterado" do
    genesis = hd(Blockchain.Chain.get_all_blocks())

    bloco_adulterado = %Blockchain.Block{
      index: 1,
      previous_hash: genesis.hash,
      timestamp: System.os_time(:second),
      data: [],
      hash: "hash_falso_adulterado_0000000000000000000000000000000000000000000"
    }

    chain_adulterada = [genesis, bloco_adulterado]
    chain_as_maps = JSON.decode!(JSON.encode!(chain_adulterada))

    result = Blockchain.Chain.maybe_replace_chain(chain_as_maps)

    assert result == :rejected
    assert length(Blockchain.Chain.get_all_blocks()) == 1
  end

  # -------------------------------------------------------
  # CENÁRIO 5: maybe_replace_chain ignora chain menor
  # -------------------------------------------------------

  test "maybe_replace_chain ignora chain menor que a local" do
    add_block_to_chain("sector_1", 10, :debit)
    add_block_to_chain("sector_1", 10, :debit)

    assert length(Blockchain.Chain.get_all_blocks()) == 3

    # Envia só o gênese (chain menor)
    genesis = hd(Blockchain.Chain.get_all_blocks())
    chain_as_maps = JSON.decode!(JSON.encode!([genesis]))

    result = Blockchain.Chain.maybe_replace_chain(chain_as_maps)

    assert result == :ignored
    assert length(Blockchain.Chain.get_all_blocks()) == 3
  end

  # -------------------------------------------------------
  # CENÁRIO 6: chain vazia é rejeitada
  # -------------------------------------------------------

  test "maybe_replace_chain rejeita chain vazia" do
    result = Blockchain.Chain.maybe_replace_chain([])
    assert result == :rejected
    assert length(Blockchain.Chain.get_all_blocks()) == 1
  end
end
