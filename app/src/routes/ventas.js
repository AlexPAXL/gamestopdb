'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');
const { registrarVenta, anularVenta } = require('../lib/procs');

const router = express.Router();
const NUM_LINEAS = 8; // filas en blanco del formulario; sin JS de "agregar línea" (ver shortcut abajo)

// Resuelve con qué colaborador/sucursal se va a vender:
//  - vendedor/gerente: el suyo (fijo, viene de la sesión).
//  - admin: no tiene colaborador propio; debe elegir uno (?colaborador=ID).
async function resolverContextoVenta(req) {
  const { user } = req.session;
  if (user.fk_Colaborador) {
    return { colaboradorId: user.fk_Colaborador, sucursalId: user.fk_Sucursal, sucursalNombre: user.nombreSucursal, colaboradorNombre: user.nombreColaborador };
  }
  const colaboradorId = req.query.colaborador ? Number(req.query.colaborador) : (req.body.colaborador ? Number(req.body.colaborador) : null);
  if (!colaboradorId) return null;
  const [[colab]] = await req.db.query(
    `SELECT co.idColaborador, co.nombre_colaborador, co.fk_Sucursal, s.nombre_sucursal
     FROM colaborador co JOIN sucursal s ON s.idSucursal = co.fk_Sucursal
     WHERE co.idColaborador = ? AND co.activo`,
    [colaboradorId]
  );
  if (!colab) return null;
  return { colaboradorId: colab.idColaborador, sucursalId: colab.fk_Sucursal, sucursalNombre: colab.nombre_sucursal, colaboradorNombre: colab.nombre_colaborador };
}

router.get('/nueva', requireRole('vendedor', 'gerente', 'admin'), async (req, res) => {
  const contexto = await resolverContextoVenta(req);

  if (!contexto) {
    // Solo le pasa a admin: primero elige a nombre de qué colaborador vende.
    const [colaboradores] = await req.db.query(
      `SELECT co.idColaborador, co.nombre_colaborador, s.nombre_sucursal
       FROM colaborador co JOIN sucursal s ON s.idSucursal = co.fk_Sucursal
       WHERE co.activo ORDER BY s.nombre_sucursal, co.nombre_colaborador`
    );
    return res.render('ventas/elegir_colaborador', { title: 'Nueva venta' , colaboradores });
  }

  const [clientes] = await req.db.query('SELECT idCliente, nombre_cliente FROM v_cliente_publico ORDER BY nombre_cliente');
  const [productos] = await req.db.query(
    'SELECT idProducto, codigo_sku, nombre_producto, precio_producto, stock_disponible FROM v_inventario_sucursal WHERE idSucursal = ? ORDER BY nombre_producto',
    [contexto.sucursalId]
  );
  res.render('ventas/nueva', { title: 'Nueva venta', contexto, clientes, productos, lineas: NUM_LINEAS });
});

router.post('/', requireRole('vendedor', 'gerente', 'admin'), async (req, res) => {
  const contexto = await resolverContextoVenta(req);
  if (!contexto) {
    req.flash('error', 'Selecciona a nombre de qué colaborador se registra la venta.');
    return res.redirect('/ventas/nueva');
  }

  let clienteId = req.body.cliente_id ? Number(req.body.cliente_id) : null;
  if (!clienteId && req.body.cliente_nuevo_nombre && req.body.cliente_nuevo_correo) {
    const [r] = await req.db.query('INSERT INTO cliente (nombre_cliente, correo_cliente) VALUES (?, ?)', [
      req.body.cliente_nuevo_nombre,
      req.body.cliente_nuevo_correo,
    ]);
    clienteId = r.insertId;
  }

  const productosForm = [].concat(req.body.producto || []);
  const cantidadesForm = [].concat(req.body.cantidad || []);
  const detalle = productosForm
    .map((p, i) => ({ producto: Number(p), cantidad: Number(cantidadesForm[i]) }))
    .filter((l) => l.producto && l.cantidad > 0);

  if (!clienteId) {
    req.flash('error', 'Selecciona un cliente o registra uno nuevo.');
    return res.redirect(`/ventas/nueva?colaborador=${contexto.colaboradorId}`);
  }
  if (detalle.length === 0) {
    req.flash('error', 'Agrega al menos un producto con cantidad mayor a cero.');
    return res.redirect(`/ventas/nueva?colaborador=${contexto.colaboradorId}`);
  }

  try {
    const { idVenta, recibo } = await registrarVenta(req.db, {
      sucursal: contexto.sucursalId,
      cliente: clienteId,
      colaborador: contexto.colaboradorId,
      detalle,
    });
    res.render('ventas/recibo', { title: 'Venta registrada', idVenta, recibo, contexto });
  } catch (err) {
    req.flash('error', err.sqlMessage || 'No se pudo registrar la venta.');
    res.redirect(`/ventas/nueva?colaborador=${contexto.colaboradorId}`);
  }
});

// Listado y anulación: solo gerente/admin (gs_vendedor no tiene SELECT
// sobre venta/detalle_venta ni EXECUTE de sp_anular_venta; es un límite
// real de los permisos ya definidos en 06_security.sql, no un descuido).
router.get('/', requireRole('gerente', 'admin'), async (req, res) => {
  const [ventas] = await req.db.query(
    `SELECT v.idVenta, v.fecha_venta, v.total_venta, v.estado_venta, s.nombre_sucursal, c.nombre_cliente, co.nombre_colaborador
     FROM venta v
     JOIN sucursal s ON s.idSucursal = v.fk_Sucursal
     JOIN cliente c ON c.idCliente = v.fk_Cliente
     JOIN colaborador co ON co.idColaborador = v.fk_Colaborador
     ORDER BY v.fecha_venta DESC LIMIT 200`
  );
  res.render('ventas/lista', { title: 'Ventas' , ventas });
});

router.post('/:id/anular', requireRole('gerente', 'admin'), async (req, res) => {
  try {
    await anularVenta(req.db, { idVenta: req.params.id, motivo: req.body.motivo });
    req.flash('success', 'Venta anulada; el stock fue devuelto.');
  } catch (err) {
    req.flash('error', err.sqlMessage || 'No se pudo anular la venta.');
  }
  res.redirect('/ventas');
});

module.exports = router;
