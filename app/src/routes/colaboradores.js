'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');

const router = express.Router();
const puedeUsar = requireRole('gerente', 'admin');

router.get('/', puedeUsar, async (req, res) => {
  const [colaboradores] = await req.db.query(
    `SELECT co.*, s.nombre_sucursal FROM colaborador co JOIN sucursal s ON s.idSucursal = co.fk_Sucursal ORDER BY s.nombre_sucursal, co.nombre_colaborador`
  );
  const [sucursales] = await req.db.query('SELECT idSucursal, nombre_sucursal FROM sucursal WHERE activa ORDER BY nombre_sucursal');
  res.render('colaboradores', { title: 'Colaboradores', colaboradores, sucursales });
});

router.post('/', puedeUsar, async (req, res) => {
  const { nombre_colaborador, puesto_colaborador, fk_Sucursal } = req.body;
  await req.db.query('INSERT INTO colaborador (nombre_colaborador, puesto_colaborador, fk_Sucursal) VALUES (?, ?, ?)', [
    nombre_colaborador,
    puesto_colaborador,
    fk_Sucursal,
  ]);
  req.flash('success', 'Colaborador registrado. Para que pueda entrar al sistema, un administrador debe crear su usuario de acceso (ver README).');
  res.redirect('/colaboradores');
});

router.post('/:id/activo', puedeUsar, async (req, res) => {
  await req.db.query('UPDATE colaborador SET activo = ? WHERE idColaborador = ?', [req.body.activo ? 1 : 0, req.params.id]);
  res.redirect('/colaboradores');
});

module.exports = router;
