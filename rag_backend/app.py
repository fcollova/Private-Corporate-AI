"""
=============================================================================
PRIVATE CORPORATE AI — RAG Backend
=============================================================================
Autore:     Francesco Collovà
Versione:   1.0.0
Licenza:    Apache 2.0

Descrizione:
    Backend FastAPI che implementa una pipeline RAG (Retrieval-Augmented
    Generation) completa per documenti aziendali privati.

    Flusso principale:
        1. Upload documento (PDF/DOCX/TXT)
        2. Estrazione testo e chunking intelligente
        3. Generazione embedding con Ollama
        4. Indicizzazione su Qdrant
        5. Query → ricerca vettoriale → risposta contestuale LLM

    Endpoint esposti:
        GET  /health                → Stato del servizio
        POST /api/documents/upload  → Caricamento e indicizzazione documento
        GET  /api/documents/list    → Lista documenti indicizzati
        DELETE /api/documents/{id}  → Rimozione documento dall'indice
        POST /api/chat              → Chat RAG con i documenti
        POST /v1/chat/completions   → Compatibilità API OpenAI (per WebUI)
        GET  /metrics               → Metriche Prometheus
=============================================================================
"""

import os
import uuid
import time
import asyncio
from pathlib import Path
from typing import Optional
from contextlib import asynccontextmanager

# --- Framework Web ---
from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import aiofiles

# --- Modelli Pydantic ---
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings

# --- LangChain Core ---
from langchain_ollama import OllamaLLM, OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.schema import Document
from langchain.chains import RetrievalQA
from langchain.prompts import PromptTemplate

# --- Document Loaders ---
from langchain_community.document_loaders import (
    PyPDFLoader,
    Docx2txtLoader,
    TextLoader,
)

# --- Qdrant Client ---
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointIdsList, Filter, FieldCondition, MatchValue

# --- Utilities ---
from loguru import logger
from tenacity import retry, stop_after_attempt, wait_exponential
import httpx
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response


# =============================================================================
# CONFIGURAZIONE — Caricamento da variabili d'ambiente / .env
# =============================================================================

class Settings(BaseSettings):
    """
    Configurazione centralizzata dell'applicazione.
    Tutti i valori sono sovrascrivibili tramite variabili d'ambiente o file .env.

    Modalità supportate:
        deploy_mode="gpu"  → Inferenza GPU NVIDIA, performance massima
        deploy_mode="cpu"  → Inferenza CPU-only (Modalità LITE), nessuna GPU richiesta
    """
    # Modalità deploy: "gpu" (default) o "cpu" (modalità LITE)
    deploy_mode: str = Field(default="gpu", pattern="^(gpu|cpu)$", description="Modalita' deploy: gpu o cpu")

    # LLM
    llm_model: str = Field(default="gemma2:9b", description="Modello Ollama per l'inferenza")
    embedding_model: str = Field(default="nomic-embed-text", description="Modello per gli embedding")
    llm_temperature: float = Field(default=0.2, ge=0.0, le=1.0)
    llm_context_window: int = Field(default=4096, ge=512)

    # Ollama
    ollama_base_url: str = Field(default="http://ollama:11434")

    # Timeout richieste LLM in secondi.
    # In modalita' LITE (CPU) i tempi di risposta sono molto piu' lunghi:
    #   GPU: 5-30s tipico | CPU: 30-300s tipico
    request_timeout: int = Field(default=120, ge=30, description="Timeout richieste LLM (secondi)")

    # Qdrant
    qdrant_host: str = Field(default="qdrant")
    qdrant_port: int = Field(default=6333)
    qdrant_api_key: str = Field(default="changeme")
    qdrant_collection_name: str = Field(default="corporate_docs")

    # RAG Pipeline
    chunk_size: int = Field(default=1000, ge=100, description="Dimensione chunk in caratteri")
    chunk_overlap: int = Field(default=200, ge=0, description="Sovrapposizione tra chunk")
    top_k_results: int = Field(default=5, ge=1, le=20, description="Chunk da recuperare per query")

    # Filesystem
    upload_dir: str = Field(default="/app/uploads")
    log_level: str = Field(default="INFO")

    # Profilo Cliente
    client_company: str = Field(default="Azienda S.r.l.")
    client_slug: str = Field(default="azienda")
    client_industry: str = Field(default="Generale")
    client_contact: str = Field(default="Amministratore")
    client_email: str = Field(default="admin@azienda.local")
    client_domain: str = Field(default="localhost")
    client_language: str = Field(default="italiano")
    client_lang_code: str = Field(default="it")
    client_theme_color: str = Field(default="#1A3A5C")
    client_theme_name: str = Field(default="blue")
    client_domains: str = Field(default="corporate_docs")

    @property
    def is_cpu_mode(self) -> bool:
        """True se siamo in modalita' LITE (inferenza CPU-only)."""
        return self.deploy_mode.lower() == "cpu"

    @property
    def effective_timeout(self) -> int:
        """Timeout adattivo: piu' lungo in modalita' CPU."""
        return self.request_timeout if not self.is_cpu_mode else max(self.request_timeout, 300)

    class Config:
        # Carichiamo solo da environment vars passate da Docker
        # Evitiamo di cercare il file .env per problemi di permessi nel container
        extra = "ignore"


# Istanza globale settings
settings = Settings()

# Configura logger
logger.remove()
logger.add(
    sink=lambda msg: print(msg, end=""),
    level=settings.log_level,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> — <level>{message}</level>",
    colorize=True,
)


# =============================================================================
# METRICHE PROMETHEUS
# =============================================================================

DOCUMENTS_UPLOADED = Counter(
    "rag_documents_uploaded_total",
    "Numero totale di documenti caricati",
    ["file_type"]
)
QUERY_REQUESTS = Counter(
    "rag_query_requests_total",
    "Numero totale di query RAG ricevute"
)
QUERY_LATENCY = Histogram(
    "rag_query_latency_seconds",
    "Latenza delle query RAG in secondi",
    buckets=[0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0]
)
CHUNKS_INDEXED = Counter(
    "rag_chunks_indexed_total",
    "Numero totale di chunk indicizzati su Qdrant"
)


# =============================================================================
# MODELLI PYDANTIC — Request/Response
# =============================================================================

class ChatRequest(BaseModel):
    """Richiesta di chat RAG."""
    question: str = Field(..., min_length=1, max_length=2000, description="Domanda dell'utente")
    collection_name: Optional[str] = Field(default=None, description="Collezione specifica (None = default)")
    top_k: Optional[int] = Field(default=None, ge=1, le=20, description="Chunk da recuperare (sovrascrive setting)")
    model: Optional[str] = Field(default=None, description="Modello LLM (sovrascrive setting)")

class ChatResponse(BaseModel):
    """Risposta della pipeline RAG."""
    answer: str
    sources: list[dict]
    model_used: str
    chunks_retrieved: int
    latency_seconds: float

class DocumentInfo(BaseModel):
    """Informazioni su un documento indicizzato."""
    doc_id: str
    filename: str
    file_type: str
    chunks_count: int
    indexed_at: str
    size_bytes: Optional[int] = 0

class DomainCreateRequest(BaseModel):
    """Richiesta creazione nuovo dominio (collezione)."""
    name: str = Field(..., min_length=2, max_length=64, pattern=r'^[a-zA-Z0-9_\-]+$')

class MoveDomainRequest(BaseModel):
    """Richiesta spostamento documento tra domini."""
    target_collection: str
    source_collection: Optional[str] = None  # None = usa default

class HealthResponse(BaseModel):
    """Risposta healthcheck."""
    status: str
    deploy_mode: str
    ollama_connected: bool
    qdrant_connected: bool
    model_loaded: str
    embedding_model: str
    collection_name: str
    timeout_seconds: int
    version: str = "1.0.0"

# Schema compatibilità OpenAI
class OpenAIMessage(BaseModel):
    role: str
    content: str

class OpenAIChatRequest(BaseModel):
    model: str = "local-rag"
    messages: list[OpenAIMessage]
    stream: bool = False


# =============================================================================
# COMPONENTI RAG — Inizializzazione lazy con retry
# =============================================================================

class RagComponents:
    """
    Contenitore per i componenti condivisi della pipeline RAG.
    Utilizza inizializzazione lazy per gestire il cold start dei servizi.
    """

    def __init__(self):
        self._llm: Optional[OllamaLLM] = None
        self._embeddings: Optional[OllamaEmbeddings] = None
        self._qdrant_client: Optional[QdrantClient] = None
        self._vector_store: Optional[QdrantVectorStore] = None

    @retry(
        stop=stop_after_attempt(10),
        wait=wait_exponential(multiplier=2, min=4, max=30),
        reraise=True
    )
    def _init_ollama_llm(self, model_name: Optional[str] = None) -> OllamaLLM:
        """
        Inizializza il client LLM Ollama con retry automatico.
        In modalita' LITE (CPU), imposta timeout piu' lunghi per
        compensare la minore velocita' di inferenza.
        """
        target_model = model_name or settings.llm_model
        mode_label = "LITE/CPU" if settings.is_cpu_mode else "FULL/GPU"
        logger.info(f"Connessione a Ollama LLM: {target_model} @ {settings.ollama_base_url} [{mode_label}]")
        llm = OllamaLLM(
            model=target_model,
            base_url=settings.ollama_base_url,
            temperature=settings.llm_temperature,
            num_ctx=settings.llm_context_window,
            # Timeout adattivo: piu' alto in modalita' CPU per evitare timeout prematuri
            timeout=settings.effective_timeout,
            # In modalita' CPU: disabilita mirostat per ridurre overhead computazionale
            # mirostat=0 usa il campionamento standard, piu' veloce
            **({"mirostat": 0} if settings.is_cpu_mode else {}),
        )
        # Test connettivita' (prompt minimo per essere veloci anche su CPU)
        llm.invoke("OK")
        logger.success(f"LLM '{target_model}' pronto! [{mode_label}]")
        return llm

    @retry(
        stop=stop_after_attempt(10),
        wait=wait_exponential(multiplier=2, min=4, max=30),
        reraise=True
    )
    def _init_embeddings(self) -> OllamaEmbeddings:
        """Inizializza il modello di embedding con retry automatico."""
        logger.info(f"Caricamento modello embedding: {settings.embedding_model}")
        embeddings = OllamaEmbeddings(
            model=settings.embedding_model,
            base_url=settings.ollama_base_url,
        )
        # Test embedding
        test_vec = embeddings.embed_query("test")
        logger.success(f"Embedding model pronto! Dimensione vettore: {len(test_vec)}")
        return embeddings

    @retry(
        stop=stop_after_attempt(10),
        wait=wait_exponential(multiplier=2, min=2, max=20),
        reraise=True
    )
    def _init_qdrant(self) -> QdrantClient:
        """Connette al client Qdrant con retry automatico."""
        logger.info(f"Connessione a Qdrant: {settings.qdrant_host}:{settings.qdrant_port}")
        client = QdrantClient(
            host=settings.qdrant_host,
            port=settings.qdrant_port,
            api_key=settings.qdrant_api_key,
            https=False,      # forza HTTP — Qdrant gira senza TLS nella rete Docker
            timeout=30,
        )
        # Verifica connessione
        client.get_collections()
        logger.success("Connesso a Qdrant!")
        return client

    def get_llm(self, model_name: Optional[str] = None) -> OllamaLLM:
        """Restituisce l'istanza LLM, inizializzandola se necessario."""
        # Se viene richiesto un modello diverso, crea nuova istanza
        if model_name and model_name != settings.llm_model:
            return self._init_ollama_llm(model_name)
        if self._llm is None:
            self._llm = self._init_ollama_llm()
        return self._llm

    def get_embeddings(self) -> OllamaEmbeddings:
        """Restituisce il modello di embedding, inizializzandolo se necessario."""
        if self._embeddings is None:
            self._embeddings = self._init_embeddings()
        return self._embeddings

    def get_qdrant_client(self) -> QdrantClient:
        """Restituisce il client Qdrant, inizializzandolo se necessario."""
        if self._qdrant_client is None:
            self._qdrant_client = self._init_qdrant()
        return self._qdrant_client

    def get_vector_store(self, collection_name: Optional[str] = None) -> QdrantVectorStore:
        """Restituisce il VectorStore Qdrant per una collezione specifica."""
        target_collection = collection_name or settings.qdrant_collection_name
        return QdrantVectorStore(
            client=self.get_qdrant_client(),
            collection_name=target_collection,
            embedding=self.get_embeddings(),
        )

    async def ensure_collection_exists(self, collection_name: Optional[str] = None):
        """Crea la collezione Qdrant se non esiste già."""
        target_collection = collection_name or settings.qdrant_collection_name
        client = self.get_qdrant_client()

        existing = [c.name for c in client.get_collections().collections]
        if target_collection not in existing:
            logger.info(f"Creazione collezione Qdrant: '{target_collection}'")
            # Ottieni dimensione embedding dal modello
            embeddings = self.get_embeddings()
            sample_vec = embeddings.embed_query("dimensione")
            vector_size = len(sample_vec)

            client.create_collection(
                collection_name=target_collection,
                vectors_config=VectorParams(
                    size=vector_size,
                    distance=Distance.COSINE,   # Cosine similarity per testi
                ),
            )
            logger.success(f"Collezione '{target_collection}' creata (dimensione: {vector_size})")
        else:
            logger.debug(f"Collezione '{target_collection}' già esistente")


# Istanza globale componenti
rag = RagComponents()


# =============================================================================
# UTILITÀ PIPELINE RAG
# =============================================================================

def build_rag_prompt() -> PromptTemplate:
    """
    Costruisce il prompt template per la pipeline RAG.
    Se esiste /app/system_prompt.txt (generato da install.sh durante il
    setup cliente), lo usa come system prompt personalizzato.
    """
    system_prompt_path = Path("/app/system_prompt.txt")
    if system_prompt_path.exists():
        client_system = system_prompt_path.read_text(encoding="utf-8").strip()
        logger.info("System prompt personalizzato caricato da system_prompt.txt")
    else:
        client_system = (
            "Sei un assistente aziendale esperto e preciso. Rispondi alla domanda "
            "dell'utente basandoti ESCLUSIVAMENTE sul contesto documentale fornito di seguito."
        )

    template = f"""{client_system}

REGOLE FONDAMENTALI:
1. Rispondi SOLO con informazioni presenti nel contesto. Non inventare.
2. Se l'informazione non è nel contesto, dillo esplicitamente.
3. Cita la fonte (nome file) quando possibile.
4. Rispondi in modo chiaro e professionale.
5. Struttura la risposta in modo logico, usa elenchi se utile.

--- CONTESTO DOCUMENTALE ---
{{context}}
--- FINE CONTESTO ---

DOMANDA: {{question}}

RISPOSTA:"""

    return PromptTemplate(
        template=template,
        input_variables=["context", "question"]
    )

def get_document_loader(file_path: str, file_ext: str):
    """
    Factory function per selezionare il loader appropriato per tipo file.

    Args:
        file_path: Percorso assoluto al file
        file_ext: Estensione file (es: '.pdf', '.docx')

    Returns:
        Istanza del loader appropriato

    Raises:
        ValueError: Se il tipo di file non è supportato
    """
    loaders = {
        ".pdf":  lambda: PyPDFLoader(file_path),
        ".docx": lambda: Docx2txtLoader(file_path),
        ".doc":  lambda: Docx2txtLoader(file_path),
        ".txt":  lambda: TextLoader(file_path, encoding="utf-8"),
        ".md":   lambda: TextLoader(file_path, encoding="utf-8"),
    }
    if file_ext.lower() not in loaders:
        raise ValueError(f"Formato file non supportato: '{file_ext}'. "
                         f"Formati supportati: {list(loaders.keys())}")
    return loaders[file_ext.lower()]()


async def process_document(
    file_path: str,
    filename: str,
    doc_id: str,
    collection_name: Optional[str] = None,
) -> int:
    """
    Pipeline completa di elaborazione documento:
        1. Caricamento → 2. Chunking → 3. Embedding → 4. Indicizzazione

    Args:
        file_path:       Percorso al file su disco
        filename:        Nome originale del file
        doc_id:          ID univoco assegnato al documento
        collection_name: Collezione Qdrant target (None = default)

    Returns:
        Numero di chunk indicizzati
    """
    file_ext = Path(filename).suffix.lower()
    target_collection = collection_name or settings.qdrant_collection_name

    logger.info(f"[{doc_id}] Avvio elaborazione: '{filename}' → collezione '{target_collection}'")

    # ------------------------------------------------------------------
    # STEP 1: Caricamento documento
    # ------------------------------------------------------------------
    logger.debug(f"[{doc_id}] STEP 1: Caricamento documento...")
    loader = get_document_loader(file_path, file_ext)
    raw_documents = loader.load()
    logger.info(f"[{doc_id}] Caricate {len(raw_documents)} pagine/sezioni")

    # ------------------------------------------------------------------
    # STEP 2: Chunking con RecursiveCharacterTextSplitter
    #
    # RecursiveCharacterTextSplitter prova a dividere il testo usando
    # separatori in ordine: paragrafi → righe → frasi → parole → caratteri
    # Questo preserva la coerenza semantica meglio di un semplice split.
    # ------------------------------------------------------------------
    logger.debug(f"[{doc_id}] STEP 2: Chunking (size={settings.chunk_size}, overlap={settings.chunk_overlap})...")
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=settings.chunk_size,
        chunk_overlap=settings.chunk_overlap,
        separators=["\n\n", "\n", ". ", "! ", "? ", " ", ""],
        length_function=len,
        add_start_index=True,  # Aggiunge metadato con posizione chunk nel documento
    )
    chunks = text_splitter.split_documents(raw_documents)

    # Arricchisci i metadati di ogni chunk
    for i, chunk in enumerate(chunks):
        chunk.metadata.update({
            "doc_id":      doc_id,
            "filename":    filename,
            "file_type":   file_ext,
            "chunk_index": i,
            "total_chunks": len(chunks),
            "indexed_at":  time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        })

    logger.info(f"[{doc_id}] Generati {len(chunks)} chunk dal documento")

    # ------------------------------------------------------------------
    # STEP 3 & 4: Generazione embedding e indicizzazione su Qdrant
    #
    # QdrantVectorStore.from_documents() gestisce internamente:
    #   - Chiamata al modello embedding per ogni chunk
    #   - Inserimento dei vettori nella collezione Qdrant
    # ------------------------------------------------------------------
    logger.debug(f"[{doc_id}] STEP 3+4: Embedding e indicizzazione su Qdrant...")
    await rag.ensure_collection_exists(target_collection)

    vector_store = rag.get_vector_store(target_collection)

    # Indicizzazione in batch per performance ottimale
    batch_size = 50
    total_indexed = 0
    for batch_start in range(0, len(chunks), batch_size):
        batch = chunks[batch_start : batch_start + batch_size]
        await asyncio.to_thread(vector_store.add_documents, batch)
        total_indexed += len(batch)
        logger.debug(f"[{doc_id}] Indicizzati {total_indexed}/{len(chunks)} chunk...")

    # Aggiorna metriche
    CHUNKS_INDEXED.inc(total_indexed)
    DOCUMENTS_UPLOADED.labels(file_type=file_ext).inc()

    logger.success(f"[{doc_id}] ✓ Documento '{filename}' indicizzato: {total_indexed} chunk su Qdrant")
    return total_indexed


async def rag_query(
    question: str,
    collection_name: Optional[str] = None,
    top_k: Optional[int] = None,
    model_name: Optional[str] = None,
) -> dict:
    """
    Esegue una query RAG completa:
        1. Ricerca vettoriale (similarity search)
        2. Costruzione contesto dai chunk più rilevanti
        3. Chiamata LLM con prompt contestuale
        4. Restituzione risposta + metadati fonti

    Args:
        question:        Domanda dell'utente
        collection_name: Collezione Qdrant da interrogare
        top_k:           Numero di chunk da recuperare
        model_name:      Modello LLM da usare

    Returns:
        Dict con: answer, sources, model_used, chunks_retrieved, latency
    """
    start_time = time.time()
    QUERY_REQUESTS.inc()

    k = top_k or settings.top_k_results
    target_collection = collection_name or settings.qdrant_collection_name

    logger.info(f"Query RAG: '{question[:80]}...' | modello: {model_name or settings.llm_model} | k={k}")

    # Assicura che la collezione esista (la crea se non presente)
    await rag.ensure_collection_exists(target_collection)

    # Recupera componenti
    llm = rag.get_llm(model_name)
    vector_store = rag.get_vector_store(target_collection)

    # ------------------------------------------------------------------
    # Ricerca vettoriale: trova i chunk più semanticamente simili
    # ------------------------------------------------------------------
    retriever = vector_store.as_retriever(
        search_type="similarity",
        search_kwargs={
            "k": k,
            "score_threshold": 0.3,  # Filtra chunk con bassa similarità
        },
    )

    # ------------------------------------------------------------------
    # Pipeline RetrievalQA: retrieval + LLM in un'unica chain
    # ------------------------------------------------------------------
    qa_chain = RetrievalQA.from_chain_type(
        llm=llm,
        chain_type="stuff",              # Inserisce tutti i chunk nel prompt
        retriever=retriever,
        return_source_documents=True,    # Restituisce i documenti sorgente
        chain_type_kwargs={
            "prompt": build_rag_prompt(),
            "verbose": False,
        },
    )

    # Esegui in thread separato (operazione bloccante)
    result = await asyncio.to_thread(qa_chain.invoke, {"query": question})

    # Estrai e deduplicata le fonti
    source_docs = result.get("source_documents", [])
    seen_sources = set()
    sources = []
    for doc in source_docs:
        meta = doc.metadata
        source_key = f"{meta.get('filename', 'unknown')}_{meta.get('chunk_index', 0)}"
        if source_key not in seen_sources:
            seen_sources.add(source_key)
            sources.append({
                "filename":    meta.get("filename", "unknown"),
                "doc_id":      meta.get("doc_id", ""),
                "chunk_index": meta.get("chunk_index", 0),
                "page":        meta.get("page", 0),
                "preview":     doc.page_content[:200] + "..." if len(doc.page_content) > 200 else doc.page_content,
            })

    latency = round(time.time() - start_time, 3)
    QUERY_LATENCY.observe(latency)

    logger.success(f"Risposta generata in {latency}s | Fonti: {len(sources)}")

    return {
        "answer":           result["result"],
        "sources":          sources,
        "model_used":       model_name or settings.llm_model,
        "chunks_retrieved": len(source_docs),
        "latency_seconds":  latency,
    }


# =============================================================================
# FASTAPI APP — Lifecycle & Middleware
# =============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gestisce il ciclo di vita dell'applicazione:
    - Avvio: Inizializza connessioni e verifica servizi
    - Shutdown: Cleanup risorse
    """
    mode_label = "LITE (CPU-only)" if settings.is_cpu_mode else "FULL (GPU)"
    logger.info("═" * 60)
    logger.info("  Private Corporate AI — RAG Backend avviato")
    logger.info(f"  Modalita':         {mode_label}")
    logger.info(f"  LLM Model:        {settings.llm_model}")
    logger.info(f"  Embedding Model:  {settings.embedding_model}")
    logger.info(f"  Qdrant:           {settings.qdrant_host}:{settings.qdrant_port}")
    logger.info(f"  Collection:       {settings.qdrant_collection_name}")
    logger.info(f"  Timeout LLM:      {settings.effective_timeout}s")
    if settings.is_cpu_mode:
        logger.warning("  ⚠  Modalita' LITE attiva: risposte piu' lente (30-300s attesi)")
        logger.warning("  ⚠  Usa modelli quantizzati (q4_K_M) per performance migliori")
    logger.info("═" * 60)

    # Crea directory upload se non esiste
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
    logger.info(f"Directory upload: {settings.upload_dir}")

    # Inizializzazione lazy — i componenti si connettono alla prima richiesta
    # per non bloccare l'avvio se Ollama/Qdrant non sono ancora pronti
    logger.info("Componenti RAG in modalità lazy-init (si connettono alla prima richiesta)")

    yield  # App in esecuzione

    logger.info("Shutdown RAG Backend — cleanup completato")


# Configurazione applicazione
app = FastAPI(
    title="Private Corporate AI — RAG Backend",
    description="Pipeline RAG per documenti aziendali privati con LangChain + Ollama + Qdrant",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS — configura domini permessi in produzione
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],     # ⚠️ Restringere in produzione a domini specifici
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =============================================================================
# ENDPOINT — Health & Monitoring
# =============================================================================

@app.get("/api/health", response_model=HealthResponse, tags=["Sistema"])
async def health_check():
    """
    Verifica lo stato di salute del servizio e delle sue dipendenze.
    Utilizzato da Docker Healthcheck e sistemi di monitoring.
    """
    ollama_ok = False
    qdrant_ok = False

    # Test connessione Ollama
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{settings.ollama_base_url}/api/version")
            ollama_ok = resp.status_code == 200
    except Exception as e:
        logger.warning("Healthcheck Ollama fallito: {}", str(e))

    # Test connessione Qdrant
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(
                f"http://{settings.qdrant_host}:{settings.qdrant_port}/healthz"
            )
            qdrant_ok = resp.status_code == 200
    except Exception as e:
        logger.warning("Healthcheck Qdrant fallito: {}", str(e))

    overall_status = "healthy" if (ollama_ok and qdrant_ok) else "degraded"

    return HealthResponse(
        status=overall_status,
        deploy_mode=settings.deploy_mode,
        ollama_connected=ollama_ok,
        qdrant_connected=qdrant_ok,
        model_loaded=settings.llm_model,
        embedding_model=settings.embedding_model,
        collection_name=settings.qdrant_collection_name,
        timeout_seconds=settings.effective_timeout,
    )


@app.get("/metrics", tags=["Sistema"])
async def metrics():
    """Espone metriche in formato Prometheus per monitoring esterno."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/api/client/info", tags=["Sistema"])
async def get_client_info():
    """Restituisce le informazioni di personalizzazione del cliente."""
    return {
        "company": settings.client_company,
        "slug": settings.client_slug,
        "industry": settings.client_industry,
        "domain": settings.client_domain,
        "language": settings.client_language,
        "lang_code": settings.client_lang_code,
        "theme_color": settings.client_theme_color,
        "theme_name": settings.client_theme_name,
    }


# =============================================================================
# ENDPOINT — Gestione Documenti
# =============================================================================

@app.post("/api/documents/upload", tags=["Documenti"])
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(..., description="Documento da indicizzare (PDF, DOCX, TXT)"),
    collection_name: Optional[str] = None,
):
    """
    Carica e indicizza un documento nella pipeline RAG.

    Il documento viene:
    1. Salvato su disco
    2. Elaborato in background (chunking + embedding + indicizzazione)
    3. Reso disponibile per le query RAG

    Formati supportati: PDF, DOCX, DOC, TXT, MD
    """
    # Validazione tipo file
    allowed_extensions = {".pdf", ".docx", ".doc", ".txt", ".md"}
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Formato '{file_ext}' non supportato. Usa: {allowed_extensions}"
        )

    # Validazione dimensione (max 50MB)
    max_size_bytes = 50 * 1024 * 1024
    content = await file.read()
    if len(content) > max_size_bytes:
        raise HTTPException(
            status_code=413,
            detail=f"File troppo grande ({len(content)/1024/1024:.1f}MB). Max: 50MB"
        )

    # Salva file con ID univoco
    doc_id = str(uuid.uuid4())
    safe_filename = f"{doc_id}_{file.filename}"
    file_path = os.path.join(settings.upload_dir, safe_filename)

    async with aiofiles.open(file_path, "wb") as f:
        await f.write(content)

    logger.info(f"File salvato: {safe_filename} ({len(content)/1024:.1f}KB)")

    # Avvia elaborazione in background
    background_tasks.add_task(
        process_document,
        file_path=file_path,
        filename=file.filename,
        doc_id=doc_id,
        collection_name=collection_name,
    )

    return JSONResponse(
        status_code=202,
        content={
            "message":         "Documento ricevuto e in elaborazione",
            "doc_id":          doc_id,
            "filename":        file.filename,
            "size_bytes":      len(content),
            "collection":      collection_name or settings.qdrant_collection_name,
            "status":          "processing",
            "note":            "L'indicizzazione avviene in background. Attendere prima di interrogare il documento.",
        }
    )


@app.get("/api/documents/list", tags=["Documenti"])
async def list_documents(collection_name: Optional[str] = None):
    """
    Lista tutti i documenti indicizzati nella collezione specificata.
    Recupera i metadati direttamente da Qdrant.
    """
    target_collection = collection_name or settings.qdrant_collection_name

    try:
        client = rag.get_qdrant_client()

        # Verifica che la collezione esista
        existing = [c.name for c in client.get_collections().collections]
        if target_collection not in existing:
            return {"documents": [], "total": 0, "collection": target_collection}

        # Recupera punti con payload (scroll = paginazione completa)
        all_points, _ = client.scroll(
            collection_name=target_collection,
            limit=10000,
            with_payload=True,
            with_vectors=False,
        )

        # Aggrega per doc_id (un documento = molti chunk)
        docs_map = {}
        for point in all_points:
            payload = point.payload or {}
            # Cerca metadati sia in 'metadata' (LangChain) che nel payload radice
            meta = payload.get("metadata", payload)
            
            # Prova diverse chiavi comuni
            doc_id = meta.get("doc_id", payload.get("doc_id", "unknown"))
            filename = meta.get("filename", payload.get("filename", "unknown"))
            
            if doc_id not in docs_map:
                docs_map[doc_id] = {
                    "doc_id":       doc_id,
                    "filename":     filename,
                    "file_type":    meta.get("file_type", payload.get("file_type", "")),
                    "chunks_count": 0,
                    "indexed_at":   meta.get("indexed_at", payload.get("indexed_at", "")),
                }
            docs_map[doc_id]["chunks_count"] += 1

        if not docs_map:
            logger.warning(f"Nessun documento trovato nella collezione {target_collection} (su {len(all_points)} punti)")
        else:
            first_doc = list(docs_map.values())[0]
            logger.debug(f"Esempio documento trovato: {first_doc}")

        documents = sorted(
            docs_map.values(),
            key=lambda x: x["indexed_at"],
            reverse=True
        )

        return {
            "documents":  documents,
            "total":      len(documents),
            "collection": target_collection,
        }

    except Exception as e:
        logger.error("Errore recupero lista documenti: {}", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@app.put("/api/documents/{doc_id}/domain", tags=["Gestione Domini"])
async def move_document_domain(doc_id: str, request: MoveDomainRequest):
    """Sposta tutti i chunk di un documento da una collezione a un'altra."""
    source_collection = request.source_collection or settings.qdrant_collection_name
    target_collection = request.target_collection
    
    if source_collection == target_collection:
        raise HTTPException(400, "La collezione sorgente e target sono identiche")

    try:
        client = rag.get_qdrant_client()
        
        # 1. Verifica esistenza target
        await rag.ensure_collection_exists(target_collection)
        
        # 2. Leggi tutti i punti dalla sorgente
        points, _ = client.scroll(
            collection_name=source_collection,
            scroll_filter=Filter(must=[FieldCondition(key="doc_id", match=MatchValue(value=doc_id))]),
            limit=10000,
            with_payload=True,
            with_vectors=True,
        )
        
        if not points:
            raise HTTPException(404, f"Documento {doc_id} non trovato in {source_collection}")
            
        # 3. Inserisci nel target
        client.upsert(
            collection_name=target_collection,
            points=points
        )
        
        # 4. Elimina dalla sorgente
        client.delete(
            collection_name=source_collection,
            points_selector=PointIdsList(points=[p.id for p in points]),
        )
        
        return {
            "moved_chunks": len(points),
            "source_collection": source_collection,
            "target_collection": target_collection
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Errore spostamento documento {doc_id}: {str(e)}")
        raise HTTPException(500, str(e))


@app.post("/api/documents/{doc_id}/reindex", tags=["Gestione Domini"])
async def reindex_document(doc_id: str, background_tasks: BackgroundTasks, collection_name: Optional[str] = None):
    """Forza la re-indicizzazione di un documento esistente."""
    target_collection = collection_name or settings.qdrant_collection_name
    
    try:
        client = rag.get_qdrant_client()
        
        # Trova filename originale
        points, _ = client.scroll(
            collection_name=target_collection,
            scroll_filter=Filter(must=[FieldCondition(key="doc_id", match=MatchValue(value=doc_id))]),
            limit=1,
            with_payload=True
        )
        
        if not points:
            raise HTTPException(404, f"Documento {doc_id} non trovato")
            
        filename = points[0].payload.get("filename")
        # Il file salvato ha il prefisso doc_id_
        safe_filename = f"{doc_id}_{filename}"
        file_path = os.path.join(settings.upload_dir, safe_filename)
        
        if not os.path.exists(file_path):
            raise HTTPException(410, f"File fisico {filename} non più presente sul server")
            
        # Elimina punti esistenti
        client.delete(
            collection_name=target_collection,
            points_selector=Filter(must=[FieldCondition(key="doc_id", match=MatchValue(value=doc_id))])
        )
        
        # Avvia re-indicizzazione
        background_tasks.add_task(
            process_document,
            file_path=file_path,
            filename=filename,
            doc_id=doc_id,
            collection_name=target_collection
        )
        
        return {"reindexing": True, "doc_id": doc_id, "filename": filename}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Errore re-indicizzazione {doc_id}: {str(e)}")
        raise HTTPException(500, str(e))


@app.get("/api/domains", tags=["Gestione Domini"])
async def list_domains():
    """Elenca tutti i domini (collezioni) e relative statistiche."""
    try:
        client = rag.get_qdrant_client()
        collections = client.get_collections().collections
        
        domains = []
        for coll in collections:
            info = client.get_collection(coll.name)
            
            # Leggi ultimo timestamp
            points, _ = client.scroll(
                collection_name=coll.name,
                limit=1,
                with_payload=True,
                with_vectors=False
            )
            
            last_updated = points[0].payload.get("indexed_at") if points else None
            
            domains.append({
                "name": coll.name,
                "vectors_count": info.vectors_count,
                "points_count": info.points_count,
                "last_updated": last_updated
            })
            
        return domains
    except Exception as e:
        logger.error(f"Errore lista domini: {str(e)}")
        raise HTTPException(500, str(e))


@app.post("/api/domains", tags=["Gestione Domini"])
async def create_domain(request: DomainCreateRequest):
    """Crea una nuova collezione Qdrant."""
    try:
        client = rag.get_qdrant_client()
        existing = [c.name for c in client.get_collections().collections]
        
        if request.name in existing:
            raise HTTPException(409, "Collezione già esistente")
            
        await rag.ensure_collection_exists(request.name)
        return {"name": request.name, "created": True}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Errore creazione dominio {request.name}: {str(e)}")
        raise HTTPException(500, str(e))


@app.delete("/api/domains/{domain_name}", tags=["Gestione Domini"])
async def delete_domain(domain_name: str):
    """Elimina un dominio e tutti i suoi dati."""
    if domain_name == settings.qdrant_collection_name:
        raise HTTPException(403, "La collezione default non può essere eliminata")
        
    try:
        client = rag.get_qdrant_client()
        client.delete_collection(domain_name)
        return {"deleted": True, "name": domain_name}
    except Exception as e:
        # Se 404 Qdrant
        if "not found" in str(e).lower():
            raise HTTPException(404, "Dominio non trovato")
        logger.error(f"Errore eliminazione dominio {domain_name}: {str(e)}")
        raise HTTPException(500, str(e))


@app.delete("/api/documents/{doc_id}", tags=["Documenti"])
async def delete_document(doc_id: str, collection_name: Optional[str] = None):
    """
    Rimuove tutti i chunk di un documento dall'indice Qdrant.
    Il file fisico NON viene eliminato (audit trail).
    """
    target_collection = collection_name or settings.qdrant_collection_name

    try:
        client = rag.get_qdrant_client()

        # Cerca tutti i chunk con questo doc_id
        points, _ = client.scroll(
            collection_name=target_collection,
            scroll_filter={
                "must": [{"key": "doc_id", "match": {"value": doc_id}}]
            },
            limit=10000,
            with_payload=False,
            with_vectors=False,
        )

        if not points:
            raise HTTPException(
                status_code=404,
                detail=f"Documento '{doc_id}' non trovato nella collezione '{target_collection}'"
            )

        point_ids = [p.id for p in points]
        client.delete(
            collection_name=target_collection,
            points_selector=PointIdsList(points=point_ids),
        )

        logger.info(f"Documento {doc_id} rimosso: {len(point_ids)} chunk eliminati")

        return {
            "message":       f"Documento rimosso con successo",
            "doc_id":        doc_id,
            "chunks_deleted": len(point_ids),
            "collection":    target_collection,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Errore eliminazione documento {doc_id}: {}", str(e))
        raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# ENDPOINT — Chat RAG
# =============================================================================

@app.post("/api/chat", response_model=ChatResponse, tags=["Chat"])
async def chat_with_docs(request: ChatRequest):
    """
    Endpoint principale per la chat RAG con i documenti aziendali.

    Flusso:
        1. Ricezione domanda
        2. Ricerca semantica nei chunk indicizzati
        3. Costruzione contesto
        4. Risposta LLM basata sui documenti
        5. Restituzione risposta + riferimenti alle fonti
    """
    try:
        result = await rag_query(
            question=request.question,
            collection_name=request.collection_name,
            top_k=request.top_k,
            model_name=request.model,
        )
        return ChatResponse(**result)

    except Exception as e:
        logger.error("Errore query RAG: {}", str(e),  exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Errore durante l'elaborazione della query: {str(e)}"
        )


@app.post("/v1/chat/completions", tags=["OpenAI Compatible API"])
async def openai_compatible_chat(request: OpenAIChatRequest):
    """
    Endpoint compatibile con le API OpenAI.
    Permette l'integrazione con Open WebUI e altri client OpenAI-compatibili.

    Il backend RAG viene usato automaticamente quando ci sono documenti indicizzati.
    """
    # Estrai l'ultimo messaggio utente
    user_messages = [m for m in request.messages if m.role == "user"]
    if not user_messages:
        raise HTTPException(status_code=400, detail="Nessun messaggio utente trovato")

    question = user_messages[-1].content

    try:
        result = await rag_query(question=question)

        # Formatta risposta in stile OpenAI
        return {
            "id":      f"chatcmpl-{uuid.uuid4().hex[:8]}",
            "object":  "chat.completion",
            "created": int(time.time()),
            "model":   result["model_used"],
            "choices": [
                {
                    "index":         0,
                    "message":       {
                        "role":    "assistant",
                        "content": result["answer"],
                    },
                    "finish_reason": "stop",
                }
            ],
            "usage": {
                "prompt_tokens":     len(question.split()),
                "completion_tokens": len(result["answer"].split()),
                "total_tokens":      len(question.split()) + len(result["answer"].split()),
            },
            # Metadati aggiuntivi RAG (non standard OpenAI)
            "rag_metadata": {
                "sources":          result["sources"],
                "chunks_retrieved": result["chunks_retrieved"],
                "latency_seconds":  result["latency_seconds"],
            },
        }

    except Exception as e:
        logger.error("Errore endpoint OpenAI-compat: {}", str(e), exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


# =============================================================================
# ENDPOINT — OpenAI Compatible Models List
# =============================================================================

@app.get("/v1/models", tags=["OpenAI Compatible API"])
async def openai_list_models():
    """
    Lista modelli nel formato OpenAI — richiesto da Open WebUI per popolare
    il selettore modelli quando il RAG Backend è configurato come provider OpenAI.
    Espone i modelli Ollama disponibili più un modello virtuale 'rag' che
    rappresenta la pipeline RAG completa.
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"{settings.ollama_base_url}/api/tags")
            ollama_models = resp.json().get("models", [])
    except Exception:
        ollama_models = []

    # Modello virtuale che rappresenta la pipeline RAG completa
    rag_model = {
        "id":       "private-rag",
        "object":   "model",
        "created":  0,
        "owned_by": "private-corporate-ai",
        "description": "Pipeline RAG completa — risponde usando i documenti aziendali indicizzati",
    }

    # Modelli Ollama disponibili (filtrati: esclude embedding)
    embed_keywords = ["embed", "nomic", "minilm", "bge", "e5-"]
    chat_models = [
        {
            "id":       m["name"],
            "object":   "model",
            "created":  0,
            "owned_by": "ollama",
        }
        for m in ollama_models
        if not any(kw in m["name"].lower() for kw in embed_keywords)
    ]

    return {
        "object": "list",
        "data":   [rag_model] + chat_models,
    }


# =============================================================================
# ENDPOINT — Gestione Modelli (Utilità)
# =============================================================================

@app.get("/api/models/available", tags=["Modelli"])
async def list_available_models():
    """
    Lista i modelli LLM disponibili su Ollama.
    Utile per cambiare dinamicamente il modello usato nelle query.
    """
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"{settings.ollama_base_url}/api/tags")
            resp.raise_for_status()
            data = resp.json()

        models = [
            {
                "name":         m["name"],
                "size_gb":      round(m.get("size", 0) / 1e9, 2),
                "modified_at":  m.get("modified_at", ""),
                "is_current":   m["name"] == settings.llm_model,
            }
            for m in data.get("models", [])
        ]

        return {
            "models":        models,
            "current_model": settings.llm_model,
            "total":         len(models),
        }

    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"Impossibile recuperare lista modelli da Ollama: {str(e)}"
        )


# =============================================================================
# ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,       # Hot-reload in sviluppo (rimuovere in produzione)
        log_level=settings.log_level.lower(),
    )
