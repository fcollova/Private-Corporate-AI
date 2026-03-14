# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Makefile containing quick commands to manage the Docker stack in both GPU and CPU modes.
# =============================================================================

.PHONY: up-gpu up-lite down down-lite build restart-lite restart-gpu \
        rebuild-rag reload-nginx logs logs-rag logs-init logs-ollama \
        logs-qdrant logs-nginx logs-webui logs-lite status status-lite \
        monitor monitor-once gpu-monitor \
        pull-models-gpu pull-models-lite list-models active-model pull-model remove-model \
        health test-chat list-docs upload-doc init-collection list-rag-models \
        backup setup clean help install install-gpu install-cpu uninstall

COMPOSE_BASE = docker compose --env-file .env --env-file versions.env
COMPOSE_LITE = docker compose -f docker-compose.yaml -f docker-compose.lite.yaml --env-file .env --env-file versions.env

# -----------------------------------------------------------------------------
# START / STOP
# -----------------------------------------------------------------------------

## Start the stack in FULL mode (NVIDIA GPU required)
up-gpu:
	@echo ">>> Starting Private Corporate AI — FULL Mode (GPU)"
	@echo ">>> Ensure NVIDIA drivers and nvidia-container-toolkit are installed"
	$(COMPOSE_BASE) up -d --build
	@echo ""
	@echo ">>> Stack started! Access at: https://localhost"
	@echo ">>> Wait for model download: make logs-init"

## Start the stack in LITE mode (CPU-only, no GPU required)
up-lite:
	@echo ">>> Starting Private Corporate AI — LITE Mode (CPU-only)"
	@echo ">>> Tip: set LLM_MODEL=phi3:mini or gemma2:2b in .env"
	$(COMPOSE_LITE) up -d --build
	@echo ""
	@echo ">>> Stack started in LITE mode! Access at: https://localhost"
	@echo ">>> First LLM response may take 1-3 minutes on CPU"
	@echo ">>> Monitor model download: make logs-init"

## Stop all services (GPU mode)
down:
	$(COMPOSE_BASE) down

## Stop all services (LITE mode)
down-lite:
	$(COMPOSE_LITE) down

## Rebuild RAG Backend image
build:
	$(COMPOSE_BASE) build rag_backend

## Full restart after down (LITE mode) — main command for daily use
restart-lite:
	@echo ">>> Restarting Private Corporate AI — LITE Mode"
	$(COMPOSE_LITE) up -d
	@echo ""
	@echo ">>> Stack restarted! Access at: https://localhost"
	@echo ">>> Wait ~60s then verify with: make health"

## Full restart after down (GPU mode)
restart-gpu:
	@echo ">>> Restarting Private Corporate AI — FULL Mode (GPU)"
	$(COMPOSE_BASE) up -d
	@echo ""
	@echo ">>> Stack restarted! Access at: https://localhost"

## Recreate and restart only the RAG backend (after app.py changes)
rebuild-rag:
	@echo ">>> Rebuilding RAG Backend..."
	$(COMPOSE_LITE) up -d --build --force-recreate rag_backend
	@echo ">>> RAG Backend rebuilt. Verify with: make logs-rag"

## Recreate and restart only Nginx (after nginx.conf changes)
reload-nginx:
	@echo ">>> Reloading Nginx configuration..."
	docker exec corporate_ai_nginx nginx -t && docker exec corporate_ai_nginx nginx -s reload
	@echo ">>> Nginx reloaded."

# -----------------------------------------------------------------------------
# LOGS AND MONITORING
# -----------------------------------------------------------------------------

## Show logs for all services in real-time
logs:
	$(COMPOSE_BASE) logs -f

## Show RAG Backend logs
logs-rag:
	$(COMPOSE_BASE) logs -f rag_backend

## Show model download logs
logs-init:
	$(COMPOSE_BASE) logs -f ollama_init

## Show Ollama logs (LLM inference)
logs-ollama:
	$(COMPOSE_BASE) logs -f ollama

## Show status of all containers
status:
	$(COMPOSE_BASE) ps

## Show real-time GPU usage (FULL mode only)
gpu-monitor:
	watch -n 2 nvidia-smi

## Show real-time CPU/RAM usage for all containers
monitor:
	docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"

## Snapshot of resource usage (no continuous update)
monitor-once:
	docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

## Show Qdrant logs (vector database)
logs-qdrant:
	$(COMPOSE_LITE) logs -f qdrant

## Show Nginx logs (reverse proxy)
logs-nginx:
	$(COMPOSE_LITE) logs -f nginx

## Show Open WebUI logs
logs-webui:
	$(COMPOSE_LITE) logs -f open_webui

## Show LITE logs (using both compose files)
logs-lite:
	$(COMPOSE_LITE) logs -f

## Container status with both compose files (LITE)
status-lite:
	$(COMPOSE_LITE) ps

# -----------------------------------------------------------------------------
# MODEL DOWNLOAD
# -----------------------------------------------------------------------------

## Download models configured in .env (GPU mode)
pull-models-gpu:
	$(COMPOSE_BASE) run --rm ollama_init

## Download recommended models for CPU (LITE mode)
pull-models-lite:
	@echo ">>> Downloading CPU-optimized models..."
	$(COMPOSE_BASE) exec ollama ollama pull ${LLM_MODEL}
	$(COMPOSE_BASE) exec ollama ollama pull ${EMBEDDING_MODEL}

## List models installed on Ollama
list-models:
	$(COMPOSE_LITE) exec ollama ollama list

## Model currently loaded in memory
active-model:
	$(COMPOSE_LITE) exec ollama ollama ps

## Download a specific model — usage: make pull-model MODEL=mistral:7b-instruct-q4_K_M
pull-model:
	@[ -n "$(MODEL)" ] || (echo "Specify model: make pull-model MODEL=mistral:7b-instruct-q4_K_M" && exit 1)
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
	@echo ">>> RAG Backend Healthcheck:"
	curl -sk https://localhost/api/rag/health | python3 -m json.tool
	@echo ""
	@echo ">>> Qdrant Healthcheck:"
	curl -sk http://localhost:6333/healthz 2>/dev/null || echo "Qdrant not reachable from outside (normal if UFW active)"

## Test sample RAG query
test-chat:
	@echo ">>> Testing RAG query..."
	curl -sk -X POST https://localhost/api/rag/chat \
	  -H "Content-Type: application/json" \
	  -d '{"question": "What documents are available?", "top_k": 3}' \
	  | python3 -m json.tool

## List documents indexed in Qdrant
list-docs:
	curl -sk https://localhost/api/rag/documents/list | python3 -m json.tool

## Upload a document to RAG — usage: make upload-doc FILE=/path/to/document.pdf
upload-doc:
	@[ -n "$(FILE)" ] || (echo "Specify file: make upload-doc FILE=/path/to/document.pdf" && exit 1)
	curl -sk -X POST https://localhost/api/rag/documents/upload -F "file=@$(FILE)" | python3 -m json.tool

## Create Qdrant collection if it doesn't exist (required at first start)
init-collection:
	@echo ">>> Creating corporate_docs collection in Qdrant..."
	$(eval QDRANT_KEY := $(shell grep QDRANT_API_KEY .env | cut -d= -f2))
	curl -s -X PUT http://localhost:6333/collections/corporate_docs 	  -H "Content-Type: application/json" 	  -H "api-key: $(QDRANT_KEY)" 	  -d '{"vectors": {"size": 768, "distance": "Cosine"}}' | python3 -m json.tool

## List RAG models exposed via OpenAI-compatible API
list_rag_models:
	curl -sk https://localhost/rag/v1/models | python3 -m json.tool

## Completely wipe the RAG (delete documents and vector index)
wipe-rag:
	@echo ">>> WARNING: This operation will delete ALL indexed documents!"
	@read -p "Are you sure? Type 'YES' to confirm: " confirm && [ "$$confirm" = "YES" ]
	@echo ">>> Deleting Qdrant vector index..."
	$(eval QDRANT_KEY := $(shell grep QDRANT_API_KEY .env | cut -d= -f2))
	@docker exec corporate_ai_rag curl -s -X DELETE http://qdrant:6333/collections/corporate_docs \
	  -H "api-key: $(QDRANT_KEY)" > /dev/null || true
	@echo ">>> Deleting physical files in uploads/..."
	@docker exec corporate_ai_rag sh -c "rm -rf /app/uploads/* && touch /app/uploads/.gitkeep"
	@echo ">>> RAG cleaned successfully."
	@echo ">>> Collection will be automatically recreated on next upload."

# -----------------------------------------------------------------------------
# CONSOLE
# -----------------------------------------------------------------------------

## Start the console (included in standard up-gpu / up-lite)
up-console:
	$(COMPOSE_BASE) up -d console
	@echo "Console available at https://localhost/console/"

## Rebuild console only (after React code changes)
rebuild-console:
	$(COMPOSE_BASE) build --no-cache console
	$(COMPOSE_BASE) up -d --force-recreate console
	@echo "Console recompiled and restarted"

## Real-time console logs
logs-console:
	$(COMPOSE_BASE) logs -f console

## Open console in browser (Linux/WSL)
open-console:
	@xdg-open https://localhost/console/ 2>/dev/null || echo "Open: https://localhost/console/"

# -----------------------------------------------------------------------------
# CLIENT MANAGEMENT
# -----------------------------------------------------------------------------

## Reconfigure branding, system prompt, and domains without reinstalling
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
	@${EDITOR:-nano} rag_backend/system_prompt.txt
	$(COMPOSE_BASE) restart rag_backend
	@echo "System prompt updated and rag_backend restarted"

## Export client configuration for backup or replication
export-client-config:
	@tar -czf client-config-$(shell date +%Y%m%d).tar.gz \
		branding/ rag_backend/system_prompt.txt .env
	@echo "Configuration exported: client-config-$(shell date +%Y%m%d).tar.gz"

# -----------------------------------------------------------------------------
# BACKUP
# -----------------------------------------------------------------------------


## Perform full data backup (vector index + documents + config)
backup:
	@echo ">>> Backing up Private Corporate AI..."
	@mkdir -p ./backups
	sudo tar -czf ./backups/backup_$(shell date +%Y%m%d_%H%M%S).tar.gz \
	  /var/lib/docker/volumes/private-corporate-ai_qdrant_data \
	  /var/lib/docker/volumes/private-corporate-ai_rag_uploads \
	  /var/lib/docker/volumes/private-corporate-ai_webui_data \
	  .env 2>/dev/null || true
	@echo ">>> Backup completed in ./backups/"
	@ls -lh ./backups/ | tail -5

# -----------------------------------------------------------------------------
# INITIAL SETUP
# -----------------------------------------------------------------------------

## Quick setup: create .env and self-signed SSL certificates
setup:
	@echo ">>> Initial Setup Private Corporate AI..."
	@[ -f .env ] && echo "  .env already exists, skipping" || (cp .env.example .env && echo "  .env created from .env.example — EDIT IT before starting!")
	@mkdir -p nginx/ssl
	@[ -f nginx/ssl/server.crt ] && echo "  SSL certificates already exist, skipping" || \
	  (openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
	    -keyout nginx/ssl/server.key -out nginx/ssl/server.crt \
	    -subj "/C=IT/ST=Italy/L=Rome/O=CorporateAI/CN=localhost" \
	    -addext "subjectAltName=IP:127.0.0.1,DNS:localhost" 2>/dev/null && \
	    chmod 600 nginx/ssl/server.key && \
	    echo "  Self-signed SSL certificates generated in nginx/ssl/")
	@echo ""
	@echo ">>> Setup completed!"
	@echo "    1. Edit .env with desired model and passwords"
	@echo "    2. For GPU:  make up-gpu"
	@echo "    3. For CPU:  make up-lite"

## Full removal (containers + volumes — WARNING: deletes ALL data!)
clean:
	@echo ">>> WARNING: this operation will delete ALL data!"
	@read -p "Are you sure? Type 'YES' to confirm: " confirm && [ "$$confirm" = "YES" ]
	$(COMPOSE_BASE) down -v --remove-orphans
	@echo ">>> Stack removed completely"

# -----------------------------------------------------------------------------
# HELP
# -----------------------------------------------------------------------------

## Show this help message
help:
	@echo ""
	@echo "  Private Corporate AI — Available Commands"
	@echo "  ==========================================="
	@grep -E '^##' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "  Common examples:"
	@echo "    make setup                          → Initial configuration"
	@echo "    make up-lite                        → Start (CPU mode)"
	@echo "    make restart-lite                   → Restart after down"
	@echo "    make down-lite                      → Stop all"
	@echo "    make status-lite                    → Container status"
	@echo "    make health                         → Verify services"
	@echo "    make logs-lite                      → Real-time logs"
	@echo "    make monitor                        → CPU/RAM resources"
	@echo "    make test-chat                      → Test RAG query"
	@echo "    make pull-model MODEL=mistral:7b    → Download model"
	@echo "    make upload-doc FILE=./doc.pdf      → Upload document"
	@echo "    make rebuild-rag                    → Rebuild RAG backend"
	@echo "    make reload-nginx                   → Reload Nginx"
	@echo ""

.DEFAULT_GOAL := help

# -----------------------------------------------------------------------------
# INSTALLATION / UNINSTALLATION
# -----------------------------------------------------------------------------

## Interactive installation (detects hardware, chooses GPU or CPU)
install:
	@chmod +x install.sh install-gpu.sh install-cpu.sh uninstall.sh
	sudo ./install.sh

## Forced FULL mode installation (NVIDIA GPU)
install-gpu:
	@chmod +x install.sh install-gpu.sh
	sudo ./install-gpu.sh

## Forced LITE mode installation (CPU-only)
install-cpu:
	@chmod +x install.sh install-cpu.sh
	sudo ./install-cpu.sh

## Interactive uninstallation
uninstall:
	@chmod +x uninstall.sh
	sudo ./uninstall.sh
