'use strict';
// Crea/actualiza los usuarios de LOGIN de la app, uno por cada colaborador
// de ejemplo que ya insertó sql/07_seed.sql, más admin/auditor (que no son
// personal de una sucursal). Idempotente: se puede correr varias veces.
//
// Uso:  node scripts/seed_app_usuarios.js
require('dotenv').config();
const bcrypt = require('bcrypt');
const { pools } = require('../src/db');

// Contraseñas de DESARROLLO únicamente. Documentadas aquí y en el README
// a propósito: son datos de ejemplo (como los de sql/07_seed.sql), no
// credenciales reales. Cámbialas (UPDATE app_usuario ...) en producción.
const USUARIOS = [
  { usuario: 'admin', password: 'Admin#2026', rol: 'admin', fk_Colaborador: null },
  { usuario: 'auditor', password: 'Auditor#2026', rol: 'auditor', fk_Colaborador: null },
  { usuario: 'mperez', password: 'Gerente#2026', rol: 'gerente', fk_Colaborador: 1 }, // Mario Pérez, Zona 10
  { usuario: 'jgomez', password: 'Vendedor#2026', rol: 'vendedor', fk_Colaborador: 2 }, // Julia Gómez, Zona 10
  { usuario: 'pajuc', password: 'Gerente#2026', rol: 'gerente', fk_Colaborador: 3 }, // Pedro Ajú, Mixco
  { usuario: 'kmorales', password: 'Vendedor#2026', rol: 'vendedor', fk_Colaborador: 4 }, // Karla Morales, Mixco
  { usuario: 'ltzul', password: 'Vendedor#2026', rol: 'vendedor', fk_Colaborador: 5 }, // Luis Tzul, Xela
  { usuario: 'eruiz', password: 'Vendedor#2026', rol: 'vendedor', fk_Colaborador: 6 }, // inactivo: para probar el bloqueo de login
];

async function main() {
  for (const u of USUARIOS) {
    const hash = await bcrypt.hash(u.password, 12);
    await pools.admin.query(
      `INSERT INTO app_usuario (usuario, password_hash, rol, fk_Colaborador)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash), rol = VALUES(rol), fk_Colaborador = VALUES(fk_Colaborador)`,
      [u.usuario, hash, u.rol, u.fk_Colaborador]
    );
    console.log(`OK  ${u.usuario.padEnd(10)} rol=${u.rol.padEnd(9)} password=${u.password}`);
  }
  console.log('\nListo. Estas contraseñas son solo para desarrollo/demo.');
  await Promise.all(Object.values(pools).map((p) => p.end()));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
