'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');

const router = express.Router();

router.get('/', requireRole('vendedor', 'gerente', 'admin'), async (req, res) => {
  const { rol, fk_Sucursal } = req.session.user;
  let filas, sucursales = [];

  if (rol === 'vendedor') {
    [filas] = await req.db.query(
      'SELECT * FROM v_inventario_sucursal WHERE idSucursal = ? ORDER BY nombre_producto',
      [fk_Sucursal]
    );
  } else {
    const filtro = req.query.sucursal ? Number(req.query.sucursal) : null;
    [sucursales] = await req.db.query('SELECT idSucursal, nombre_sucursal FROM sucursal WHERE activa ORDER BY nombre_sucursal');
    [filas] = filtro
      ? await req.db.query('SELECT * FROM v_inventario_sucursal WHERE idSucursal = ? ORDER BY nombre_producto', [filtro])
      : await req.db.query('SELECT * FROM v_inventario_sucursal ORDER BY nombre_sucursal, nombre_producto');
  }

  res.render('inventario', { title: 'Inventario', filas, sucursales, rol, filtro: req.query.sucursal || '' });
});

module.exports = router;
