/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Redesigned Document Table component.
   ============================================================================= */

import React from 'react';

const getFileClass = (filename) => {
  const ext = filename.split('.').pop().toLowerCase();
  if (['pdf'].includes(ext)) return 'pdf';
  if (['doc', 'docx'].includes(ext)) return 'doc';
  if (['xls', 'xlsx', 'csv'].includes(ext)) return 'xls';
  if (['md', 'txt'].includes(ext)) return 'md';
  return '';
};

const getFileIcon = (filename) => {
  const ext = filename.split('.').pop().toLowerCase();
  if (ext === 'pdf') return '📄';
  if (['doc', 'docx'].includes(ext)) return '📝';
  if (['xls', 'xlsx'].includes(ext)) return '📊';
  if (ext === 'md') return 'Ⓜ️';
  return '📁';
};

const DocTable = ({ docs, onDelete, onReindex, t }) => {
  return (
    <table className="doc-table">
      <thead>
        <tr>
          <th>Documento</th>
          <th>Stato</th>
          <th>Tipo</th>
          <th>Dimensione</th>
          <th style={{ textAlign: 'right' }}>Azioni</th>
        </tr>
      </thead>
      <tbody>
        {docs.length === 0 ? (
          <tr>
            <td colSpan="5" style={{ textAlign: 'center', padding: '40px', color: 'var(--text3)' }}>
              Nessun documento trovato in questo dominio.
            </td>
          </tr>
        ) : (
          docs.map(doc => {
            const isProcessing = ['queued', 'extracting', 'contextualizing', 'embedding'].includes(doc.status);
            
            return (
              <tr key={doc.doc_id} className={isProcessing ? 'processing' : ''}>
                <td>
                  <div className="file-cell">
                    <div className={`file-icon ${getFileClass(doc.filename)}`}>
                      {getFileIcon(doc.filename)}
                    </div>
                    <div>
                      <div className="file-name">{doc.filename}</div>
                      <div className="file-id">{doc.doc_id}</div>
                    </div>
                  </div>
                </td>
                <td>
                  {isProcessing ? (
                    <div className="prog-wrap">
                      <span className={`badge ${doc.status}`}>
                        <span className="badge-dot"></span>
                        {doc.status.toUpperCase()}
                      </span>
                      <div className="prog-bar">
                        <div 
                          className="prog-fill" 
                          style={{ 
                            width: `${doc.progress || 30}%`, 
                            background: doc.status === 'embedding' ? 'var(--purple)' : 'var(--accent)' 
                          }}
                        ></div>
                      </div>
                    </div>
                  ) : (
                    <span className={`badge ${doc.status === 'completed' ? 'ready' : 'failed'}`}>
                      <span className="badge-dot"></span>
                      {doc.status === 'completed' ? 'PRONTO' : 'ERRORE'}
                    </span>
                  )}
                </td>
                <td>
                  <span style={{ color: 'var(--text2)', fontFamily: 'var(--mono)', fontSize: '11px' }}>
                    {doc.filename.split('.').pop().toUpperCase()}
                  </span>
                </td>
                <td>
                  <span style={{ color: 'var(--text2)', fontSize: '12px' }}>
                    {(doc.size_bytes / 1024).toFixed(1)} KB
                  </span>
                </td>
                <td>
                  <div className="row-actions">
                    <button 
                      className="act-btn warn" 
                      onClick={() => onReindex(doc.doc_id)} 
                      disabled={isProcessing}
                      title="Re-index"
                    >
                      <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
                        <path d="M2 7a5 5 0 009.5-1.5M12 7a5 5 0 01-9.5 1.5M2 4v3h3M12 10v-3h-3"/>
                      </svg>
                    </button>
                    <button 
                      className="act-btn danger" 
                      onClick={() => onDelete(doc.doc_id)}
                      title="Elimina"
                    >
                      <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
                        <path d="M2 4h10M5 4V2h4v2M6 7v4M8 7v4M3 4l.7 8h6.6L11 4"/>
                      </svg>
                    </button>
                  </div>
                </td>
              </tr>
            );
          })
        )}
      </tbody>
    </table>
  );
};

export default DocTable;
