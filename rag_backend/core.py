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
from langchain.embeddings import CacheBackedEmbeddings
from langchain.storage import RedisStore

# Importazione robusta per FastEmbedSparse (precedentemente FastEmbedSparseEmbeddings)
try:
    from langchain_qdrant import FastEmbedSparse
except ImportError:
    try:
        from langchain_qdrant import FastEmbedSparseEmbeddings as FastEmbedSparse
    except ImportError:
        try:
            from langchain_qdrant.fastembed_sparse import FastEmbedSparseEmbeddings as FastEmbedSparse
        except ImportError:
            # Fallback se non disponibile (vecchie versioni o installazione incompleta)
            FastEmbedSparse = None

from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, SparseVectorParams, SparseIndexParams

from config import settings

class RagComponents:
    def __init__(self):
        self._llm: Optional[OllamaLLM] = None
        self._embeddings: Optional[OllamaEmbeddings] = None
        self._sparse_embeddings: Optional[object] = None
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
        base_embeddings = OllamaEmbeddings(
            model=settings.embedding_model,
            base_url=settings.ollama_base_url,
        )
        
        if settings.embedding_cache_enabled:
            try:
                logger.info(f"Abilitazione cache embedding su Redis: {settings.redis_url}")
                # Store per i vettori su Redis
                store = RedisStore(redis_url=settings.redis_url, namespace="embeddings")
                cached_embeddings = CacheBackedEmbeddings.from_bytes_store(
                    underlying_embeddings=base_embeddings,
                    document_embedding_cache=store,
                    namespace=base_embeddings.model
                )
                # Verifica connettività (opzionale)
                cached_embeddings.embed_query("test-cache")
                return cached_embeddings
            except Exception as e:
                logger.error(f"Errore inizializzazione cache Redis: {e}. Procedo senza cache.")
        
        base_embeddings.embed_query("test")
        return base_embeddings

    def _init_sparse_embeddings(self) -> Optional[object]:
        if FastEmbedSparse is None:
            logger.error("FastEmbedSparse non disponibile. Hybrid Search disabilitata.")
            return None
        logger.info("Inizializzazione Sparse Embeddings (BM25)...")
        # Usiamo BM25 per una ricerca full-text affidabile
        return FastEmbedSparse(model_name="Qdrant/bm25")

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

    def get_sparse_embeddings(self) -> Optional[object]:
        if self._sparse_embeddings is None:
            self._sparse_embeddings = self._init_sparse_embeddings()
        return self._sparse_embeddings

    def get_qdrant_client(self) -> QdrantClient:
        if self._qdrant_client is None:
            self._qdrant_client = self._init_qdrant()
        return self._qdrant_client

    def _collection_has_sparse_vectors(self, collection_name: str) -> bool:
        """Verifica se la collection Qdrant ha vettori sparse configurati."""
        try:
            client = self.get_qdrant_client()
            info = client.get_collection(collection_name)
            sparse_vectors = getattr(info.config.params, "sparse_vectors", None)
            return bool(sparse_vectors and "text-sparse" in sparse_vectors)
        except Exception:
            return False

    def get_vector_store(self, collection_name: Optional[str] = None) -> QdrantVectorStore:
        target_collection = collection_name or settings.qdrant_collection_name
        sparse_embeddings = self.get_sparse_embeddings()

        use_hybrid = (
            settings.hybrid_search_enabled
            and sparse_embeddings is not None
            and self._collection_has_sparse_vectors(target_collection)
        )

        if use_hybrid:
            return QdrantVectorStore(
                client=self.get_qdrant_client(),
                collection_name=target_collection,
                embedding=self.get_embeddings(),
                sparse_embedding=sparse_embeddings,
                sparse_vector_name="text-sparse",
                retrieval_mode=RetrievalMode.HYBRID,
            )

        if settings.hybrid_search_enabled and sparse_embeddings is not None:
            logger.warning(
                f"Collection '{target_collection}' non ha vettori sparse. "
                "Fallback a dense-only. Re-indicizza i documenti per abilitare la Hybrid Search."
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
            if settings.hybrid_search_enabled and FastEmbedSparse is not None:
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
