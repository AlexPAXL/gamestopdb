'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');

const router = express.Router();
const puedeUsar = requireRole('gerente', 'admin');

router.get('/', puedeUsar, async (req, res) => {
  const [sucursales] = await req.db.query('SELECT * FROM sucursal ORDER BY nombre_sucursal');
  const [telefonos] = await req.db.query('SELECT * FROM telefono_sucursal ORDER BY fk_Sucursal');
  const porSucursal = {};
  telefonos.forEach((t) => {
    (porSucursal[t.fk_Sucursal] ||= []).push(t.telefono_sucursal);
  });
  res.render('sucursales', { title: 'Sucursales', sucursales, porSucursal });
});

router.post('/', puedeUsar, async (req, res) => {
  const { nombre_sucursal, direccion_sucursal, ciudad_sucursal } = req.body;
  await req.db.query('INSERT INTO sucursal (nombre_sucursal, direccion_sucursal, ciudad_sucursal) VALUES (?, ?, ?)', [
    nombre_sucursal,
    direccion_sucursal,
    ciudad_sucursal,
  ]);
  req.flash('success', 'Sucursal creada.');
  res.redirect('/sucursales');
});

router.post('/:id/telefono', puedeUsar, async (req, res) => {
  await req.db.query('INSERT INTO telefono_sucursal (telefono_sucursal, fk_Sucursal) VALUES (?, ?)', [
    req.body.telefono,
    req.params.id,
  ]);
  req.flash('success', 'Teléfono agregado.');
  res.redirect('/sucursales');
});

router.post('/:id/activa', puedeUsar, async (req, res) => {
  await req.db.query('UPDATE sucursal SET activa = ? WHERE idSucursal = ?', [req.body.activa === '1' ? 1 : 0, req.params.id]);
  res.redirect('/sucursales');
});

module.exports = router;
