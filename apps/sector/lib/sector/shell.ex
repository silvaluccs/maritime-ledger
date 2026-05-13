defmodule Sector.Shell do
  @moduledoc """
  Interface simples para interagir com o nó no terminal do IEx.
  """

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

  def help do
    IO.puts("""

    === COMANDOS DO SHELL DO SETOR ===
    request       - Cria uma requisição (prioridade aleatória).
    request <prio>- Cria uma requisição com prioridade específica (ex: request 1).
    queue         - Visualiza a fila de requisições.
    help          - Mostra essa mensagem de ajuda.
    exit          - Encerra o nó.
    ==================================
    """)
  end

  def start do
    # Aguarda 1 segundo para não misturar com os logs de inicialização
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
    data = IO.gets("sector-shell> ")

    if data != :eof do
      process_command(String.trim(data))
      loop()
    end
  end

  defp process_command(cmd) do
    cond do
      cmd == "request" ->
        request(nil)

      String.starts_with?(cmd, "request ") ->
        handle_request_with_prio(cmd)

      cmd == "queue" ->
        queue()

      cmd == "help" ->
        help()

      cmd == "exit" ->
        System.halt(0)

      cmd == "" ->
        :ok

      String.starts_with?(cmd, "\e") ->
        :ok

      true ->
        IO.puts("Comando inválido. Digite 'help'.")
    end
  end

  defp handle_request_with_prio(cmd) do
    [_, prio_str] = String.split(cmd, " ", parts: 2)

    case Integer.parse(prio_str) do
      {prio, ""} when prio in [0, 1, 2] -> request(prio)
      _ -> IO.puts("Prioridade inválida. Use 0, 1 ou 2.")
    end
  end
end
