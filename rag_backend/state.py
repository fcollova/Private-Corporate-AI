# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Shared state manager for tracking background processing tasks.
# =============================================================================

from typing import Dict, Optional
import time

class ProcessingStateManager:
    def __init__(self):
        # Mappa: doc_id -> { filename, status, started_at, error }
        self.active_tasks: Dict[str, dict] = {}

    def add_task(self, doc_id: str, filename: str):
        self.active_tasks[doc_id] = {
            "filename": filename,
            "status": "processing",
            "started_at": time.time(),
            "error": None
        }

    def complete_task(self, doc_id: str):
        if doc_id in self.active_tasks:
            del self.active_tasks[doc_id]

    def fail_task(self, doc_id: str, error: str):
        if doc_id in self.active_tasks:
            self.active_tasks[doc_id]["status"] = "error"
            self.active_tasks[doc_id]["error"] = error

    def get_all(self):
        return self.active_tasks

state_manager = ProcessingStateManager()
