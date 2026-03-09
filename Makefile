# =============================================================================
# PRIVATE CORPORATE AI — Makefile
# Comandi rapidi per gestire lo stack in entrambe le modalità
# =============================================================================
# Uso: make <comando>
# Es:  make up-gpu     → avvia in modalità GPU
#      make up-lite    → avvia in modalità LITE (CPU-only)
#      make down       → ferma tutto
#      make logs       → mostra log in tempo reale
# =============================================================================

.PHONY: up-gpu up-lite down down-lite build restart-lite restart-gpu \
        rebuild-rag reload-nginx logs logs-rag logs-init logs-ollama \
        logs-qdrant logs-nginx logs-webui logs-lite status status-lite \
        monitor monitor-once gpu-monitor \
        pull-models-gpu pull-models-lite list-models active-model pull-model remove-model \
        health test-chat list-docs upload-doc init-collection list-rag-models \
        backup setup clean help install install-gpu install-cpu uninstall

COMPOSE_BASE = docker compose --env-file .env
COMPOSE_LITE = docker compose -f docker-compose.yaml -f docker-compose.lite.yaml --env-file .env

# -----------------------------------------------------------------------------
# AVVIO / STOP
# -----------------------------------------------------------------------------

## Avvia lo stack in modalità FULL (GPU NVIDIA richiesta)
up-gpu:
	@echo ">>> Avvio Private Corporate AI — Modalità FULL (GPU)"
	@echo ">>> Assicurati che i driver NVIDIA e nvidia-container-toolkit siano installati"
	$(COMPOSE_BASE) up -d --build
	@echo ""
	@echo ">>> Stack avviato! Accedi a: https://localhost"
	@echo ">>> Attendi il download dei modelli: make logs-init"

## Avvia lo stack in modalità LITE (CPU-only, nessuna GPU richiesta)
up-lite:
	@echo ">>> Avvio Private Corporate AI — Modalità LITE (CPU-only)"
	@echo ">>> Consiglio: imposta LLM_MODEL=phi3:mini o gemma2:2b nel .env"
	$(COMPOSE_LITE) up -d --build
	@echo ""
	@echo ">>> Stack avviato in modalità LITE! Accedi a: https://localhost"
	@echo ">>> La prima risposta LLM potrebbe richiedere 1-3 minuti su CPU"
	@echo ">>> Monitora il download modelli: make logs-init"

## Ferma tutti i servizi (modalità GPU)
down:
	$(COMPOSE_BASE) down

## Ferma tutti i servizi (modalità LITE)
down-lite:
	$(COMPOSE_LITE) down

## Ricostruisce l'immagine del RAG Backend
build:
	$(COMPOSE_BASE) build rag_backend

## Riavvio completo dopo down (modalità LITE) — comando principale per uso quotidiano
restart-lite:
	@echo ">>> Riavvio Private Corporate AI — Modalità LITE"
	$(COMPOSE_LITE) up -d
	@echo ""
	@echo ">>> Stack riavviato! Accedi a: https://localhost"
	@echo ">>> Attendi ~60s poi verifica con: make health"

## Riavvio completo dopo down (modalità GPU)
restart-gpu:
	@echo ">>> Riavvio Private Corporate AI — Modalità FULL (GPU)"
	$(COMPOSE_BASE) up -d
	@echo ""
	@echo ">>> Stack riavviato! Accedi a: https://localhost"

## Ricrea e riavvia solo il RAG backend (dopo modifiche a app.py)
rebuild-rag:
	@echo ">>> Rebuild RAG Backend..."
	$(COMPOSE_LITE) up -d --build --force-recreate rag_backend
	@echo ">>> RAG Backend ricostruito. Verifica: make logs-rag"

## Ricrea e riavvia solo Nginx (dopo modifiche a nginx.conf)
reload-nginx:
	@echo ">>> Ricarica configurazione Nginx..."
	docker exec corporate_ai_nginx nginx -t && docker exec corporate_ai_nginx nginx -s reload
	@echo ">>> Nginx ricaricato."

# -----------------------------------------------------------------------------
# LOG E MONITORING
# -----------------------------------------------------------------------------

## Mostra log di tutti i servizi in tempo reale
logs:
	$(COMPOSE_BASE) logs -f

## Mostra log del RAG Backend
logs-rag:
	$(COMPOSE_BASE) logs -f rag_backend

## Mostra log del download modelli
logs-init:
	$(COMPOSE_BASE) logs -f ollama_init

## Mostra log di Ollama (inferenza LLM)
logs-ollama:
	$(COMPOSE_BASE) logs -f ollama

## Mostra stato di tutti i container
status:
	$(COMPOSE_BASE) ps

## Mostra utilizzo GPU in tempo reale (solo modalità FULL)
gpu-monitor:
	watch -n 2 nvidia-smi

## Mostra utilizzo CPU/RAM di tutti i container in tempo reale
monitor:
	docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"

## Snapshot istantaneo utilizzo risorse (senza aggiornamento continuo)
monitor-once:
	docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

## Mostra log di Qdrant (vector database)
logs-qdrant:
	$(COMPOSE_LITE) logs -f qdrant

## Mostra log di Nginx (reverse proxy)
logs-nginx:
	$(COMPOSE_LITE) logs -f nginx

## Mostra log di Open WebUI
logs-webui:
	$(COMPOSE_LITE) logs -f open_webui

## Mostra log LITE (con entrambi i file compose)
logs-lite:
	$(COMPOSE_LITE) logs -f

## Stato container con entrambi i file compose (LITE)
status-lite:
	$(COMPOSE_LITE) ps

# -----------------------------------------------------------------------------
# DOWNLOAD MODELLI
# -----------------------------------------------------------------------------

## Scarica i modelli configurati in .env (modalità GPU)
pull-models-gpu:
	$(COMPOSE_BASE) run --rm ollama_init

## Scarica i modelli consigliati per CPU (modalità LITE)
pull-models-lite:
	@echo ">>> Download modelli ottimizzati per CPU..."
	$(COMPOSE_BASE) exec ollama ollama pull ${LLM_MODEL}
	$(COMPOSE_BASE) exec ollama ollama pull ${EMBEDDING_MODEL}

## Lista modelli installati su Ollama
list-models:
	$(COMPOSE_LITE) exec ollama ollama list

## Modello attualmente caricato in memoria
active-model:
	$(COMPOSE_LITE) exec ollama ollama ps

## Scarica un modello specifico — uso: make pull-model MODEL=mistral:7b-instruct-q4_K_M
pull-model:
	@[ -n "$(MODEL)" ] || (echo "Specifica il modello: make pull-model MODEL=mistral:7b-instruct-q4_K_M" && exit 1)
	docker exec corporate_ai_ollama ollama pull $(MODEL)

## Rimuove un modello specifico — uso: make remove-model MODEL=gemma2:2b
remove-model:
	@[ -n "$(MODEL)" ] || (echo "Specifica il modello: make remove-model MODEL=gemma2:2b" && exit 1)
	docker exec corporate_ai_ollama ollama rm $(MODEL)

# -----------------------------------------------------------------------------
# TEST E HEALTH
# -----------------------------------------------------------------------------

## Verifica stato di salute di tutti i servizi
health:
	@echo ">>> Healthcheck RAG Backend:"
	curl -sk https://localhost/api/rag/health | python3 -m json.tool
	@echo ""
	@echo ">>> Healthcheck Qdrant:"
	curl -sk http://localhost:6333/healthz 2>/dev/null || echo "Qdrant non raggiungibile dall'esterno (normale se UFW attivo)"

## Test query RAG di esempio
test-chat:
	@echo ">>> Test query RAG..."
	curl -sk -X POST https://localhost/api/rag/chat \
	  -H "Content-Type: application/json" \
	  -d '{"question": "Quali documenti sono disponibili?", "top_k": 3}' \
	  | python3 -m json.tool

## Lista documenti indicizzati in Qdrant
list-docs:
	curl -sk https://localhost/api/rag/documents/list | python3 -m json.tool

## Carica un documento nel RAG — uso: make upload-doc FILE=/percorso/documento.pdf
upload-doc:
	@[ -n "$(FILE)" ] || (echo "Specifica il file: make upload-doc FILE=/percorso/documento.pdf" && exit 1)
	curl -sk -X POST https://localhost/api/rag/documents/upload -F "file=@$(FILE)" | python3 -m json.tool

## Crea la collezione Qdrant se non esiste (necessario al primo avvio)
init-collection:
	@echo ">>> Creazione collezione corporate_docs in Qdrant..."
	$(eval QDRANT_KEY := $(shell grep QDRANT_API_KEY .env | cut -d= -f2))
	curl -s -X PUT http://localhost:6333/collections/corporate_docs 	  -H "Content-Type: application/json" 	  -H "api-key: $(QDRANT_KEY)" 	  -d '{"vectors": {"size": 768, "distance": "Cosine"}}' | python3 -m json.tool

## Lista modelli RAG esposti via API OpenAI-compatibile
list_rag_models:
	curl -sk https://localhost/rag/v1/models | python3 -m json.tool

## Svuota completamente il RAG (cancella documenti e indice vettoriale)
wipe-rag:
	@echo ">>> ATTENZIONE: Questa operazione cancellera' TUTTI i documenti indicizzati!"
	@read -p "Sei sicuro? Digita 'SI' per confermare: " confirm && [ "$$confirm" = "SI" ]
	@echo ">>> Eliminazione indice vettoriale Qdrant..."
	$(eval QDRANT_KEY := $(shell grep QDRANT_API_KEY .env | cut -d= -f2))
	@docker exec corporate_ai_rag curl -s -X DELETE http://qdrant:6333/collections/corporate_docs \
	  -H "api-key: $(QDRANT_KEY)" > /dev/null || true
	@echo ">>> Eliminazione file fisici in uploads/..."
	@docker exec corporate_ai_rag sh -c "rm -rf /app/uploads/* && touch /app/uploads/.gitkeep"
	@echo ">>> RAG ripulito correttamente."
	@echo ">>> La collezione verra' ricreata automaticamente al prossimo upload."

# -----------------------------------------------------------------------------
# CONSOLE
# -----------------------------------------------------------------------------

## Avvia la console (inclusa nel normale up-gpu / up-lite)
up-console:
	$(COMPOSE_BASE) up -d console
	@echo "Console disponibile su https://localhost/console/"

## Rebuild della sola console (dopo modifiche al codice React)
rebuild-console:
	$(COMPOSE_BASE) build --no-cache console
	$(COMPOSE_BASE) up -d --force-recreate console
	@echo "Console ricompilata e riavviata"

## Log in tempo reale della console
logs-console:
	$(COMPOSE_BASE) logs -f console

## Apri la console nel browser (Linux/WSL)
open-console:
	@xdg-open https://localhost/console/ 2>/dev/null || echo "Apri: https://localhost/console/"

# -----------------------------------------------------------------------------
# BACKUP
# -----------------------------------------------------------------------------


## Esegui backup completo dei dati (indice vettoriale + documenti + config)
backup:
	@echo ">>> Backup Private Corporate AI..."
	@mkdir -p ./backups
	sudo tar -czf ./backups/backup_$(shell date +%Y%m%d_%H%M%S).tar.gz \
	  /var/lib/docker/volumes/private-corporate-ai_qdrant_data \
	  /var/lib/docker/volumes/private-corporate-ai_rag_uploads \
	  /var/lib/docker/volumes/private-corporate-ai_webui_data \
	  .env 2>/dev/null || true
	@echo ">>> Backup completato in ./backups/"
	@ls -lh ./backups/ | tail -5

# -----------------------------------------------------------------------------
# SETUP INIZIALE
# -----------------------------------------------------------------------------

## Setup rapido: crea .env e certificati SSL self-signed
setup:
	@echo ">>> Setup iniziale Private Corporate AI..."
	@[ -f .env ] && echo "  .env gia' presente, skip" || (cp .env.example .env && echo "  .env creato da .env.example — MODIFICALO prima di avviare!")
	@mkdir -p nginx/ssl
	@[ -f nginx/ssl/server.crt ] && echo "  Certificati SSL gia' presenti, skip" || \
	  (openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
	    -keyout nginx/ssl/server.key -out nginx/ssl/server.crt \
	    -subj "/C=IT/ST=Italia/L=Roma/O=CorporateAI/CN=localhost" \
	    -addext "subjectAltName=IP:127.0.0.1,DNS:localhost" 2>/dev/null && \
	    chmod 600 nginx/ssl/server.key && \
	    echo "  Certificati SSL self-signed generati in nginx/ssl/")
	@echo ""
	@echo ">>> Setup completato!"
	@echo "    1. Modifica .env con il modello e le password desiderate"
	@echo "    2. Per GPU:  make up-gpu"
	@echo "    3. Per CPU:  make up-lite"

## Rimozione completa (container + volumi — ATTENZIONE: cancella tutti i dati!)
clean:
	@echo ">>> ATTENZIONE: questa operazione cancellera' TUTTI i dati!"
	@read -p "Sei sicuro? Digita 'SI' per confermare: " confirm && [ "$$confirm" = "SI" ]
	$(COMPOSE_BASE) down -v --remove-orphans
	@echo ">>> Stack rimosso completamente"

# -----------------------------------------------------------------------------
# HELP
# -----------------------------------------------------------------------------

## Mostra questo messaggio di aiuto
help:
	@echo ""
	@echo "  Private Corporate AI — Comandi disponibili"
	@echo "  ==========================================="
	@grep -E '^##' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "  Esempi comuni:"
	@echo "    make setup                          → Prima configurazione"
	@echo "    make up-lite                        → Avvia (modalità CPU)"
	@echo "    make restart-lite                   → Riavvia dopo down"
	@echo "    make down-lite                      → Ferma tutto"
	@echo "    make status-lite                    → Stato container"
	@echo "    make health                         → Verifica servizi"
	@echo "    make logs-lite                      → Log in tempo reale"
	@echo "    make monitor                        → Risorse CPU/RAM"
	@echo "    make test-chat                      → Test query RAG"
	@echo "    make pull-model MODEL=mistral:7b    → Scarica modello"
	@echo "    make upload-doc FILE=./doc.pdf      → Carica documento"
	@echo "    make rebuild-rag                    → Rebuild RAG backend"
	@echo "    make reload-nginx                   → Ricarica Nginx"
	@echo ""

.DEFAULT_GOAL := help

# -----------------------------------------------------------------------------
# INSTALLAZIONE / DISINSTALLAZIONE
# -----------------------------------------------------------------------------

## Installazione interattiva (rileva hardware, sceglie GPU o CPU)
install:
	@chmod +x install.sh install-gpu.sh install-cpu.sh uninstall.sh
	sudo ./install.sh

## Installazione forzata modalità FULL (GPU NVIDIA)
install-gpu:
	@chmod +x install.sh install-gpu.sh
	sudo ./install-gpu.sh

## Installazione forzata modalità LITE (CPU-only)
install-cpu:
	@chmod +x install.sh install-cpu.sh
	sudo ./install-cpu.sh

## Disinstallazione interattiva
uninstall:
	@chmod +x uninstall.sh
	sudo ./uninstall.sh
