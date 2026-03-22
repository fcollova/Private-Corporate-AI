/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: UI component to display a table of indexed documents with status and icons.
   ============================================================================= */

import React from 'react';

const getFileIcon = (ext) => {
  const e = ext?.toLowerCase() || '';
  if (e.includes('pdf')) return { icon: '📄', color: '#f87171' }; // Red
  if (e.includes('doc')) return { icon: '📝', color: '#60a5fa' }; // Blue
  if (e.includes('xls')) return { icon: '📊', color: '#34d399' }; // Green
  if (e.includes('ppt')) return { icon: '🖼️', color: '#fb923c' }; // Orange
  if (e.includes('md'))  return { icon: 'Ⓜ️', color: '#94a3b8' }; // Gray
  return { icon: '📄', color: '#94a3b8' };
};

const StatusBadge = ({ status, error, progress }) => {
  const styles = {
    padding: '2px 8px',
    borderRadius: '12px',
    fontSize: '0.75rem',
    fontWeight: 'bold',
    textTransform: 'uppercase',
    display: 'inline-block',
    marginBottom: '4px'
  };

  const statusMap = {
    'queued':          { label: 'In coda', color: '#94a3b8', bg: '#334155' },
    'extracting':      { label: 'Estrazione', color: '#60a5fa', bg: '#1e3a8a' },
    'contextualizing': { label: 'Contesto', color: '#fbbf24', bg: '#78350f' },
    'embedding':       { label: 'Indicizzazione', color: '#c084fc', bg: '#581c87' },
    'completed':       { label: 'Pronto', color: '#10b981', bg: '#064e3b' },
    'failed':          { label: 'Errore', color: '#ef4444', bg: '#7f1d1d' }
  };

  const s = statusMap[status] || { label: status, color: '#fff', bg: '#334155' };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minWidth: '120px' }}>
      <span title={error} style={{ ...styles, background: s.bg, color: s.color }}>{s.label}</span>
      {status !== 'completed' && status !== 'failed' && (
        <div style={{ width: '100%', height: '4px', background: '#334155', borderRadius: '2px', overflow: 'hidden' }}>
          <div style={{ width: `${progress}%`, height: '100%', background: s.color, transition: 'width 0.3s' }}></div>
        </div>
      )}
    </div>
  );
};

const DocTable = ({ docs, onAction, onDelete, onReindex }) => (
  <div style={{ padding: '1rem', background: '#1e293b', borderRadius: '8px', color: '#f1f5f9' }}>
    <table style={{ width: '100%', borderCollapse: 'collapse' }}>
      <thead>
        <tr style={{ borderBottom: '1px solid #334155', textAlign: 'left' }}>
          <th style={{ padding: '0.5rem' }}>File</th>
          <th style={{ padding: '0.5rem' }}>Tipo</th>
          <th style={{ padding: '0.5rem' }}>Stato</th>
          <th style={{ padding: '0.5rem' }}>Dimensione</th>
          <th style={{ padding: '0.5rem' }}>Data</th>
          <th style={{ padding: '0.5rem' }}>Azioni</th>
        </tr>
      </thead>
      <tbody>
        {docs.map(doc => {
          const { icon, color } = getFileIcon(doc.file_type);
          const isProcessing = ['queued', 'extracting', 'contextualizing', 'embedding'].includes(doc.status);
          
          return (
            <tr key={doc.doc_id} style={{ borderBottom: '1px solid #334155', opacity: isProcessing ? 0.8 : 1 }}>
              <td style={{ padding: '0.5rem', display: 'flex', alignItems: 'center' }}>
                <span style={{ marginRight: '8px', fontSize: '1.2rem', color }}>{icon}</span>
                {doc.filename}
              </td>
              <td style={{ padding: '0.5rem' }}>{doc.file_type}</td>
              <td style={{ padding: '0.5rem' }}>
                <StatusBadge status={doc.status} error={doc.error} progress={doc.progress} />
              </td>
              <td style={{ padding: '0.5rem' }}>{(doc.size_bytes / 1024).toFixed(1)} KB</td>
              <td style={{ padding: '0.5rem', fontSize: '0.85rem' }}>
                {new Date(doc.indexed_at || doc.created_at).toLocaleString()}
              </td>
              <td style={{ padding: '0.5rem' }}>
                <button 
                  onClick={() => onAction(doc)} 
                  disabled={isProcessing}
                  style={{ marginRight: '5px', opacity: isProcessing ? 0.5 : 1 }}
                >Sposta</button>
                <button 
                  onClick={() => onReindex(doc.doc_id)} 
                  disabled={isProcessing}
                  style={{ marginRight: '5px', color: '#fbbf24', opacity: isProcessing ? 0.5 : 1 }}
                >Re-index</button>
                <button 
                  onClick={() => onDelete(doc.doc_id)} 
                  style={{ color: '#f87171' }}
                >Elimina</button>
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  </div>
);

export default DocTable;
