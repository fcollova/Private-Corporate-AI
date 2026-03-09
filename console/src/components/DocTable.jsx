import React from 'react';

const DocTable = ({ docs, onAction, onDelete, onReindex }) => (
  <div style={{ padding: '1rem', background: '#1e293b', borderRadius: '8px' }}>
    <table style={{ width: '100%', borderCollapse: 'collapse' }}>
      <thead>
        <tr style={{ borderBottom: '1px solid #334155', textAlign: 'left' }}>
          <th style={{ padding: '0.5rem' }}>Nome File</th>
          <th style={{ padding: '0.5rem' }}>Tipo</th>
          <th style={{ padding: '0.5rem' }}>Chunk</th>
          <th style={{ padding: '0.5rem' }}>Indicizzato il</th>
          <th style={{ padding: '0.5rem' }}>Azioni</th>
        </tr>
      </thead>
      <tbody>
        {docs.map(doc => (
          <tr key={doc.doc_id} style={{ borderBottom: '1px solid #334155' }}>
            <td style={{ padding: '0.5rem' }}>{doc.filename}</td>
            <td style={{ padding: '0.5rem' }}>{doc.file_type}</td>
            <td style={{ padding: '0.5rem' }}>{doc.chunks_count}</td>
            <td style={{ padding: '0.5rem' }}>{new Date(doc.indexed_at).toLocaleString()}</td>
            <td style={{ padding: '0.5rem' }}>
              <button onClick={() => onAction(doc)} style={{ marginRight: '5px' }}>Sposta</button>
              <button onClick={() => onReindex(doc.doc_id)} style={{ marginRight: '5px', color: '#fbbf24' }}>Re-index</button>
              <button onClick={() => onDelete(doc.doc_id)} style={{ color: '#f87171' }}>Elimina</button>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  </div>
);

export default DocTable;
