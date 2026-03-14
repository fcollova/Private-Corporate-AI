# Contributing to Private Corporate AI

First off, thank you for considering contributing to Private Corporate AI! It's people like you who make this project a great tool for everyone.

This guide will help you understand the contribution process, from reporting bugs to submitting new features.

---

## 🚩 How to Contribute

### 1. Reporting Issues
Before opening a new issue, please search the [existing issues](https://github.com/<your-org>/private-corporate-ai/issues) to see if it has already been reported.

When reporting an issue, please use the appropriate template:
- **Bug Report:** For reporting unexpected behavior.
- **Feature Request:** For suggesting new ideas or enhancements.

### 2. Forking and Pull Requests
We use the standard GitHub Flow for contributions:

1. **Fork** the repository to your own account.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/your-username/private-corporate-ai.git
   cd private-corporate-ai
   ```
3. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/my-new-feature
   ```
4. **Make your changes** and commit them with a descriptive message.
5. **Push** your branch to your fork:
   ```bash
   git push origin feature/my-new-feature
   ```
6. **Open a Pull Request (PR)** against our `main` branch.

---

## 🛠️ Development Setup

Refer to the [README.md](./README.md) for installation instructions. Use `make up-lite` for development if you don't have an NVIDIA GPU, as it's faster to iterate on CPU for most code changes.

### Coding Conventions

#### Python (RAG Backend)
- We follow **PEP 8** style guidelines.
- Use **Type Hints** for all function signatures.
- We use **FastAPI** for the web framework and **LangChain** for RAG orchestration.
- Logging should be done using the `loguru` library.
- Keep functions modular and focused on a single responsibility.

#### JavaScript/React (Console)
- We use **React** with **Vite**.
- Prefer functional components and hooks.
- Use **Vanilla CSS** or the existing theme structure for styling.
- Ensure API calls are handled through the defined `ragClient.js`.

---

## 🧪 Testing Your Changes

Before submitting a PR, ensure your changes don't break existing functionality:

1. **Service Health Check:**
   ```bash
   make health
   ```
   This verifies that the RAG Backend, Ollama, and Qdrant are communicating correctly.

2. **RAG Pipeline Test:**
   ```bash
   make test-chat
   ```
   This sends a test query to verify the full RAG cycle (retrieval + generation).

3. **Manual Validation:**
   - If you modified the UI, verify it across different screen sizes.
   - If you added a loader, test it with several sample files of that format.

---

## 📂 Adding New Document Loaders

Private Corporate AI uses LangChain community loaders. To add support for a new file format:

1. **Check Requirements:** Ensure the necessary library is in `rag_backend/requirements.txt`.
2. **Update `get_document_loader`:** Modify the `get_document_loader` function in `rag_backend/pipeline.py` to include the new extension mapping.
   ```python
   def get_document_loader(file_path: str, file_ext: str):
       loaders = {
           ".pdf":  lambda: PyPDFLoader(file_path),
           ".docx": lambda: Docx2txtLoader(file_path),
           # Add your new extension here:
           ".xyz":  lambda: MyNewLoader(file_path),
       }
       return loaders[file_ext.lower()]()
   ```
3. **Verify `process_document`:** Ensure the `process_document` logic handles any specific requirements for your new format (e.g., custom metadata extraction).
4. **Update README:** Add the new format to the "Supported document formats" list in `README.md`.

---

## 📝 Commit Messages

- Use the present tense ("Add feature" not "Added feature").
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...").
- Reference issues and pull requests liberally after the first line.

---

Thank you for your contribution! 🚀
