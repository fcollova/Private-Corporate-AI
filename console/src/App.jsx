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

const App = () => {
  const [selectedDomain, setSelectedDomain] = useState('corporate_docs');
  const [refresh, setRefresh] = useState(0);
  const [domains, setDomains] = useState([]);
  const [docs, setDocs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [clientInfo, setClientInfo] = useState({
    company: 'Private Corporate AI',
    theme_color: '#3b82f6'
  });

  const pollingRef = useRef(null);

  const fetchData = async () => {
    // Non settiamo loading a true durante il polling per non disturbare l'utente
    try {
      const info = await api.clientInfo();
      if (info && info.company) setClientInfo(info);
      
      const doms = await api.listDomains();
      setDomains(Array.isArray(doms) ? doms : []);

      const response = await api.listDocs(selectedDomain);
      const newDocs = Array.isArray(response?.documents) ? response.documents : [];
      setDocs(newDocs);

      // Se ci sono documenti in elaborazione, attiviamo il polling
      const hasProcessing = newDocs.some(d => d.status === 'processing');
      if (hasProcessing && !pollingRef.current) {
        pollingRef.current = setInterval(fetchData, 3000);
      } else if (!hasProcessing && pollingRef.current) {
        clearInterval(pollingRef.current);
        pollingRef.current = null;
      }
    } catch (e) { 
      console.error("Errore fetch dati:", e); 
    }
  };

  useEffect(() => { 
    setLoading(true);
    fetchData().then(() => setLoading(false));
    return () => { if (pollingRef.current) clearInterval(pollingRef.current); };
  }, [selectedDomain, refresh]);

  const handleUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setUploading(true);
    try {
      await api.uploadDoc(file, selectedDomain);
      fetchData(); // Aggiorna subito per mostrare lo stato "processing"
    } catch (e) {
      alert("Errore durante l'upload.");
    }
    setUploading(false);
  };

  const handleDelete = async (id) => {
    if(!confirm("Eliminare definitivamente il documento?")) return;
    try {
      await api.deleteDoc(id, selectedDomain);
      fetchData();
    } catch (e) { alert("Errore eliminazione."); }
  };

  const handleReindex = async (id) => {
    try {
      await api.reindexDoc(id, selectedDomain);
      fetchData();
    } catch (e) { alert("Errore re-indexing."); }
  };

  const handleMove = (doc) => {
    const newDomain = prompt("Inserisci il nome del dominio di destinazione:", selectedDomain);
    if (!newDomain || newDomain === selectedDomain) return;
    api.moveDoc(doc.doc_id, { target_collection: newDomain })
      .then(() => fetchData())
      .catch(() => alert("Errore durante lo spostamento."));
  };

  const handleCreateDomain = async () => {
    const name = prompt("Inserisci il nome tecnico del nuovo dominio (es: ufficio_legale):");
    if (!name) return;
    try {
      await api.createDomain(name);
      fetchData();
    } catch (e) {
      alert("Errore creazione dominio. Verifica che il nome non contenga spazi o caratteri speciali.");
    }
  };

  const primaryColor = clientInfo?.theme_color || '#3b82f6';
  const companyName = clientInfo?.company || 'Private Corporate AI';

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#0f172a', 
      color: '#f8fafc',
      fontFamily: 'Inter, system-ui, sans-serif'
    }}>
      {/* HEADER PRINCIPALE */}
      <header style={{ 
        background: '#1e293b', 
        padding: '1rem 2rem', 
        borderBottom: '1px solid #334155',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ 
            background: `linear-gradient(135deg, ${primaryColor} 0%, color-mix(in srgb, ${primaryColor}, black 20%) 100%)`,
            width: '40px', height: '40px', borderRadius: '8px',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontWeight: 'bold', fontSize: '20px'
          }}>{companyName.substring(0, 2).toUpperCase()}</div>
          <div>
            <h1 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 700 }}>{companyName}</h1>
            <p style={{ margin: 0, fontSize: '0.75rem', color: '#94a3b8', letterSpacing: '0.05em' }}>DOCUMENT CONSOLE</p>
          </div>
        </div>
        
        <div style={{ display: 'flex', gap: '12px' }}>
          <button 
            onClick={() => setRefresh(r => r + 1)}
            style={{ 
              background: '#334155', border: 'none', color: 'white', 
              padding: '8px 16px', borderRadius: '6px', cursor: 'pointer',
              display: 'flex', alignItems: 'center', gap: '8px'
            }}
          >
            {loading ? '...' : '🔄 Aggiorna'}
          </button>
          <button 
            onClick={handleCreateDomain}
            style={{ 
              background: '#334155', border: 'none', color: 'white', 
              padding: '8px 16px', borderRadius: '6px', cursor: 'pointer'
            }}
          >
            + Nuovo Dominio
          </button>
          <input type="file" onChange={handleUpload} id="upload" style={{ display: 'none' }} />
          <button 
            onClick={() => document.getElementById('upload').click()}
            disabled={uploading}
            style={{ 
              background: primaryColor, border: 'none', color: 'white', 
              padding: '8px 16px', borderRadius: '6px', cursor: 'pointer',
              fontWeight: 600
            }}
          >
            {uploading ? 'Caricamento...' : '↑ Carica Documento'}
          </button>
        </div>
      </header>

      <div style={{ display: 'grid', gridTemplateColumns: '280px 1fr', minHeight: 'calc(100vh - 73px)' }}>
        
        {/* SIDEBAR DOMINI */}
        <aside style={{ 
          background: '#0f172a', 
          borderRight: '1px solid #334155',
          padding: '1.5rem'
        }}>
          <h3 style={{ fontSize: '0.75rem', color: '#64748b', textTransform: 'uppercase', marginBottom: '1rem' }}>Domini Disponibili</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {Array.isArray(domains) && domains.map(d => (
              <div 
                key={d.name}
                onClick={() => setSelectedDomain(d.name)}
                style={{ 
                  padding: '12px 16px',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  background: selectedDomain === d.name ? `color-mix(in srgb, ${primaryColor}, transparent 90%)` : 'transparent',
                  border: selectedDomain === d.name ? `1px solid ${primaryColor}` : '1px solid transparent',
                  color: selectedDomain === d.name ? `color-mix(in srgb, ${primaryColor}, white 20%)` : '#94a3b8',
                  transition: 'all 0.2s'
                }}
              >
                <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>{d.name}</div>
                <div style={{ fontSize: '0.75rem', opacity: 0.7 }}>{d.points_count} frammenti vettoriali</div>
              </div>
            ))}
          </div>
        </aside>

        {/* MAIN CONTENT - TABELLA DOCUMENTI */}
        <main style={{ padding: '2rem', background: '#020617' }}>
          <div style={{ marginBottom: '1.5rem' }}>
            <h2 style={{ margin: 0, fontSize: '1.5rem' }}>Knowledge Base: <span style={{ color: primaryColor }}>{selectedDomain}</span></h2>
            <p style={{ color: '#64748b', margin: '4px 0 0 0' }}>Gestisci i documenti indicizzati in questo dominio informativo.</p>
          </div>

          <div style={{ 
            borderRadius: '12px', 
            overflow: 'hidden',
            boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)'
          }}>
            {loading && docs.length === 0 ? (
              <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>Caricamento documenti...</div>
            ) : (
              <DocTable 
                docs={docs} 
                onAction={handleMove}
                onDelete={handleDelete}
                onReindex={handleReindex}
              />
            )}
          </div>
        </main>
      </div>

      {/* FOOTER DI TRASPARENZA (EU AI Act Compliance) */}
      <footer style={{ 
        background: '#1e293b', 
        padding: '0.75rem 2rem', 
        borderTop: '1px solid #334155',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        fontSize: '0.8rem',
        color: '#94a3b8'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ 
            background: '#334155', 
            padding: '2px 8px', 
            borderRadius: '4px', 
            fontSize: '0.7rem',
            fontWeight: 'bold',
            color: '#f1f5f9'
          }}>AI DISCLOSURE</span>
          <span>Interazione con sistema di Intelligenza Artificiale (EU AI Act Compliant). Le risposte sono generate automaticamente e devono essere verificate.</span>
        </div>
      </footer>
    </div>
  );
};

export default App;