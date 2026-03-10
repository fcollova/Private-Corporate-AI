import React, { useState, useEffect } from 'react';
import { api } from './api/ragClient';

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

  const fetchData = async () => {
    setLoading(true);
    try {
      const info = await api.clientInfo();
      if (info && info.company) setClientInfo(info);
      
      const doms = await api.listDomains();
      setDomains(Array.isArray(doms) ? doms : []);

      const response = await api.listDocs(selectedDomain);
      setDocs(Array.isArray(response?.documents) ? response.documents : []);
    } catch (e) { 
      console.error("Errore fetch dati:", e); 
    }
    setLoading(false);
  };

  useEffect(() => { fetchData(); }, [selectedDomain, refresh]);

  const handleUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setUploading(true);
    try {
      await api.uploadDoc(file, selectedDomain);
      alert("Upload avviato con successo. Il documento apparirà tra pochi secondi.");
      setTimeout(fetchData, 3000); 
    } catch (e) {
      alert("Errore durante l'upload.");
    }
    setUploading(false);
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

  const getFileIcon = (type) => {
    if (type?.includes('pdf')) return '📕';
    if (type?.includes('doc')) return '📘';
    if (type?.includes('txt') || type?.includes('md')) return '📄';
    return '📁';
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
            background: '#1e293b', 
            borderRadius: '12px', 
            border: '1px solid #334155',
            overflow: 'hidden',
            boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1)'
          }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.9rem' }}>
              <thead>
                <tr style={{ background: '#334155', color: '#cbd5e1', textAlign: 'left' }}>
                  <th style={{ padding: '12px 20px' }}>Documento</th>
                  <th style={{ padding: '12px 20px', textAlign: 'center' }}>Frammenti (Chunk)</th>
                  <th style={{ padding: '12px 20px', textAlign: 'right' }}>Azioni</th>
                </tr>
              </thead>
              <tbody>
                {!docs || docs.length === 0 ? (
                  <tr>
                    <td colSpan="3" style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
                      Nessun documento trovato in questo dominio. Carica un file per iniziare.
                    </td>
                  </tr>
                ) : (
                  docs.map(doc => (
                    <tr key={doc.doc_id} style={{ borderBottom: '1px solid #334155' }}>
                      <td style={{ padding: '16px 20px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <span style={{ fontSize: '1.5rem' }}>{getFileIcon(doc.file_type)}</span>
                          <div>
                            <div style={{ fontWeight: 600, color: '#f1f5f9' }}>{doc.filename || 'Senza nome'}</div>
                            <div style={{ fontSize: '0.7rem', color: '#64748b', fontFamily: 'monospace' }}>ID: {doc.doc_id}</div>
                          </div>
                        </div>
                      </td>
                      <td style={{ padding: '16px 20px', textAlign: 'center' }}>
                        <span style={{ 
                          background: '#0f172a', 
                          padding: '4px 10px', 
                          borderRadius: '12px',
                          fontSize: '0.8rem',
                          border: '1px solid #334155'
                        }}>
                          {doc.chunks_count} chunks
                        </span>
                      </td>
                      <td style={{ padding: '16px 20px', textAlign: 'right' }}>
                        <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                          <button 
                            onClick={() => api.reindexDoc(doc.doc_id, selectedDomain).then(() => { alert("Re-indicizzazione avviata."); fetchData(); })}
                            title="Rigenera embedding"
                            style={{ 
                              background: 'transparent', border: '1px solid #475569', color: '#cbd5e1', 
                              padding: '6px 12px', borderRadius: '4px', cursor: 'pointer', fontSize: '0.8rem'
                            }}
                          >
                            Re-index
                          </button>
                          <button 
                            onClick={() => { if(confirm("Eliminare definitivamente il documento?")) api.deleteDoc(doc.doc_id, selectedDomain).then(() => fetchData()); }}
                            style={{ 
                              background: '#7f1d1d', border: 'none', color: '#fecaca', 
                              padding: '6px 12px', borderRadius: '4px', cursor: 'pointer', fontSize: '0.8rem'
                            }}
                          >
                            Elimina
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </main>
      </div>
    </div>
  );
};

export default App;