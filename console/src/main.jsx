/* =============================================================================
   PROJECT: Private Corporate AI
   AUTHOR: Francesco Collovà
   LICENSE: Apache License 2.0
   YEAR: 2026
   DESCRIPTION: Entry point for the Document Console React application.
   ============================================================================= */

import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './theme.css'; // Global redesign theme

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
