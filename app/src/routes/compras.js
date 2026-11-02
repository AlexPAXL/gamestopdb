'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');
const { registrarCompra } = require('../lib/procs');

const router = express.Router();
const puedeUsar = requireRole('gerente', 'admin');
const NUM_LINEAS = 8;

router.get('/nueva', puedeUsar, async (req, res) => {
  const { user } = req.session;
  const [proveedores] = await req.db.query('SELECT idProveedor, nombre_proveedor FROM proveedor WHERE activo ORDER BY nombre_proveedor');
  const [productos] = await req.db.query('SELECT idProducto, nombre_producto, codigo_sku FROM producto WHERE activo ORDER BY nombre_producto');
  const [sucursales] = await req.db.query('SELECT idSucursal, nombre_sucursal FROM sucursal WHERE activa ORDER BY nombre_sucursal');
  res.render('compras/nueva', {
    title: 'Registrar compra',
    proveedores,
    productos,
    sucursales,
    sucursalFija: user.fk_Sucursal || null,
    lineas: NUM_LINEAS,
  });
});

router.post('/', puedeUsar, async (req, res) => {
  const { user } = req.session;
  const sucursal = Number(user.fk_Sucursal || req.body.sucursal);
  const proveedor = Number(req.body.proveedor);

  const productosForm = [].concat(req.body.producto || []);
  const cantidadesForm = [].concat(req.body.cantidad || []);
  const preciosForm = [].concat(req.body.precio || []);
  const detalle = productosForm
    .map((p, i) => ({ producto: Number(p), cantidad: Number(cantidadesForm[i]), precio: Number(preciosForm[i]) }))
    .filter((l) => l.producto && l.cantidad > 0 && l.precio > 0);

  if (!sucursal || !proveedor || detalle.length === 0) {
    req.flash('error', 'Completa proveedor, sucursal y al menos un producto con cantidad y precio.');
    return res.redirect('/compras/nueva');
  }

  try {
    const { idCompra } = await registrarCompra(req.db, { proveedor, sucursal, detalle });
    req.flash('success', `Compra #${idCompra} registrada; el inventario ya quedó actualizado.`);
    res.redirect('/compras');
  } catch (err) {
    req.flash('error', err.sqlMessage || 'No se pudo registrar la compra.');
    res.redirect('/compras/nueva');
  }
});

router.get('/', puedeUsar, async (req, res) => {
  const [compras] = await req.db.query(
    `SELECT c.idCompra_Proveedor, c.fecha_compra, c.total_compra, pr.nombre_proveedor, s.nombre_sucursal
     FROM compra_proveedor c
     JOIN proveedor pr ON pr.idProveedor = c.fk_Proveedor
     JOIN sucursal s ON s.idSucursal = c.fk_Sucursal
     ORDER BY c.fecha_compra DESC LIMIT 200`
  );
  res.render('compras/lista', { title: 'Compras a proveedores', compras });
});

module.exports = router;
