defmodule Sector.NodeAlgoritmTest do
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

    # ← aguarda portas serem liberadas pelo SO
    Process.sleep(500)

    System.delete_env("HOSTS")
    :ok
  end

  # Aguarda o TcpServer processar {:new_client} antes de enviar dados,
  # evitando a race condition onde o auth chega antes do socket estar em pending_auth
  # (o que faz o auth ser despachado como mensagem desconhecida e o próximo pacote
  # receber "Primeira mensagem nao foi auth. Fechando conexao.").
  defp connect_and_auth(port, id) do
    {:ok, socket} =
      :gen_tcp.connect(~c"127.0.0.1", port, [:binary, packet: :line, active: false])

    Process.sleep(30)

    auth = JSON.encode!(%{"type" => "auth", "id" => id, "passkey" => @passkey}) <> "\n"
    :ok = :gen_tcp.send(socket, auth)
    socket
  end

  test "fluxo completo de exclusao mutua: envia request, recebe reply e entra na secao critica" do
    peer_port = 5070
    node_port = 5071

    {:ok, listen_socket} =
      :gen_tcp.listen(peer_port, [:binary, packet: :line, active: false, reuseaddr: true])

    System.put_env("HOSTS", "127.0.0.1:#{peer_port}")

    {:ok, _pid} = Sector.Node.start_link(tcp_port: node_port)

    # Aceita a conexão de saída do TcpClient
    {:ok, peer_server_socket} = :gen_tcp.accept(listen_socket, 2000)

    # Conecta o peer de volta ao TcpServer e autentica
    peer_client_socket = connect_and_auth(node_port, "127.0.0.1:#{peer_port}")

    # Dispara manualmente a solicitação de CS
    send(Sector.Node, :try_critical_section)

    # peer_server_socket recebe: 1) auth do TcpClient, 2) request do Node
    assert {:ok, _auth} = :gen_tcp.recv(peer_server_socket, 0, 5000)
    data = recv_until_type(peer_server_socket, "request")
    assert data != nil
    assert data["type"] == "request"
    req_clock = data["clock"]
    # Peer envia seu próprio request com clock maior (menor prioridade de Lamport)
    node_id = data["from"]

    peer_request_msg = %{
      "type" => "request",
      "from" => "127.0.0.1:#{peer_port}",
      "to" => "broadcast",
      "clock" => req_clock + 10,
      "priority" => 0
    }

    :ok = :gen_tcp.send(peer_client_socket, JSON.encode!(peer_request_msg) <> "\n")

    # Peer envia o Reply autorizando o Node A a entrar na SC
    reply_msg = %{
      "type" => "reply",
      "from" => "127.0.0.1:#{peer_port}",
      "to" => node_id,
      "clock" => req_clock + 1,
      "priority" => 0
    }

    :ok = :gen_tcp.send(peer_client_socket, JSON.encode!(reply_msg) <> "\n")

    # Node entra na SC e aguarda drone. Conecta o drone com sleep para evitar race condition.
    drone_socket = connect_and_auth(node_port, "test_drone")

    drone_status_msg = %{
      "type" => "drone_status",
      "drone_id" => "test_drone",
      "status" => "IDLE"
    }

    :ok = :gen_tcp.send(drone_socket, JSON.encode!(drone_status_msg) <> "\n")

    # Node aloca o drone e aguarda MissionAck para concluir a SC.
    # Com a lógica de ACK, o Reply adiado para o peer só sai após o MissionAck.
    Process.sleep(500)

    :ok =
      :gen_tcp.send(
        drone_socket,
        JSON.encode!(%{
          "type" => "mission_ack",
          "drone_id" => "test_drone",
          "to" => node_id
        }) <> "\n"
      )

    reply_data = receive_until_reply(peer_server_socket, node_id, 15_000)
    assert reply_data != nil
    if drone_socket, do: :gen_tcp.close(drone_socket)

    :gen_tcp.close(peer_client_socket)
    :gen_tcp.close(peer_server_socket)
    :gen_tcp.close(listen_socket)
  end

  test "reenvia request para peer que conecta tardiamente" do
    node_port = 5072
    peer_port = 5073

    System.put_env("HOSTS", "127.0.0.1:#{peer_port}")

    {:ok, _pid} = Sector.Node.start_link(tcp_port: node_port)

    # Dispara a solicitação ANTES do peer conectar
    send(Sector.Node, :try_critical_section)

    {:ok, listen_socket} =
      :gen_tcp.listen(peer_port, [:binary, packet: :line, active: false, reuseaddr: true])

    {:ok, peer_server_socket} = :gen_tcp.accept(listen_socket, 6000)

    # Recebe: 1) auth do TcpClient, 2) request re-enviado por causa da conexão tardia
    assert {:ok, _auth} = :gen_tcp.recv(peer_server_socket, 0, 5000)
    data = recv_until_type(peer_server_socket, "request")
    assert data != nil
    assert data["type"] == "request"
    _req_clock = data["clock"]
    _node_id = data["from"]
    :gen_tcp.close(peer_server_socket)
    :gen_tcp.close(listen_socket)
  end

  test "se o drone cair durante missao a requisicao eh reenfileirada com prioridade 2" do
    node_port = 5056

    {:ok, _pid} = Sector.Node.start_link(tcp_port: node_port)

    send(Sector.Node, :try_critical_section)

    Process.sleep(500)
    state = :sys.get_state(Sector.Node)
    assert state.in_critical_section? == true
    assert state.waiting_for_drone? == true

    mission_name = state.request_for_process

    # Conecta o drone com sleep para evitar race condition no auth
    drone_socket = connect_and_auth(node_port, "crashing_drone")

    drone_status_msg = %{
      "type" => "drone_status",
      "drone_id" => "crashing_drone",
      "status" => "IDLE"
    }

    :ok = :gen_tcp.send(drone_socket, JSON.encode!(drone_status_msg) <> "\n")

    Process.sleep(500)

    state_after_alloc = :sys.get_state(Sector.Node)
    assert state_after_alloc.in_critical_section? == true
    assert state_after_alloc.pending_mission_ack != nil
    assert Map.has_key?(state_after_alloc.drones_doing_mission, "crashing_drone")

    # Drone cai antes de enviar MissionAck
    :gen_tcp.close(drone_socket)

    Process.sleep(500)

    state_after_crash = :sys.get_state(Sector.Node)
    assert not Map.has_key?(state_after_crash.drones_doing_mission, "crashing_drone")

    found_in_queue =
      Enum.find(state_after_crash.request_queue, fn {priority, name, _ts, _status} ->
        name == mission_name and priority == 2
      end)

    is_processing_again =
      state_after_crash.in_critical_section? and
        state_after_crash.request_for_process == mission_name

    assert found_in_queue != nil or is_processing_again
  end

  test "quando o drone envia MissionReject a missao volta para a fila com prioridade" do
    node_port = 5057

    {:ok, _pid} = Sector.Node.start_link(tcp_port: node_port)

    send(Sector.Node, :try_critical_section)

    Process.sleep(500)
    state = :sys.get_state(Sector.Node)
    assert state.in_critical_section? == true

    mission_name = state.request_for_process

    # Conecta o drone com sleep para evitar race condition no auth
    drone_socket = connect_and_auth(node_port, "rejecting_drone")

    drone_status_msg = %{
      "type" => "drone_status",
      "drone_id" => "rejecting_drone",
      "status" => "IDLE"
    }

    :ok = :gen_tcp.send(drone_socket, JSON.encode!(drone_status_msg) <> "\n")

    Process.sleep(500)

    state_after_alloc = :sys.get_state(Sector.Node)
    assert state_after_alloc.in_critical_section? == true
    assert state_after_alloc.pending_mission_ack != nil

    mission_reject_msg = %{
      "type" => "mission_reject",
      "drone_id" => "rejecting_drone",
      "to" => state.node_id,
      "mission_name" => mission_name,
      "clock" => state.clock
    }

    :ok = :gen_tcp.send(drone_socket, JSON.encode!(mission_reject_msg) <> "\n")
    Process.sleep(500)

    state_after_reject = :sys.get_state(Sector.Node)
    assert state_after_reject.pending_mission_ack == nil

    found_in_queue =
      Enum.find(state_after_reject.request_queue, fn {priority, name, _ts, _status} ->
        name == mission_name and priority == 2
      end)

    is_processing_again = state_after_reject.request_for_process == mission_name

    assert found_in_queue != nil or is_processing_again

    :gen_tcp.close(drone_socket)
  end

  test "entra na secao critica quando unico peer desconecta e tenta alocar drone" do
    peer_port = 5054
    node_port = 5055

    {:ok, listen_socket} =
      :gen_tcp.listen(peer_port, [:binary, packet: :line, active: false, reuseaddr: true])

    System.put_env("HOSTS", "127.0.0.1:#{peer_port}")
    {:ok, _pid} = Sector.Node.start_link(tcp_port: node_port)

    {:ok, peer_server_socket} = :gen_tcp.accept(listen_socket, 2000)

    send(Sector.Node, :try_critical_section)

    # Recebe: 1) auth do TcpClient, 2) request
    assert {:ok, _auth} = :gen_tcp.recv(peer_server_socket, 0, 5000)
    data = recv_until_type(peer_server_socket, "request")
    assert data != nil
    assert data["type"] == "request"
    _req_clock = data["clock"]
    # Fecha sem enviar reply — Node deve entrar na SC ao detectar desconexão
    _node_id = data["from"]
    :gen_tcp.close(peer_server_socket)
    :gen_tcp.close(listen_socket)

    Process.sleep(1000)
    state = :sys.get_state(Sector.Node)
    assert state.in_critical_section? == true
    assert state.waiting_for_drone? == true
  end

  test "aborta propria requisicao quando recebe request de maior prioridade" do
    peer_port = 5060
    node_port = 5061

    {:ok, listen_socket} =
      :gen_tcp.listen(peer_port, [:binary, packet: :line, active: false, reuseaddr: true])

    System.put_env("HOSTS", "127.0.0.1:#{peer_port}")

    {:ok, _pid} = Sector.Node.start_link(tcp_port: node_port)

    {:ok, peer_server_socket} = :gen_tcp.accept(listen_socket, 2000)

    peer_client_socket = connect_and_auth(node_port, "127.0.0.1:#{peer_port}")

    # Força missão de PRIORIDADE 0 via cast direto
    sensor_req = %Core.Protocol.SensorRequest{
      type: :sensor_request,
      sensor_id: "s1",
      priority: 0,
      reason: "baixa prioridade"
    }

    GenServer.cast(Sector.Node, {:network_message, sensor_req})

    # Recebe: 1) auth do TcpClient, 2) request (Prio 0)
    assert {:ok, _auth} = :gen_tcp.recv(peer_server_socket, 0, 5000)

    data1 = recv_until_type(peer_server_socket, "request")

    assert data1 != nil

    assert data1["type"] == "request"

    req_clock = data1["clock"]
    # Peer envia request de PRIORIDADE 1 (maior prioridade)
    peer_request_msg = %{
      "type" => "request",
      "from" => "127.0.0.1:#{peer_port}",
      "to" => "broadcast",
      "clock" => req_clock + 5,
      "priority" => 1
    }

    :ok = :gen_tcp.send(peer_client_socket, JSON.encode!(peer_request_msg) <> "\n")

    # Node aborta e envia Reply imediatamente
    assert {:ok, data2} = :gen_tcp.recv(peer_server_socket, 0, 5000)
    assert %{"type" => "reply", "request_ts" => peer_ts} = JSON.decode!(String.trim(data2))
    assert peer_ts == req_clock + 5

    # Node reenvia seu request (mesma missão Prio 0, novo clock)
    assert {:ok, data3} = :gen_tcp.recv(peer_server_socket, 0, 5000)
    assert %{"type" => "request", "priority" => 0} = JSON.decode!(String.trim(data3))

    :gen_tcp.close(peer_client_socket)
    :gen_tcp.close(peer_server_socket)
    :gen_tcp.close(listen_socket)
  end

  defp receive_until_reply(socket, expected_from, timeout) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, data} ->
        msg = JSON.decode!(String.trim(data))

        case msg do
          %{"type" => "reply", "from" => ^expected_from} ->
            msg

          _ ->
            # mensagem ignorada (ex: block_proposal), continua esperando
            receive_until_reply(socket, expected_from, timeout)
        end

      {:error, _} ->
        nil
    end
  end

  defp recv_until_type(socket, type, timeout \\ 5000) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, data} ->
        msg = JSON.decode!(String.trim(data))

        if msg["type"] == type do
          msg
        else
          recv_until_type(socket, type, timeout)
        end

      {:error, _} ->
        nil
    end
  end
end
