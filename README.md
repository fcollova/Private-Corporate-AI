# 🔒 Private Corporate AI

> **Generative AI that never leaves your server.**

A complete, production-ready, 100% open-source stack to deploy LLMs and RAG (*Retrieval-Augmented Generation*) **inside** your corporate infrastructure. Zero data sent to external servers. Zero cloud vendor dependencies. Full GDPR compliance.

> ⚠️ **Status: Active Development — v0.2.0**  
> This project is under active development. APIs and configurations may change between releases. See [ROADMAP.md](./ROADMAP.md) for the planned feature timeline.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Version](https://img.shields.io/badge/version-0.2.0-orange.svg)](./Release.txt)
[![Status](https://img.shields.io/badge/status-active%20development-yellow.svg)]()
[![Docker](https://img.shields.io/badge/Docker-Compose_v3.9-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi)](https://fastapi.tiangolo.com/)

**Author:** Francesco Collovà

---

## 🇮🇹 Italiano | 🇬🇧 English

> 🇮🇹 **Versione italiana disponibile:** [README.it.md](./README.it.md)

The core documentation is bilingual. Technical sections (installation, API reference, configuration) are in English. The full Italian version of this README is available at [`README.it.md`](./README.it.md) — see also [`GUIDA_OPERATIVA.md`](./GUIDA_OPERATIVA.md) for the complete Italian operational guide.

---

## Table of Contents

- [Why This Project](#-why-this-project)
- [EU AI Act Compliance](#-eu-ai-act-compliance)
- [Architecture](#️-architecture)
- [Advanced RAG Pipeline](#-advanced-rag-pipeline)
- [Technology Stack](#-technology-stack)
- [Requirements](#-requirements)
- [Quick Start](#-quick-start)
- [Accessing the Interface](#-accessing-the-interface)
- [Makefile Commands Reference](#️-makefile-commands-reference)
- [Document Management Console](#-document-management-console)
- [API Reference](#-api-reference)
- [Configuration](#️-configuration)
- [Roadmap](#-roadmap)
- [License](#-license)

---

## 💡 Why This Project

Every prompt sent to a cloud AI service travels through external networks, gets logged, and may be used to train future models. For confidential contracts, product strategies, HR data, or proprietary code — this is unacceptable.

**Private Corporate AI** solves the problem at its root: the entire stack runs locally. A prompt originates in the user's browser, passes through Nginx, is processed by Docker containers, reaches the local LLM model — and the response travels the reverse path. **At no point does a single byte leave the corporate perimeter.**

Beyond privacy, this project was built to address the growing need for **regulatory compliance**, particularly with the new **EU Regulation on Artificial Intelligence (EU AI Act)**, giving organizations a powerful, safe, and verifiable AI tool.

---

## 🇪🇺 EU AI Act Compliance

### Structural Compliance Advantages

The on-premise architecture offers compliance benefits that cloud-based AI systems cannot guarantee with the same simplicity:

| Requirement | How Private Corporate AI Addresses It |
|---|---|
| **Data Sovereignty** | No corporate data ever leaves the organization's servers. Eliminates data transfer issues to cloud GPAI providers (GPT-4, Gemini, etc.) subject to Art. 53 obligations. |
| **Human Oversight by Design** | Every system response cites verifiable documentary sources. The system generates advisory outputs, not autonomous decisions (Art. 14). |
| **Integrated Cybersecurity** | SSL/TLS, isolated Docker networks, randomly generated credentials at each installation — basis for Art. 15 requirements. |
| **Documentary Traceability** | Every indexed document is identifiable with a unique ID, timestamp and metadata — basis for Art. 12 record-keeping. |
| **Transparency** | *(Phase 1 Roadmap)* AI disclosure disclaimer and AI literacy module for end users (Art. 4 & 50). |

### ⚠️ High-Risk Scenarios

The risk profile changes if the system is used for:
- Personnel decisions, employee selection or evaluation
- Credit or insurance assessments
- Public Administration contexts

In these scenarios, additional compliance measures are required. See the [EU AI Act analysis document](./doc/private-corporate-ai-EU-AIAct-analisi.pdf) for a detailed assessment.

---

## 🏗️ Architecture

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

**Separate Docker networks by design:**
- `frontend_net` — Nginx, Open WebUI, RAG Console, RAG Backend
- `backend_net` — RAG Backend, Ollama, Qdrant

The two-network separation ensures that the LLM inference engine and vector database are never directly accessible from the browser layer, reducing the attack surface.

---

## ⚡ RAG Backend Highlights (v0.2.0)

The backend has been re-architected for corporate stability and performance:

- **Persistent Metadata Store**: Uses **SQLite/SQLAlchemy** to track document lifecycle, ensuring state persistence across restarts.
- **Content De-duplication**: Automatic **SHA-256 hashing** prevents redundant indexing of the same files.
- **Parallel Ingestion**: Async batch processing with semaphores speeds up document indexing by up to **75%**.
- **Redis Embedding Cache**: Integrated **Redis** to cache vector embeddings, reducing latency and LLM load for repeated queries.
- **SSE Streaming**: Real-time answer generation via **Server-Sent Events** for a modern, responsive chat experience.

---

## 🧠 Advanced RAG Pipeline

Unlike traditional RAG systems, **Private Corporate AI** implements two state-of-the-art techniques to maximize response accuracy:

### 1. Contextual Retrieval
For each text fragment (chunk), the local LLM automatically generates a brief contextual prefix based on the entire document. This prevents loss of meaning when a chunk is retrieved in isolation (e.g., a table without the chapter heading it belongs to).

### 2. Hybrid Search (Dense + Sparse)
The system combines:
- **Semantic vector search** — finds conceptually related content
- **BM25 text search** — matches exact codes, acronyms, and specific terms

Results are merged using **Reciprocal Rank Fusion (RRF)**, ensuring **30–40% superior recall** on corporate technical documents compared to semantic search alone.

---

## 🛠️ Technology Stack

| Container | Image | Role | License |
|-----------|-------|------|---------|
| `corporate_ai_nginx` | `nginx:1.27.4-alpine` | SSL/TLS reverse proxy, rate limiting, security headers | BSD |
| `corporate_ai_webui` | `ghcr.io/open-webui/open-webui:v0.8.8` | Web chat interface, conversation management | MIT |
| `corporate_ai_console` | `node:20-alpine` | **Document Management Console** (React + Vite) | MIT |
| `corporate_ai_rag` | *Custom build* | FastAPI + LangChain, RAG pipeline, Advanced PDF Table Extraction (**PyMuPDF4LLM**), OpenAI-compatible API | Apache 2.0 |
| `corporate_ai_redis` | `redis:7.4.2-alpine` | **Embedding & Query Cache** | MIT |
| `corporate_ai_ollama` | `ollama/ollama:0.17.7` | Local LLM runtime, CPU and NVIDIA GPU support | MIT |
| `corporate_ai_qdrant` | `qdrant/qdrant:v1.17.0` | Vector database, Hybrid Search (Dense + Sparse/BM25) with RRF | Apache 2.0 |
| `corporate_ai_ollama_init` | `ollama/ollama` | One-shot init: downloads LLM and embedding model on first startup | MIT |

---

## 📋 Requirements

### FULL Mode (GPU — Recommended)

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| NVIDIA GPU | 8 GB VRAM | 16–24 GB VRAM (RTX 3090/4090) |
| RAM | 16 GB | 32–64 GB |
| Storage | 50 GB | 200–500 GB NVMe |
| OS | Linux / WSL2 | Ubuntu 22.04+ LTS |
| Response time | — | 2–15 seconds |

### LITE Mode (CPU-only — No GPU Required)

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores (x86_64 with AVX2) | 8–16 cores |
| RAM | 8 GB | 16–32 GB |
| Storage | 30 GB | 60–200 GB SSD |
| OS | Linux / WSL2 | Ubuntu 22.04+ LTS |
| Response time | — | 30–180 seconds |

> **AVX2 Note:** Ollama uses AVX2 instructions to accelerate CPU inference. Verify support with: `grep avx2 /proc/cpuinfo | head -1` — any modern CPU (post-2013) supports it.

### 🖥️ Windows (WSL2) Users
If you are installing Private Corporate AI on **Windows via WSL2**, please read the **[WSL2 Setup Section](./DEPLOYMENT_GUIDE.md#2b-wsl2-windows-subsystem-for-linux-setup)** in the Deployment Guide. It covers critical information regarding Docker Desktop integration, GPU setup, and filesystem performance.

---

## 🚀 Quick Start

Installation is fully automated via an interactive script that configures the entire environment (Docker, models, database, certificates) based on detected hardware.

### 1. Clone & Run the Installer

```bash
git clone https://github.com/fcollova/Private-Corporate-AI.git
cd private-corporate-ai
chmod +x install.sh
sudo ./install.sh
```

> Non-interactive flags are also supported: `./install.sh --gpu` or `./install.sh --cpu`

### 2. Installation Wizard Steps

The installer guides you through:

1. **Hardware Detection** — Automatic analysis of CPU, RAM and NVIDIA GPU
2. **Mode Selection** — Choose between **FULL (GPU)** for maximum performance or **LITE (CPU)** for GPU-less servers
3. **LLM Model Selection** — Choose the optimal model (e.g. Gemma 2, Llama 3.1, DeepSeek-R1)
4. **Client Customization** — Enter company name and choose a color theme for interface branding
5. **Credential Generation** — Automatic creation of unique secret keys and self-signed SSL certificates

### 3. Monitor Installation

Installation typically takes 5–15 minutes, primarily for LLM model download (several GB).

```bash
# Monitor initial model download
make logs-init

# Monitor system resource usage during build
make monitor
```

### 4. Verify Installation

```bash
# Check health of all services
make health

# Send a test query to the RAG
make test-chat
```

Then navigate to `https://localhost`. Accept the security warning (self-signed certificate) and verify the Open WebUI login screen appears.

---

## 🌐 Accessing the Interface

After startup (allow 2–5 minutes for model download on first run):

| Service | URL | Notes |
|---------|-----|-------|
| **Open WebUI** | `https://localhost` | Main chat interface |
| **Document Console** | `https://localhost/console/` | Document and RAG domain management |
| **RAG API Docs** | `https://localhost/rag-docs` | Interactive Swagger UI |
| **RAG Health** | `https://localhost/api/health` | Ollama + Qdrant + Redis status |

---

## ⚙️ Makefile Commands Reference

The entire stack is managed via `make`. Here is the complete command reference by category.

### 🚀 Stack Management

| Command | Description |
|---------|-------------|
| `make install` | **Interactive installation** (auto-detects hardware, configures GPU or CPU) |
| `make setup` | Quick setup: creates `.env` and generates self-signed SSL certificates |
| `make up-gpu` | Start in **FULL (NVIDIA GPU)** mode |
| `make up-lite` | Start in **LITE (CPU-only)** mode |
| `make restart-gpu` | Quick restart in FULL mode |
| `make restart-lite` | Quick restart in LITE mode |
| `make down` | Stop all services (FULL mode) |
| `make down-lite` | Stop all services (LITE mode) |
| `make build` | Rebuild the RAG Backend image |
| `make rebuild-rag` | Recreate and restart only the RAG Backend (hot-fix) |
| `make reload-nginx` | Verify and reload Nginx configuration |
| `make clean` | ⚠️ **Removes everything**: containers, networks and **data volumes** |

### 📊 Logging & Monitoring

| Command | Description |
|---------|-------------|
| `make status` | Health status and uptime of all containers |
| `make logs` | Combined real-time logs for all services |
| `make logs-rag` | RAG Backend specific logs (FastAPI) |
| `make logs-init` | Monitor initial model download |
| `make logs-ollama` | LLM inference engine logs |
| `make logs-redis` | **NEW**: Redis cache logs |
| `make monitor` | **Resource dashboard**: real-time CPU, RAM and Network |
| `make gpu-monitor` | VRAM and GPU temperature monitoring (NVIDIA) |
| `make logs-nginx` | Reverse proxy and HTTP traffic logs |
| `make logs-webui` | Open WebUI chat interface logs |

### 🤖 LLM Model Management

| Command | Description |
|---------|-------------|
| `make list-models` | List currently installed models on Ollama |
| `make active-model` | Show which model is currently loaded in RAM/VRAM |
| `make pull-model MODEL=...` | Download a specific model (e.g. `MODEL=llama3:8b`) |
| `make remove-model MODEL=...` | Remove a model from disk |
| `make pull-models-lite` | Force download of CPU-optimized models |

### 📁 Documents & RAG (CLI)

| Command | Description |
|---------|-------------|
| `make health` | Verify connectivity between RAG, Ollama, Qdrant and Redis |
| `make upload-doc FILE=...` | Upload and index a file (PDF, DOCX, TXT, MD, XLSX, PPTX) |
| `make list-docs` | List indexed documents in the SQL metadata database |
| `make test-chat` | Send a query to the RAG and receive response with sources |
| `make wipe-rag` | ⚠️ **Wipe RAG**: deletes vectors, uploads, SQL database and Redis cache |
| `make init-collection` | Manually initialize the Qdrant collection |

### 💻 Document Management Console

| Command | Description |
|---------|-------------|
| `make up-console` | Start specifically the Console container |
| `make rebuild-console` | Recompile the React (Vite) app from scratch |
| `make logs-console` | Console dev/production server logs |
| `make open-console` | Automatically open the console URL in the browser |

### 🏢 Client Customization

| Command | Description |
|---------|-------------|
| `make client-info` | Display the currently active company profile |
| `make reconfigure-client` | Relaunch the wizard to change logos and domains |
| `make edit-system-prompt` | Open the editor to modify the AI "instructions" |
| `make export-client-config` | Create a `.tar.gz` package with all customization |

### 🛠️ Maintenance & Security

| Command | Description |
|---------|-------------|
| `make backup` | Create a compressed backup of all Docker volumes (including SQL) and `.env` |
| `make uninstall` | Guided safe removal procedure for the entire stack |
| `make help` | Show the interactive command guide |

---

## 📂 Document Management Console

The React console (`/console/`) enables advanced management of the corporate knowledge base:

- **Multiple Domains** — Organize documents into separate Qdrant collections (e.g. "Legal", "HR", "Technical")
- **Monitoring** — View the number of extracted fragments (chunks) per document
- **Maintenance** — Forced re-indexing and document migration between domains
- **Dynamic Branding** — Interface automatically adapts to the company name and colors configured during installation

---

## 📡 API Reference

The RAG backend exposes advanced endpoints for domain management. Full interactive documentation available at `https://localhost/rag-docs`.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/domains` | List all domains and vector statistics |
| `POST` | `/api/domains` | Create a new information domain |
| `DELETE` | `/api/domains/{name}` | Delete a domain and all its data |
| `POST` | `/api/documents/upload` | Upload and index a document |
| `PUT` | `/api/documents/{id}/domain` | Move a document between domains |
| `POST` | `/api/documents/{id}/reindex` | Force re-indexing of a file |
| `POST` | `/api/chat` | Native RAG query with cited sources |

### Real-time Monitoring
The console now supports real-time monitoring of document processing:
- **Status Tracking**: Visual indicators for *Processing*, *Indexed*, and *Error* states.
- **Automatic Polling**: UI automatically refreshes while documents are being indexed.
- **Dynamic Icons**: Visual file type identification (.pdf, .docx, .xlsx, .pptx, .md).

---

## 🧪 Testing

The RAG Backend includes a unit test suite to ensure the integrity of the document processing pipeline.

```bash
# Run tests (requires pytest and pytest-asyncio)
pytest rag_backend/tests
```

---

## 🗂️ Configuration

### `.env` File

The `.env` file is auto-generated by the installer. Key variables:

```env
# LLM Model to use (pulled automatically on first start)
LLM_MODEL=gemma2:9b

# Embedding model for RAG vector indexing
EMBEDDING_MODEL=nomic-embed-text

# URL base for console API calls to the RAG backend
CONSOLE_RAG_API_BASE=/api/rag

# Company branding (set by install wizard)
CLIENT_NAME=Your Company Name
```

A complete example is available in [`.env.example`](./.env.example).

### System Prompt Customization

Customize the AI behavior for your specific domain:

```bash
make edit-system-prompt
```

The system prompt is stored in `rag_backend/system_prompt.txt` and controls how the LLM responds to queries, including tone, language, citation format and domain-specific instructions.

---

## 🗺️ Roadmap

> This is an actively developed project. The roadmap is driven by **EU AI Act compliance requirements** (deadline: August 2026) and enterprise integration needs.

### Phase 1 — Compliance & Quick Wins *(Month 1)*
- [x] XLSX and PPTX document loader support (via Microsoft MarkItDown)
- [ ] AI Transparency Disclaimer in Open WebUI (Art. 4 & 50 AI Act)
- [ ] AI Literacy onboarding module for end users
- [ ] Docker log retention policy (6-month persistence, Art. 12 AI Act)

### Phase 2 — Connectivity & Deep Indexing *(Months 2–3)*
- [ ] OCR pipeline via Tesseract (support for scanned PDFs and images)
- [ ] SharePoint / OneDrive sync connector (Microsoft Graph API)
- [ ] Google Workspace connector (Service Account)
- [ ] NAS / local file server auto-ingestion via Docker volume
- [ ] Human validation of retrieved chunks in Document Console (Art. 14 AI Act)

### Phase 3 — Governance & Advanced Audit *(Months 4–6)*
- [ ] Document versioning and in-place index update
- [ ] GDPR-compliant audit trail with PII anonymization
- [ ] Technical Documentation auto-generation (EU AI Act Annex IV)
- [ ] Multi-tenancy with granular domain permissions (HR / Legal / Tech isolation)

Full details in [ROADMAP.md](./ROADMAP.md).

---

## 📄 License

This project is distributed under the **Apache 2.0** license. Included components retain their original licenses:

| Component | License |
|-----------|---------|
| Ollama | MIT |
| Qdrant | Apache 2.0 |
| Open WebUI | MIT |
| Nginx | BSD |
| FastAPI | MIT |
| LangChain | MIT |

---

## Contact

**Francesco Collovà** — Author & Maintainer

- **Bug reports:** [Open an Issue](https://github.com/fcollova/Private-Corporate-AI/issues)
- **Ideas & questions:** [GitHub Discussions](https://github.com/fcollova/Private-Corporate-AI/discussions)
- **Collaboration:** [LinkedIn](https://linkedin.com/in/fcollova)

> For inquiries reach out via LinkedIn with a brief description of your needs.

*Built with ❤️ for organizations that take data privacy seriously.*

*Personal Project Disclaimer
This project is developed and maintained independently by Francesco Collovà as a personal initiative, in personal time and using exclusively personal resources.
It is not affiliated with, sponsored by, or endorsed by any current or former employer. The views, architectural choices, and technical decisions expressed in this project reflect solely the author's personal expertise and do not represent the position of any organization the author is or has been associated with.
No proprietary information, confidential data, or intellectual property belonging to any employer has been used in the development of this project.*