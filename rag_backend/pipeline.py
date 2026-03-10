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

from config import settings, CHUNKS_INDEXED, DOCUMENTS_UPLOADED, QUERY_REQUESTS, QUERY_LATENCY
from core import rag

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
    }
    return loaders[file_ext.lower()]()

async def process_document(file_path: str, filename: str, doc_id: str, collection_name: Optional[str] = None) -> int:
    file_ext = Path(filename).suffix.lower()
    target_collection = collection_name or settings.qdrant_collection_name
    
    loader = get_document_loader(file_path, file_ext)
    raw_documents = loader.load()
    
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=settings.chunk_size,
        chunk_overlap=settings.chunk_overlap,
        add_start_index=True,
    )
    chunks = text_splitter.split_documents(raw_documents)

    for i, chunk in enumerate(chunks):
        chunk.metadata.update({
            "doc_id":      doc_id,
            "filename":    filename,
            "file_type":   file_ext,
            "chunk_index": i,
            "indexed_at":  time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
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

async def rag_query(question: str, collection_name: Optional[str] = None, top_k: Optional[int] = None, model_name: Optional[str] = None) -> dict:
    start_time = time.time()
    QUERY_REQUESTS.inc()
    target_collection = collection_name or settings.qdrant_collection_name
    
    await rag.ensure_collection_exists(target_collection)
    llm = rag.get_llm(model_name)
    vector_store = rag.get_vector_store(target_collection)

    retriever = vector_store.as_retriever(search_kwargs={"k": top_k or settings.top_k_results, "score_threshold": 0.3})
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
