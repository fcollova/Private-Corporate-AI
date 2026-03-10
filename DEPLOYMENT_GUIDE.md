# 🏢 Private Corporate AI — Guida al Deploy
### Stack: Ollama + Qdrant + RAG Backend + Open WebUI + Nginx
**Target:** Ubuntu Server 22.04/24.04 LTS

---

## 📋 Indice

1. [Modalità di Deploy](#1-modalità-di-deploy)
2. [Prerequisiti Hardware](#2-prerequisiti-hardware)
3. [Installazione Driver NVIDIA (solo GPU)](#3-installazione-driver-nvidia-solo-gpu)
4. [Installazione Docker](#4-installazione-docker)
5. [NVIDIA Container Toolkit (solo GPU)](#5-nvidia-container-toolkit-solo-gpu)
6. [Configurazione Progetto](#6-configurazione-progetto)
7. [Scelta del Modello LLM](#7-scelta-del-modello-llm)
8. [Avvio Modalità FULL (GPU)](#8-avvio-modalità-full-gpu)
9. [Avvio Modalità LITE (CPU-only)](#9-avvio-modalità-lite-cpu-only)
10. [Verifica e Test](#10-verifica-e-test)
11. [Operazioni Comuni](#11-operazioni-comuni)
12. [Monitoring](#12-monitoring)
13. [Sicurezza in Produzione](#13-sicurezza-in-produzione)
14. [Document Console](#14-document-console)
15. [Personalizzazione Cliente](#15-personalizzazione-cliente)
16. [Troubleshooting](#16-troubleshooting)

---

## 1. Modalità di Deploy

Il boilerplate supporta due modalità di esecuzione selezionabili tramite variabili d'ambiente e file Compose:

| | Modalità FULL (GPU) | Modalità LITE (CPU-only) |
|---|---|---|
| **Hardware** | GPU NVIDIA (16-24GB VRAM) | Solo CPU + RAM |
| **Velocità risposta** | 2–15 secondi | 30–180 secondi |
| **Qualità modelli** | Alta (7-14B parametri) | Media (2-7B quantizzati) |
| **RAM richiesta** | 32+ GB | 8-16 GB |
| **Comando avvio** | `make up-gpu` | `make up-lite` |
| **Compose files** | `docker-compose.yaml` | `docker-compose.yaml` + `docker-compose.lite.yaml` |
| **NVIDIA Toolkit** | ✅ Richiesto | ❌ Non necessario |

> **Consiglio:** La modalità LITE è ideale per ambienti di sviluppo, test, server cloud economici (es. VPS 16GB RAM), o qualsiasi server privo di GPU dedicata.

---

## 2. Prerequisiti Hardware

### Modalità FULL (GPU)

| Componente | Minimo | Consigliato |
|---|---|---|
| **CPU** | 8 core | 16+ core |
| **RAM** | 32 GB | 64 GB |
| **GPU VRAM** | 16 GB (RTX 3090) | 24 GB (RTX 4090) |
| **Storage** | 200 GB SSD | 500 GB NVMe |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |

### Modalità LITE (CPU-only)

| Componente | Minimo | Consigliato |
|---|---|---|
| **CPU** | 4 core (x86_64 con AVX2) | 8-16 core |
| **RAM** | 8 GB | 16-32 GB |
| **GPU** | ❌ Non richiesta | — |
| **Storage** | 50 GB SSD | 200 GB SSD |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |

> **Nota AVX2:** Ollama usa istruzioni AVX2 per accelerare l'inferenza CPU. Verifica con: `grep avx2 /proc/cpuinfo | head -1` — qualsiasi CPU moderna (post-2013) le supporta.

---

## 3. Installazione Driver NVIDIA (solo GPU)

> ⏭️ **Salta questa sezione se usi la modalità LITE (CPU-only)**

```bash
sudo apt update && sudo apt upgrade -y
sudo ubuntu-drivers autoinstall
sudo reboot

# Verifica dopo il riavvio
nvidia-smi
```

---

## 4. Installazione Docker

```bash
# Installa Docker Engine + Compose Plugin
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER && newgrp docker

# Verifica
docker --version
docker compose version
```

---

## 5. NVIDIA Container Toolkit (solo GPU)

> ⏭️ **Salta questa sezione se usi la modalità LITE (CPU-only)**

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update && sudo apt install nvidia-container-toolkit -y
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Test GPU nel container
docker run --rm --gpus all nvidia/cuda:12.3.0-base-ubuntu22.04 nvidia-smi
```

---

## 6. Configurazione Progetto

```bash
# Setup iniziale (crea .env e certificati SSL self-signed)
make setup

# Apri .env e personalizza OBBLIGATORIAMENTE:
#   1. LLM_MODEL       → scegli il modello (vedi sezione 7)
#   2. DEPLOY_MODE     → "gpu" o "cpu"
#   3. Tutte le PASSWORD (QDRANT_API_KEY, WEBUI_SECRET_KEY)
nano .env
```

---

## 7. Scelta del Modello LLM

### Modalità FULL (GPU — 16-24GB VRAM)

```bash
# Nel file .env:
DEPLOY_MODE=gpu
LLM_MODEL=gemma2:9b           # Consigliato: ottimo ITA/ENG, VRAM ~8GB
# LLM_MODEL=deepseek-r1:14b   # Alternativa: ragionamento avanzato, VRAM ~12GB
# LLM_MODEL=mistral:7b        # Leggero e veloce, VRAM ~6GB
```

### Modalità LITE (CPU-only)

I modelli **quantizzati a 4-bit (q4_K_M)** sono fondamentali in modalità LITE: offrono ~97% della qualità originale con il 60% di RAM in meno e velocità significativamente maggiore.

```bash
# Nel file .env:
DEPLOY_MODE=cpu

# Scegli in base alla RAM disponibile:
LLM_MODEL=phi3:mini                      # RAM ~2.3 GB — sviluppo/test
# LLM_MODEL=gemma2:2b                    # RAM ~1.6 GB — ultra-compatto
# LLM_MODEL=llama3.2:3b                  # RAM ~2.0 GB — Meta, bilanciato
# LLM_MODEL=mistral:7b-instruct-q4_K_M   # RAM ~4.1 GB — migliore qualità
# LLM_MODEL=qwen2.5:7b-instruct-q4_K_M   # RAM ~4.4 GB — top per ITA/ENG

# Parametri ottimizzati per CPU (già impostati dall'override LITE):
LLM_CONTEXT_WINDOW=2048    # Ridotto per risparmiare RAM
CHUNK_SIZE=700             # Chunk più piccoli → query più veloci
TOP_K_RESULTS=3            # Meno chunk → risposta più rapida
```

**Tabella comparativa modelli CPU-only:**

| Modello | RAM | Qualità ITA | Token/s (8-core) | Note |
|---|---|---|---|---|
| `gemma2:2b` | ~1.6 GB | ⭐⭐⭐ | ~8 tok/s | Ultra-compatto |
| `phi3:mini` | ~2.3 GB | ⭐⭐⭐ | ~6 tok/s | Microsoft, rapido |
| `llama3.2:3b` | ~2.0 GB | ⭐⭐⭐ | ~7 tok/s | Meta, bilanciato |
| `mistral:7b-instruct-q4_K_M` | ~4.1 GB | ⭐⭐⭐⭐ | ~3 tok/s | **Consigliato** |
| `qwen2.5:7b-instruct-q4_K_M` | ~4.4 GB | ⭐⭐⭐⭐⭐ | ~3 tok/s | **Top per ITA** |

---

## 8. Avvio Modalità FULL (GPU)

```bash
# Build + avvio (prima volta)
make up-gpu

# Monitora il download dei modelli (può richiedere 5-30 min)
make logs-init

# Verifica stato servizi
make status
```

---

## 9. Avvio Modalità LITE (CPU-only)

```bash
# Assicurati che DEPLOY_MODE=cpu nel .env
# e che LLM_MODEL sia un modello leggero/quantizzato

# Build + avvio in modalità LITE
make up-lite

# Monitora il download dei modelli
make logs-init

# Verifica stato servizi
make status

# Test: la prima query potrebbe richiedere 1-3 minuti (normale)
make test-chat
```

### Ottimizzazioni specifiche per CPU

```bash
# Forza Ollama ad usare un numero specifico di thread
# Imposta nel .env al numero di core FISICI (non logici)
OLLAMA_CPU_THREADS=8   # Es: su server 16-thread (8 core fisici)

# Verifica quanti core fisici hai:
lscpu | grep "Core(s) per socket"

# Monitor utilizzo CPU durante l'inferenza:
htop   # oppure: watch -n 1 "mpstat 1 1"
```

### Limiti di memoria configurabili

Il file `docker-compose.lite.yaml` imposta limiti di memoria per ogni servizio. Personalizzali in base alla RAM disponibile:

```yaml
# In docker-compose.lite.yaml, servizio ollama:
deploy:
  resources:
    limits:
      memory: 8g    # Adegua alla dimensione del modello + 2GB overhead
                    # phi3:mini  → 4g
                    # mistral-q4 → 7g
                    # qwen2.5-q4 → 7g
```

---

## 10. Verifica e Test

```bash
# Healthcheck completo (mostra anche deploy_mode)
make health

# Output atteso in modalità LITE:
# {
#   "status": "healthy",
#   "deploy_mode": "cpu",
#   "ollama_connected": true,
#   "qdrant_connected": true,
#   "model_loaded": "mistral:7b-instruct-q4_K_M",
#   "timeout_seconds": 300
# }

# Test upload documento
curl -k -X POST https://localhost/api/rag/documents/upload \
  -F "file=@/path/al/tuo/documento.pdf"

# Test query RAG
make test-chat

# Accesso Web
# https://localhost → Open WebUI
# https://localhost/rag-docs → Swagger API
```

---

## 11. Operazioni Comuni

```bash
make logs          # Log tutti i servizi
make logs-rag      # Log pipeline RAG
make logs-ollama   # Log inferenza LLM
make list-models   # Lista modelli installati
make list-docs     # Lista documenti indicizzati
make backup        # Backup dati
make status        # Stato container

# Cambiare modello in modalità LITE senza riavvio completo:
# 1. Modifica LLM_MODEL nel .env
# 2. make up-lite  (Docker riapplica solo le diff)
```

---

## 12. Monitoring

```bash
# Metriche Prometheus
curl -k https://localhost/rag-metrics

# Modalità GPU: monitor VRAM
make gpu-monitor

# Modalità LITE: monitor CPU e RAM
htop
watch -n 2 'free -h && echo "---" && docker stats --no-stream'
```

---

## 13. Sicurezza in Produzione

```bash
make setup         # Crea .env e certificati iniziali

# Checklist obbligatoria:
# 1. Cambia TUTTE le password nel .env
# 2. Configura UFW (sia GPU che LITE)
sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
sudo ufw deny 6333/tcp && sudo ufw deny 11434/tcp
sudo ufw deny 8000/tcp && sudo ufw deny 8080/tcp
sudo ufw enable

# 3. Per produzione: usa Let's Encrypt (non self-signed)
sudo certbot certonly --standalone -d ai.tuaazienda.com
sudo cp /etc/letsencrypt/live/ai.tuaazienda.com/fullchain.pem nginx/ssl/server.crt
sudo cp /etc/letsencrypt/live/ai.tuaazienda.com/privkey.pem nginx/ssl/server.key
```

---

## 14. Document Console

La **Document Management Console** è un'interfaccia React dedicata per la gestione avanzata della knowledge base.

- **URL:** `https://localhost/console/`
- **Funzionalità:**
  - Visualizzazione di tutti i **domini** (collezioni Qdrant) e relative statistiche.
  - Creazione ed eliminazione di nuovi domini informativi.
  - Elenco dettagliato dei documenti per dominio.
  - **Spostamento** di documenti tra domini diversi.
  - **Re-indicizzazione** forzata di documenti esistenti.
  - Upload di nuovi documenti con selezione del dominio target.

### Gestione Domini (Collezioni)
La console permette di creare domini logici separati (es: `legale`, `hr`, `tecnico`). Solo i caratteri `[a-zA-Z0-9_-]` sono ammessi per i nomi dei domini, con una lunghezza massima di 64 caratteri.

> **⚠️ Attenzione:** L'eliminazione di un dominio rimuove permanentemente tutti i punti vettoriali indicizzati in esso. Questa operazione non è reversibile.

### Re-indicizzazione
Utile se viene cambiato il modello di embedding (`EMBEDDING_MODEL` nel `.env`). La re-indicizzazione ricarica il file originale dalla cartella `uploads/` e rigenera i vettori.

---

## 15. Personalizzazione Cliente

Lo script `install.sh` include una fase di **Personalizzazione Cliente** (`collect_client_profile()`) che permette di adattare lo stack all'identità e alle esigenze specifiche del cliente finale durante il primo setup.

### Artefatti Generati
Il processo di setup crea i seguenti file nella directory `branding/` e `rag_backend/`:

*   `branding/client.json`: Registro tecnico dell'installazione (azienda, contatti, moduli attivi).
*   `branding/banner.txt`: Banner ASCII personalizzato che compare ad ogni avvio dell'installer.
*   `branding/theme.css`: CSS personalizzato applicato a Open WebUI per riflettere i colori aziendali.
*   `rag_backend/system_prompt.txt`: Il prompt di sistema che definisce il comportamento dell'AI (es. "Sei l'assistente di Azienda S.r.l.").

### Operazioni Post-Installazione

#### Modificare il System Prompt
Se desideri affinare il comportamento del modello dopo l'installazione:
1. Modifica il file `rag_backend/system_prompt.txt`.
2. Riavvia il backend: `make rebuild-rag` (o `make restart-lite`).
3. Oppure usa il comando rapido: `make edit-system-prompt`.

#### Riconfigurare il Profilo Cliente
Per cambiare nome azienda, email di riferimento o tema colori senza reinstallare lo stack Docker:
```bash
sudo ./install.sh --reconfigure-client
# Oppure via Makefile:
make reconfigure-client
```

#### Esportare la Configurazione
Per creare un pacchetto di backup della sola personalizzazione cliente (utile per replicare il setup su un server di disaster recovery):
```bash
make export-client-config
```

---

## 16. Troubleshooting

### Modalità LITE — Problemi comuni

| Problema | Soluzione |
|---|---|
| Risposta LLM in timeout (>300s) | Usa modello più piccolo (phi3:mini, gemma2:2b) o riduci TOP_K_RESULTS=2 |
| OOM killer uccide Ollama | Aumenta `memory: Xg` in docker-compose.lite.yaml o scegli modello più piccolo |
| CPU al 100% in stallo | Limita OLLAMA_CPU_THREADS al numero di core fisici |
| Modello non trovato | `make list-models` poi `docker compose exec ollama ollama pull <model>` |
| AVX non supportato | Controlla `grep avx2 /proc/cpuinfo` — CPU troppo vecchia se assente |

### Modalità FULL — Problemi comuni

| Problema | Soluzione |
|---|---|
| GPU non rilevata | `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker` |
| CUDA out of memory | Scegli modello più piccolo o aumenta quantizzazione (es: :q4_K_M) |
| Modello non scaricato | `make pull-models-gpu` |

---

*Private Corporate AI — Documentazione v1.1.0 — Aggiornato con Modalità LITE (CPU-only)*
