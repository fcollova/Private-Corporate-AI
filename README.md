# 🔒 Private Corporate AI

> **L'intelligenza artificiale generativa che non lascia mai il tuo server.**

Uno stack completo, production-ready e 100% open source per portare LLM e RAG (*Retrieval-Augmented Generation*) **dentro** la tua infrastruttura aziendale. Zero dati verso server esterni. Zero dipendenze da vendor cloud. Piena conformità GDPR.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Compose_v3.9-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi)](https://fastapi.tiangolo.com/)

---

## Perché questo progetto

Ogni prompt inviato a un servizio AI cloud attraversa reti esterne, viene loggato e potenzialmente usato per addestrare modelli futuri. Per contratti riservati, strategie di prodotto, dati HR, codice proprietario — questo è inaccettabile.

**Private Corporate AI** risolve il problema alla radice: l'intero stack gira localmente. Il prompt nasce sul browser dell'utente, attraversa Nginx, viene elaborato dai container Docker, raggiunge il modello LLM — e la risposta percorre il cammino inverso. **In nessun momento un byte lascia il perimetro aziendale.**

---

## Stack tecnologico

| Container | Immagine | Ruolo | Licenza |
|-----------|----------|-------|---------|
| `corporate_ai_nginx` | `nginx:alpine` | Reverse proxy SSL/TLS, rate limiting, security headers | BSD |
| `corporate_ai_webui` | `ghcr.io/open-webui/open-webui` | Interfaccia chat web, gestione conversazioni | MIT |
| `corporate_ai_console` | `node:20-alpine` | **Document Management Console** (React + Vite) | MIT |
| `corporate_ai_rag` | *Custom build* | FastAPI + LangChain, pipeline RAG, API OpenAI-compatibile | MIT |
| `corporate_ai_ollama` | `ollama/ollama` | Runtime LLM locale, supporto CPU e GPU NVIDIA | MIT |
| `corporate_ai_qdrant` | `qdrant/qdrant` | Vector database, ricerca semantica per similarità coseno | Apache 2.0 |
| `corporate_ai_ollama_init` | `ollama/ollama` | Init one-shot: scarica LLM e modello embedding al primo avvio | MIT |

---

## Architettura

```
                        ┌─────────────────────────────────────────────────┐
        Browser  ──────▶│  NGINX  (SSL · Rate Limit · Security Headers)   │
        HTTPS           └──────────────┬────────────────────────────────--┘
                                       │  frontend_net  172.20.0.0/24
               ┌───────────────────────┼───────────────────────────┐
               ▼                       ▼                           ▼
        ┌──────────────┐       ┌──────────────┐            ┌──────────────┐
        │ Open WebUI   │       │ RAG Console  │            │ RAG Backend  │
        │    (Chat)    │       │ (Management) │            │  (FastAPI)   │
        └──────────────┘       └──────────────┘            └──────┬───────┘
                                                                  │
                                       │  backend_net  172.21.0.0/24
                                       ┌───────────────┼──────────────────┐
                                       │               │                  │
                               ┌───────▼──────┐ ┌─────▼────────┐  ┌──────▼─────┐
                               │   OLLAMA LLM │ │   QDRANT     │  │ ollama_init│
                               │  (inference) │ │  (vectors)   │  │ (one-shot) │
                               └──────────────┘ └──────────────┘  └────────────┘
```

**Reti Docker separate by design:**
- `frontend_net` — Nginx, Open WebUI, RAG Console, RAG Backend
- `backend_net` — RAG Backend, Ollama, Qdrant

---

## Requisiti

### Modalità FULL (GPU — consigliata)

| Componente | Minimo | Consigliato |
|------------|--------|-------------|
| GPU NVIDIA | 8 GB VRAM | 16–24 GB VRAM (RTX 3090/4090) |
| RAM | 16 GB | 32 GB |
| Disco | 50 GB | 100 GB+ |
| OS | Linux / WSL2 | Ubuntu 22.04+ |

### Modalità LITE (CPU-only — nessuna GPU richiesta)

| Componente | Minimo | Consigliato |
|------------|--------|-------------|
| CPU | 4 core | 8+ core |
| RAM | 8 GB | 16–32 GB |
| Disco | 30 GB | 60 GB+ |

---

## Accesso all'interfaccia

Dopo l'avvio (attendere 2–5 minuti per il download dei modelli al primo avvio):

| Servizio | URL | Note |
|----------|-----|-------|
| Open WebUI | `https://localhost` | Interfaccia chat principale |
| **Document Console** | `https://localhost/console/` | Gestione documenti e domini RAG |
| RAG API docs | `https://localhost/rag-docs` | Swagger UI interattivo |
| RAG Health | `https://localhost/api/rag/health` | Status Ollama + Qdrant |

---

## Comandi principali (Makefile)

### 🚀 Gestione Stack e Console
| Comando | Descrizione |
|---------|-------------|
| `make up-gpu` | Avvia lo stack in modalità FULL (GPU NVIDIA richiesta) |
| `make up-lite` | Avvia lo stack in modalità LITE (CPU-only) |
| `make rebuild-console` | Ricompila e riavvia la Document Console (React) |
| `make open-console` | Apre la console nel browser predefinito |
| `make logs-console` | Mostra i log del container della console |
| `make down` | Ferma tutti i servizi |
| `make reload-nginx` | Ricarica la configurazione di Nginx |

### 📁 Documenti e RAG Avanzato
| Comando | Descrizione |
|---------|-------------|
| `make upload-doc FILE=...` | Carica e indicizza un file (es. `FILE=./doc.pdf`) |
| `make list-docs` | Elenca i documenti presenti nell'indice vettoriale |
| `make wipe-rag` | ⚠️ **Svuota completamente il RAG** (indice + file fisici) |
| `make test-chat` | Invia una query di test al RAG via CLI |
| `make health` | Esegue un controllo di salute su tutti i servizi |

### 🤖 Gestione Modelli LLM
| Comando | Descrizione |
|---------|-------------|
| `make list-models` | Elenca tutti i modelli scaricati localmente |
| `make pull-model MODEL=...` | Scarica un modello specifico (es. `MODEL=llama3`) |
| `make active-model` | Mostra il modello attualmente in memoria |

---

## Document Management Console

La nuova console React (`/console/`) permette una gestione granulare della knowledge base aziendale:
- **Domini Multipli:** Organizza i documenti in collezioni Qdrant separate (es. "Legal", "HR", "Technical").
- **Monitoraggio:** Visualizza il numero di frammenti (chunk) estratti per ogni documento.
- **Manutenzione:** Re-indicizzazione forzata (utile se cambi modello di embedding) e spostamento documenti tra domini.
- **Branding:** Interfaccia professionale coerente con l'identità visiva del progetto.

---

## API Reference

Il RAG backend espone endpoint avanzati per la gestione dei domini. Documentazione su `https://localhost/rag-docs`.

| Metodo | Path | Descrizione |
|--------|------|-------------|
| `GET` | `/api/domains` | Elenca tutti i domini e statistiche vettoriali |
| `POST` | `/api/domains` | Crea un nuovo dominio informativo |
| `DELETE` | `/api/domains/{name}` | Elimina un dominio e tutti i suoi dati |
| `POST` | `/api/documents/upload` | Upload e indicizzazione documento |
| `PUT` | `/api/documents/{id}/domain` | Sposta un documento tra domini |
| `POST` | `/api/documents/{id}/reindex` | Forza la re-indicizzazione di un file |
| `POST` | `/api/chat` | Query RAG nativa con fonti |

---

## Configurazione `.env`

Aggiunta sezione per la console:
```env
# URL base per le chiamate API dalla console verso il RAG backend
CONSOLE_RAG_API_BASE=/api/rag
```

---

## Licenza

Questo progetto è distribuito sotto licenza **MIT**. I componenti inclusi mantengono le proprie licenze originali (Ollama: MIT, Qdrant: Apache 2.0, Open WebUI: MIT).

---

## Crediti

Stack assembrato e documentato per la **massima privacy aziendale**.
Documentazione tecnica completa disponibile nella cartella `/docs`.
