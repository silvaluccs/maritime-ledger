defmodule Sector.Shell do
  @moduledoc """
  Interface simples para interagir com o nó no terminal do IEx.
  """

  @my_node_id "#{node()}"

  def request(priority \\ nil) do
    Sector.Node.request_mission(priority)
  end

  def queue do
    queue = Sector.Node.get_queue()

    if queue == [] do
      IO.puts("\n=== [SHELL] Fila de requisições está vazia. ===")
    else
      IO.puts("\n=== [SHELL] Fila Atual ===")

      Enum.each(queue, fn {priority, name, ts, status} ->
        IO.puts("Missão: #{name} | Prioridade: #{priority} | TS: #{ts} | Status: #{status}")
      end)
    end
  end

  def my_balance do
    base_id = System.get_env("NODE_NAME") || "#{node()}"
    owner_id = if String.contains?(base_id, ":"), do: base_id, else: "#{base_id}:5050"
    balance = Blockchain.Ledger.get_balance(owner_id)

    IO.puts("\n===  SEU SALDO ===")
    IO.puts("Nó ID: #{owner_id}")
    IO.puts("Saldo: #{balance} moedas")
    IO.puts("====================\n")
  end

  def all_balances do
    IO.puts("\n===   RANKING DE SALDOS DA REDE ===")
    balances = Blockchain.Ledger.get_all_balances()

    if balances == [] do
      IO.puts("Nenhuma transação financeira registrada ainda.")
    else
      Enum.each(balances, fn {owner_id, balance} ->
        IO.puts("  #{String.pad_trailing(owner_id, 15)} ➔ #{balance} moedas")
      end)
    end

    IO.puts("=====================================\n")
  end

  def get_last_block do
    IO.puts("\n=== [SHELL] Ultimo block ===")

    case Blockchain.Chain.get_last_block() do
      nil -> IO.puts("Nenhum bloco encontrado.")
      block -> show_block(block)
    end
  end

  def show_block(block) do
    IO.puts("--------------------------------------------------------------------------------")
    IO.puts("  BLOCO DE INDEX ##{block.index}")
    IO.puts("--------------------------------------------------------------------------------")
    IO.puts("   Hash Anterior : #{block.previous_hash}")
    IO.puts("   Hash Atual    : #{block.hash}")
    IO.puts("   Timestamp     : #{block.timestamp}")
    IO.puts("   Conteúdo do Bloco :")

    format_data(block.data)
    IO.puts("--------------------------------------------------------------------------------\n")
  end

  defp format_data([]), do: IO.puts("     [Nenhum dado registrado neste bloco]")

  defp format_data([%Blockchain.Transaction{} | _] = transactions) do
    Enum.each(transactions, fn tx ->
      IO.puts("     ╔══════════════════════════════════════════════════════════════════════════")
      IO.puts("     ║ 💰 TIPO:     #{String.upcase(Atom.to_string(tx.type))}")
      IO.puts("     ║ ID:       #{tx.id}")
      IO.puts("     ║ Dono:     #{tx.owner_id}")
      IO.puts("     ║ Quantia:  #{tx.amount} moedas")
      IO.puts("     ║ Motivo:   #{tx.mission_reason}")
      IO.puts("     ║ Assin.:   #{String.slice(tx.signature, 0..15)}... (truncado)")
      IO.puts("     ╚══════════════════════════════════════════════════════════════════════════")
    end)
  end

  defp format_data([%Blockchain.MissionLog{} | _] = logs) do
    Enum.each(logs, fn log ->
      IO.puts("     ╔══════════════════════════════════════════════════════════════════════════")
      IO.puts("     ║ 🛸 LOG DE MISSÃO")
      IO.puts("     ║ ID:       #{log.id}")
      IO.puts("     ║ Drone:    #{log.drone_id}")
      IO.puts("     ║ Setor:    #{log.sector_id}")
      IO.puts("     ║ Motivo:   #{log.reason}")
      IO.puts("     ║ Resultado:#{log.result}")
      IO.puts("     ║ Assin.:   #{String.slice(log.signature, 0..15)}... (truncado)")
      IO.puts("     ╚══════════════════════════════════════════════════════════════════════════")
    end)
  end

  defp format_data(unknown_data) do
    IO.puts("     ║ Dados brutos: #{inspect(unknown_data)}")
  end

  def get_chain do
    IO.puts("\n=== [SHELL] Blockchain Completa ===")
    blocks = Blockchain.Chain.get_all_blocks()

    if blocks == [] do
      IO.puts("A blockchain está vazia.")
    else
      Enum.each(blocks, fn block ->
        show_block(block)
      end)
    end
  end

  def help do
    IO.puts("""
    === COMANDOS DO SHELL DO SETOR ===
    request       - Cria uma requisição (prioridade aleatória).
    request <prio>- Cria uma requisição com prioridade específica (ex: request 1).
    queue         - Visualiza a fila de requisições.
    balance       - Consulta o saldo total DESTE nó.
    balances      - Lista o saldo de TODOS os nós da rede.
    last          - Mostra o ultimo bloco da chain.
    chain         - Mostra todos os blocos da chain.
    help          - Mostra essa mensagem de ajuda.
    exit          - Encerra o nó.
    ==================================
    """)
  end

  def start do
    Process.sleep(1000)

    IO.puts("""
    ============================================
                MARITIME P2P - SECTOR
    ============================================
    Pronto! O nó está rodando.
    Digite 'help' para ver os comandos.
    """)

    loop()
  end

  def loop do
    case IO.gets("sector-shell> ") do
      :eof ->
        :ok

      {:error, reason} ->
        IO.puts("Erro ao ler comando: #{inspect(reason)}")
        loop()

      data ->
        process_command(String.trim(data))
        loop()
    end
  end

  defp process_command(cmd) do
    cond do
      cmd == "request" -> request(nil)
      String.starts_with?(cmd, "request ") -> handle_request_with_prio(cmd)
      cmd == "queue" -> queue()
      cmd == "balance" -> my_balance()
      cmd == "balances" -> all_balances()
      cmd == "last" -> get_last_block()
      cmd == "chain" -> get_chain()
      cmd == "help" -> help()
      cmd == "exit" -> System.halt(0)
      cmd == "" -> :ok
      String.starts_with?(cmd, "\e") -> :ok
      true -> IO.puts("Comando inválido: '#{cmd}'. Digite 'help'.")
    end
  end

  defp handle_request_with_prio(cmd) do
    [_, prio_str] = String.split(cmd, " ", parts: 2)

    case Integer.parse(String.trim(prio_str)) do
      {prio, ""} when prio in [0, 1, 2] -> request(prio)
      _ -> IO.puts("Prioridade inválida. Use 0, 1 ou 2.")
    end
  end
end
