'use strict';
// Los procedimientos de sql/04_routines.sql usan SIGNAL SQLSTATE '45000'
// para sus propias reglas de negocio (stock insuficiente, venta ya
// anulada, etc.) y ESOS mensajes ya están escritos en español para que
// el usuario los lea directo (ver AUDITORIA.md: la lógica de negocio
// vive a propósito en la base de datos). Cualquier OTRO error de MySQL
// (clave duplicada, restricción CHECK con su nombre interno, sintaxis,
// conexión…) no está pensado para mostrarse tal cual: expondría nombres
// de tabla/columna/índice y confundiría al usuario.
function mensajeAmigable(err, fallback) {
  if (err && err.sqlState === '45000' && err.sqlMessage) return err.sqlMessage;
  return fallback;
}

module.exports = { mensajeAmigable };
