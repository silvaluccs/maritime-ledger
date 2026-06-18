# 🌊 Maritime Ledger — Sistema Distribuído de Monitoramento Marítimo


![Elixir](https://img.shields.io/badge/Elixir-1.19%2B-4B275F?logo=elixir&logoColor=white)
![Docker Compose](https://img.shields.io/badge/Docker%20Compose-enabled-2496ED?logo=docker&logoColor=white)
![P2P](https://img.shields.io/badge/Architecture-P2P-0A0A0A)
![Blockchain](https://img.shields.io/badge/Blockchain-integrada-F7931A)
![Status](https://img.shields.io/badge/Status-Ativo-success)

![Visão geral do sistema](images/geral.png)


> **Um sistema P2P que coordena sensores, setores e drones para responder a incidentes no mar sem um servidor central — com blockchain integrada para auditoria de missões e controle de créditos.**


---


## 📚 Sumário

1. [Resumo em uma frase](#-resumo-em-uma-frase)
2. [A ideia do Maritime P2P](#-a-ideia-do-maritime-p2p)
3. [Visão geral da arquitetura](#-visão-geral-da-arquitetura)
4. [Como o sistema foi construído](#-como-o-sistema-foi-construído)
5. [Componentes do sistema](#-componentes-do-sistema)
6. [Fluxo de funcionamento (passo a passo)](#-fluxo-de-funcionamento-passo-a-passo)
7. [Algoritmo distribuído: Ricart–Agrawala](#-algoritmo-distribuído-ricartagrawala)
8. [Prioridades, preempção e fila global](#-prioridades-preempção-e-fila-global)
9. [Blockchain integrada](#-blockchain-integrada)
10. [Sincronização da chain entre peers](#-sincronização-da-chain-entre-peers)
11. [Tolerância a falhas e reconexão](#-tolerância-a-falhas-e-reconexão)
12. [Segurança e autenticação](#-segurança-e-autenticação)
13. [Protocolo de mensagens (JSON)](#-protocolo-de-mensagens-json)
14. [Executando com Docker Compose](#-executando-com-docker-compose)
15. [Executando com Makefile](#-executando-com-makefile)
16. [Variáveis de ambiente](#-variáveis-de-ambiente)
17. [Estrutura do repositório](#-estrutura-do-repositório)
18. [Comandos do Shell do Setor](#-comandos-do-shell-do-setor)
19. [Testes](#-testes)
20. [Limitações e melhorias recomendadas](#-limitações-e-melhorias-recomendadas)

---

## ✅ Resumo em uma frase

**O Maritime P2P coordena, de forma descentralizada, o envio de drones para missões marítimas usando prioridades, algoritmos distribuídos, autenticação segura via TCP e blockchain para auditoria imutável e controle de créditos por missão.**

---

## A ideia do Maritime P2P

Imagine várias **bases costeiras (Setores)**, cada uma com **drones de resgate**. Vários **sensores** espalhados pelo oceano enviam alertas o tempo todo. Se todas as bases decidirem enviar drones ao mesmo tempo para o mesmo incidente, ocorre confusão. Se nenhuma enviar, o problema piora.

O **Maritime P2P** resolve isso de forma inteligente: as bases conversam entre si e decidem **quem pode agir primeiro**, sem precisar de um "chefe central". Emergências reais têm prioridade maior e podem interromper tarefas menos importantes.

Além disso, cada missão **custa créditos** ao setor que a executou, e todo o histórico fica registrado em uma **blockchain distribuída** — imutável, auditável e sincronizada entre todos os nós da rede.

---

## 🏗️ Visão geral da arquitetura

O projeto é um **sistema distribuído** com **comunicação via TCP**, seguindo o modelo **P2P**. Ele foi construído em **Elixir**, com cinco aplicações principais:

- **`sector`** → o cérebro distribuído (coordena a decisão coletiva)
- **`drone`** → executa as missões físicas
- **`sensors`** → gera alertas e requisições
- **`core`** → protocolos, tipos de mensagens e autenticação
- **`blockchain`** → ledger distribuído de créditos e logs de missão _(novo)_

---

## 🛠️ Como o sistema foi construído

**Tecnologias principais:**
- **Elixir**: concorrência leve e tolerância a falhas.
- **TCP Sockets** com mensagens **JSON line-delimited** (uma mensagem por linha).
- **Arquitetura distribuída** sem servidor central.
- **Algoritmo de Ricart–Agrawala** para exclusão mútua.
- **Prioridades e preempção** para emergências.
- **Autenticação** com SHA‑256 (passkey).
- **Blockchain própria** com persistência em disco (`chain.json`), sincronização entre peers e consenso por propagação.

O sistema é totalmente orientado a eventos: cada mensagem recebida por TCP é transformada em uma struct, processada em um **GenServer** e encaminhada para o fluxo certo.

---

## 🧩 Componentes do sistema

### 1. 🏢 Setores (`apps/sector`)
São os **nós distribuídos**. Cada setor decide quando pode entrar na **Seção Crítica** (o direito de enviar drones) e verifica se possui **créditos suficientes** antes de qualquer requisição.

Principais módulos:
- `Sector.Node`: coração do algoritmo distribuído, agora integrado com o ledger de créditos e a sincronização da chain.
- `Sector.TcpServer`: recebe mensagens TCP, incluindo `block_proposal`, `chain_sync_request` e `chain_sync_response`.
- `Sector.TcpClient`: conecta em outros setores e inicia sincronização da chain ao reconectar.
- `Sector.Shell`: interface interativa local, com novos comandos de blockchain.
- `Sector.NodeId`: identifica o nó para mensagens internas.

### 2. 🚁 Drones (`apps/drone`)
Representam executores das missões.

Principais módulos:
- `Drone.TcpClient`: conecta a setores e recebe missões.
- `Drone.Worker`: gerencia o estado (`IDLE`/`BUSY`) e executa missões.

### 3. 📡 Sensores (`apps/sensors`)
Geram eventos de maneira aleatória e realista.

Principais módulos:
- `Sensors.Worker`: conecta a um setor e envia requisições periódicas.
- `Sensors.Reasons`: catálogo de motivos realistas (incêndios, vazamentos, SOS...).

### 4. 🧠 Core (`apps/core`)
Biblioteca compartilhada com definições do protocolo.

Principais módulos:
- `Core.Protocol`: structs das mensagens, incluindo os novos tipos de blockchain.
- `Core.Auth`: hash de passkey (SHA‑256).
- `Core.Env`: parse de variáveis de ambiente de hosts.

### 5. ⛓️ Blockchain (`apps/blockchain`) — _novo_
Ledger distribuído que registra créditos dos setores e logs de missão de forma imutável.

Principais módulos:
- `Blockchain.Block`: struct de bloco com hash SHA‑256, validação de integridade e referência ao bloco anterior.
- `Blockchain.Chain`: GenServer que gerencia a cadeia, persiste em `chain.json` e implementa a lógica de substituição por cadeia mais longa ou detecção de corrupção local.
- `Blockchain.Ledger`: consulta saldos acumulados a partir das transações da cadeia.
- `Blockchain.Miner`: cria blocos com débitos (missões), laudos de conclusão e operações de mint.
- `Blockchain.Consensus`: propõe e valida blocos novos, propagando-os para todos os peers conectados.
- `Blockchain.Transaction`: struct de transação financeira (mint/debit).
- `Blockchain.MissionLog`: struct de registro de missão (drone, setor, motivo e resultado).

---

## 🔄 Fluxo de funcionamento (passo a passo)

1. **Sensores conectam** a um setor e se autenticam.
2. Periodicamente, sensores enviam **SensorRequest** com prioridade e motivo.
3. O setor verifica se possui **saldo ≥ 10 créditos** antes de enfileirar a missão. Se não tiver, a requisição é recusada.
4. Cada setor mantém uma **fila local** e tenta entrar na Seção Crítica usando Ricart–Agrawala.
5. Quando autorizado, o setor **debita 10 créditos** na blockchain e envia uma **Mission** ao drone.
6. O drone responde com:
   - **MissionAck** se estava `IDLE` (aceitou), ou
   - **MissionReject** se estava `BUSY` (rejeitou).
7. Ao final da missão (drone retorna a `IDLE`), o setor registra um **MissionLog** na blockchain com o resultado.
8. Se o drone cair ou rejeitar, o setor **re-enfileira a missão** com prioridade 2.

---

## 🤝 Algoritmo distribuído: Ricart–Agrawala

Este é o coração do sistema de coordenação. Ele garante que **apenas um setor por vez** entre na Seção Crítica.

### Como funciona no projeto
- Cada setor envia `Request` com **clock lógico** e **prioridade**.
- Todos os setores comparam timestamps (Lamport) e desempate por ID.
- O setor só entra na Seção Crítica após receber `Reply` de todos.
- Se um setor está em CS, ele **adia** replies e envia depois.

### Implementação real (resumo do código)
- `request_ts` guarda o timestamp da tentativa.
- `awaiting_replies` guarda quem ainda não respondeu.
- `deferred_replies` guarda replies adiados.
- `Reply` carrega `request_ts` para evitar respostas antigas.

---

## ⚡ Prioridades, preempção e fila global

O sistema tem **prioridades reais**, mas **sem quebrar o algoritmo**. A regra é:

✅ **O algoritmo de exclusão mútua usa apenas timestamps e IDs** (Ricart–Agrawala puro).

✅ **A prioridade atua na fila local e na preempção**:
- Prioridade 1 (urgente) pode **interromper** prioridades menores.
- Prioridade 2 é usada para **missões re-enfileiradas** após falhas.
- Missões são ordenadas por **maior prioridade** e, em empate, por **menor timestamp**.

### Preempção (abort)
Se um setor está solicitando ou aguardando drone e recebe uma request **mais urgente**, ele:
1. **Aborta sua própria solicitação**.
2. Envia `Reply` para o setor urgente.
3. Re-enfileira sua missão original com o timestamp correto.

### Regra anti-fome
Há uma heurística que dá chance ao final da fila quando a diferença de clocks cresce demais, evitando starvation em cenários extremos.

---

## ⛓️ Blockchain integrada

A blockchain do Maritime P2P é **própria**, construída em Elixir, e opera como parte do ecossistema distribuído dos setores.

### Estrutura de um bloco
Cada bloco contém `index`, `previous_hash`, `timestamp`, `hash` e um campo `data` que pode carregar transações financeiras (`Transaction`) ou laudos de missão (`MissionLog`).

O hash é calculado via SHA‑256 sobre os campos do bloco e serve como garantia de integridade. Um bloco é considerado válido apenas se seu hash bate com o calculado e se o `previous_hash` aponta para o hash do bloco anterior.

### Bloco gênese e créditos iniciais
Ao subir, cada setor carrega (ou cria) a chain a partir do arquivo `chain.json`. Se o arquivo não existir ou estiver vazio, o **bloco gênese** é gerado automaticamente com transações de `mint` que distribuem **100 créditos** para cada setor listado na configuração via `BLOCKCHAIN_SECTORS`.

### Controle de créditos por missão
Antes de enfileirar qualquer requisição, o setor consulta o `Blockchain.Ledger` e verifica se possui **saldo ≥ 10 créditos**. Se não tiver, a missão é recusada imediatamente:

```
=== [SHELL] ❌ Sem créditos para requisitar drone! Saldo insuficiente. ===
```

Ao alocar o drone, o `Blockchain.Miner` propõe um bloco com um `debit` de 10 créditos ao setor. Quando o drone retorna a `IDLE` após a missão, um `MissionLog` com resultado `completed` é registrado em um novo bloco.

### Persistência em disco
A chain é salva em `chain.json` a cada novo bloco adicionado. No Makefile, esse arquivo é montado como volume no container do setor para sobreviver a reinicializações.

---

## 🔁 Sincronização da chain entre peers

Como cada nó mantém sua própria cópia da chain, o sistema precisa garantir que todos os peers estejam com a cadeia mais atual.

### Sincronização ao reconectar
Quando um setor (re)conecta a um peer via `Sector.TcpClient`, envia automaticamente um `ChainSyncRequest` com o índice do seu último bloco local. O peer responde com `ChainSyncResponse` contendo a chain completa **apenas se tiver blocos a mais**. O receptor então aplica a regra de substituição.

### Sincronização forçada no boot
Além da reconexão, 2 segundos após subir, cada setor transmite um `ChainSyncRequest` para todos os peers já conectados — garantindo que um nó que reiniciou fique atualizado sem depender do fluxo de reconexão.

### Regra de substituição (`maybe_replace_chain`)
Ao receber uma chain externa, o `Blockchain.Chain` aplica a seguinte lógica em ordem:

1. Se a chain recebida for **inválida** (qualquer bloco com hash corrompido), ela é ignorada.
2. Se a chain **local estiver corrompida** (edição manual ou falha de disco), ela é **substituída pela chain íntegra da rede**, com alerta no shell.
3. Se a chain recebida **não for maior** que a local, ela é ignorada.
4. Caso contrário, a chain local é **substituída pela mais longa**.

### Propagação de novos blocos
Quando um setor minera um novo bloco, o `Blockchain.Consensus` o propaga para todos os peers como `BlockProposal`. Cada peer valida o bloco recebido contra seu último bloco local antes de adicioná-lo.

### Protocolo de sincronização (fluxo resumido)

```
Setor A (re)conecta → envia ChainSyncRequest {last_index: 3}
Setor B (tem 5 blocos) → responde com ChainSyncResponse {chain: [...5 blocos]}
Setor A → aplica maybe_replace_chain → atualiza para 5 blocos

Setor A minera bloco 6 → envia BlockProposal para todos
Setor B → valida bloco 6 → adiciona à chain local
```

---

## 🛡️ Tolerância a falhas e reconexão

O sistema é projetado para falhar com elegância:

- **Setores tentam reconectar** automaticamente a peers (`Sector.TcpClient`), e ao reconectar enviam `ChainSyncRequest` para atualizar a chain.
- Se um peer cai, o setor remove-o de `awaiting_replies`.
- Se um **drone desconecta em missão**, a missão volta para a fila com prioridade 2.
- Drones também tentam reconectar a setores automaticamente.
- A chain local é verificada a cada sincronização — se corrompida, é restaurada automaticamente pela chain íntegra da rede.

---

## 🔐 Segurança e autenticação

Toda conexão TCP exige **autenticação**:

- A primeira mensagem enviada deve ser `Auth`.
- A passkey é **hashed (SHA‑256)** via `Core.Auth`.
- O servidor aceita ou derruba a conexão em até **3 segundos**.

> ⚠️ **Importante:** se `PASSKEY` estiver vazia, o hash será do valor vazio. Em Docker, isso pode acontecer se você não definir a variável. Recomenda-se **sempre setar `PASSKEY` explicitamente**.

---

## 📡 Protocolo de mensagens (JSON)

Todas as mensagens são JSON **line-delimited** (uma mensagem por linha).

### Tipos principais

- **Auth** — `type`, `id`, `passkey`
- **Request** (Ricart–Agrawala) — `type`, `from`, `to`, `clock`, `priority`
- **Reply** — `type`, `from`, `to`, `clock`, `priority`, `request_ts`
- **DroneStatus** — `type`, `drone_id`, `status`
- **Mission** — `type`, `drone_id`, `from`, `mission_name`, `clock`
- **MissionAck** — `type`, `drone_id`, `to`
- **MissionReject** — `type`, `drone_id`, `to`, `mission_name`, `clock`
- **SensorStatus** — `type`, `sensor_id`, `status`
- **SensorRequest** — `type`, `sensor_id`, `priority`, `reason`

### Tipos de blockchain _(novos)_

- **BlockProposal** — `type`, `from`, `block` → propaga um novo bloco minerado para todos os peers
- **ChainSyncRequest** — `type`, `from`, `last_index` → solicita a chain completa ao peer (enviado ao reconectar e no boot)
- **ChainSyncResponse** — `type`, `from`, `chain` → responde com a lista completa de blocos em formato JSON

---

## 🐳 Executando com Docker Compose

O projeto vem pronto para rodar com Docker Compose. Ele sobe:
- 3 setores (`sector1`, `sector2`, `sector3`)
- 2 drones (`drone1`, `drone2`)
- Sensores estão comentados, mas você pode ativar facilmente

### 1. Defina a passkey

```bash
export PASSKEY="minha_chave_segura"
```

### 2. Suba tudo

```bash
docker compose up --build
```

### 3. Acessar shell de um setor (opcional)

Os setores rodam com `stdin_open` e `tty`, então você pode anexar e usar o Shell:

```bash
docker compose attach sector1
```

### 4. Ativar sensores no Compose

No arquivo `docker-compose.yml`, os serviços `sensor1`, `sensor2`, `sensor3` estão comentados. Basta descomentá-los para ativar.

---

## 🧰 Executando com Makefile

O Makefile foi atualizado para suportar as variáveis da blockchain e o mapeamento de hosts entre containers em rede `host`.

### Ver comandos disponíveis

```bash
make help
```

### Variáveis do Makefile

| Variável | Descrição | Padrão |
|---|---|---|
| `SECTOR_NAME` | Nome simbólico do setor | `sector_local` |
| `SECTOR_PORT` | Porta TCP do setor | `5050` |
| `SECTOR_HOSTS` | Peers do setor no formato `host:porta` | _(vazio)_ |
| `ADD_HOST` | Mapeamento de hostname → IP para `--add-host` (ex: `sector1:172.16.x.x`) | _(vazio)_ |
| `BLOCKCHAIN_SECTORS` | Lista de todos os setores da rede para o bloco gênese, no formato `setor1:porta,setor2:porta` | _(vazio)_ |
| `DRONE_ID` | Identificador do drone | timestamp automático |
| `DRONE_PEERS` | Setores que o drone conecta | `127.0.0.1:5050` |
| `SENSOR_HOST` | Setor que o sensor conecta | `127.0.0.1:5050` |
| `PASSKEY` | Chave de autenticação compartilhada | `maritime_luqueta_2026` |

> **Importante:** `ADD_HOST` é necessário quando containers em `--network host` precisam resolver nomes de outros containers pelo hostname. Use o IP real da máquina onde o outro setor está rodando.

### Exemplo: subir dois setores na LAN

```bash
# Na máquina 192.168.1.50
make run-sector \
     SECTOR_NAME=sector1 \
     SECTOR_PORT=5050 \
     BLOCKCHAIN_SECTORS=sector1:5050,sector2:5050 \
     PASSKEY="maritime_luqueta_2026"

# Na máquina 192.168.1.51
make run-sector \
     SECTOR_NAME=sector2 \
     SECTOR_PORT=5050 \
     ADD_HOST=sector1:192.168.1.50 \
     SECTOR_HOSTS=sector1:5050 \
     BLOCKCHAIN_SECTORS=sector1:5050,sector2:5050 \
     PASSKEY="maritime_luqueta_2026"
```

> O volume `-v chain.json:/app/chain.json` é montado automaticamente pelo `run-sector`, garantindo que a blockchain persista entre reinicializações do container.

### Subir um drone

```bash
make run-drone PASSKEY="maritime_luqueta_2026" DRONE_PEERS=192.168.1.50:5050
```

### Subir um sensor

```bash
make run-sensor PASSKEY="maritime_luqueta_2026" SENSOR_HOST=192.168.1.50:5050
```

### Comandos de build

```bash
make build-all     # Constrói sector, drone e sensor
make build-sector
make build-drone
make build-sensor
```

---

## ⚙️ Variáveis de ambiente

### Setores
- `NODE_NAME`: nome simbólico do nó (usado no ID do setor e como `owner_id` no ledger)
- `TCP_PORT`: porta TCP do setor (default `5050`)
- `HOSTS`: lista de peers no formato `ip:porta,ip:porta`
- `BLOCKCHAIN_SECTORS`: lista de setores para configurar o bloco gênese, no formato `sector1:5050,sector2:5050`
- `PASSKEY`: chave para autenticação

### Drones
- `DRONE_ID`: identificador do drone
- `TCP_PEERS`: lista de setores `ip:porta`
- `PASSKEY`: chave para autenticação

### Sensores
- `HOST`: endereço do setor principal `ip:porta`
- `PASSKEY`: chave para autenticação

---

## 🧬 Estrutura do repositório

```
maritime-p2p/
├── apps/
│   ├── core/        # Protocolos, Auth e Env
│   ├── sector/      # Setores (nós distribuídos)
│   ├── drone/       # Drones
│   ├── sensors/     # Sensores
│   └── blockchain/  # Ledger distribuído (novo)
│       ├── lib/blockchain/
│       │   ├── block.ex         # Struct de bloco + cálculo de hash
│       │   ├── chain.ex         # GenServer da cadeia + persistência
│       │   ├── consensus.ex     # Proposta e validação de blocos
│       │   ├── ledger.ex        # Consulta de saldos
│       │   ├── miner.ex         # Criação de blocos (debit, mint, log)
│       │   ├── transaction.ex   # Struct de transação financeira
│       │   └── mission_log.ex   # Struct de log de missão
│       └── test/
├── chain.json           # Persistência da blockchain (gerado em runtime)
├── docker-compose.yml
├── Makefile
└── README.md
```

---

## 🧑‍💻 Comandos do Shell do Setor

Ao iniciar um setor com o shell (como no Docker Compose), você pode usar:

**Controle de missões:**
- `request` → gera missão com prioridade aleatória
- `request <0|1|2>` → gera missão com prioridade específica
- `queue` → mostra a fila atual

**Blockchain:** _(novos)_
- `balance` → exibe o saldo de créditos deste setor
- `balances` → lista o saldo de todos os setores da rede
- `last` → exibe o último bloco da chain
- `chain` → exibe todos os blocos da blockchain

**Geral:**
- `help` → mostra ajuda
- `exit` → encerra o setor

---

## ✅ Testes

Para rodar todos os testes automatizados:

```bash
mix test
```

Os testes cobrem:
- Fluxo completo de exclusão mútua
- Preempção por prioridade
- Re-enfileiramento com timestamp correto
- Drones desconectando no meio da missão
- Autenticação via TCP
- Blockchain: adição e validação de blocos, integridade da cadeia
- Blockchain: consulta de saldos pelo ledger
- Blockchain: mineração de transações (debit, mint, log)
- Sincronização da chain entre peers (`chain_sync_request` / `chain_sync_response`)

---

## 🔮 Limitações e melhorias recomendadas

- **Autenticação simples** (passkey hash). Recomenda-se evoluir para TLS/mTLS ou HMAC com desafio-resposta.
- **Blockchain sem Proof of Work**: o consenso é por propagação direta entre peers confiáveis, adequado para uma rede P2P fechada, mas sem proteção contra nós maliciosos.
- **Sem descoberta automática**: peers devem ser conhecidos por `HOSTS` e `BLOCKCHAIN_SECTORS`.
- **Persistência somente da chain**: filas de missão e estado do algoritmo distribuído são totalmente em memória e perdidos ao reiniciar.
- **Regeneração de créditos manual**: há suporte a `propose_mint` no `Blockchain.Miner`, mas não existe gatilho automático — um mecanismo de reabastecimento periódico seria recomendado para redes de longa duração.

---

## ✅ Conclusão

O **Maritime P2P** é um projeto completo de sistemas distribuídos: ele mostra na prática como coordenar nós independentes, lidar com falhas e prioridades, manter a segurança mínima em um ambiente totalmente descentralizado e agora também como integrar uma **blockchain própria** para auditoria imutável de missões e controle de créditos entre os nós da rede.
