/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Main React application component for the Document Console.
   ============================================================================= */

import React, { useState, useEffect, useRef } from 'react';
import { api } from './api/ragClient';
import DocTable from './components/DocTable';
import Modal from './components/Modal';
import IndexingManagement from './components/IndexingManagement';
import Monitoring from './components/Monitoring';
import locales from './locales';

const App = () => {
  const [currentView, setCurrentView] = useState('knowledge'); // 'knowledge', 'indexing', 'monitoring'
  const [selectedDomain, setSelectedDomain] = useState('corporate_docs');
  const [refresh, setRefresh] = useState(0);
  const [domains, setDomains] = useState([]);
  const [docs, setDocs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [clientInfo, setClientInfo] = useState({
    company: 'Private Corporate AI',
    theme_color: '#3b82f6',
    lang_code: 'it'
  });

  // Modal State
  const [modal, setModal] = useState({ isOpen: false, title: '', content: '', onConfirm: () => {}, confirmText: 'OK' });

  const pollingRef = useRef(null);
  
  // Choose locale based on clientInfo (default to 'it')
  const t = locales[clientInfo.lang_code] || locales.it;

  const fetchData = async () => {
    try {
      const info = await api.clientInfo();
      if (info && info.company) setClientInfo(info);
      
      const doms = await api.listDomains();
      setDomains(Array.isArray(doms) ? doms : []);

      if (currentView === 'knowledge') {
        const response = await api.listDocs(selectedDomain);
        const newDocs = Array.isArray(response?.documents) ? response.documents : [];
        setDocs(newDocs);

        const hasProcessing = newDocs.some(d => ['queued', 'extracting', 'contextualizing', 'embedding'].includes(d.status));
        if (hasProcessing && !pollingRef.current) {
          pollingRef.current = setInterval(fetchData, 3000);
        } else if (!hasProcessing && pollingRef.current) {
          clearInterval(pollingRef.current);
          pollingRef.current = null;
        }
      }
    } catch (e) { 
      console.error("Fetch error:", e); 
    }
  };

  useEffect(() => { 
    setLoading(true);
    fetchData().then(() => setLoading(false));
    return () => { if (pollingRef.current) clearInterval(pollingRef.current); };
  }, [selectedDomain, refresh, currentView]);

  const handleUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setUploading(true);
    try {
      await api.uploadDoc(file, selectedDomain);
      fetchData();
    } catch (e) {
      alert(t.errorUpload);
    }
    setUploading(false);
  };

  const handleDelete = (id) => {
    setModal({
      isOpen: true,
      title: t.actionDelete,
      content: t.confirmDelete,
      confirmText: t.actionDelete,
      onConfirm: async () => {
        try {
          await api.deleteDoc(id, selectedDomain);
          fetchData();
          setModal(prev => ({ ...prev, isOpen: false }));
        } catch (e) { alert(t.errorDelete); }
      }
    });
  };

  const handleReindex = async (id) => {
    try {
      await api.reindexDoc(id, selectedDomain);
      fetchData();
    } catch (e) { alert(t.errorReindex); }
  };

  const handleMove = (doc) => {
    const newDomain = prompt(t.errorMove, selectedDomain); 
    if (!newDomain || newDomain === selectedDomain) return;
    api.moveDoc(doc.doc_id, { target_collection: newDomain })
      .then(() => fetchData())
      .catch(() => alert(t.errorMove));
  };

  const handleCreateDomain = async () => {
    const name = prompt(t.promptNewDomain);
    if (!name) return;
    try {
      await api.createDomain(name);
      fetchData();
    } catch (e) {
      alert(t.errorNewDomain);
    }
  };

  const filteredDocs = docs.filter(doc => 
    doc.filename.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const primaryColor = clientInfo?.theme_color || '#3b82f6';
  const companyName = clientInfo?.company || 'Private Corporate AI';

  const NavItem = ({ id, label, icon }) => (
    <div 
      onClick={() => setCurrentView(id)}
      style={{ 
        padding: '12px 16px', borderRadius: '10px', cursor: 'pointer',
        background: currentView === id ? `rgba(59, 130, 246, 0.1)` : 'transparent',
        color: currentView === id ? '#f1f5f9' : '#64748b',
        fontWeight: currentView === id ? 700 : 500,
        display: 'flex', alignItems: 'center', gap: '12px', transition: 'all 0.2s'
      }}
    >
      <span style={{ fontSize: '1.2rem' }}>{icon}</span>
      {label}
    </div>
  );

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#0f172a', 
      color: '#f8fafc',
      fontFamily: 'Inter, system-ui, sans-serif'
    }}>
      <Modal 
        isOpen={modal.isOpen} 
        title={modal.title} 
        onClose={() => setModal(prev => ({ ...prev, isOpen: false }))}
        onConfirm={modal.onConfirm}
        confirmText={modal.confirmText}
      >
        {modal.content}
      </Modal>

      {/* HEADER PRINCIPALE */}
      <header style={{ 
        background: '#1e293b', 
        padding: '1rem 2rem', 
        borderBottom: '1px solid #334155',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        position: 'sticky', top: 0, zIndex: 100
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ 
            background: `linear-gradient(135deg, ${primaryColor} 0%, color-mix(in srgb, ${primaryColor}, black 20%) 100%)`,
            width: '40px', height: '40px', borderRadius: '10px',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontWeight: 'bold', fontSize: '18px', boxShadow: `0 0 15px color-mix(in srgb, ${primaryColor}, transparent 60%)`
          }}>{companyName.substring(0, 2).toUpperCase()}</div>
          <div>
            <h1 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 700, letterSpacing: '-0.025em' }}>{companyName}</h1>
            <p style={{ margin: 0, fontSize: '0.7rem', color: '#64748b', fontWeight: 600, letterSpacing: '0.05em' }}>{t.title}</p>
          </div>
        </div>
        
        <div style={{ display: 'flex', gap: '12px' }}>
          <button 
            onClick={() => setRefresh(r => r + 1)}
            style={{ 
              background: '#334155', border: 'none', color: '#94a3b8', 
              padding: '8px 16px', borderRadius: '8px', cursor: 'pointer',
              display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.9rem', fontWeight: 500
            }}
          >
            {loading ? '...' : t.refresh}
          </button>
          {currentView === 'knowledge' && (
            <>
              <button 
                onClick={handleCreateDomain}
                style={{ 
                  background: '#334155', border: 'none', color: '#f1f5f9', 
                  padding: '8px 16px', borderRadius: '8px', cursor: 'pointer',
                  fontSize: '0.9rem', fontWeight: 500
                }}
              >
                {t.newDomain}
              </button>
              <input type="file" onChange={handleUpload} id="upload" style={{ display: 'none' }} />
              <button 
                onClick={() => document.getElementById('upload').click()}
                disabled={uploading}
                style={{ 
                  background: primaryColor, border: 'none', color: 'white', 
                  padding: '8px 18px', borderRadius: '8px', cursor: 'pointer',
                  fontWeight: 600, fontSize: '0.9rem', boxShadow: `0 4px 6px -1px color-mix(in srgb, ${primaryColor}, transparent 70%)`
                }}
              >
                {uploading ? t.uploading : t.upload}
              </button>
            </>
          )}
        </div>
      </header>

      <div style={{ display: 'grid', gridTemplateColumns: '300px 1fr', minHeight: 'calc(100vh - 73px)' }}>
        
        {/* SIDEBAR NAVIGATION */}
        <aside style={{ 
          background: '#0f172a', 
          borderRight: '1px solid #334155',
          padding: '2rem 1.5rem',
          display: 'flex',
          flexDirection: 'column',
          gap: '2rem'
        }}>
          <div>
            <h3 style={{ fontSize: '0.7rem', color: '#475569', textTransform: 'uppercase', marginBottom: '1rem', letterSpacing: '0.1em', fontWeight: 800 }}>Menu</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              <NavItem id="knowledge" label={t.menuKnowledge} icon="📚" />
              <NavItem id="indexing" label={t.menuIndexing} icon="⚙️" />
              <NavItem id="monitoring" label={t.menuMonitoring} icon="📊" />
            </div>
          </div>

          {currentView === 'knowledge' && (
            <div>
              <h3 style={{ fontSize: '0.7rem', color: '#475569', textTransform: 'uppercase', marginBottom: '1.25rem', letterSpacing: '0.1em', fontWeight: 800 }}>{t.availableDomains}</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                {Array.isArray(domains) && domains.map(d => (
                  <div 
                    key={d.name}
                    onClick={() => setSelectedDomain(d.name)}
                    style={{ 
                      padding: '12px 16px',
                      borderRadius: '10px',
                      cursor: 'pointer',
                      background: selectedDomain === d.name ? `rgba(255, 255, 255, 0.05)` : 'transparent',
                      border: selectedDomain === d.name ? `1px solid rgba(255, 255, 255, 0.1)` : '1px solid transparent',
                      color: selectedDomain === d.name ? '#f1f5f9' : '#64748b',
                      transition: 'all 0.2s'
                    }}
                  >
                    <div style={{ fontWeight: 600, fontSize: '0.9rem', marginBottom: '2px' }}>{d.name}</div>
                    <div style={{ fontSize: '0.75rem', opacity: 0.6 }}>{d.points_count} {t.fragments}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </aside>

        {/* MAIN CONTENT */}
        <main style={{ padding: '2.5rem', background: '#020617' }}>
          
          {currentView === 'knowledge' && (
            <>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '2rem' }}>
                <div>
                  <h2 style={{ margin: 0, fontSize: '1.75rem', fontWeight: 800, letterSpacing: '-0.025em' }}>{t.knowledgeBase}: <span style={{ color: primaryColor }}>{selectedDomain}</span></h2>
                  <p style={{ color: '#64748b', margin: '8px 0 0 0', fontSize: '0.95rem' }}>{t.manageDocs}</p>
                </div>
                <div style={{ position: 'relative' }}>
                  <input 
                    type="text" 
                    placeholder={t.searchPlaceholder}
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    style={{
                      background: '#1e293b', border: '1px solid #334155', color: 'white',
                      padding: '10px 16px', borderRadius: '8px', width: '300px',
                      outline: 'none', fontSize: '0.9rem'
                    }}
                  />
                </div>
              </div>

              <div style={{ boxShadow: '0 20px 25px -5px rgb(0 0 0 / 0.2)' }}>
                {loading && docs.length === 0 ? (
                  <div style={{ padding: '60px', textAlign: 'center', color: '#64748b' }}>
                    <div style={{ fontSize: '1.5rem', marginBottom: '1rem' }}>⌛</div>
                    {t.loadingDocs}
                  </div>
                ) : (
                  <DocTable 
                    docs={filteredDocs} 
                    onAction={handleMove}
                    onDelete={handleDelete}
                    onReindex={handleReindex}
                    t={t}
                  />
                )}
              </div>
            </>
          )}

          {currentView === 'indexing' && (
            <IndexingManagement t={t} primaryColor={primaryColor} selectedDomain={selectedDomain} />
          )}

          {currentView === 'monitoring' && (
            <Monitoring t={t} primaryColor={primaryColor} />
          )}

        </main>
      </div>

      {/* FOOTER */}
      <footer style={{ 
        background: '#0f172a', 
        padding: '1rem 2rem', 
        borderTop: '1px solid #334155',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        fontSize: '0.75rem',
        color: '#64748b'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <span style={{ 
            background: 'rgba(51, 65, 85, 0.5)', 
            padding: '4px 10px', 
            borderRadius: '6px', 
            fontSize: '0.65rem',
            fontWeight: '800',
            color: '#cbd5e1',
            border: '1px solid rgba(255, 255, 255, 0.1)'
          }}>{t.aiDisclosure}</span>
          <span style={{ opacity: 0.8 }}>{t.aiDisclosureText}</span>
        </div>
      </footer>
    </div>
  );
};

export default App;
