'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');
const { consultarCliente } = require('../lib/procs');

const router = express.Router();
const puedeUsar = requireRole('vendedor', 'gerente', 'admin');

router.get('/', puedeUsar, async (req, res) => {
  const [clientes] = await req.db.query('SELECT * FROM v_cliente_publico ORDER BY nombre_cliente');
  res.render('clientes/lista', { title: 'Clientes', clientes, revelado: null });
});

router.post('/', puedeUsar, async (req, res) => {
  const { nombre_cliente, correo_cliente } = req.body;
  await req.db.query('INSERT INTO cliente (nombre_cliente, correo_cliente) VALUES (?, ?)', [nombre_cliente, correo_cliente]);
  req.flash('success', 'Cliente registrado.');
  res.redirect('/clientes');
});

// El correo completo solo se obtiene por el procedimiento (DEFINER):
// cada consulta queda registrada en la bitácora, aunque quien la pida sea admin.
router.post('/:id/consultar', puedeUsar, async (req, res) => {
  const cliente = await consultarCliente(req.db, req.params.id);
  const [clientes] = await req.db.query('SELECT * FROM v_cliente_publico ORDER BY nombre_cliente');
  res.render('clientes/lista', { title: 'Clientes', clientes, revelado: cliente });
});

module.exports = router;
