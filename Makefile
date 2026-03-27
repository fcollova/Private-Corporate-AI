# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Makefile containing quick commands to manage the Docker stack.
# =============================================================================

.PHONY: up down build restart rebuild-rag reload-nginx logs status \
        monitor monitor-once gpu-monitor \
        list-models active-model pull-model remove-model \
        health test-chat list-docs upload-doc init-collection list-rag-models \
        backup setup clean help install install-gpu install-cpu uninstall \
        rebuild-console logs-console open-console client-info reconfigure-client

# ── Dynamic Configuration from .env ─────────────────────────────────────────
# Read profile and mode from .env (defaults: corporate, gpu)
DEPLOY_PROFILE := $(shell grep "^DEPLOY_PROFILE=" .env 2>/dev/null | cut -d= -f2 | tr -d "'\"")
DEPLOY_PROFILE := $(if $(DEPLOY_PROFILE),$(DEPLOY_PROFILE),corporate)

DEPLOY_MODE := $(shell grep "^DEPLOY_MODE=" .env 2>/dev/null | cut -d= -f2 | tr -d "'\"")
DEPLOY_MODE := $(if $(DEPLOY_MODE),$(DEPLOY_MODE),gpu)

# Protocol based on profile (Solo uses HTTP, Corporate uses HTTPS)
PROTOCOL := $(if $(filter solo,$(DEPLOY_PROFILE)),http,https)

# Compose command based on profile and mode
ifeq ($(DEPLOY_PROFILE),solo)
    COMPOSE = docker compose -f docker-compose.solo.yaml --env-file .env --env-file versions.env
else
    ifeq ($(DEPLOY_MODE),gpu)
        COMPOSE = docker compose --env-file .env --env-file versions.env
    else
        COMPOSE = docker compose -f docker-compose.yaml -f docker-compose.lite.yaml --env-file .env --env-file versions.env
    endif
endif

# -----------------------------------------------------------------------------
# START / STOP
# -----------------------------------------------------------------------------

## Start the stack (automatic profile/mode detection from .env)
up:
	@echo ">>> Starting Private Corporate AI — Profile: $(DEPLOY_PROFILE), Mode: $(DEPLOY_MODE)"
	$(COMPOSE) up -d --build
	@echo ""
	@echo ">>> Stack started! Access at: $(PROTOCOL)://localhost"

## Start the stack in FULL mode (Corporate/GPU)
up-gpu:
	@echo ">>> Starting Private Corporate AI — CORPORATE Mode (GPU)"
	docker compose --env-file .env --env-file versions.env up -d --build
	@echo ""
	@echo ">>> Stack started! Access at: https://localhost"

## Start the stack in LITE mode (Corporate/CPU)
up-lite:
	@echo ">>> Starting Private Corporate AI — CORPORATE LITE Mode (CPU)"
	docker compose -f docker-compose.yaml -f docker-compose.lite.yaml --env-file .env --env-file versions.env up -d --build
	@echo ""
	@echo ">>> Stack started! Access at: https://localhost"

## Stop all services
down:
	$(COMPOSE) down

## Rebuild RAG Backend image
build:
	$(COMPOSE) build rag_backend

## Full restart
restart:
	@echo ">>> Restarting Private Corporate AI..."
	$(COMPOSE) up -d
	@echo ""
	@echo ">>> Stack restarted! Access at: $(PROTOCOL)://localhost"

## Recreate and restart only the RAG backend
rebuild-rag:
	@echo ">>> Rebuilding RAG Backend..."
	$(COMPOSE) up -d --build --force-recreate rag_backend
	@echo ">>> RAG Backend rebuilt."

## Recreate and restart only Nginx
reload-nginx:
	@echo ">>> Reloading Nginx configuration..."
	docker exec corporate_ai_nginx nginx -t && docker exec corporate_ai_nginx nginx -s reload
	@echo ">>> Nginx reloaded."

# -----------------------------------------------------------------------------
# LOGS AND MONITORING
# -----------------------------------------------------------------------------

## Show logs for all services in real-time
logs:
	$(COMPOSE) logs -f

## Show RAG Backend logs
logs-rag:
	$(COMPOSE) logs -f rag_backend

## Show model download logs
logs-init:
	$(COMPOSE) logs -f ollama_init

## Show Ollama logs (LLM inference)
logs-ollama:
	$(COMPOSE) logs -f ollama

## Show status of all containers
status:
	$(COMPOSE) ps

## Show real-time GPU usage
gpu-monitor:
	watch -n 2 nvidia-smi

## Show real-time CPU/RAM usage for all containers
monitor:
	docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"

## Snapshot of resource usage
monitor-once:
	docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

## Show Qdrant logs
logs-qdrant:
	$(COMPOSE) logs -f qdrant

## Show Redis logs (Corporate only)
logs-redis:
	@if [ "$(DEPLOY_PROFILE)" = "solo" ]; then echo "Redis not used in SOLO mode"; else $(COMPOSE) logs -f redis; fi

## Show Nginx logs
logs-nginx:
	$(COMPOSE) logs -f nginx

## Show Open WebUI logs
logs-webui:
	$(COMPOSE) logs -f open_webui

# -----------------------------------------------------------------------------
# MODEL DOWNLOAD
# -----------------------------------------------------------------------------

## Download models configured in .env
pull-models:
	$(COMPOSE) run --rm ollama_init

## List models installed on Ollama
list-models:
	$(COMPOSE) exec ollama ollama list

## Model currently loaded in memory
active-model:
	$(COMPOSE) exec ollama ollama ps

## Download a specific model — usage: make pull-model MODEL=mistral:7b
pull-model:
	@[ -n "$(MODEL)" ] || (echo "Specify model: make pull-model MODEL=mistral:7b" && exit 1)
	docker exec corporate_ai_ollama ollama pull $(MODEL)

## Remove a specific model — usage: make remove-model MODEL=gemma2:2b
remove-model:
	@[ -n "$(MODEL)" ] || (echo "Specify model: make remove-model MODEL=gemma2:2b" && exit 1)
	docker exec corporate_ai_ollama ollama rm $(MODEL)

# -----------------------------------------------------------------------------
# TEST AND HEALTH
# -----------------------------------------------------------------------------

## Verify health status of all services
health:
	@echo ">>> RAG Backend Healthcheck ($(PROTOCOL)):"
	@curl -sk $(PROTOCOL)://localhost/api/rag/health | python3 -m json.tool || echo "RAG Backend not responding"
	@echo ""
	@echo ">>> Qdrant Healthcheck:"
	@curl -sk http://localhost:6333/healthz 2>/dev/null || echo "Qdrant healthz not reachable from outside"
	@if [ "$(DEPLOY_PROFILE)" = "corporate" ]; then \
		echo ""; \
		echo ">>> Redis Healthcheck:"; \
		docker exec corporate_ai_redis redis-cli ping 2>/dev/null || echo "Redis not reachable"; \
	fi

## Test sample RAG query
test-chat:
	@echo ">>> Testing RAG query via $(PROTOCOL)..."
	curl -sk -X POST $(PROTOCOL)://localhost/api/rag/chat \
	  -H "Content-Type: application/json" \
	  -d '{"question": "What documents are available?", "top_k": 3}' \
	  | python3 -m json.tool

## List documents indexed in Qdrant
list-docs:
	curl -sk $(PROTOCOL)://localhost/api/rag/documents/list | python3 -m json.tool

## Upload a document to RAG — usage: make upload-doc FILE=/path/to/document.pdf
upload-doc:
	@[ -n "$(FILE)" ] || (echo "Specify file: make upload-doc FILE=/path/to/document.pdf" && exit 1)
	curl -sk -X POST $(PROTOCOL)://localhost/api/rag/documents/upload -F "file=@$(FILE)" | python3 -m json.tool

## Create Qdrant collection if it doesn't exist
init-collection:
	@echo ">>> Creating corporate_docs collection in Qdrant..."
	$(eval QDRANT_KEY := $(shell grep QDRANT_API_KEY .env | cut -d= -f2 | tr -d "'\""))
	curl -s -X PUT http://localhost:6333/collections/corporate_docs \
	  -H "Content-Type: application/json" \
	  -H "api-key: $(QDRANT_KEY)" \
	  -d '{"vectors": {"size": 768, "distance": "Cosine"}}' | python3 -m json.tool

## List RAG models exposed via OpenAI-compatible API
list-rag-models:
	curl -sk $(PROTOCOL)://localhost/rag/v1/models | python3 -m json.tool

## Completely wipe the RAG
wipe-rag:
	@echo ">>> WARNING: This operation will delete ALL indexed documents and metadata!"
	@read -p "Are you sure? Type 'YES' to confirm: " confirm && [ "$$confirm" = "YES" ]
	@echo ">>> Calling System Wipe API..."
	curl -sk -X POST $(PROTOCOL)://localhost/api/rag/wipe | python3 -m json.tool
	@echo ">>> RAG system cleaned successfully."

# -----------------------------------------------------------------------------
# CONSOLE
# -----------------------------------------------------------------------------

## Start the console
up-console:
	@if [ "$(DEPLOY_PROFILE)" = "solo" ]; then echo "Console is integrated in Nginx (Solo Mode)"; else $(COMPOSE) up -d console; fi

## Rebuild console
rebuild-console:
	@if [ "$(DEPLOY_PROFILE)" = "solo" ]; then \
		echo ">>> Rebuilding static console for SOLO mode..."; \
		docker run --rm -u $(shell id -u):$(shell id -g) -v $(shell pwd)/console:/app -w /app node:20-alpine sh -c "npm install && npm run build"; \
		echo ">>> Static files rebuilt in console/dist/"; \
		echo ">>> Reloading Nginx to serve new files..."; \
		docker exec corporate_ai_nginx nginx -s reload; \
	else \
		$(COMPOSE) run --rm -u $(shell id -u):$(shell id -g) console sh -c "npm install && npm run build" && $(COMPOSE) build --no-cache console && $(COMPOSE) up -d --force-recreate console; \
	fi

## Real-time console logs
logs-console:
	@if [ "$(DEPLOY_PROFILE)" = "solo" ]; then echo "Console logs are inside Nginx logs (Solo Mode)"; else $(COMPOSE) logs -f console; fi

## Open console in browser
open-console:
	@xdg-open $(PROTOCOL)://localhost/console/ 2>/dev/null || echo "Open: $(PROTOCOL)://localhost/console/"

# -----------------------------------------------------------------------------
# CLIENT MANAGEMENT
# -----------------------------------------------------------------------------

## Reconfigure branding, system prompt, and domains
reconfigure-client:
	sudo ./install.sh --reconfigure-client

## Show current client profile
client-info:
	@if [ -f branding/client.json ]; then \
		python3 -c "import json,sys; d=json.load(open('branding/client.json')); \
		[print(f'  {k:<20} {v}') for k,v in d.items()]"; \
	else \
		echo "  No client profile configured. Run: make reconfigure-client"; \
	fi

## Edit LLM model system prompt
edit-system-prompt:
	@$${EDITOR:-nano} rag_backend/system_prompt.txt
	$(COMPOSE) restart rag_backend
	@echo "System prompt updated and rag_backend restarted"

# -----------------------------------------------------------------------------
# BACKUP & MAINTENANCE
# -----------------------------------------------------------------------------

## Perform full data backup
backup:
	@echo ">>> Backing up Private Corporate AI..."
	@mkdir -p ./backups
	sudo tar -czf ./backups/backup_$(shell date +%Y%m%d_%H%M%S).tar.gz \
	  /var/lib/docker/volumes/private-corporate-ai_qdrant_data \
	  /var/lib/docker/volumes/private-corporate-ai_rag_uploads \
	  /var/lib/docker/volumes/private-corporate-ai_rag_data \
	  /var/lib/docker/volumes/private-corporate-ai_webui_data \
	  .env 2>/dev/null || true
	@echo ">>> Backup completed in ./backups/"

## Initial setup (SSL + .env)
setup:
	sudo ./install.sh --help

## Full removal (containers + volumes)
clean:
	@echo ">>> WARNING: this operation will delete ALL data!"
	@read -p "Are you sure? Type 'YES' to confirm: " confirm && [ "$$confirm" = "YES" ]
	$(COMPOSE) down -v --remove-orphans
	@echo ">>> Stack removed completely"

# -----------------------------------------------------------------------------
# HELP (PROFESSIONAL CLI)
# -----------------------------------------------------------------------------

# Colori
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
CYAN   := $(shell tput -Txterm setaf 6)
RESET  := $(shell tput -Txterm sgr0)

## Show this help message
help:
	@echo ""
	@echo "$(WHITE)Private Corporate AI — Command Line Interface$(RESET)"
	@echo "$(DIM)Versione 0.2.1 (Active Profile: $(DEPLOY_PROFILE))$(RESET)"
	@echo ""
	@echo "$(CYAN)USAGE:$(RESET)"
	@echo "  make $(GREEN)<target>$(RESET)"
	@echo ""
	@echo "$(CYAN)INSTALLATION:$(RESET)"
	@printf "  $(GREEN)install$(RESET)             Interactive installer (Solo/Corporate, GPU/CPU)\n"
	@printf "  $(GREEN)uninstall$(RESET)           Guided safe removal procedure\n"
	@echo ""
	@echo "$(CYAN)STACK MANAGEMENT:$(RESET)"
	@printf "  $(GREEN)up$(RESET)                  Start stack based on .env config\n"
	@printf "  $(GREEN)down$(RESET)                Stop all services\n"
	@printf "  $(GREEN)restart$(RESET)             Quick restart services\n"
	@printf "  $(GREEN)rebuild-rag$(RESET)         Rebuild only the RAG Backend\n"
	@echo ""
	@echo "$(CYAN)LOGS & MONITORING:$(RESET)"
	@printf "  $(GREEN)status$(RESET)              Check health of all containers\n"
	@printf "  $(GREEN)logs$(RESET)                Combined logs for all services\n"
	@printf "  $(GREEN)monitor$(RESET)             Real-time CPU/RAM resource usage\n"
	@echo ""
	@echo "$(CYAN)RAG OPERATIONS:$(RESET)"
	@printf "  $(GREEN)health$(RESET)              Verify connectivity ($(PROTOCOL))\n"
	@printf "  $(GREEN)test-chat$(RESET)           Test a RAG query from CLI\n"
	@printf "  $(GREEN)upload-doc$(RESET)          Upload a file (usage: FILE=path/to/file)\n"
	@echo ""
	@echo "$(CYAN)CONSOLE:$(RESET)"
	@printf "  $(GREEN)rebuild-console$(RESET)      Recompile frontend (Static for Solo, Container for Corp)\n"
	@printf "  $(GREEN)open-console$(RESET)         Open browser at /console/\n"
	@echo ""

.DEFAULT_GOAL := help

## Installation commands
install:
	@chmod +x install.sh
	sudo ./install.sh

install-gpu:
	sudo ./install.sh --gpu

install-cpu:
	sudo ./install.sh --cpu

uninstall:
	@chmod +x uninstall.sh
	sudo ./uninstall.sh
