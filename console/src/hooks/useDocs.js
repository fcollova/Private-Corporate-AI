import { useState, useEffect } from 'react';
import { api } from '../api/ragClient';

export const useDocs = (collection) => {
  const [docs, setDocs] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchDocs = async () => {
    setLoading(true);
    try {
      const data = await api.listDocs(collection);
      setDocs(data.documents || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  };

  useEffect(() => { fetchDocs(); }, [collection]);

  return { docs, loading, refetch: fetchDocs };
};
