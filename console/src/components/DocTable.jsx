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

const StatusBadge = ({ status, error, progress, t }) => {
  const styles = {
    padding: '4px 10px',
    borderRadius: '12px',
    fontSize: '0.7rem',
    fontWeight: '700',
    textTransform: 'uppercase',
    display: 'inline-block',
    marginBottom: '4px',
    letterSpacing: '0.025em'
  };

  const statusMap = {
    'queued':          { label: t.statusQueued, color: '#94a3b8', bg: 'rgba(148, 163, 184, 0.1)', border: '1px solid rgba(148, 163, 184, 0.2)' },
    'extracting':      { label: t.statusExtracting, color: '#60a5fa', bg: 'rgba(96, 165, 250, 0.1)', border: '1px solid rgba(96, 165, 250, 0.2)' },
    'contextualizing': { label: t.statusContextualizing, color: '#fbbf24', bg: 'rgba(251, 191, 36, 0.1)', border: '1px solid rgba(251, 191, 36, 0.2)' },
    'embedding':       { label: t.statusEmbedding, color: '#c084fc', bg: 'rgba(192, 132, 252, 0.1)', border: '1px solid rgba(192, 132, 252, 0.2)' },
    'completed':       { label: t.statusCompleted, color: '#10b981', bg: 'rgba(16, 185, 129, 0.1)', border: '1px solid rgba(16, 185, 129, 0.2)' },
    'failed':          { label: t.statusFailed, color: '#ef4444', bg: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.2)' }
  };

  const s = statusMap[status] || { label: status, color: '#fff', bg: '#334155' };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minWidth: '130px' }}>
      <span title={error} style={{ ...styles, background: s.bg, color: s.color, border: s.border }}>{s.label}</span>
      {status !== 'completed' && status !== 'failed' && (
        <div style={{ width: '100%', height: '4px', background: '#334155', borderRadius: '2px', overflow: 'hidden' }}>
          <div style={{ width: `${progress}%`, height: '100%', background: s.color, transition: 'width 0.3s' }}></div>
        </div>
      )}
    </div>
  );
};

const DocTable = ({ docs, onAction, onDelete, onReindex, t }) => (
  <div style={{ background: '#1e293b', borderRadius: '12px', color: '#f1f5f9', overflow: 'hidden', border: '1px solid #334155' }}>
    <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
      <thead style={{ background: '#0f172a' }}>
        <tr>
          <th style={{ padding: '1rem', fontSize: '0.8rem', color: '#64748b', textTransform: 'uppercase' }}>{t.tableHeaderFile}</th>
          <th style={{ padding: '1rem', fontSize: '0.8rem', color: '#64748b', textTransform: 'uppercase' }}>{t.tableHeaderType}</th>
          <th style={{ padding: '1rem', fontSize: '0.8rem', color: '#64748b', textTransform: 'uppercase' }}>{t.tableHeaderStatus}</th>
          <th style={{ padding: '1rem', fontSize: '0.8rem', color: '#64748b', textTransform: 'uppercase' }}>{t.tableHeaderSize}</th>
          <th style={{ padding: '1rem', fontSize: '0.8rem', color: '#64748b', textTransform: 'uppercase' }}>{t.tableHeaderDate}</th>
          <th style={{ padding: '1rem', fontSize: '0.8rem', color: '#64748b', textTransform: 'uppercase', textAlign: 'right' }}>{t.tableHeaderActions}</th>
        </tr>
      </thead>
      <tbody>
        {docs.length === 0 ? (
          <tr>
            <td colSpan="6" style={{ padding: '3rem', textAlign: 'center', color: '#64748b' }}>
              No documents found.
            </td>
          </tr>
        ) : docs.map(doc => {
          const { icon, color } = getFileIcon(doc.file_type);
          const isProcessing = ['queued', 'extracting', 'contextualizing', 'embedding'].includes(doc.status);
          
          return (
            <tr key={doc.doc_id} style={{ borderTop: '1px solid #334155', opacity: isProcessing ? 0.8 : 1, transition: 'background 0.2s' }}>
              <td style={{ padding: '1rem', display: 'flex', alignItems: 'center' }}>
                <span style={{ marginRight: '12px', fontSize: '1.25rem', color }}>{icon}</span>
                <div style={{ fontWeight: 500 }}>{doc.filename}</div>
              </td>
              <td style={{ padding: '1rem', fontSize: '0.9rem', color: '#94a3b8' }}>{doc.file_type.toUpperCase()}</td>
              <td style={{ padding: '1rem' }}>
                <StatusBadge status={doc.status} error={doc.error} progress={doc.progress} t={t} />
              </td>
              <td style={{ padding: '1rem', fontSize: '0.9rem', color: '#94a3b8' }}>{(doc.size_bytes / 1024).toFixed(1)} KB</td>
              <td style={{ padding: '1rem', fontSize: '0.8rem', color: '#64748b' }}>
                {new Date(doc.indexed_at || doc.created_at).toLocaleString()}
              </td>
              <td style={{ padding: '1rem', textAlign: 'right' }}>
                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
                  <button 
                    onClick={() => onAction(doc)} 
                    disabled={isProcessing}
                    title={t.actionMove}
                    style={{ 
                      background: '#334155', border: 'none', color: '#f1f5f9', 
                      padding: '6px 12px', borderRadius: '4px', cursor: 'pointer',
                      fontSize: '0.8rem', opacity: isProcessing ? 0.5 : 1
                    }}
                  >{t.actionMove}</button>
                  <button 
                    onClick={() => onReindex(doc.doc_id)} 
                    disabled={isProcessing}
                    title={t.actionReindex}
                    style={{ 
                      background: 'rgba(251, 191, 36, 0.1)', border: '1px solid rgba(251, 191, 36, 0.2)', color: '#fbbf24', 
                      padding: '6px 12px', borderRadius: '4px', cursor: 'pointer',
                      fontSize: '0.8rem', opacity: isProcessing ? 0.5 : 1
                    }}
                  >{t.actionReindex}</button>
                  <button 
                    onClick={() => onDelete(doc.doc_id)} 
                    title={t.actionDelete}
                    style={{ 
                      background: 'rgba(248, 113, 113, 0.1)', border: '1px solid rgba(248, 113, 113, 0.2)', color: '#f87171', 
                      padding: '6px 12px', borderRadius: '4px', cursor: 'pointer',
                      fontSize: '0.8rem'
                    }}
                  >{t.actionDelete}</button>
                </div>
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  </div>
);

export default DocTable;
