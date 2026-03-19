# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Document processing pipeline and RAG query logic.
# =============================================================================

import os
import time
import asyncio
from pathlib import Path
from typing import Optional
from loguru import logger
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA
from langchain.prompts import PromptTemplate
from langchain_community.document_loaders import PyPDFLoader, Docx2txtLoader, TextLoader
from markitdown import MarkItDown
from langchain.schema import Document

from config import settings, CHUNKS_INDEXED, DOCUMENTS_UPLOADED, QUERY_REQUESTS, QUERY_LATENCY
from core import rag

class MarkItDownLoader:
    """Wrapper per caricare documenti usando Microsoft MarkItDown e convertirli in LangChain Documents."""
    def __init__(self, file_path: str):
        self.file_path = file_path
        self.md = MarkItDown()

    def load(self) -> list[Document]:
        try:
            result = self.md.convert(self.file_path)
            return [Document(page_content=result.text_content, metadata={"source": self.file_path})]
        except Exception as e:
            logger.error(f"Errore durante la conversione MarkItDown per {self.file_path}: {e}")
            raise

def build_rag_prompt() -> PromptTemplate:
    system_prompt_path = Path("/app/system_prompt.txt")
    if system_prompt_path.exists():
        client_system = system_prompt_path.read_text(encoding="utf-8").strip()
    else:
        client_system = "Sei un assistente aziendale esperto. Rispondi basandoti sul contesto fornito."

    template = f"""{client_system}
--- CONTESTO ---
{{context}}
--- FINE ---
DOMANDA: {{question}}
RISPOSTA:"""
    return PromptTemplate(template=template, input_variables=["context", "question"])

def get_document_loader(file_path: str, file_ext: str):
    loaders = {
        ".pdf":  lambda: PyPDFLoader(file_path),
        ".docx": lambda: Docx2txtLoader(file_path),
        ".doc":  lambda: Docx2txtLoader(file_path),
        ".txt":  lambda: TextLoader(file_path, encoding="utf-8"),
        ".md":   lambda: TextLoader(file_path, encoding="utf-8"),
        ".xlsx": lambda: MarkItDownLoader(file_path),
        ".pptx": lambda: MarkItDownLoader(file_path),
    }
    ext = file_ext.lower()
    if ext not in loaders:
        raise ValueError(f"Formato file non supportato: {ext}")
    return loaders[ext]()

async def generate_contextual_prefix(full_text: str, chunk_content: str, filename: str) -> str:
    """
    Genera un prefisso di contesto per il chunk utilizzando l'LLM locale.
    Implementazione ispirata alla tecnica 'Contextual Retrieval' di Anthropic.
    """
    llm = rag.get_llm()
    # Limitiamo il testo completo per evitare di superare la context window dell'LLM di supporto
    doc_context = full_text[:4000] 
    
    prompt = f"""Analizza questo estratto dal documento '{filename}'.
DOCUMENTO INTERO (estratto):
{doc_context}
---
ESTRATTO SPECIFICO:
{chunk_content}
---
Fornisci una brevissima frase (massimo 15 parole) che spieghi a quale sezione appartiene l'estratto e il suo contesto generale nel documento.
RISPOSTA:"""
    
    try:
        # Usiamo un timeout ridotto per non rallentare troppo l'indicizzazione
        context = await asyncio.to_thread(llm.invoke, prompt)
        return f"[CONTESTO: {context.strip()}] "
    except Exception as e:
        logger.warning(f"Errore generazione contesto per chunk: {e}")
        return ""

async def process_document(file_path: str, filename: str, doc_id: str, collection_name: Optional[str] = None) -> int:
    try:
        file_ext = Path(filename).suffix.lower()
        target_collection = collection_name or settings.qdrant_collection_name
        
        loader = get_document_loader(file_path, file_ext)
        raw_documents = loader.load()
        full_doc_text = "\n".join([doc.page_content for doc in raw_documents])
        
        # Chunking Semantico: Privilegiamo la divisione per paragrafi e sezioni logiche
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=settings.chunk_size,
            chunk_overlap=settings.chunk_overlap,
            separators=["\n\n\n", "\n\n", "\n", ". ", "? ", "! ", " ", ""],
            add_start_index=True,
        )
        chunks = text_splitter.split_documents(raw_documents)

        # Applicazione Contextual Retrieval
        logger.info(f"Generazione contesto per {len(chunks)} chunk di {filename}...")
        for i, chunk in enumerate(chunks):
            prefix = await generate_contextual_prefix(full_doc_text, chunk.page_content, filename)
            chunk.page_content = prefix + chunk.page_content
            
            chunk.metadata.update({
                "doc_id":      doc_id,
                "filename":    filename,
                "file_type":   file_ext,
                "chunk_index": i,
                "indexed_at":  time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "has_context": True if prefix else False
            })

        await rag.ensure_collection_exists(target_collection)
        vector_store = rag.get_vector_store(target_collection)

        batch_size = 50
        total_indexed = 0
        for i in range(0, len(chunks), batch_size):
            batch = chunks[i : i + batch_size]
            await asyncio.to_thread(vector_store.add_documents, batch)
            total_indexed += len(batch)

        CHUNKS_INDEXED.inc(total_indexed)
        DOCUMENTS_UPLOADED.labels(file_type=file_ext).inc()
        return total_indexed
    except Exception as e:
        logger.error(f"Errore irreversibile nell'indicizzazione di {filename}: {e}")
        # In una versione più avanzata, potremmo aggiornare uno stato nel DB per il doc_id
        return 0

async def rag_query(question: str, collection_name: Optional[str] = None, top_k: Optional[int] = None, model_name: Optional[str] = None) -> dict:
    start_time = time.time()
    QUERY_REQUESTS.inc()
    target_collection = collection_name or settings.qdrant_collection_name
    
    await rag.ensure_collection_exists(target_collection)
    llm = rag.get_llm(model_name)
    vector_store = rag.get_vector_store(target_collection)

    # Verifica se Hybrid Search è realmente disponibile nel core
    is_hybrid_available = settings.hybrid_search_enabled and rag.get_sparse_embeddings() is not None
    
    search_type = "hybrid" if is_hybrid_available else "similarity"
    search_kwargs = {"k": top_k or settings.top_k_results}
    
    # Lo score threshold ha senso principalmente per similarity search pura
    if not is_hybrid_available:
        search_kwargs["score_threshold"] = 0.3

    retriever = vector_store.as_retriever(search_type=search_type, search_kwargs=search_kwargs)
    qa_chain = RetrievalQA.from_chain_type(
        llm=llm, chain_type="stuff", retriever=retriever, 
        return_source_documents=True,
        chain_type_kwargs={"prompt": build_rag_prompt()}
    )

    result = await asyncio.to_thread(qa_chain.invoke, {"query": question})
    
    sources = []
    seen = set()
    for doc in result.get("source_documents", []):
        meta = doc.metadata
        sid = f"{meta.get('filename')}_{meta.get('chunk_index')}"
        if sid not in seen:
            seen.add(sid)
            sources.append({
                "filename": meta.get("filename"),
                "doc_id": meta.get("doc_id"),
                "preview": doc.page_content[:200]
            })

    latency = round(time.time() - start_time, 3)
    QUERY_LATENCY.observe(latency)
    return {
        "answer": result["result"],
        "sources": sources,
        "model_used": model_name or settings.llm_model,
        "chunks_retrieved": len(result.get("source_documents", [])),
        "latency_seconds": latency,
    }
