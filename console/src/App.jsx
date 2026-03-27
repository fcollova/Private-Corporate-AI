/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Main Redesigned Application Shell.
   ============================================================================= */

import React, { useState, useEffect, useRef } from 'react';
import { api } from './api/ragClient';
import DocTable from './components/DocTable';
import Modal from './components/Modal';
import IndexingManagement from './components/IndexingManagement';
import IndexingTest from './components/IndexingTest';
import Monitoring from './components/Monitoring';
import locales from './locales';

const App = () => {
  const [currentView, setCurrentView] = useState('knowledge');
  const [selectedDomain, setSelectedDomain] = useState('corporate_docs');
  const [refresh, setRefresh] = useState(0);
  const [domains, setDomains] = useState([]);
  const [docs, setDocs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [clientInfo, setClientInfo] = useState({ company: 'Private AI', theme_color: '#4f7fff', lang_code: 'it' });
  
  const [modal, setModal] = useState({ isOpen: false, title: '', content: '', onConfirm: () => {}, confirmText: 'OK' });
  const pollingRef = useRef(null);
  
  const t = locales[clientInfo.lang_code] || locales.it;

  const fetchData = async () => {
    try {
      const info = await api.clientInfo();
      if (info?.company) setClientInfo(info);
      
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
    } catch (e) { console.error(e); }
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
    } catch (e) { alert(t.errorUpload); }
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

  const handleCreateDomain = async () => {
    const name = prompt(t.promptNewDomain);
    if (!name) return;
    try {
      await api.createDomain(name);
      fetchData();
    } catch (e) { alert(t.errorNewDomain); }
  };

  const filteredDocs = docs.filter(doc => 
    doc.filename.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const stats = {
    total: docs.length,
    fragments: domains.find(d => d.name === selectedDomain)?.points_count || 0,
    processing: docs.filter(d => ['queued', 'extracting', 'contextualizing', 'embedding'].includes(d.status)).length,
    errors: docs.filter(d => d.status === 'failed').length
  };

  return (
    <div className="shell">
      <Modal 
        isOpen={modal.isOpen} 
        title={modal.title} 
        onClose={() => setModal(prev => ({ ...prev, isOpen: false }))}
        onConfirm={modal.onConfirm}
        confirmText={modal.confirmText}
      >
        {modal.content}
      </Modal>

      {/* TOPBAR */}
      <div className="topbar">
        <div className="logo">
          <div className="logo-mark">{clientInfo.company.substring(0, 2).toUpperCase()}</div>
          <div>
            <div className="logo-name">{clientInfo.company}</div>
            <div className="logo-sub">DOCUMENT CONSOLE</div>
          </div>
        </div>
        <div className="topbar-sep"></div>
        <div className="breadcrumb">
          Knowledge Base › <span>{selectedDomain}</span>
        </div>
        <div className="topbar-actions">
          <button className="btn-icon" title="Aggiorna" onClick={() => setRefresh(r => r + 1)} disabled={loading}>
            <svg width="13" height="13" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
              <path d="M1 3v4h4M13 11v-4h-4M1 7A6 6 0 0012.5 9M13 7a6 6 0 00-11.5-2"/>
            </svg>
          </button>
          <button className="btn" onClick={handleCreateDomain}>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"><path d="M6 1v10M1 6h10"/></svg>
            Nuovo Dominio
          </button>
          <button className="btn btn-primary" onClick={() => document.getElementById('upload').click()} disabled={uploading}>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M6 8V2M3 5l3-3 3 3M1 10h10"/></svg>
            {uploading ? t.uploading : t.upload}
          </button>
          <input type="file" id="upload" style={{ display: 'none' }} onChange={handleUpload} />
        </div>
      </div>

      <div className="main-shell">
        {/* SIDEBAR */}
        <div className="sidebar">
          <div className="sidebar-section">
            <div className="sidebar-label">Navigazione</div>
            <div className={`nav-item ${currentView === 'knowledge' ? 'active' : ''}`} onClick={() => setCurrentView('knowledge')}>
              📚 {t.menuKnowledge}
            </div>
            <div className={`nav-item ${currentView === 'indexing' ? 'active' : ''}`} onClick={() => setCurrentView('indexing')}>
              ⚙️ {t.menuIndexing}
            </div>
            <div className={`nav-item ${currentView === 'monitoring' ? 'active' : ''}`} onClick={() => setCurrentView('monitoring')}>
              📊 {t.menuMonitoring}
            </div>
            <div className={`nav-item ${currentView === 'index_test' ? 'active' : ''}`} onClick={() => setCurrentView('index_test')}>
              🔍 {t.menuTest}
            </div>
          </div>

          <div className="sidebar-section" style={{ flex: 1, overflowY: 'auto' }}>
            <div className="sidebar-label">{t.sidebarDomains}</div>
            {domains.map(d => (
              <div 
                key={d.name} 
                className={`domain-item ${selectedDomain === d.name ? 'active' : ''}`}
                onClick={() => setSelectedDomain(d.name)}
              >
                <div className="domain-dot" style={{ background: selectedDomain === d.name ? 'var(--accent)' : 'var(--text3)' }}></div>
                <div className="domain-info">
                  <div className="domain-name">{d.name}</div>
                  <div className="domain-count">{d.points_count} frammenti</div>
                </div>
              </div>
            ))}
          </div>

          <div className="sidebar-footer">
            <div className="health-row">
              <div className="health-dot"></div>
              <div className="health-label">Backend RAG</div>
              <div className="health-val">Online</div>
            </div>
          </div>
        </div>

        {/* CONTENT AREA */}
        <div className="content">
          {currentView === 'knowledge' && (
            <>
              <div className="content-header">
                <div className="domain-title">
                  <h1>{selectedDomain}</h1>
                  <div className="domain-tag">ATTIVO</div>
                </div>
                <div className="domain-desc">{t.manageDocs}</div>
              </div>

              {/* STATS */}
              <div className="stats-row">
                <div className="stat-card">
                  <div className="stat-label">Documenti</div>
                  <div className="stat-value">{stats.total}</div>
                </div>
                <div className="stat-card">
                  <div className="stat-label">Frammenti</div>
                  <div className="stat-value">{stats.fragments}</div>
                </div>
                <div className="stat-card">
                  <div className="stat-label">In elaborazione</div>
                  <div className="stat-value" style={{ color: 'var(--accent)' }}>{stats.processing}</div>
                </div>
                <div className="stat-card">
                  <div className="stat-label">Errori</div>
                  <div className="stat-value" style={{ color: 'var(--red)' }}>{stats.errors}</div>
                </div>
              </div>

              {/* TABLE */}
              <div className="table-wrap">
                <div className="table-toolbar">
                  <div className="search-box">
                    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="var(--text3)" strokeWidth="1.4" strokeLinecap="round">
                      <circle cx="5" cy="5" r="3.5"/><path d="M7.8 7.8l2 2"/>
                    </svg>
                    <input placeholder={t.searchPlaceholder} value={searchQuery} onChange={e => setSearchQuery(e.target.value)} />
                  </div>
                </div>
                <DocTable 
                  docs={filteredDocs} 
                  onDelete={handleDelete} 
                  onReindex={handleReindex} 
                  t={t} 
                />
              </div>
            </>
          )}

          {currentView === 'indexing' && <div style={{ padding: '24px' }}><IndexingManagement t={t} selectedDomain={selectedDomain} /></div>}
          {currentView === 'index_test' && <div style={{ padding: '24px' }}><IndexingTest t={t} selectedDomain={selectedDomain} /></div>}
          {currentView === 'monitoring' && <div style={{ padding: '24px' }}><Monitoring t={t} /></div>}
        </div>
      </div>

      {/* STATUSBAR */}
      <div className="statusbar">
        <div className="sb-item">
          <div className="sb-dot" style={{ background: 'var(--green)' }}></div>
          Sistema operativo
        </div>
        <div className="sb-sep"></div>
        <div className="sb-item">{stats.processing} elaborazioni in corso</div>
        {stats.errors > 0 && (
          <>
            <div className="sb-sep"></div>
            <div className="sb-item" style={{ color: 'var(--red)' }}>{stats.errors} errore/i riscontrato/i</div>
          </>
        )}
        <div className="ai-badge">
          <svg width="9" height="9" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round">
            <circle cx="5" cy="5" r="3.5"/><path d="M3.5 5h3M5 3.5v3"/>
          </svg>
          EU AI Act Compliant · {t.aiDisclosureText}
        </div>
      </div>
    </div>
  );
};

export default App;
