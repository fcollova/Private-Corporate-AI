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

const StatusBadge = ({ status, error }) => {
  const styles = {
    padding: '2px 8px',
    borderRadius: '12px',
    fontSize: '0.75rem',
    fontWeight: 'bold',
    textTransform: 'uppercase'
  };

  if (status === 'processing') return <span style={{ ...styles, background: '#fbbf24', color: '#000' }}>Elaborazione...</span>;
  if (status === 'error') return <span title={error} style={{ ...styles, background: '#ef4444', color: '#fff' }}>Errore</span>;
  return <span style={{ ...styles, background: '#10b981', color: '#fff' }}>Indicizzato</span>;
};

const DocTable = ({ docs, onAction, onDelete, onReindex }) => (
  <div style={{ padding: '1rem', background: '#1e293b', borderRadius: '8px', color: '#f1f5f9' }}>
    <table style={{ width: '100%', borderCollapse: 'collapse' }}>
      <thead>
        <tr style={{ borderBottom: '1px solid #334155', textAlign: 'left' }}>
          <th style={{ padding: '0.5rem' }}>File</th>
          <th style={{ padding: '0.5rem' }}>Tipo</th>
          <th style={{ padding: '0.5rem' }}>Stato</th>
          <th style={{ padding: '0.5rem' }}>Chunk</th>
          <th style={{ padding: '0.5rem' }}>Data</th>
          <th style={{ padding: '0.5rem' }}>Azioni</th>
        </tr>
      </thead>
      <tbody>
        {docs.map(doc => {
          const { icon, color } = getFileIcon(doc.file_type);
          const isProcessing = doc.status === 'processing';
          
          return (
            <tr key={doc.doc_id} style={{ borderBottom: '1px solid #334155', opacity: isProcessing ? 0.7 : 1 }}>
              <td style={{ padding: '0.5rem', display: 'flex', alignItems: 'center' }}>
                <span style={{ marginRight: '8px', fontSize: '1.2rem', color }}>{icon}</span>
                {doc.filename}
              </td>
              <td style={{ padding: '0.5rem' }}>{doc.file_type}</td>
              <td style={{ padding: '0.5rem' }}>
                <StatusBadge status={doc.status} error={doc.error} />
              </td>
              <td style={{ padding: '0.5rem' }}>{doc.chunks_count}</td>
              <td style={{ padding: '0.5rem', fontSize: '0.85rem' }}>
                {new Date(doc.indexed_at).toLocaleString()}
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
