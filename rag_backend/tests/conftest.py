import pytest
from unittest.mock import MagicMock, AsyncMock

@pytest.fixture
def mock_settings():
    with MagicMock() as mock:
        mock.chunk_size = 1000
        mock.chunk_overlap = 200
        mock.qdrant_collection_name = "test_collection"
        mock.llm_model = "test_model"
        mock.hybrid_search_enabled = True
        mock.top_k_results = 5
        yield mock

@pytest.fixture
def mock_rag():
    with MagicMock() as mock:
        mock.get_llm = MagicMock()
        mock.get_vector_store = MagicMock()
        mock.get_sparse_embeddings = MagicMock(return_value=None)
        mock.ensure_collection_exists = AsyncMock()
        yield mock

@pytest.fixture
def mock_llm():
    with MagicMock() as mock:
        mock.invoke = MagicMock(return_value="Test Answer")
        yield mock

@pytest.fixture
def mock_vector_store():
    with MagicMock() as mock:
        mock.add_documents = MagicMock()
        mock.as_retriever = MagicMock()
        yield mock
