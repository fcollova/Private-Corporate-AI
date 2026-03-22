import pytest
import asyncio
from unittest.mock import MagicMock, patch, AsyncMock
from pathlib import Path
from pipeline import get_document_loader, MarkItDownLoader, MarkdownPDFLoader
from models import DocumentStatus, Document as SQLDocument
from sqlalchemy import select

def test_get_document_loader_pdf():
    loader = get_document_loader("test.pdf", ".pdf")
    assert isinstance(loader, MarkdownPDFLoader)

def test_get_document_loader_docx():
    # Ora DOCX usa MarkItDownLoader
    loader = get_document_loader("test.docx", ".docx")
    assert isinstance(loader, MarkItDownLoader)

def test_get_document_loader_xlsx():
    loader = get_document_loader("test.xlsx", ".xlsx")
    assert isinstance(loader, MarkItDownLoader)

def test_get_document_loader_unsupported():
    with pytest.raises(ValueError, match="Formato file non supportato"):
        get_document_loader("test.exe", ".exe")

@patch("pipeline.pymupdf4llm")
def test_markdown_pdf_loader_load(mock_pymupdf):
    mock_pymupdf.to_markdown.return_value = "| Table |"
    loader = MarkdownPDFLoader("test.pdf")
    documents = loader.load()
    assert len(documents) == 1
    assert "page_content" in documents[0].__dict__ or hasattr(documents[0], "page_content")
    assert "| Table |" in documents[0].page_content

@pytest.mark.asyncio
@patch("pipeline.rag")
@patch("pipeline.settings")
@patch("pipeline.SessionLocal")
async def test_process_document_success(mock_session_local, mock_settings, mock_rag, db_session, tmp_path):
    # 1. Setup Database state
    doc_id = "test-uuid"
    filename = "test.txt"
    new_doc = SQLDocument(
        doc_id=doc_id,
        filename=filename,
        file_type=".txt",
        file_hash="hash123",
        collection_name="test_col",
        status=DocumentStatus.QUEUED
    )
    db_session.add(new_doc)
    await db_session.commit()

    # 2. Setup Mocks
    mock_settings.chunk_size = 100
    mock_settings.chunk_overlap = 10
    mock_settings.ollama_num_parallel = 1
    
    mock_llm = MagicMock()
    # mock_llm.ainvoke = AsyncMock(return_value="Context:") # Se usassimo ainvoke
    # Per ora generate_contextual_prefix usa get_llm().invoke
    mock_llm.invoke.return_value = "Context: "
    mock_rag.get_llm.return_value = mock_llm
    
    mock_vector_store = MagicMock()
    mock_rag.get_vector_store.return_value = mock_vector_store
    mock_rag.ensure_collection_exists = AsyncMock()
    
    # Mock SessionLocal per far usare il nostro db_session in-memory dentro pipeline.py
    mock_session_local.return_value.__aenter__.return_value = db_session

    # 3. Esecuzione
    test_file = tmp_path / "test.txt"
    test_file.write_text("Contenuto di test molto lungo per generare chunk.")
    
    from pipeline import process_document
    with patch("pipeline.TextLoader.load") as mock_load:
        from langchain.schema import Document
        mock_load.return_value = [Document(page_content="Contenuto di test", metadata={})]
        
        await process_document(str(test_file), filename, doc_id)

    # 4. Verifiche
    # Verifica che lo stato nel DB sia COMPLETED
    stmt = select(SQLDocument).where(SQLDocument.doc_id == doc_id)
    result = await db_session.execute(stmt)
    updated_doc = result.scalar_one()
    
    assert updated_doc.status == DocumentStatus.COMPLETED
    assert updated_doc.progress == 100
    assert updated_doc.indexed_at is not None
    
    mock_vector_store.add_documents.assert_called()
