# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **XLSX and PPTX support**: Full integration of Microsoft MarkItDown for Office document processing.
- **Advanced PDF Table Extraction**: Replaced PyPDF with **PyMuPDF4LLM** to preserve table structures in Markdown format.
- **Table-Aware Metadata**: Added `is_table` flag to document chunks for improved retrieval of structured data.
- **Real-time Document Status**: Added `ProcessingStateManager` to track background tasks and display *Processing/Indexed/Error* states in the console.
- **Console UI Refresh**: Integrated dynamic file icons, status badges, and automatic polling for a better UX.
- **Unit Testing Suite**: Comprehensive test suite for RAG Backend pipeline (`rag_backend/tests/`).
- WIP: OCR pipeline via Tesseract for scanned PDFs and images.

## [0.1.0] - 2026-03-14

### Added
- **Contextual Retrieval**: Local LLM automatically generates a contextual prefix for each text fragment to preserve meaning.
- **Hybrid Search (Dense + Sparse)**: Combined semantic vector search and BM25 text search with RRF merging.
- **Document Management Console**: React-based interface for managing domains, collections, and document indexing.
- **Multiple Domains Support**: Ability to organize documents into separate Qdrant collections.
- **Dynamic Branding**: Interface branding (name, colors) customizable via installation wizard.
- **Automated Installer**: Interactive script for hardware detection and stack configuration.
- **EU AI Act Compliance Framework**: Structural features designed for data sovereignty and traceability.

### Changed
- Improved Nginx configuration with enhanced security headers and rate limiting.
- Optimized RAG pipeline performance for both GPU and CPU modes.

### Fixed
- Fixed issues with large document indexing timeouts.
- Resolved various UI inconsistencies in the Open WebUI integration.
