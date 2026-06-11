# --- Variáveis Padrão ---
SECTOR_NAME ?= sector_local
SECTOR_PORT ?= 5050
SECTOR_HOSTS ?= ""

# IPs/Nomes dos nós vizinhos para o --add-host (Ex: sector1:172.16.201.10)
ADD_HOST ?= ""

# Lista completa de mapeamento de todos os setores na blockchain
BLOCKCHAIN_SECTORS ?= ""

DRONE_ID ?= drone_$(shell date +%s)
DRONE_PEERS ?= 127.0.0.1:5050

SENSOR_HOST ?= 127.0.0.1:5050

# Passkey de autenticação entre os nós (obrigatória)
PASSKEY ?= "maritime_luqueta_2026"

.PHONY: help build-all build-sector build-drone build-sensor run-sector run-drone run-sensor

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
	@echo "Comandos de Execução (Usando --network host e volumes):"
	@echo "  make run-sector      - Inicia um nó do Setor."
	@echo "  make run-drone       - Inicia um nó de Drone."
	@echo "  make run-sensor      - Inicia um nó de Sensor."
	@echo ""
	@echo "Exemplo de execução idêntico ao seu comando manual:"
	@echo "  make run-sector \\"
	@echo "       SECTOR_NAME=sector2 \\"
	@echo "       ADD_HOST=sector1:172.16.201.10 \\"
	@echo "       SECTOR_HOSTS=sector1:5050 \\"
	@echo "       BLOCKCHAIN_SECTORS=sector1:5050,sector2:5050 \\"
	@echo "       PASSKEY=\"maritime_luqueta_2026\""
	@echo "======================================================================"

# --- COMANDOS DE BUILD ---
build-sector:
	docker build -f apps/sector/Dockerfile -t maritime_sector .

build-drone:
	docker build -f apps/drone/Dockerfile -t maritime_drone .

build-sensor:
	docker build -f apps/sensors/Dockerfile -t maritime_sensor .

build-all: build-sector build-drone build-sensor

# --- COMANDOS DE EXECUÇÃO ---
run-sector: build-sector
	docker run -it --rm \
		--name $(SECTOR_NAME) \
		--network host \
		$(if $(ADD_HOST),--add-host $(ADD_HOST)) \
		-v $(shell pwd)/chain.json:/app/chain.json \
		-e NODE_NAME=$(SECTOR_NAME) \
		-e TCP_PORT=$(SECTOR_PORT) \
		-e HOSTS=$(SECTOR_HOSTS) \
		-e BLOCKCHAIN_SECTORS=$(BLOCKCHAIN_SECTORS) \
		-e PASSKEY=$(PASSKEY) \
		maritime_sector

run-drone: build-drone
	docker run -it --rm \
		--network host \
		-e DRONE_ID=$(DRONE_ID) \
		-e TCP_PEERS=$(DRONE_PEERS) \
		-e PASSKEY=$(PASSKEY) \
		maritime_drone

run-sensor: build-sensor
	docker run -it --rm \
		--network host \
		-e HOST=$(SENSOR_HOST) \
		-e PASSKEY=$(PASSKEY) \
		maritime_sensor
