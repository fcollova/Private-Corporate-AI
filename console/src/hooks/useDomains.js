import { useState, useEffect } from 'react';
import { api } from '../api/ragClient';

export const useDomains = () => {
  const [domains, setDomains] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchDomains = async () => {
    setLoading(true);
    try {
      const data = await api.listDomains();
      setDomains(data || []);
    } catch (e) { console.error(e); }
    setLoading(false);
  };

  useEffect(() => { fetchDomains(); }, []);

  return { domains, loading, refetch: fetchDomains };
};
