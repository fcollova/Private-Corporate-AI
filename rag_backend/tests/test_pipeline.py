import pytest
from unittest.mock import MagicMock, patch
from pathlib import Path
from pipeline import get_document_loader, MarkItDownLoader

def test_get_document_loader_pdf():
    loader = get_document_loader("test.pdf", ".pdf")
    from langchain_community.document_loaders import PyPDFLoader
    assert isinstance(loader, PyPDFLoader)

def test_get_document_loader_docx():
    loader = get_document_loader("test.docx", ".docx")
    from langchain_community.document_loaders import Docx2txtLoader
    assert isinstance(loader, Docx2txtLoader)

def test_get_document_loader_xlsx():
    loader = get_document_loader("test.xlsx", ".xlsx")
    assert isinstance(loader, MarkItDownLoader)

def test_get_document_loader_pptx():
    loader = get_document_loader("test.pptx", ".pptx")
    assert isinstance(loader, MarkItDownLoader)

def test_get_document_loader_unsupported():
    with pytest.raises(ValueError, match="Formato file non supportato"):
        get_document_loader("test.exe", ".exe")

@patch("pipeline.MarkItDown")
def test_markitdown_loader_load(mock_markitdown):
    # Mock MarkItDown conversion
    mock_instance = mock_markitdown.return_value
    mock_result = MagicMock()
    mock_result.text_content = "# Test Content"
    mock_instance.convert.return_value = mock_result
    
    loader = MarkItDownLoader("test.xlsx")
    documents = loader.load()
    
    assert len(documents) == 1
    assert documents[0].page_content == "# Test Content"
    assert documents[0].metadata["source"] == "test.xlsx"
    mock_instance.convert.assert_called_once_with("test.xlsx")

@pytest.mark.asyncio
@patch("pipeline.rag")
@patch("pipeline.settings")
async def test_process_document_xlsx(mock_settings, mock_rag, tmp_path):
    # Setup mocks
    mock_settings.chunk_size = 1000
    mock_settings.chunk_overlap = 200
    mock_settings.qdrant_collection_name = "test_col"
    
    mock_llm = MagicMock()
    mock_llm.invoke.return_value = "Context Prefix"
    mock_rag.get_llm.return_value = mock_llm
    
    mock_vector_store = MagicMock()
    mock_rag.get_vector_store.return_value = mock_vector_store
    mock_rag.ensure_collection_exists = AsyncMock()
    
    # Create a dummy file
    test_file = tmp_path / "test.xlsx"
    test_file.write_text("dummy")
    
    # Mock MarkItDownLoader
    with patch("pipeline.MarkItDownLoader.load") as mock_load:
        from langchain.schema import Document
        mock_load.return_value = [Document(page_content="Excel data", metadata={})]
        
        from pipeline import process_document
        total_indexed = await process_document(str(test_file), "test.xlsx", "doc123")
        
        assert total_indexed > 0
        mock_rag.ensure_collection_exists.assert_called_once()
        mock_vector_store.add_documents.assert_called()
