/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Component for managing indexing settings and testing retrieval.
   ============================================================================= */

import React, { useState, useEffect } from 'react';
import { api } from '../api/ragClient';

const IndexingManagement = ({ t, primaryColor, selectedDomain }) => {
  const [settings, setSettings] = useState({
    chunk_size: 1000,
    chunk_overlap: 200,
    top_k_results: 5,
    hybrid_search_enabled: true,
    llm_temperature: 0.2
  });
  const [stats, setStats] = useState(null);
  const [testQuery, setTestQuery] = useState('');
  const [testResults, setTestResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.getIndexingSettings().then(setSettings).catch(console.error);
    api.getIndexingStats().then(setStats).catch(console.error);
  }, []);

  const handleSave = async (e) => {
    if (e) e.preventDefault();
    setSaving(true);
    try {
      await api.updateIndexingSettings(settings);
      alert(t.settingsSaved);
      // Refresh stats in case something changed
      api.getIndexingStats().then(setStats).catch(console.error);
    } catch (e) {
      alert("Error saving settings");
    }
    setSaving(false);
  };

  const runTest = async () => {
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

  const inputStyle = {
    background: '#0f172a', border: '1px solid #334155', color: 'white',
    padding: '10px', borderRadius: '8px', width: '100%', marginTop: '5px',
    outline: 'none'
  };

  const labelStyle = { color: '#94a3b8', fontSize: '0.85rem', fontWeight: '600' };

  const Card = ({ title, icon, children, style }) => (
    <section style={{ 
      background: '#1e293b', padding: '2rem', borderRadius: '12px', 
      border: '1px solid #334155', height: '100%', ...style 
    }}>
      <h3 style={{ marginTop: 0, marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '10px', fontSize: '1.1rem' }}>
        <span style={{ color: primaryColor }}>{icon}</span> {title}
      </h3>
      {children}
    </section>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      
      {/* STATS SECTION */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '1.5rem' }}>
        {[
          { label: t.totalCollections, value: stats?.total_collections || 0, icon: '📂' },
          { label: t.totalVectors, value: stats?.total_vectors?.toLocaleString() || 0, icon: '💎' },
          { label: t.totalPoints, value: stats?.total_points?.toLocaleString() || 0, icon: '📍' },
          { label: 'Domains', value: stats?.domains?.length || 0, icon: '🌐' }
        ].map((stat, i) => (
          <div key={i} style={{ 
            background: '#1e293b', padding: '1.5rem', borderRadius: '12px', 
            border: '1px solid #334155', textAlign: 'center'
          }}>
            <div style={{ fontSize: '1.5rem', marginBottom: '8px' }}>{stat.icon}</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 800, color: '#f1f5f9' }}>{stat.value}</div>
            <div style={{ fontSize: '0.75rem', color: '#64748b', textTransform: 'uppercase', marginTop: '4px', fontWeight: 700 }}>{stat.label}</div>
          </div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
        
        {/* CONFIGURATION SECTION */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
          
          <Card title={t.indexingParams} icon="🏗️">
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              <div>
                <label style={labelStyle}>{t.chunkSize}</label>
                <input type="number" value={settings.chunk_size} onChange={e => setSettings({...settings, chunk_size: parseInt(e.target.value)})} style={inputStyle} />
              </div>
              <div>
                <label style={labelStyle}>{t.chunkOverlap}</label>
                <input type="number" value={settings.chunk_overlap} onChange={e => setSettings({...settings, chunk_overlap: parseInt(e.target.value)})} style={inputStyle} />
              </div>
              <p style={{ fontSize: '0.75rem', color: '#fbbf24', margin: '0.5rem 0', fontStyle: 'italic' }}>
                ⚠️ {t.warningReindex}
              </p>
              <button 
                onClick={handleSave}
                disabled={saving}
                style={{ 
                  background: primaryColor, border: 'none', color: 'white', 
                  padding: '12px', borderRadius: '8px', cursor: 'pointer',
                  fontWeight: 600
                }}
              >
                {saving ? '...' : t.saveAndReindex}
              </button>
            </div>
          </Card>

          <Card title={t.retrievalParams} icon="⚡">
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
              <div>
                <label style={labelStyle}>{t.topK}</label>
                <input type="number" value={settings.top_k_results} onChange={e => setSettings({...settings, top_k_results: parseInt(e.target.value)})} style={inputStyle} />
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <input type="checkbox" checked={settings.hybrid_search_enabled} onChange={e => setSettings({...settings, hybrid_search_enabled: e.target.checked})} id="hybrid" />
                <label htmlFor="hybrid" style={{...labelStyle, cursor: 'pointer'}}>{t.hybridSearch}</label>
              </div>
              <div>
                <label style={labelStyle}>{t.temperature}</label>
                <input type="number" step="0.1" min="0" max="1" value={settings.llm_temperature} onChange={e => setSettings({...settings, llm_temperature: parseFloat(e.target.value)})} style={inputStyle} />
              </div>
              <button 
                onClick={handleSave}
                disabled={saving}
                style={{ 
                  background: 'rgba(255, 255, 255, 0.05)', border: '1px solid rgba(255, 255, 255, 0.1)', color: '#f1f5f9', 
                  padding: '12px', borderRadius: '8px', cursor: 'pointer',
                  fontWeight: 600
                }}
              >
                {saving ? '...' : t.saveOnly}
              </button>
            </div>
          </Card>

        </div>

        {/* TEST QUERY SECTION */}
        <Card title={t.testTitle} icon="🔍">
          <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            <div style={{ display: 'flex', gap: '10px', marginBottom: '1.5rem' }}>
              <input 
                type="text" 
                placeholder={t.testPlaceholder}
                value={testQuery}
                onChange={e => setTestQuery(e.target.value)}
                style={{...inputStyle, marginTop: 0}}
              />
              <button 
                onClick={runTest}
                disabled={loading}
                style={{ 
                  background: '#334155', border: 'none', color: 'white', 
                  padding: '0 20px', borderRadius: '8px', cursor: 'pointer',
                  fontWeight: 600
                }}
              >
                {loading ? '...' : t.runTest}
              </button>
            </div>

            <div style={{ flex: 1, overflowY: 'auto', maxHeight: '600px', paddingRight: '10px' }}>
              <h4 style={{ color: '#64748b', fontSize: '0.7rem', textTransform: 'uppercase', marginBottom: '1rem', letterSpacing: '0.1em' }}>{t.testResults}</h4>
              {testResults ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                  {testResults.map((res, i) => (
                    <div key={i} style={{ 
                      padding: '1.25rem', background: '#0f172a', borderRadius: '10px', 
                      borderLeft: `3px solid ${primaryColor}`, boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' 
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', alignItems: 'center' }}>
                        <span style={{ color: '#10b981', fontSize: '0.75rem', fontWeight: '800', background: 'rgba(16, 185, 129, 0.1)', padding: '2px 8px', borderRadius: '4px' }}>
                          {t.score}: {res.score.toFixed(4)}
                        </span>
                        <span style={{ color: '#64748b', fontSize: '0.7rem', fontWeight: 600 }}>{res.metadata.source || 'Unknown'}</span>
                      </div>
                      <p style={{ margin: 0, fontSize: '0.85rem', color: '#94a3b8', lineHeight: '1.6' }}>{res.text}</p>
                    </div>
                  ))}
                </div>
              ) : (
                <div style={{ textAlign: 'center', padding: '5rem 2rem', color: '#475569', fontSize: '0.9rem' }}>
                  <div style={{ fontSize: '2rem', marginBottom: '1rem', opacity: 0.3 }}>🔎</div>
                  {t.testPlaceholder}
                </div>
              )}
            </div>
          </div>
        </Card>
      </div>

    </div>
  );
};

export default IndexingManagement;
