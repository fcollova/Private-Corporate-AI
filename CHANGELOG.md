# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-03-27

### Added
- **New "Solo" Deployment Profile**: A lightweight stack (5 containers) optimized for professional studios (1-3 users) using HTTP on port 80 and integrated static console.
- **Dedicated "Index Test" View**: Isolated retrieval testing into a separate console page to improve focus management and UI stability.
- **Sidebar "Index Test" Menu**: Added a new navigation item with localized labels ("Index Test" in both IT/EN).

### Changed
- **Refactored Console Components**: Moved `Card`, `NavItem`, and static styles outside main render functions to prevent unnecessary unmounting and focus loss.
- **Optimized Console Build**: Updated `make rebuild-console` to automatically reload Nginx in Solo mode and ensure correct UID/GID ownership.

### Fixed
- **Input Focus Loss**: Resolved a persistent bug where indexing test inputs would lose focus during typing due to component recreation.
- **UI Layout Overlap**: Fixed a CSS overlap where the test query input could physically cover the "Run Test" button.
- **Nginx Config Persistence**: Fixed an issue where rebuilding the console in Solo mode wouldn't reflect changes until a manual Nginx reload.
- **Improved Installer Ownership**: Updated `install.sh` to correctly restore user ownership for `console/dist` and `console/node_modules` after root installation, preventing permission errors.
- **Permission Errors**: Fixed `EACCES` errors when running `npm install` inside the console after a sudo-based installation.

## [0.2.0] - 2026-03-21

### Added
- **Persistent SQL Metadata Store**: Replaced in-memory state with an asynchronous SQLite database (SQLAlchemy 2.0) for document lifecycle tracking and persistence.
- **Redis Embedding Cache**: Integrated Redis to cache vector embeddings, significantly reducing latency and LLM load for repeated document chunks.
- **Parallel Document Ingestion**: Implemented `asyncio.gather` with semaphore control (`OLLAMA_NUM_PARALLEL`) to process multiple document fragments simultaneously.
- **SSE (Server-Sent Events) Streaming**: Real-time response generation for the chat API, providing a modern and responsive user experience.
- **Corporate Metadata Support**: Added `owner_id`, `department_id`, and `access_level` fields to the document schema, ready for IAM integration.
- **Content De-duplication**: Automatic SHA-256 hashing during upload to prevent redundant indexing of identical files.
- **AI Transparency Disclaimer**: Integrated mandatory AI disclosure in both the Document Console and Open WebUI to comply with **EU AI Act Art. 50**.
- **Centralized System Wipe**: Added `/api/system/wipe` endpoint for atomic cleaning of SQL, Qdrant, Redis, and physical files.
- **Advanced Office Loaders**: Switched to `MarkItDown` for all Office formats (.docx, .doc, .xlsx, .pptx), ensuring superior table and structure extraction.
- **Multi-worker Gunicorn Setup**: Production-ready backend configuration using Gunicorn with Uvicorn workers for high concurrency.

### Changed
- **Consolidated Healthcheck**: Updated RAG Health API to monitor Ollama, Qdrant, and Redis connectivity simultaneously.
- **Enhanced `make` commands**: Polished `make help` with colors and categories; updated `make wipe-rag` and `make backup` for the new SQL/Redis architecture.
- **Improved Installation**: `install.sh` now automatically configures performance variables and persistent volumes for the metadata store.

### Fixed
- Fixed naming conflicts between LangChain and SQLAlchemy models in the processing pipeline.
- Resolved Docker Compose dependency issues causing 500 errors during initial startup.
- Fixed inconsistent vector fragment counts in the UI after manual data deletion.

## [0.1.0] - 2026-03-14

### Added
- **Contextual Retrieval**: Local LLM automatically generates a contextual prefix for each text fragment to preserve meaning.
- **Hybrid Search (Dense + Sparse)**: Combined semantic vector search and BM25 text search with RRF merging.
- **Document Management Console**: React-based interface for managing domains, collections, and document indexing.
- **Multiple Domains Support**: Ability to organize documents into separate Qdrant collections.
- **Dynamic Branding**: Interface branding (name, colors) customizable via installation wizard.
- **Automated Installer**: Interactive script for hardware detection and stack configuration.
- **EU AI Act Compliance Framework**: Structural features designed for data sovereignty and traceability.
