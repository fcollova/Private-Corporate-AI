# Guida all'Integrazione e Configurazione: Private Corporate AI (PCAI)

## 1. Architettura di Rete (Network Topology)

PCAI utilizza un sistema a **doppia rete isolata** per garantire la massima sicurezza dei dati aziendali.

### 1.1 frontend_net (172.20.0.0/24)
Rete dedicata alla comunicazione tra il Reverse Proxy e le interfacce utente.
- **Servizi**: `nginx`, `open_webui`, `console`, `rag_backend`.
- **Scopo**: Esporre i servizi web e permettere al frontend di chiamare le API del backend.

### 1.2 backend_net (172.21.0.0/24)
Rete segregata non accessibile direttamente dal browser.
- **Servizi**: `rag_backend`, `ollama`, `qdrant`, `redis`, `ollama_init`.
- **Scopo**: Proteggere i motori di calcolo e i database. Solo il `rag_backend` fa da ponte tra le due reti.

---

## 2. Flussi di Comunicazione Tra Container

| Origine | Destinazione | Protocollo | Porta | Scopo |
|:--- | :--- | :--- | :--- | :--- |
| **Nginx** | `open_webui` | HTTP | 8080 | Interfaccia chat principale |
| **Nginx** | `console` | HTTP | 3000 | Gestione documenti |
| **Nginx** | `rag_backend`| HTTP | 8000 | API RAG e Swagger |
| **Open WebUI**| `rag_backend`| HTTP | 8000 | Inoltro query RAG (v1/chat) |
| **Open WebUI**| `ollama` | HTTP | 11434| Chat diretta (opzionale) |
| **Console** | `rag_backend`| HTTP | 8000 | Caricamento e gestione doc |
| **RAG Backend**| `ollama` | HTTP | 11434| Generazione embeddings e LLM |
| **RAG Backend**| `qdrant` | HTTP/gRPC| 6333 | Ricerca vettoriale |
| **RAG Backend**| `redis` | TCP | 6379 | Caching degli embeddings |

---

## 3. Matrice dei Parametri di Configurazione (.env)

### 3.1 Performance & Scalabilità
- `WEB_WORKERS`: Numero di processi paralleli Gunicorn per il backend (Consigliato: `num_cpu * 2`).
- `OLLAMA_NUM_PARALLEL`: Quante chiamate LLM simultanee può gestire Ollama (Critico per l'ingestion parallela).
- `EMBEDDING_CACHE_ENABLED`: Se `true`, attiva Redis per non ricalcolare mai lo stesso vettore.

### 3.2 RAG Pipeline
- `CHUNK_SIZE`: Lunghezza dei frammenti di testo (1000 standard, 700 per CPU).
- `CHUNK_OVERLAP`: Sovrapposizione tra chunk (evita tagli semantici).
- `TOP_K_RESULTS`: Quanti documenti correlati inviare all'LLM (3-5 consigliato).

### 3.3 Database & Persistenza
- `DATABASE_URL`: Stringa di connessione SQLAlchemy (`sqlite+aiosqlite:////app/data/rag.db`).
- `REDIS_URL`: Indirizzo del server Redis (`redis://redis:6379/0`).
- `QDRANT_API_KEY`: Chiave di sicurezza per proteggere l'indice vettoriale.

---

## 4. Gestione dei Volumi e Persistenza Dati

Il sistema è stateless a livello di codice, ma stateful a livello di volumi:

1.  **`rag_data`**: Contiene `rag.db` (SQLite). È la "Single Source of Truth" per lo stato dei documenti. **Backup critico**.
2.  **`qdrant_data`**: Contiene l'indice vettoriale. Se perso, richiede la re-indicizzazione di tutti i file.
3.  **`rag_uploads`**: Archivio dei file fisici caricati. Necessario per la funzione "Re-index".
4.  **`ollama_data`**: Archivio dei modelli LLM (Gemma, Llama). Può pesare decine di GB. Facilmente rigenerabile tramite `make pull-model`.
5.  **`webui_data`**: Database degli utenti e cronologia delle chat.

---

## 5. Logica di Bootstrap e Healthchecks

L'ordine di avvio è orchestrato per prevenire errori 500:

1.  **Ollama & Qdrant & Redis**: Partono per primi.
2.  **RAG Backend**: Attende che i suddetti siano "Started". Inizializza lo schema SQL e si mette in stato `Healthy` solo dopo aver verificato la connessione a Ollama.
3.  **Open WebUI**: Parte dopo il RAG Backend. Effettua il pull dei modelli se mancanti.
4.  **Nginx**: Parte per ultimo. Diventa `Healthy` solo quando Open WebUI risponde alla porta 8080, garantendo che l'utente non veda mai una pagina di errore.

---

## 6. Sicurezza Corporate

- **No Cloud**: Tutta la risoluzione DNS è interna ai container Docker.
- **SSL Termination**: Gestita esclusivamente da Nginx.
- **Credential Generation**: `install.sh` genera chiavi casuali per ogni installazione, salvandole nel `.env`.
- **Hashing**: La de-duplicazione via SHA-256 assicura che documenti identici non vengano processati due volte, prevenendo attacchi di "resource exhaustion".

---
*Documento tecnico di integrazione v0.2.0*
*Aggiornato al: 21 Marzo 2026*
