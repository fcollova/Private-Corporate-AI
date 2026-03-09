# PRIVATE CORPORATE AI — Gemini CLI Context

This `GEMINI.md` file provides essential context for the Gemini CLI agent to interact effectively with the "Private Corporate AI" project. It summarizes the project's purpose, technology stack, architecture, and operational guidelines derived from the codebase and documentation.

## Project Overview

"Private Corporate AI" is a self-hosted, 100% open-source solution designed to bring Retrieval-Augmented Generation (RAG) capabilities with Large Language Models (LLMs) into a corporate infrastructure, ensuring maximum data privacy and GDPR compliance by keeping all AI operations on-premises.

### Key Technologies:

*   **Container Orchestration:** Docker Compose (`docker-compose.yaml`, `docker-compose.lite.yaml`).
*   **Reverse Proxy & Security:** Nginx.
*   **User Interface:** Open WebUI (a modern, chat-based web interface).
*   **RAG Backend:** FastAPI application (Python) utilizing LangChain for document processing and RAG pipeline management.
*   **LLM Inference:** Ollama, a local LLM runtime with support for both CPU and NVIDIA GPU.
*   **Vector Database:** Qdrant, used for storing and retrieving document embeddings.

### Architecture:

The project employs a robust Docker-based microservices architecture, segregating services into `frontend_net` and `backend_net` for enhanced security and isolation.

*   **Nginx** acts as the ingress point, handling SSL/TLS termination, rate limiting, security headers, and routing traffic to:
    *   **Open WebUI** for the main chat interface.
    *   **RAG Backend (FastAPI)**, which orchestrates the RAG pipeline.
*   The **RAG Backend** communicates with:
    *   **Ollama** for LLM inference and embedding generation.
    *   **Qdrant** for vector storage and semantic search.
*   The system supports two main deployment modes:
    *   **FULL (GPU):** Leverages NVIDIA GPUs for high-performance LLM inference.
    *   **LITE (CPU-only):** Optimized for environments without dedicated GPUs, utilizing CPU resources.

## Building and Running

The project provides comprehensive scripts and a `Makefile` for streamlined setup and operation.

### Initial Setup:

The recommended way to set up the project is by running the interactive installer script:

```bash
chmod +x install.sh
sudo ./install.sh
```

This script automatically detects hardware, installs necessary dependencies (Docker, NVIDIA Container Toolkit if applicable), generates a secure `.env` configuration file, and sets up self-signed SSL certificates.

### Deployment Modes:

Once configured, the stack can be launched in two modes:

*   **FULL (GPU):** For systems with NVIDIA GPUs.
    ```bash
    make up-gpu
    ```
*   **LITE (CPU-only):** For systems without GPUs. This mode uses `docker-compose.lite.yaml` as an override to optimize for CPU performance.
    ```bash
    make up-lite
    ```

### Common Operations:

The `Makefile` contains numerous targets for managing the stack:

*   **Start/Stop:** `make up-gpu`, `make up-lite`, `make down`, `make down-lite`.
*   **Restart:** `make restart-gpu`, `make restart-lite`.
*   **Build/Rebuild:** `make build` (builds RAG backend), `make rebuild-rag` (rebuilds and restarts RAG backend), `make reload-nginx`.
*   **Logging & Monitoring:** `make logs` (all services), `make logs-rag`, `make logs-ollama`, `make status`, `make monitor`, `make gpu-monitor`.
*   **Model Management:** `make pull-model MODEL=mistral:7b-instruct-q4_K_M`, `make list-models`, `make active-model`.
*   **Document Management:** `make upload-doc FILE=/path/to/document.pdf`, `make list-docs`.
*   **Health Check:** `make health`.
*   **Backup:** `make backup`.
*   **Cleanup:** `make clean` (⚠️ **Deletes all data!**).

### Access Points:

*   **Open WebUI (Chat Interface):** `https://localhost`
*   **RAG API (Swagger UI):** `https://localhost/rag-docs`
*   **RAG Health Check:** `https://localhost/api/rag/health`

## Development Conventions

### Configuration:

*   **Environment Variables:** Project configuration is managed via a `.env` file, generated from `.env.example`. This file contains settings for LLM models, Qdrant, RAG pipeline parameters, WebUI secrets, and Nginx. Sensitive information (API keys, secret keys) are automatically generated during setup.
*   **Model Selection:** The `.env` file allows specifying `LLM_MODEL` and `EMBEDDING_MODEL`. Different models are recommended for GPU vs. CPU modes, with quantitative suggestions for RAM/VRAM.

### Code Structure:

*   **`rag_backend/`:** Contains the core FastAPI application (`app.py`), its `Dockerfile`, and Python dependencies (`requirements.txt`).
*   **`nginx/`:** Holds the Nginx configuration (`nginx.conf`) and SSL certificates (`ssl/`).

### RAG Pipeline:

The RAG backend (`rag_backend/app.py`) implements the following pipeline:

1.  **Document Loading:** Supports PDF (`PyPDFLoader`), DOCX/DOC (`Docx2txtLoader`), and TXT/MD (`TextLoader`).
2.  **Chunking:** Uses `RecursiveCharacterTextSplitter` to break down documents into smaller, semantically coherent chunks (e.g., 1000 characters with 200 overlap by default).
3.  **Embedding:** Generates vector embeddings for each chunk using `OllamaEmbeddings` (e.g., `nomic-embed-text` model).
4.  **Indexing:** Stores the embeddings in Qdrant along with relevant metadata.
5.  **Querying:** Performs similarity search in Qdrant to retrieve `top_k` (default 5) most relevant chunks, constructs a contextual prompt, and sends it to `OllamaLLM` for generating a response, citing sources.

### Nginx Configuration:

`nginx.conf` sets up:

*   HTTP to HTTPS redirect.
*   SSL/TLS termination (using self-signed certs by default, production-ready with Let's Encrypt).
*   Routing for Open WebUI, RAG Backend API, and Swagger UI.
*   Security headers (`X-Frame-Options`, `X-Content-Type-Options`, `Content-Security-Policy`).
*   Rate limiting to protect against abuse.
*   Gzip compression for performance.
*   Structured logging for better analysis.

### Security and Best Practices:

The project emphasizes security with:

*   Automatic generation of strong, random secrets during installation.
*   Instructions for firewall configuration (`ufw`).
*   Guidance on replacing self-signed SSL certificates with production-grade ones (e.g., Let's Encrypt).
*   Recommendations for enabling authentication in Open WebUI.

### Contribution Guidelines:

The `README.md` explicitly invites contributions, highlighting areas for improvement such as support for additional document formats, multi-user authentication, monitoring dashboards, multi-tenancy, and automatic backups.
