'use strict';
// Componentes de Alpine.js (build CSP: sin eval, por eso x-data referencia
// estos nombres registrados en vez de llevar un objeto literal inline).
// Nada de lógica de negocio aquí: solo estado de UI (abrir/cerrar).
document.addEventListener('alpine:init', () => {
  Alpine.data('sidebar', () => ({ open: false }));
  Alpine.data('dropdown', () => ({ open: false }));
  Alpine.data('confirmModal', () => ({ open: false }));
  // Sin estado propio: solo sirve de raíz Alpine para que @change pueda
  // auto-enviar un <form> de filtro (la CSP bloquea onchange="" inline).
  Alpine.data('autoSubmit', () => ({}));
});
