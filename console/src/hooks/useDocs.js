/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Custom React hook to manage document fetching and state for a specific domain.
   ============================================================================= */

import { useState, useEffect } from 'react';
import { api } from '../api/ragClient';

export const useDocs = (collection) => {
  const [docs, setDocs] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchDocs = async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const data = await api.listDocs(collection);
      setDocs(data.documents || []);
    } catch (e) { console.error(e); }
    if (!silent) setLoading(false);
  };

  useEffect(() => { 
    fetchDocs(); 
  }, [collection]);

  // Polling automatico se ci sono documenti in lavorazione
  useEffect(() => {
    const hasProcessing = docs.some(d => ['queued', 'extracting', 'contextualizing', 'embedding'].includes(d.status));
    
    if (hasProcessing) {
      const interval = setInterval(() => fetchDocs(true), 3000);
      return () => clearInterval(interval);
    }
  }, [docs]);

  return { docs, loading, refetch: fetchDocs };
};
