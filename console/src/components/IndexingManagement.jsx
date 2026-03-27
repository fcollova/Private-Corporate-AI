/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Component for managing indexing settings and testing retrieval.
   ============================================================================= */

import React, { useState, useEffect, useRef } from 'react';
import { api } from '../api/ragClient';

const labelStyle = { color: '#94a3b8', fontSize: '0.85rem', fontWeight: '600' };
const inputStyle = {
  background: '#0f172a', border: '1px solid #334155', color: 'white',
  padding: '10px', borderRadius: '8px', width: '100%', marginTop: '5px',
  outline: 'none', boxSizing: 'border-box'
};

const Card = ({ title, icon, children, style, primaryColor }) => (
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

const IndexingManagement = ({ t, primaryColor, selectedDomain }) => {
  const [settings, setSettings] = useState({
    chunk_size: 1000,
    chunk_overlap: 200,
    top_k_results: 5,
    hybrid_search_enabled: true,
    llm_temperature: 0.2
  });
  const [stats, setStats] = useState(null);
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

      <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '2rem', maxWidth: '800px' }}>
        
        {/* CONFIGURATION SECTION */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
          
          <Card title={t.indexingParams} icon="🏗️" primaryColor={primaryColor}>
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

          <Card title={t.retrievalParams} icon="⚡" primaryColor={primaryColor}>
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
      </div>

    </div>
  );
};

export default IndexingManagement;
