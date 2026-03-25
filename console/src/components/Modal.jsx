import React, { useState } from 'react';

const Modal = ({ isOpen, title, onClose, onConfirm, children, confirmText = 'OK', cancelText = 'Cancel' }) => {
  if (!isOpen) return null;

  return (
    <div style={{
      position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.75)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      zIndex: 1000, backdropFilter: 'blur(4px)'
    }}>
      <div style={{
        background: '#1e293b', padding: '1.5rem', borderRadius: '12px',
        width: '400px', maxWidth: '90%', border: '1px solid #334155',
        boxShadow: '0 20px 25px -5px rgb(0 0 0 / 0.1)'
      }}>
        <h3 style={{ marginTop: 0, color: '#f1f5f9' }}>{title}</h3>
        <div style={{ margin: '1rem 0', color: '#94a3b8' }}>{children}</div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '1.5rem' }}>
          <button 
            onClick={onClose}
            style={{ 
              background: '#334155', border: 'none', color: 'white', 
              padding: '8px 16px', borderRadius: '6px', cursor: 'pointer' 
            }}
          >{cancelText}</button>
          <button 
            onClick={onConfirm}
            style={{ 
              background: '#3b82f6', border: 'none', color: 'white', 
              padding: '8px 16px', borderRadius: '6px', cursor: 'pointer',
              fontWeight: 600
            }}
          >{confirmText}</button>
        </div>
      </div>
    </div>
  );
};

export default Modal;
