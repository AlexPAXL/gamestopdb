// Un pool de conexiones por rol de MySQL (gs_admin, gs_gerente, gs_vendedor,
// gs_auditor) + uno de solo-lectura para el login (svc_auth). Así el motor
// de MySQL -no el código Node- es quien de verdad impone el mínimo
// privilegio que ya definió sql/06_security.sql: si una consulta no está
// permitida para ese rol, MySQL la rechaza aunque la ruta tenga un bug.
'use strict';
const mysql = require('mysql2/promise');

function pool(user, password) {
  return mysql.createPool({
    host: process.env.DB_HOST,
    user,
    password,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 5,
    namedPlaceholders: false,
  });
}

const pools = {
  auth: pool(process.env.DB_USER_AUTH, process.env.DB_PASS_AUTH),
  admin: pool(process.env.DB_USER_ADMIN, process.env.DB_PASS_ADMIN),
  gerente: pool(process.env.DB_USER_GERENTE, process.env.DB_PASS_GERENTE),
  vendedor: pool(process.env.DB_USER_VENDEDOR, process.env.DB_PASS_VENDEDOR),
  auditor: pool(process.env.DB_USER_AUDITOR, process.env.DB_PASS_AUDITOR),
};

// req.db (ver middleware/auth.js) ya resuelve el pool correcto por sesión;
// esto es solo el mapa que usa ese middleware y el login.
function poolForRole(rol) {
  const p = pools[rol];
  if (!p) throw new Error(`Rol desconocido: ${rol}`);
  return p;
}

module.exports = { pools, poolForRole };
