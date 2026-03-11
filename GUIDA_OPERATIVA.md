# 🛠️ Guida Operativa per Amministratori — Private Corporate AI

Questa guida è destinata agli amministratori di sistema per l'installazione, la configurazione, il monitoraggio e la manutenzione dello stack **Private Corporate AI**.

---

## 📋 Indice
1. [Architettura Tecnica](#1-architettura-tecnica)
2. [Installazione e Setup](#2-installazione-e-setup)
3. [Verifica Post-Installazione](#3-verifica-post-installazione)
4. [Gestione dei Modelli (Ollama)](#4-gestione-dei-modelli-ollama)
5. [Gestione Documenti e RAG](#5-gestione-documenti-e-rag)
6. [Monitoraggio e Log](#6-monitoraggio-e-log)
7. [Manutenzione e Sicurezza](#7-manutenzione-e-sicurezza)
8. [Risoluzione dei Problemi (Troubleshooting)](#8-risoluzione-dei-problemi-troubleshooting)

---

## 1. Architettura Tecnica

Lo stack è composto da container Docker orchestrati via `docker-compose`:
- **Nginx:** Reverse proxy con SSL self-signed e rate limiting.
- **Open WebUI:** Interfaccia chat per l'utente finale (Porta 80/443 via Nginx).
- **RAG Backend (FastAPI):** Orchestratore della pipeline RAG e gestione documenti.
- **Ollama:** Motore di inferenza per LLM ed Embedding (supporta CPU e GPU).
- **Qdrant:** Vector Database per l'indicizzazione semantica.
- **Console (React):** Interfaccia amministrativa per la gestione dei domini e documenti.

---

## 2. Installazione e Setup

### 2.1 Installazione Automatica (Consigliata)
Lo script `install.sh` rileva l'hardware e configura automaticamente le dipendenze (Docker, NVIDIA Toolkit).

```bash
# Esecuzione interattiva
sudo ./install.sh

# Oppure forza una modalità specifica
sudo ./install.sh --gpu  # Modalità FULL (GPU NVIDIA)
sudo ./install.sh --cpu  # Modalità LITE (Solo CPU)
```

> **Nota Tecnica:** Il comando `make install` (che richiama `install.sh`) è **idempotente**. Se il sistema è già configurato, non sovrascrive i volumi dati esistenti e non riscarica i modelli LLM se già presenti (a meno di cambi espliciti nel `.env`).

### 2.2 Variabili d'Ambiente (.env)
Il file `.env` contiene le configurazioni critiche. Parametri principali:
- `DEPLOY_MODE`: `gpu` o `cpu`.
- `LLM_MODEL`: Nome del modello Ollama (es: `gemma2:9b`).
- `EMBEDDING_MODEL`: Modello per i vettori (default: `nomic-embed-text`).
- `QDRANT_API_KEY`: Chiave generata automaticamente per la sicurezza del DB.

---

## 3. Verifica Post-Installazione

Dopo l'avvio, è fondamentale verificare che tutti i componenti comunichino correttamente.

### 3.1 Stato dei Container
```bash
make status
```
*Tutti i container devono risultare in stato `Up` (o `Up (healthy)`).*

### 3.2 Healthcheck dell'API RAG
```bash
make health
```
Questo comando interroga il backend e verifica la connessione con Ollama e Qdrant.

### 3.3 Test di Inferenza (Chat)
Verifica che il modello risponda correttamente alle query:
```bash
make test-chat
```

---

## 4. Gestione dei Modelli (Ollama)

### 4.1 Persistenza e Inizializzazione
I modelli LLM sono memorizzati nel volume Docker **`ollama_data`** (percorso interno `/root/.ollama`). 

Al primo avvio (o dopo un rebuild), il container di servizio **`ollama_init`** esegue il comando `ollama pull` per i modelli definiti nel `.env` (`LLM_MODEL` e `EMBEDDING_MODEL`). 

**Caratteristiche del processo:**
- **Nessun Riscaricamento Inutile:** Grazie all'uso dei volumi, i modelli sopravvivono al riavvio dei container, all'aggiornamento del codice e alla reinstallazione.
- **Verifica Intelligente:** Il comando `ollama pull` verifica l'integrità dei file esistenti (tramite SHA256) e scarica solo i layer mancanti o aggiornati.
- **Isolamento:** Il container `ollama_init` termina automaticamente con successo dopo aver garantito la presenza dei modelli, senza consumare ulteriori risorse.

Monitora il progresso con:
```bash
make logs-init
```

### 4.2 Gestione Manuale dei Modelli
```bash
make list-models         # Elenca i modelli scaricati
make active-model        # Mostra il modello attualmente in RAM/VRAM
make pull-model MODEL=llama3:8b  # Scarica un nuovo modello
```

---

## 5. Gestione Documenti e RAG

### 5.1 Indicizzazione di un Documento via CLI
```bash
make upload-doc FILE=/path/to/document.pdf
```

### 5.2 Elenco Documenti Indicizzati
```bash
make list-docs
```

### 5.3 Pulizia Totale dei Dati RAG
```bash
make wipe-rag
```
*Attenzione: questo comando elimina tutti i vettori e i documenti caricati.*

---

## 6. Monitoraggio e Log

### 6.1 Analisi dei Log
I log sono fondamentali per diagnosticare errori di timeout o di memoria.
```bash
make logs             # Log globali (tutti i servizi)
make logs-rag         # Log specifici della pipeline RAG
make logs-ollama      # Log del motore AI
make logs-nginx       # Log degli accessi web e sicurezza
```

### 6.2 Monitoraggio Risorse
```bash
make monitor          # Dashboard in tempo reale (CPU/RAM/Network)
make gpu-monitor      # Monitoraggio specifico per GPU NVIDIA (VRAM/Temp)
```

---

## 7. Manutenzione e Sicurezza

### 7.1 Backup dei Dati
Il comando crea un archivio compresso di tutti i volumi Docker (DB, documenti, modelli) e del file `.env`.
```bash
make backup
```

### 7.2 Aggiornamento Configurazione Cliente
Per cambiare branding o system prompt senza reinstallare:
```bash
make reconfigure-client
```

### 7.3 Sicurezza Rete
Assicurarsi che le porte interne (6333, 11434, 8000) non siano esposte all'esterno. Solo le porte 80 e 443 devono essere accessibili.
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## 8. Risoluzione dei Problemi (Troubleshooting)

### 8.1 Timeout nelle risposte (Modalità LITE)
In modalità CPU, la prima risposta può essere lenta. 
- **Soluzione:** Verifica il numero di thread assegnati nel `.env` (`OLLAMA_CPU_THREADS`). Deve corrispondere ai core FISICI del server.

### 8.2 Errori "Out of Memory" (OOM)
- **Soluzione:** Se la RAM è insufficiente, usa modelli più piccoli (es. `phi3:mini` invece di `gemma2:9b`) o aumenta il limite di memoria nel file `docker-compose.lite.yaml`.

### 8.3 Qdrant non si avvia o è in "Unhealthy"
- **Soluzione:** Controlla i permessi della cartella `qdrant_data/` o prova a reinizializzare la collezione:
```bash
make init-collection
```

---
*Documentazione Amministrativa v1.1.0 — Private Corporate AI*
