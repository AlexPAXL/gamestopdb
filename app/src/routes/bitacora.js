'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');

const router = express.Router();

router.get('/', requireRole('gerente', 'admin', 'auditor'), async (req, res) => {
  const tabla = req.query.tabla || '';
  const operacion = req.query.operacion || '';
  const condiciones = [];
  const params = [];
  if (tabla) { condiciones.push('tabla = ?'); params.push(tabla); }
  if (operacion) { condiciones.push('operacion = ?'); params.push(operacion); }
  const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : '';

  const [filas] = await req.db.query(
    `SELECT idBitacora, fecha, usuario_db, tabla, operacion, id_registro, detalle, datos_anteriores, datos_nuevos
     FROM bitacora ${where} ORDER BY fecha DESC LIMIT 150`,
    params
  );
  res.render('bitacora', { title: 'Bitácora de auditoría', filas, tabla, operacion });
});

module.exports = router;
