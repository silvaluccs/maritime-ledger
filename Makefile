# Nome da rede docker para os containers se comunicarem localmente (caso rode no mesmo PC)
NETWORK_NAME=maritime_network

# --- Variáveis Padrão ---
# Configurações do Sector
SECTOR_NAME ?= sector_local
SECTOR_PORT ?= 5050
SECTOR_HOSTS ?= ""

# Configurações do Drone
DRONE_ID ?= drone_$(shell date +%s)
DRONE_PEERS ?= 127.0.0.1:5050

# Configurações do Sensor
SENSOR_HOST ?= 127.0.0.1:5050

.PHONY: help setup-network build-all build-sector build-drone build-sensor run-sector run-drone run-sensor

# Exibe o painel de ajuda por padrão se rodar apenas `make`
.DEFAULT_GOAL := help

help:
	@echo "======================================================================"
	@echo "                   MARITIME P2P - MAKEFILE HELP                       "
	@echo "======================================================================"
	@echo ""
	@echo "Comandos de Build:"
	@echo "  make build-all       - Constrói as imagens de todos os apps."
	@echo "  make build-sector    - Constrói a imagem apenas do Setor."
	@echo "  make build-drone     - Constrói a imagem apenas do Drone."
	@echo "  make build-sensor    - Constrói a imagem apenas do Sensor."
	@echo ""
	@echo "Comandos de Execução:"
	@echo "  make run-sector      - Inicia um nó do Setor."
	@echo "  make run-drone       - Inicia um nó de Drone."
	@echo "  make run-sensor      - Inicia um nó de Sensor."
	@echo ""
	@echo "Exemplos de uso e Variáveis (LAN / Local):"
	@echo ""
	@echo "  A rede de Setores é P2P (Full Mesh). O ideal é que todos saibam os IPs dos"
	@echo "  outros. O sistema possui reconexão automática, então não tem problema um"
	@echo "  Setor tentar conectar em outro que ainda não subiu."
	@echo ""
	@echo "  1. Subir o primeiro Setor (PC 1 - 192.168.1.50) apontando para o PC 2:"
	@echo "     make run-sector SECTOR_NAME=setor1 SECTOR_PORT=5050 SECTOR_HOSTS=192.168.1.51:5050"
	@echo ""
	@echo "  2. Subir o segundo Setor (PC 2 - 192.168.1.51) apontando para o PC 1:"
	@echo "     make run-sector SECTOR_NAME=setor2 SECTOR_PORT=5050 SECTOR_HOSTS=192.168.1.50:5050"
	@echo ""
	@echo "  3. Subir um Drone apontando para um dos Setores:"
	@echo "     make run-drone DRONE_PEERS=192.168.1.50:5050"
	@echo ""
	@echo "  4. Subir um Sensor apontando para um dos Setores:"
	@echo "     make run-sensor SENSOR_HOST=192.168.1.50:5050"
	@echo "======================================================================"

# Cria a rede docker caso ela não exista
setup-network:
	@docker network inspect $(NETWORK_NAME) >/dev/null 2>&1 || docker network create $(NETWORK_NAME)

# --- COMANDOS DE BUILD ---

build-sector:
	docker build -f apps/sector/Dockerfile -t maritime_sector .

build-drone:
	docker build -f apps/drone/Dockerfile -t maritime_drone .

build-sensor:
	docker build -f apps/sensors/Dockerfile -t maritime_sensor .

build-all: build-sector build-drone build-sensor

# --- COMANDOS DE EXECUÇÃO ---

# O Setor possui um nome fixo dinâmico (--name) e
# mapeia a porta TCP para a máquina hospedeira, permitindo descoberta na LAN.
run-sector: setup-network build-sector
	docker run -it --rm \
		--name $(SECTOR_NAME) \
		--network $(NETWORK_NAME) \
		-p $(SECTOR_PORT):$(SECTOR_PORT)/tcp \
		-e NODE_NAME=$(SECTOR_NAME) \
		-e TCP_PORT=$(SECTOR_PORT) \
		-e HOSTS=$(SECTOR_HOSTS) \
		maritime_sector

# Drones NÃO possuem nome fixo (--name).
run-drone: setup-network build-drone
	docker run -it --rm \
		--network $(NETWORK_NAME) \
		-e DRONE_ID=$(DRONE_ID) \
		-e TCP_PEERS=$(DRONE_PEERS) \
		maritime_drone

# Sensores NÃO possuem nome fixo (--name).
run-sensor: setup-network build-sensor
	docker run -it --rm \
		--network $(NETWORK_NAME) \
		-e HOST=$(SENSOR_HOST) \
		maritime_sensor
