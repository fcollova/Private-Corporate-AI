const BASE = import.meta.env.VITE_RAG_BASE_URL || '/api/rag';

export const api = {
  // Documenti
  listDocs:     (collection) => fetch(`${BASE}/documents/list${collection ? `?collection_name=${collection}` : ''}`).then(r => r.json()),
  uploadDoc:    (file, collection) => { const fd = new FormData(); fd.append('file', file); if (collection) fd.append('collection_name', collection); return fetch(`${BASE}/documents/upload`, { method: 'POST', body: fd }).then(r => r.json()); },
  deleteDoc:    (id, collection) => fetch(`${BASE}/documents/${id}${collection ? `?collection_name=${collection}` : ''}`, { method: 'DELETE' }).then(r => r.json()),
  reindexDoc:   (id, collection) => fetch(`${BASE}/documents/${id}/reindex${collection ? `?collection_name=${collection}` : ''}`, { method: 'POST' }).then(r => r.json()),
  moveDoc:      (id, body) => fetch(`${BASE}/documents/${id}/domain`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).then(r => r.json()),

  // Domini
  listDomains:  () => fetch(`${BASE}/domains`).then(r => r.json()),
  createDomain: (name) => fetch(`${BASE}/domains`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name }) }).then(r => r.json()),
  deleteDomain: (name) => fetch(`${BASE}/domains/${name}`, { method: 'DELETE' }).then(r => r.json()),

  // Health
  health:       () => fetch(`${BASE}/health`).then(r => r.json()),
};
