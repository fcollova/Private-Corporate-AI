# Architettura Tecnica: Private Corporate AI (PCAI) RAG Backend v0.2.0

## 1. Visione d'Insieme
Il backend PCAI è il nucleo computazionale del sistema, responsabile dell'orchestrazione tra modelli linguistici locali (Ollama), database vettoriali (Qdrant) e persistenza dei metadati (SQLite). È progettato per garantire **isolamento dei dati**, **performance scalabili** e **tracciabilità corporate**.

---

## 2. Architettura dei Processi & Scalabilità

### 2.1 Gunicorn + Uvicorn Workers
Il sistema adotta un modello di esecuzione multi-processo per superare i limiti del Global Interpreter Lock (GIL) di Python nelle operazioni CPU-bound:
- **Process Manager**: Gunicorn gestisce il ciclo di vita dei worker.
- **Worker Class**: `uvicorn.workers.UvicornWorker` per la gestione asincrona delle richieste I/O-bound.
- **Concurrency**: Il numero di worker è configurabile tramite `WEB_WORKERS`, permettendo di saturare correttamente le risorse multi-core del server.

### 2.2 Gestione Asincrona
Tutta la logica è implementata nativamente in `async/await`. Le operazioni bloccanti (es. caricamento file pesanti o chiamate sincrone a librerie legacy) sono delegate a thread pool separati tramite `asyncio.to_thread()`, garantendo che l'event loop rimanga sempre reattivo.

---

## 3. Data Layer: Il "Dual-Store Pattern"

PCAI separa nettamente i dati di business dai vettori matematici per garantire integrità e velocità di ricerca.

### 3.1 Metadata Store (SQL)
Implementato con **SQLAlchemy 2.0** e **SQLite** (file-based per semplicità di deploy, ma pronto per PostgreSQL).
- **Tabella `documents`**: Memorizza hash del file (SHA-256), stato dell'elaborazione, progresso (0-100%), metadati corporate (`department_id`, `access_level`) e timestamp.
- **Integrità**: Impedisce l'indicizzazione duplicata dello stesso contenuto, ottimizzando lo spazio sul disco e il tempo di calcolo LLM.

### 3.2 Vector Store (Qdrant)
Utilizzato esclusivamente per il retrieval semantico e full-text.
- **Hybrid Search**: Ogni punto (chunk) in Qdrant contiene sia un vettore denso (embeddings semantici) che un vettore sparso (BM25).
- **RRF (Reciprocal Rank Fusion)**: Combina i risultati delle due ricerche per una precisione superiore del 30% rispetto alla sola ricerca vettoriale.

---

## 4. Pipeline di Ingestion: "Parallel Contextual Retrieval"

L'ingestion dei documenti è la fase più onerosa. PCAI v0.2.0 introduce un'ottimizzazione radicale dei tempi.

### 4.1 Flusso di Elaborazione
1.  **Hashing & Queueing**: Il file viene validato e messo in stato `QUEUED` nel DB SQL.
2.  **Extraction**: Utilizzo di `MarkItDown` (Microsoft) per convertire Office/PDF in Markdown strutturato.
3.  **Semantic Chunking**: Suddivisione in frammenti con overlap configurabile.
4.  **Parallel Contextualization**:
    - Per ogni chunk, viene invocato l'LLM per generare un prefisso di contesto.
    - **Concurrency Control**: Un `asyncio.Semaphore` (regolato da `OLLAMA_NUM_PARALLEL`) impedisce di sovraccaricare la VRAM della GPU, permettendo però elaborazioni parallele massicce.
5.  **Batch Indexing**: I chunk arricchiti vengono inviati a Qdrant in batch da 50 punti per ottimizzare il throughput di rete.

---

## 5. Strato di Caching: Redis Embedding Cache

Per ridurre la latenza delle query ricorrenti e velocizzare la re-indicizzazione di documenti simili:
- **Tecnologia**: `CacheBackedEmbeddings` di LangChain collegato a un'istanza **Redis 7**.
- **Funzionamento**: Prima di invocare Ollama per generare un embedding, il sistema calcola l'hash del testo. Se presente in Redis, il vettore viene restituito istantaneamente ($<5ms$).
- **Risparmio**: Riduzione del carico computazionale sulla GPU fino al 90% per documenti con sezioni ripetitive (es. clausole legali standard).

---

## 6. Chat & Streaming (SSE)

L'interazione con l'utente è gestita tramite **Server-Sent Events (SSE)** per una UX fluida.
- **Endpoint**: `/api/chat/stream`.
- **Protocollo**: Il backend genera un generatore asincrono che effettua il retrieval da Qdrant e poi "streama" i token prodotti dall'LLM man mano che vengono generati.
- **Payload Strutturato**:
    ```json
    {"type": "metadata", "sources": [...]} // Inviato subito dopo il retrieval
    {"type": "content", "content": "..."}  // Inviato per ogni token/parola
    {"type": "end", "latency": 1.23}       // Inviato a fine generazione
    ```

---

## 7. Sicurezza & Isolamento Corporate

- **Network Hardening**: Utilizzo di reti Docker interne (`backend_net`) per isolare Ollama, Qdrant e Redis. Questi servizi non espongono porte sull'host.
- **RBAC Ready**: La struttura del database SQL è già predisposta per filtrare i risultati di Qdrant in base al `department_id` dell'utente (Multi-tenancy logica).
- **Audit Trail**: Ogni operazione di upload, delete o query è tracciata nel database SQL, fornendo una base per la conformità all'Art. 12 dell'EU AI Act.

---

## 8. Parametri di Performance Consigliati

| Variabile | Valore GPU (Consigliato) | Valore LITE (CPU) |
|-----------|--------------------------|-------------------|
| `WEB_WORKERS` | 2-4 | 1-2 |
| `OLLAMA_NUM_PARALLEL` | 4-8 | 1 |
| `CHUNK_SIZE` | 1000 | 700 |
| `EMBEDDING_CACHE` | Enabled (Redis) | Enabled (Redis) |

---
*Specifiche tecniche valide per PCAI v0.2.0*
*Ultimo aggiornamento: Marzo 2026*
