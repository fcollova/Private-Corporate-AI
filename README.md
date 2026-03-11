# 🔒 Private Corporate AI

> **L'intelligenza artificiale generativa che non lascia mai il tuo server.**

Uno stack completo, production-ready e 100% open source per portare LLM e RAG (*Retrieval-Augmented Generation*) **dentro** la tua infrastruttura aziendale. Zero dati verso server esterni. Zero dipendenze da vendor cloud. Piena conformità GDPR.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

**Autore:** Francesco Collovà
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
| `corporate_ai_rag` | *Custom build* | FastAPI + LangChain, pipeline RAG, API OpenAI-compatibile | Apache 2.0 |
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

## Prima Installazione

L'installazione è completamente automatizzata tramite uno script interattivo che configura l'intero ambiente (Docker, modelli, database, certificati) in base all'hardware rilevato.

### 1. Avvio dell'Installer
Per iniziare, clona il repository ed esegui lo script principale con privilegi di root:
```bash
chmod +x install.sh
sudo ./install.sh
```
*Lo script supporta anche flag per installazioni non interattive: `./install.sh --gpu` o `./install.sh --cpu`.*

### 2. Passaggi della Procedura Guidata
L'installer ti guiderà attraverso i seguenti step:
1.  **Rilevamento Hardware:** Analisi automatica di CPU, RAM e GPU NVIDIA.
2.  **Scelta Modalità:** Selezione tra **FULL (GPU)** per massime prestazioni o **LITE (CPU)** per server senza GPU.
3.  **Selezione Modello LLM:** Scelta del modello ottimale (es. Gemma 2, Llama 3.1, DeepSeek-R1).
4.  **Personalizzazione Cliente:** Inserimento del nome azienda e scelta del tema colore per il branding dell'interfaccia.
5.  **Generazione Credenziali:** Creazione automatica di chiavi segrete univoche e certificati SSL self-signed.

### 3. Monitoraggio dell'Installazione
L'installazione richiede solitamente dai 5 ai 15 minuti, principalmente per il download dei modelli LLM (diversi GB).

Puoi monitorare l'avanzamento con questi strumenti:
*   **Log di installazione:** Il dettaglio completo è disponibile nel file `install.log`.
*   **Download Modelli:** Per seguire il progresso dello scaricamento iniziale:
    ```bash
    make logs-init
    ```
*   **Risorse di Sistema:** Per monitorare il carico di CPU e RAM durante la build:
    ```bash
    make monitor
    ```

### 4. Verifica Finale
Al termine, lo script mostrerà un riepilogo con gli URL di accesso. Per confermare che tutto sia operativo:

1.  **Healthcheck API:** Esegui `make health`. Dovresti vedere lo stato `healthy` per Ollama, Qdrant e RAG.
2.  **Accesso Web:** Naviga su `https://localhost`. Accetta l'avviso di sicurezza (per via del certificato self-signed) e verifica che appaia la schermata di login di Open WebUI.
3.  **Test di Inferenza:** Verifica che il modello sia pronto a rispondere:
    ```bash
    make test-chat
    ```

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

Lo stack viene gestito interamente tramite `make`. Di seguito l'elenco completo dei comandi suddivisi per categoria.

### 🚀 Gestione Stack
| Comando | Descrizione |
|---------|-------------|
| `make install` | **Installazione interattiva** (rileva hardware, configura GPU o CPU) |
| `make setup` | Setup rapido: crea `.env` e genera certificati SSL self-signed |
| `make up-gpu` | Avvia in modalità **FULL (GPU NVIDIA)** |
| `make up-lite` | Avvia in modalità **LITE (CPU-only)** |
| `make restart-gpu` | Riavvio rapido in modalità FULL |
| `make restart-lite` | Riavvio rapido in modalità LITE |
| `make down` | Ferma tutti i servizi (modalità FULL) |
| `make down-lite` | Ferma tutti i servizi (modalità LITE) |
| `make build` | Ricostruisce l'immagine del RAG Backend |
| `make rebuild-rag` | Ricrea e riavvia solo il RAG Backend (hot-fix) |
| `make reload-nginx` | Verifica e ricarica la configurazione di Nginx |
| `make clean` | ⚠️ **Rimuove tutto**: container, reti e **volumi dati** |

### 📊 Log e Monitoring
| Comando | Descrizione |
|---------|-------------|
| `make status` | Stato di salute e uptime di tutti i container |
| `make logs` | Log combinati di tutti i servizi in tempo reale |
| `make logs-rag` | Log specifici del RAG Backend (FastAPI) |
| `make logs-init` | Monitora il download iniziale dei modelli |
| `make logs-ollama` | Log del motore di inferenza LLM |
| `make monitor` | **Dashboard risorse**: CPU, RAM e Rete in tempo reale |
| `make gpu-monitor` | Monitoraggio VRAM e temperatura GPU (NVIDIA) |
| `make logs-nginx` | Log del reverse proxy e traffico HTTP |
| `make logs-webui` | Log dell'interfaccia chat Open WebUI |

### 🤖 Gestione Modelli LLM
| Comando | Descrizione |
|---------|-------------|
| `make list-models` | Elenca i modelli attualmente installati su Ollama |
| `make active-model` | Mostra quale modello è attualmente caricato in RAM/VRAM |
| `make pull-model MODEL=...` | Scarica un modello specifico (es. `MODEL=llama3:8b`) |
| `make remove-model MODEL=...` | Rimuove un modello dal disco |
| `make pull-models-lite` | Forza il download dei modelli ottimizzati per CPU |

### 📁 Documenti e RAG (CLI)
| Comando | Descrizione |
|---------|-------------|
| `make health` | Verifica la connettività tra RAG, Ollama e Qdrant |
| `make upload-doc FILE=...` | Carica e indicizza un file (PDF, DOCX, TXT, MD) |
| `make list-docs` | Elenca i documenti indicizzati nel database vettoriale |
| `make test-chat` | Invia una domanda al RAG e ricevi la risposta con fonti |
| `make wipe-rag` | ⚠️ **Svuota il RAG**: cancella tutti i vettori e i file caricati |
| `make init-collection` | Inizializza manualmente la collezione Qdrant |

### 💻 Document Management Console
| Comando | Descrizione |
|---------|-------------|
| `make up-console` | Avvia specificamente il container della Console |
| `make rebuild-console` | Ricompila da zero l'app React (Vite) |
| `make logs-console` | Log del server di sviluppo/produzione console |
| `make open-console` | Apre automaticamente l'URL della console nel browser |

### 🏢 Personalizzazione e Cliente
| Comando | Descrizione |
|---------|-------------|
| `make client-info` | Visualizza il profilo aziendale correntemente attivo |
| `make reconfigure-client` | Rilancia il wizard per cambiare loghi e domini |
| `make edit-system-prompt` | Apre l'editor per modificare le "istruzioni" dell'AI |
| `make export-client-config` | Crea un pacchetto `.tar.gz` con tutta la personalizzazione |

### 🛠️ Manutenzione e Sicurezza
| Comando | Descrizione |
|---------|-------------|
| `make backup` | Crea un backup compresso di tutti i volumi Docker e `.env` |
| `make uninstall` | Procedura guidata di rimozione sicura dello stack |
| `make help` | Mostra la guida interattiva ai comandi |

---

## Document Management Console

La console React (`/console/`) permette una gestione avanzata della knowledge base aziendale:
- **Domini Multipli:** Organizza i documenti in collezioni Qdrant separate (es. "Legal", "HR", "Technical").
- **Monitoraggio:** Visualizza il numero di frammenti (chunk) estratti per ogni documento.
- **Manutenzione:** Re-indicizzazione forzata e spostamento documenti tra domini.
- **Branding Dinamico:** L'interfaccia si adatta automaticamente al nome e ai colori del cliente configurati durante l'installazione.

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

## Roadmap Evolutiva

Il progetto segue una roadmap mirata alla **Compliance (EU AI Act)** e alla **Connectivity Enterprise**:
- **Phase 1:** Adeguamento normativo, disclaimer trasparenza e log retention.
- **Phase 2:** Integrazione con SharePoint, Google Workspace e pipeline OCR.
- **Phase 3:** Multi-tenancy avanzata, audit trail GDPR-compliant e versionamento documenti.

Dettagli completi disponibili nel file [ROADMAP.md](./ROADMAP.md).

---

## Licenza

Questo progetto è distribuito sotto licenza **Apache 2.0**. I componenti inclusi mantengono le proprie licenze originali (Ollama: MIT, Qdrant: Apache 2.0, Open WebUI: MIT).

---

## Crediti

Stack assembrato e documentato per la **massima privacy aziendale**.
Documentazione tecnica completa disponibile nella cartella `/docs`.
