/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Dedicated component for testing retrieval (Index Test).
   ============================================================================= */

import React, { useState, useEffect, useRef } from 'react';
import { api } from '../api/ragClient';

const inputStyle = {
  background: '#0f172a', border: '1px solid #334155', color: 'white',
  padding: '12px 16px', borderRadius: '8px', width: '100%',
  outline: 'none', boxSizing: 'border-box', fontSize: '1rem'
};

const IndexingTest = ({ t, primaryColor, selectedDomain }) => {
  const [testQuery, setTestQuery] = useState('');
  const [testResults, setTestResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const inputRef = useRef(null);

  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.focus();
    }
  }, [testQuery]);

  const runTest = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!testQuery) return;
    setLoading(true);
    try {
      const res = await api.testIndexingQuery(testQuery, selectedDomain);
      setTestResults(res.results);
    } catch (e) {
      alert("Error running test");
    }
    setLoading(false);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem', maxWidth: '1000px', margin: '0 auto' }}>
      
      <header>
        <h2 style={{ margin: 0, fontSize: '1.75rem', fontWeight: 800, letterSpacing: '-0.025em' }}>
          {t.testTitle}: <span style={{ color: primaryColor }}>{selectedDomain}</span>
        </h2>
        <p style={{ color: '#64748b', margin: '8px 0 0 0', fontSize: '0.95rem' }}>
          Testa l'efficacia del recupero (Retrieval) per il dominio selezionato.
        </p>
      </header>

      <div style={{ 
        background: '#1e293b', padding: '2.5rem', borderRadius: '16px', 
        border: '1px solid #334155', boxShadow: '0 20px 25px -5px rgb(0 0 0 / 0.3)'
      }}>
        <form onSubmit={runTest} style={{ display: 'flex', gap: '15px' }}>
          <input 
            type="text" 
            ref={inputRef}
            placeholder={t.testPlaceholder}
            value={testQuery}
            onChange={e => setTestQuery(e.target.value)}
            style={inputStyle}
          />
          <button 
            type="submit"
            disabled={loading}
            style={{ 
              background: primaryColor, border: 'none', color: 'white', 
              padding: '0 30px', borderRadius: '8px', cursor: 'pointer',
              fontWeight: 700, fontSize: '1rem', whiteSpace: 'nowrap',
              boxShadow: `0 4px 6px -1px color-mix(in srgb, ${primaryColor}, transparent 70%)`
            }}
          >
            {loading ? '...' : t.runTest}
          </button>
        </form>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
        <h4 style={{ color: '#64748b', fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '0.15em', fontWeight: 800 }}>
          {t.testResults}
        </h4>
        
        {testResults ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
            {testResults.map((res, i) => (
              <div key={i} style={{ 
                padding: '1.5rem', background: '#0f172a', borderRadius: '12px', 
                borderLeft: `4px solid ${primaryColor}`, boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.2)',
                animation: 'fadeIn 0.3s ease-out'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '12px', alignItems: 'center' }}>
                  <span style={{ color: '#10b981', fontSize: '0.8rem', fontWeight: '800', background: 'rgba(16, 185, 129, 0.1)', padding: '4px 10px', borderRadius: '6px' }}>
                    {t.score}: {res.score.toFixed(4)}
                  </span>
                  <span style={{ color: '#475569', fontSize: '0.75rem', fontWeight: 700 }}>{res.metadata.source || 'N/A'}</span>
                </div>
                <p style={{ margin: 0, fontSize: '0.95rem', color: '#cbd5e1', lineHeight: '1.7' }}>{res.text}</p>
              </div>
            ))}
          </div>
        ) : (
          <div style={{ 
            textAlign: 'center', padding: '8rem 2rem', color: '#334155', 
            background: 'rgba(30, 41, 59, 0.5)', borderRadius: '16px', border: '1px dashed #334155' 
          }}>
            <div style={{ fontSize: '3rem', marginBottom: '1.5rem', opacity: 0.2 }}>🔍</div>
            <p style={{ fontSize: '1.1rem', fontWeight: 500 }}>{t.testPlaceholder}</p>
          </div>
        )}
      </div>

    </div>
  );
};

export default IndexingTest;
