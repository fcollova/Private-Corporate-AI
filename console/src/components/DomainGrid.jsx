import React from 'react';

const DomainGrid = ({ domains, onSelect, onDelete, selected }) => (
  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: '1rem', padding: '1rem' }}>
    {domains.map(domain => (
      <div 
        key={domain.name} 
        onClick={() => onSelect(domain.name)}
        style={{ 
          padding: '1rem', 
          background: selected === domain.name ? '#334155' : '#1e293b', 
          borderRadius: '8px',
          cursor: 'pointer',
          border: selected === domain.name ? '2px solid #3b82f6' : '1px solid #334155'
        }}
      >
        <h3 style={{ margin: '0 0 0.5rem 0' }}>{domain.name}</h3>
        <div style={{ fontSize: '0.8rem', opacity: 0.8 }}>
          <div>Vettori: {domain.vectors_count}</div>
          <div>Ultimo agg: {domain.last_updated ? new Date(domain.last_updated).toLocaleDateString() : 'Mai'}</div>
        </div>
        <button 
          onClick={(e) => { e.stopPropagation(); onDelete(domain.name); }} 
          style={{ marginTop: '1rem', width: '100%', color: '#f87171' }}
        >
          Elimina
        </button>
      </div>
    ))}
  </div>
);

export default DomainGrid;
