'use strict';
require('dotenv').config();

// Falla rápido con un mensaje claro en vez de un error críptico más adelante
// (p. ej. express-session reventando en medio de un request) si falta crear
// el .env.
const REQUERIDAS = [
  'SESSION_SECRET', 'DB_HOST', 'DB_NAME',
  'DB_USER_AUTH', 'DB_PASS_AUTH',
  'DB_USER_ADMIN', 'DB_PASS_ADMIN',
  'DB_USER_GERENTE', 'DB_PASS_GERENTE',
  'DB_USER_VENDEDOR', 'DB_PASS_VENDEDOR',
  'DB_USER_AUDITOR', 'DB_PASS_AUDITOR',
];
const faltantes = REQUERIDAS.filter((k) => !process.env[k]);
if (faltantes.length) {
  console.error('\nFalta configurar el archivo .env (variables faltantes: ' + faltantes.join(', ') + ').');
  console.error('Copie app/.env.example a app/.env y ajuste los valores antes de arrancar.\n');
  process.exit(1);
}

const app = require('./src/app');

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`GameStop app escuchando en http://localhost:${port}`);
});
