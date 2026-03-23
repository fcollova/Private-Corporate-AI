# 🔒 Private Corporate AI

> **L'intelligenza artificiale generativa che non lascia mai il tuo server.**

Uno stack completo, production-ready e 100% open source per portare LLM e RAG (*Retrieval-Augmented Generation*) **dentro** la tua infrastruttura aziendale. Zero dati verso server esterni. Zero dipendenze da vendor cloud. Piena conformità GDPR.

> ⚠️ **Stato: Sviluppo Attivo — v0.2.0**  
> Questo progetto è in sviluppo attivo. API e configurazioni potrebbero cambiare tra una release e l'altra. Consulta [ROADMAP.md](./ROADMAP.md) per la pianificazione delle funzionalità.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Version](https://img.shields.io/badge/versione-0.2.0-orange.svg)](./Release.txt)
[![Status](https://img.shields.io/badge/stato-sviluppo%20attivo-yellow.svg)]()
[![Docker](https://img.shields.io/badge/Docker-Compose_v3.9-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi)](https://fastapi.tiangolo.com/)

**Autore:** Francesco Collovà

---

> 🇬🇧 **English version:** [README.md](./README.md)

---

## Indice

- [Perché questo progetto](#-perché-questo-progetto)
- [Conformità EU AI Act](#-conformità-eu-ai-act)
- [Architettura](#️-architettura)
- [Pipeline RAG Avanzata](#-pipeline-rag-avanzata)
- [Stack Tecnologico](#️-stack-tecnologico)
- [Requisiti](#-requisiti)
- [Installazione Rapida](#-installazione-rapida)
- [Accesso all'Interfaccia](#-accesso-allinterfaccia)
- [Comandi Makefile](#️-comandi-makefile)
- [Document Management Console](#-document-management-console)
- [API Reference](#-api-reference)
- [Configurazione](#️-configurazione)
- [Roadmap](#️-roadmap)
- [Licenza](#-licenza)

---

## 💡 Perché questo progetto

Ogni prompt inviato a un servizio AI cloud attraversa reti esterne, viene loggato e potenzialmente usato per addestrare modelli futuri. Per contratti riservati, strategie di prodotto, dati HR, codice proprietario — questo è inaccettabile.

**Private Corporate AI** risolve il problema alla radice: l'intero stack gira localmente. Il prompt nasce sul browser dell'utente, attraversa Nginx, viene elaborato dai container Docker, raggiunge il modello LLM — e la risposta percorre il cammino inverso. **In nessun momento un byte lascia il perimetro aziendale.**

Oltre alla privacy, questo progetto nasce per rispondere alla crescente necessità di **conformità normativa**, in particolare rispetto al nuovo **Regolamento UE sull'Intelligenza Artificiale (EU AI Act)**, garantendo alle aziende uno strumento potente ma sicuro e verificabile.

---

## 🇪🇺 Conformità EU AI Act

### Vantaggi Strutturali di Conformità

L'architettura on-premise offre vantaggi di conformità che i sistemi AI cloud-based non possono garantire con la stessa semplicità:

| Requisito | Come Private Corporate AI lo soddisfa |
|---|---|
| **Sovranità del Dato** | Nessun dato aziendale lascia i server dell'organizzazione. Elimina alla radice i problemi di trasferimento dati verso provider GPAI cloud (GPT-4, Gemini, ecc.), soggetti agli obblighi dell'Art. 53. |
| **Human Oversight by Design** | Ogni risposta del sistema cita le fonti documentali verificabili. Il sistema genera output consultivi, non decisioni autonome (Art. 14). |
| **Cybersecurity Integrata** | SSL/TLS, reti Docker isolate, credenziali generate casualmente ad ogni installazione — base per i requisiti dell'Art. 15. |
| **Tracciabilità Documentale** | Ogni documento indicizzato è identificabile con ID univoco, timestamp e metadati — base per il record-keeping richiesto dall'Art. 12. |
| **Trasparenza** | *(Roadmap Phase 1)* Disclaimer di trasparenza AI e modulo di AI literacy per gli utenti finali (Art. 4 & 50). |

### ⚠️ Scenari ad Alto Rischio

Il profilo di rischio cambia se il sistema viene utilizzato per:
- Decisioni su personale, selezione o valutazione dei dipendenti
- Valutazioni creditizie o assicurative
- Contesti di Pubblica Amministrazione

In questi scenari sono richieste misure di conformità aggiuntive. Consulta il [documento di analisi EU AI Act](./doc/private-corporate-ai-EU-AIAct-analisi.pdf) per una valutazione dettagliata.

---

## 🏗️ Architettura

```
                    ┌─────────────────────────────────────────────────┐
    Browser  ──────▶│  NGINX  (SSL · Rate Limit · Security Headers)   │
    HTTPS           └──────────────┬───────────────────────────────────┘
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

La separazione in due reti garantisce che il motore di inferenza LLM e il database vettoriale non siano mai direttamente raggiungibili dal layer browser, riducendo la superficie di attacco.

---

## ⚡ RAG Backend Highlights (v0.2.0)

Il backend è stato riprogettato per garantire stabilità e prestazioni di livello corporate:

- **Metadata Store Persistente**: Utilizza **SQLite/SQLAlchemy** per tracciare il ciclo di vita dei documenti, garantendo la persistenza dello stato anche dopo il riavvio.
- **De-duplicazione Contenuti**: L'hashing automatico **SHA-256** previene l'indicizzazione ridondante degli stessi file.
- **Ingestion Parallela**: L'elaborazione batch asincrona velocizza l'indicizzazione dei documenti fino al **75%**.
- **Cache Embedding su Redis**: Integrazione di **Redis** per memorizzare gli embedding vettoriali, riducendo latenza e carico LLM per query ripetute.
- **SSE Streaming**: Generazione delle risposte in tempo reale tramite **Server-Sent Events** per un'esperienza chat fluida e reattiva.

---

## 🧠 Pipeline RAG Avanzata

A differenza dei sistemi RAG tradizionali, **Private Corporate AI** implementa due tecniche all'avanguardia per massimizzare la precisione delle risposte:

### 1. Contextual Retrieval
Per ogni frammento di testo (chunk), l'LLM locale genera automaticamente un breve prefisso di contesto basato sull'intero documento. Questo previene la perdita di significato quando un chunk viene recuperato isolatamente (es. una tabella senza l'intestazione del capitolo di appartenenza).

### 2. Hybrid Search (Dense + Sparse)
Il sistema combina:
- **Ricerca vettoriale semantica** — trova contenuti concettualmente correlati
- **Ricerca testuale BM25** — intercetta codici esatti, acronimi e termini specifici

I risultati sono fusi tramite **Reciprocal Rank Fusion (RRF)**, garantendo una **recall superiore del 30–40%** su documenti tecnici aziendali rispetto alla sola ricerca semantica.

---

## 🛠️ Stack Tecnologico

| Container | Immagine | Ruolo | Licenza |
|-----------|----------|-------|---------|
| `corporate_ai_nginx` | `nginx:1.27.4-alpine` | Reverse proxy SSL/TLS, rate limiting, security headers | BSD |
| `corporate_ai_webui` | `ghcr.io/open-webui/open-webui:v0.8.8` | Interfaccia chat web, gestione conversazioni | MIT |
| `corporate_ai_console` | `node:20-alpine` | **Document Management Console** (React + Vite) | MIT |
| `corporate_ai_rag` | *Custom build* | FastAPI + LangChain, pipeline RAG, Estrazione avanzata tabelle PDF (**PyMuPDF4LLM**), API OpenAI-compatibile | Apache 2.0 |
| `corporate_ai_redis` | `redis:7.4.2-alpine` | **Cache Embedding e Query** | MIT |
| `corporate_ai_ollama` | `ollama/ollama:0.17.7` | Runtime LLM locale, supporto CPU e GPU NVIDIA | MIT |
| `corporate_ai_qdrant` | `qdrant/qdrant:v1.17.0` | Vector database, Hybrid Search (Dense + Sparse/BM25) con RRF | Apache 2.0 |
| `corporate_ai_ollama_init` | `ollama/ollama` | Init one-shot: scarica LLM e modello embedding al primo avvio | MIT |

---

## 📋 Requisiti

### Modalità FULL (GPU — Consigliata)

| Componente | Minimo | Consigliato |
|------------|--------|-------------|
| GPU NVIDIA | 8 GB VRAM | 16–24 GB VRAM (RTX 3090/4090) |
| RAM | 16 GB | 32–64 GB |
| Disco | 50 GB | 200–500 GB NVMe |
| OS | Linux / WSL2 | Ubuntu 22.04+ LTS |
| Tempo risposta | — | 2–15 secondi |

### Modalità LITE (Solo CPU — Nessuna GPU Richiesta)

| Componente | Minimo | Consigliato |
|------------|--------|-------------|
| CPU | 4 core (x86_64 con AVX2) | 8–16 core |
| RAM | 8 GB | 16–32 GB |
| Disco | 30 GB | 60–200 GB SSD |
| OS | Linux / WSL2 | Ubuntu 22.04+ LTS |
| Tempo risposta | — | 30–180 secondi |

> **Nota AVX2:** Ollama usa istruzioni AVX2 per accelerare l'inferenza CPU. Verifica con: `grep avx2 /proc/cpuinfo | head -1` — qualsiasi CPU moderna (post-2013) le supporta.

### 🖥️ Utenti Windows (WSL2)
Se stai installando Private Corporate AI su **Windows tramite WSL2**, leggi attentamente la **[Sezione Setup WSL2](./DEPLOYMENT_GUIDE.md#2b-wsl2-windows-subsystem-for-linux-setup)** nella Guida al Deploy. Contiene informazioni fondamentali su integrazione Docker Desktop, configurazione GPU e performance del file system.

---

## 🚀 Installazione Rapida

L'installazione è completamente automatizzata tramite uno script interattivo che configura l'intero ambiente (Docker, modelli, database, certificati) in base all'hardware rilevato.

### 1. Clona ed Esegui l'Installer

```bash
git clone https://github.com/<your-org>/private-corporate-ai.git
cd private-corporate-ai
chmod +x install.sh
sudo ./install.sh
```

> Sono supportati anche flag per installazioni non interattive: `./install.sh --gpu` oppure `./install.sh --cpu`

### 2. Passaggi della Procedura Guidata

L'installer ti guiderà attraverso:

1. **Rilevamento Hardware** — Analisi automatica di CPU, RAM e GPU NVIDIA
2. **Scelta Modalità** — Selezione tra **FULL (GPU)** per massime prestazioni o **LITE (CPU)** per server senza GPU
3. **Selezione Modello LLM** — Scelta del modello ottimale (es. Gemma 2, Llama 3.1, DeepSeek-R1)
4. **Personalizzazione Cliente** — Inserimento del nome azienda e scelta del tema colore per il branding
5. **Generazione Credenziali** — Creazione automatica di chiavi segrete univoche e certificati SSL self-signed

### 3. Monitoraggio dell'Installazione

L'installazione richiede solitamente dai 5 ai 15 minuti, principalmente per il download dei modelli LLM (diversi GB).

```bash
# Monitora il download iniziale dei modelli
make logs-init

# Monitora le risorse di sistema durante la build
make monitor
```

### 4. Verifica Finale

```bash
# Controlla lo stato di salute di tutti i servizi
make health

# Invia una domanda di test al RAG
make test-chat
```

Poi naviga su `https://localhost`. Accetta l'avviso di sicurezza (certificato self-signed) e verifica che appaia la schermata di login di Open WebUI.

---

## 🌐 Accesso all'Interfaccia

Dopo l'avvio (attendere 2–5 minuti per il download dei modelli al primo avvio):

| Servizio | URL | Note |
|----------|-----|------|
| **Open WebUI** | `https://localhost` | Interfaccia chat principale |
| **Document Console** | `https://localhost/console/` | Gestione documenti e domini RAG |
| **RAG API Docs** | `https://localhost/rag-docs` | Swagger UI interattivo |
| **RAG Health** | `https://localhost/api/health` | Status Ollama + Qdrant + Redis |

---

## ⚙️ Comandi Makefile

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
| `make logs-redis` | **NUOVO**: Log della cache Redis |
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
| `make health` | Verifica la connettività tra RAG, Ollama, Qdrant e Redis |
| `make upload-doc FILE=...` | Carica e indicizza un file (PDF, DOCX, TXT, MD, XLSX, PPTX) |
| `make list-docs` | Elenca i documenti indicizzati nel database SQL dei metadati |
| `make test-chat` | Invia una domanda al RAG e ricevi la risposta con fonti |
| `make wipe-rag` | ⚠️ **Svuota il RAG**: cancella vettori, file, database SQL e cache Redis |
| `make init-collection` | Inizializza manualmente la collezione Qdrant |

### 💻 Document Management Console

| Comando | Descrizione |
|---------|-------------|
| `make up-console` | Avvia specificamente il container della Console |
| `make rebuild-console` | Ricompila da zero l'app React (Vite) |
| `make logs-console` | Log del server di sviluppo/produzione console |
| `make open-console` | Apre automaticamente l'URL della console nel browser |

### 🏢 Personalizzazione Cliente

| Comando | Descrizione |
|---------|-------------|
| `make client-info` | Visualizza il profilo aziendale correntemente attivo |
| `make reconfigure-client` | Rilancia il wizard per cambiare loghi e domini |
| `make edit-system-prompt` | Apre l'editor per modificare le "istruzioni" dell'AI |
| `make export-client-config` | Crea un pacchetto `.tar.gz` con tutta la personalizzazione |

### 🛠️ Manutenzione e Sicurezza

| Comando | Descrizione |
|---------|-------------|
| `make backup` | Crea un backup compresso di tutti i volumi Docker (incluso SQL) e `.env` |
| `make uninstall` | Procedura guidata di rimozione sicura dello stack |
| `make help` | Mostra la guida interattiva ai comandi |

---

## 📂 Document Management Console

La console React (`/console/`) permette una gestione avanzata della knowledge base aziendale:

- **Domini Multipli** — Organizza i documenti in collezioni Qdrant separate (es. "Legal", "HR", "Technical")
- **Monitoraggio** — Visualizza il numero di frammenti (chunk) estratti per ogni documento
- **Manutenzione** — Re-indicizzazione forzata e spostamento documenti tra domini
- **Branding Dinamico** — L'interfaccia si adatta automaticamente al nome e ai colori del cliente configurati durante l'installazione

---

## 📡 API Reference

Il RAG backend espone endpoint avanzati per la gestione dei domini. Documentazione interattiva completa disponibile su `https://localhost/rag-docs`.

| Metodo | Path | Descrizione |
|--------|------|-------------|
| `GET` | `/api/domains` | Elenca tutti i domini e statistiche vettoriali |
| `POST` | `/api/domains` | Crea un nuovo dominio informativo |
| `DELETE` | `/api/domains/{name}` | Elimina un dominio e tutti i suoi dati |
| `POST` | `/api/documents/upload` | Upload e indicizzazione documento |
| `PUT` | `/api/documents/{id}/domain` | Sposta un documento tra domini |
| `POST` | `/api/documents/{id}/reindex` | Forza la re-indicizzazione di un file |
| `POST` | `/api/chat` | Query RAG nativa con fonti citate |

### Monitoraggio in tempo reale
La console ora supporta il monitoraggio in tempo reale dell'elaborazione dei documenti:
- **Tracciamento Stato**: Indicatori visivi per gli stati *In elaborazione*, *Indicizzato* ed *Errore*.
- **Polling Automatico**: L'interfaccia si aggiorna automaticamente mentre i documenti vengono indicizzati.
- **Icone Dinamiche**: Identificazione visiva immediata del tipo di file (.pdf, .docx, .xlsx, .pptx, .md).

---

## 🧪 Testing

Il RAG Backend include una suite di test unitari per garantire l'integrità della pipeline di elaborazione dei documenti.

```bash
# Esegui i test (richiede pytest e pytest-asyncio)
pytest rag_backend/tests
```

---

## 🗂️ Configurazione

### File `.env`

Il file `.env` viene generato automaticamente dall'installer. Variabili principali:

```env
# Modello LLM da utilizzare (scaricato automaticamente al primo avvio)
LLM_MODEL=gemma2:9b

# Modello di embedding per l'indicizzazione vettoriale RAG
EMBEDDING_MODEL=nomic-embed-text

# URL base per le chiamate API dalla console verso il RAG backend
CONSOLE_RAG_API_BASE=/api/rag

# Branding aziendale (impostato dal wizard di installazione)
CLIENT_NAME=Nome Azienda
```

Un esempio completo è disponibile in [`.env.example`](./.env.example).

### Personalizzazione del System Prompt

Personalizza il comportamento dell'AI per il tuo dominio specifico:

```bash
make edit-system-prompt
```

Il system prompt è memorizzato in `rag_backend/system_prompt.txt` e controlla come l'LLM risponde alle query: tono, lingua, formato delle citazioni e istruzioni specifiche del dominio.

---

## 🗺️ Roadmap

> Questo è un progetto in sviluppo attivo. La roadmap è guidata dai **requisiti di conformità EU AI Act** (scadenza: agosto 2026) e dalle esigenze di integrazione enterprise.

### Phase 1 — Compliance & Quick Wins *(Mese 1)*
- [x] Supporto loader documenti XLSX e PPTX (via Microsoft MarkItDown)
- [ ] Disclaimer di Trasparenza AI in Open WebUI (Art. 4 & 50 AI Act)
- [ ] Modulo di AI Literacy per l'onboarding degli utenti finali
- [ ] Policy di log retention Docker (persistenza 6 mesi, Art. 12 AI Act)

### Phase 2 — Connectivity & Deep Indexing *(Mesi 2–3)*
- [ ] Pipeline OCR via Tesseract (supporto PDF scansionati e immagini)
- [ ] Connettore di sincronizzazione SharePoint / OneDrive (Microsoft Graph API)
- [ ] Connettore Google Workspace (Service Account)
- [ ] Auto-ingestion da NAS / file server locale via volume Docker
- [ ] Validazione umana dei chunk recuperati nella Document Console (Art. 14 AI Act)

### Phase 3 — Governance & Advanced Audit *(Mesi 4–6)*
- [ ] Versionamento documenti e aggiornamento in-place dell'indice vettoriale
- [ ] Audit trail GDPR-compliant con anonimizzazione automatica dei dati personali (PII)
- [ ] Generazione automatica della Documentazione Tecnica (Allegato IV EU AI Act)
- [ ] Multi-tenancy con permessi granulari per dominio (isolamento HR / Legal / Tech)

Dettagli completi in [ROADMAP.md](./ROADMAP.md).

---

## 📄 Licenza

Questo progetto è distribuito sotto licenza **Apache 2.0**. I componenti inclusi mantengono le proprie licenze originali:

| Componente | Licenza |
|------------|---------|
| Ollama | MIT |
| Qdrant | Apache 2.0 |
| Open WebUI | MIT |
| Nginx | BSD |
| FastAPI | MIT |
| LangChain | MIT |

---

*Costruito con ❤️ per le organizzazioni che fanno della privacy dei dati una priorità.*