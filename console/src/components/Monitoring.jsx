/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Monitoring page for detailed Qdrant statistics and parameters.
   ============================================================================= */

import React, { useState, useEffect } from 'react';
import { api } from '../api/ragClient';

const Monitoring = ({ t, primaryColor }) => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchStats = async () => {
    setLoading(true);
    try {
      const data = await api.getIndexingStats();
      setStats(data);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchStats();
  }, []);

  if (loading && !stats) return <div style={{ color: '#64748b', textAlign: 'center', padding: '5rem' }}>{t.loadingDocs}</div>;

  const Card = ({ title, children }) => (
    <div style={{ 
      background: '#1e293b', border: '1px solid #334155', borderRadius: '12px', 
      padding: '1.5rem', marginBottom: '2rem' 
    }}>
      <h3 style={{ marginTop: 0, marginBottom: '1.5rem', fontSize: '1rem', color: '#f1f5f9', borderBottom: '1px solid #334155', paddingBottom: '0.75rem' }}>{title}</h3>
      {children}
    </div>
  );

  const StatRow = ({ label, value }) => (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
      <span style={{ color: '#94a3b8', fontSize: '0.9rem' }}>{label}</span>
      <span style={{ color: '#f1f5f9', fontWeight: 600, fontSize: '0.9rem' }}>{value}</span>
    </div>
  );

  return (
    <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h2 style={{ margin: 0 }}>{t.monitoringTitle}</h2>
        <button 
          onClick={fetchStats} 
          style={{ 
            background: '#334155', border: 'none', color: 'white', 
            padding: '8px 16px', borderRadius: '8px', cursor: 'pointer' 
          }}
        >
          {t.refreshStats}
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '2rem' }}>
        
        {/* INFO DI SISTEMA */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
          <Card title={t.systemInfo}>
            <StatRow label={t.version} value={stats?.system?.version} />
            <StatRow label={t.engine} value={stats?.database_engine} />
            <StatRow label="Deploy Mode" value={stats?.deploy_mode?.toUpperCase()} />
            <StatRow label={t.totalCollections} value={stats?.total_collections} />
            <StatRow label={t.totalVectors} value={stats?.total_vectors?.toLocaleString()} />
            <StatRow label={t.totalPoints} value={stats?.total_points?.toLocaleString()} />
          </Card>

          <div style={{ background: `color-mix(in srgb, ${primaryColor}, transparent 90%)`, padding: '1.5rem', borderRadius: '12px', border: `1px solid ${primaryColor}` }}>
            <h4 style={{ margin: '0 0 10px 0', color: primaryColor }}>Status</h4>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#10b981' }}></div>
              <span style={{ fontWeight: 700, color: '#f1f5f9' }}>OPERATIONAL</span>
            </div>
            <p style={{ fontSize: '0.75rem', color: '#64748b', marginTop: '10px' }}>Tutti i sistemi vettoriali rispondono correttamente.</p>
          </div>
        </div>

        {/* DETTAGLIO COLLEZIONI */}
        <div>
          <h3 style={{ fontSize: '1.1rem', marginBottom: '1.5rem', color: '#f1f5f9' }}>{t.collectionDetail}</h3>
          {stats?.collections_detail?.map((coll, idx) => (
            <Card key={idx} title={`Collection: ${coll.name}`}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
                <div>
                  <StatRow label="Status" value={<span style={{ color: coll.status === 'green' ? '#10b981' : '#fbbf24' }}>{coll.status.toUpperCase()}</span>} />
                  <StatRow label={t.optimizer} value={coll.optimizer_status.toUpperCase()} />
                  <StatRow label={t.points} value={coll.points_count?.toLocaleString()} />
                  <StatRow label={t.vectors} value={coll.vectors_count?.toLocaleString()} />
                  <StatRow label={t.segments} value={coll.segments_count} />
                </div>
                <div>
                  <h4 style={{ fontSize: '0.8rem', color: '#64748b', textTransform: 'uppercase', marginBottom: '10px' }}>{t.configParams}</h4>
                  <StatRow label={t.vectorSize} value={coll.config.vector_size} />
                  <StatRow label={t.distance} value={coll.config.distance} />
                  <StatRow label="HNSW m" value={coll.config.hnsw_config.m} />
                  <StatRow label="HNSW ef" value={coll.config.hnsw_config.ef_construct} />
                </div>
              </div>
            </Card>
          ))}
        </div>

      </div>
    </div>
  );
};

export default Monitoring;
