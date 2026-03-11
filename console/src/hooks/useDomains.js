/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Custom React hook to manage domain fetching and state.
   ============================================================================= */

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
