'use strict';
// Wrappers finos sobre los procedimientos/función ya probados en
// sql/08_validation.sql. Nada de lógica de negocio aquí: eso vive en la
// base de datos a propósito (ver AUDITORIA.md). Esto solo traduce la
// forma CALL ... + variable de sesión @out de MySQL a async/await.

// Usamos una sola conexión (no el pool directo) para el CALL y el
// SELECT @salida: las variables de sesión @var son por-conexión, y con
// el pool cada query podría tomar una conexión distinta.
async function withConnection(pool, fn) {
  const conn = await pool.getConnection();
  try {
    return await fn(conn);
  } finally {
    conn.release();
  }
}

function firstResultSet(rawResults) {
  const sets = Array.isArray(rawResults) ? rawResults : [rawResults];
  return Array.isArray(sets[0]) ? sets[0] : [];
}

async function registrarVenta(pool, { sucursal, cliente, colaborador, detalle }) {
  return withConnection(pool, async (conn) => {
    const [rawResults] = await conn.query('CALL sp_registrar_venta(?, ?, ?, ?, @idVenta)', [
      sucursal,
      cliente,
      colaborador,
      JSON.stringify(detalle),
    ]);
    const [[{ idVenta }]] = await conn.query('SELECT @idVenta AS idVenta');
    return { idVenta, recibo: firstResultSet(rawResults) };
  });
}

async function registrarCompra(pool, { proveedor, sucursal, detalle }) {
  return withConnection(pool, async (conn) => {
    await conn.query('CALL sp_registrar_compra(?, ?, ?, @idCompra)', [
      proveedor,
      sucursal,
      JSON.stringify(detalle),
    ]);
    const [[{ idCompra }]] = await conn.query('SELECT @idCompra AS idCompra');
    return { idCompra };
  });
}

async function anularVenta(pool, { idVenta, motivo }) {
  await pool.query('CALL sp_anular_venta(?, ?)', [idVenta, motivo]);
}

async function consultarCliente(pool, idCliente) {
  const [rawResults] = await pool.query('CALL sp_consultar_cliente(?)', [idCliente]);
  return firstResultSet(rawResults)[0] || null;
}

async function stockDisponible(pool, { sucursal, producto }) {
  const [[row]] = await pool.query('SELECT fn_stock_disponible(?, ?) AS stock', [sucursal, producto]);
  return row.stock;
}

module.exports = { registrarVenta, registrarCompra, anularVenta, consultarCliente, stockDisponible };
