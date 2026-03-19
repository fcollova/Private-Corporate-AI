# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Core RAG components initialization including LLM, Embeddings, and Vector Store.
# =============================================================================

from typing import Optional
from loguru import logger
from tenacity import retry, stop_after_attempt, wait_exponential
from langchain_ollama import OllamaLLM, OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore, RetrievalMode

# Importazione robusta per FastEmbedSparseEmbeddings
try:
    from langchain_qdrant import FastEmbedSparseEmbeddings
except ImportError:
    try:
        from langchain_qdrant.fastembed_sparse import FastEmbedSparseEmbeddings
    except ImportError:
        # Fallback se non disponibile (vecchie versioni o installazione incompleta)
        FastEmbedSparseEmbeddings = None

from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, SparseVectorParams, SparseIndexParams

from config import settings

class RagComponents:
    def __init__(self):
        self._llm: Optional[OllamaLLM] = None
        self._embeddings: Optional[OllamaEmbeddings] = None
        self._sparse_embeddings: Optional[FastEmbedSparseEmbeddings] = None
        self._qdrant_client: Optional[QdrantClient] = None

    @retry(stop=stop_after_attempt(10), wait=wait_exponential(multiplier=2, min=4, max=30), reraise=True)
    def _init_ollama_llm(self, model_name: Optional[str] = None) -> OllamaLLM:
        target_model = model_name or settings.llm_model
        llm = OllamaLLM(
            model=target_model,
            base_url=settings.ollama_base_url,
            temperature=settings.llm_temperature,
            num_ctx=settings.llm_context_window,
            timeout=settings.effective_timeout,
        )
        llm.invoke("OK")
        return llm

    @retry(stop=stop_after_attempt(10), wait=wait_exponential(multiplier=2, min=4, max=30), reraise=True)
    def _init_embeddings(self) -> OllamaEmbeddings:
        embeddings = OllamaEmbeddings(
            model=settings.embedding_model,
            base_url=settings.ollama_base_url,
        )
        embeddings.embed_query("test")
        return embeddings

    def _init_sparse_embeddings(self) -> Optional[object]:
        if FastEmbedSparseEmbeddings is None:
            logger.error("FastEmbedSparseEmbeddings non disponibile. Hybrid Search disabilitata.")
            return None
        logger.info("Inizializzazione Sparse Embeddings (BM25)...")
        # Usiamo BM25 per una ricerca full-text affidabile
        return FastEmbedSparseEmbeddings(model_name="Qdrant/bm25")

    @retry(stop=stop_after_attempt(10), wait=wait_exponential(multiplier=2, min=2, max=20), reraise=True)
    def _init_qdrant(self) -> QdrantClient:
        client = QdrantClient(
            host=settings.qdrant_host,
            port=settings.qdrant_port,
            api_key=settings.qdrant_api_key,
            https=False,
            timeout=30,
        )
        client.get_collections()
        return client

    def get_llm(self, model_name: Optional[str] = None) -> OllamaLLM:
        if model_name and model_name != settings.llm_model:
            return self._init_ollama_llm(model_name)
        if self._llm is None:
            self._llm = self._init_ollama_llm()
        return self._llm

    def get_embeddings(self) -> OllamaEmbeddings:
        if self._embeddings is None:
            self._embeddings = self._init_embeddings()
        return self._embeddings

    def get_sparse_embeddings(self) -> FastEmbedSparseEmbeddings:
        if self._sparse_embeddings is None:
            self._sparse_embeddings = self._init_sparse_embeddings()
        return self._sparse_embeddings

    def get_qdrant_client(self) -> QdrantClient:
        if self._qdrant_client is None:
            self._qdrant_client = self._init_qdrant()
        return self._qdrant_client

    def get_vector_store(self, collection_name: Optional[str] = None) -> QdrantVectorStore:
        target_collection = collection_name or settings.qdrant_collection_name
        sparse_embeddings = self.get_sparse_embeddings()
        
        if settings.hybrid_search_enabled and sparse_embeddings is not None:
            return QdrantVectorStore(
                client=self.get_qdrant_client(),
                collection_name=target_collection,
                embedding=self.get_embeddings(),
                sparse_embedding=sparse_embeddings,
                sparse_vector_name="text-sparse",
                retrieval_mode=RetrievalMode.HYBRID,
            )
        
        return QdrantVectorStore(
            client=self.get_qdrant_client(),
            collection_name=target_collection,
            embedding=self.get_embeddings(),
        )

    async def ensure_collection_exists(self, collection_name: Optional[str] = None):
        target_collection = collection_name or settings.qdrant_collection_name
        client = self.get_qdrant_client()
        existing = [c.name for c in client.get_collections().collections]
        if target_collection not in existing:
            embeddings = self.get_embeddings()
            sample_vec = embeddings.embed_query("dimensione")
            
            sparse_config = None
            if settings.hybrid_search_enabled and FastEmbedSparseEmbeddings is not None:
                sparse_config = {
                    "text-sparse": SparseVectorParams(
                        index=SparseIndexParams(on_disk=True)
                    )
                }
            
            client.create_collection(
                collection_name=target_collection,
                vectors_config=VectorParams(size=len(sample_vec), distance=Distance.COSINE),
                sparse_vectors_config=sparse_config
            )

rag = RagComponents()
