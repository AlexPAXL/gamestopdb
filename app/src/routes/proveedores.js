'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');

const router = express.Router();
const puedeUsar = requireRole('gerente', 'admin');

router.get('/', puedeUsar, async (req, res) => {
  const [proveedores] = await req.db.query('SELECT * FROM proveedor ORDER BY nombre_proveedor');
  res.render('proveedores', { title: 'Proveedores', proveedores });
});

router.post('/', puedeUsar, async (req, res) => {
  const { nombre_proveedor, telefono_proveedor, correo_proveedor } = req.body;
  await req.db.query('INSERT INTO proveedor (nombre_proveedor, telefono_proveedor, correo_proveedor) VALUES (?, ?, ?)', [
    nombre_proveedor,
    telefono_proveedor,
    correo_proveedor,
  ]);
  req.flash('success', 'Proveedor registrado.');
  res.redirect('/proveedores');
});

router.post('/:id/activo', puedeUsar, async (req, res) => {
  await req.db.query('UPDATE proveedor SET activo = ? WHERE idProveedor = ?', [req.body.activo ? 1 : 0, req.params.id]);
  res.redirect('/proveedores');
});

module.exports = router;
