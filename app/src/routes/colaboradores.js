'use strict';
const express = require('express');
const bcrypt = require('bcrypt');
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
  
  const connection = await req.db.getConnection();
  try {
    await connection.beginTransaction();

    // 1. Insertar el colaborador en la base de datos
    const [resultColab] = await connection.query(
      'INSERT INTO colaborador (nombre_colaborador, puesto_colaborador, fk_Sucursal) VALUES (?, ?, ?)',
      [nombre_colaborador, puesto_colaborador, fk_Sucursal]
    );
    const idColaborador = resultColab.insertId;

    // 2. Generar usuario automático (minúsculas y sin espacios) y contraseña temporal cifrada
    const usuarioGenerado = nombre_colaborador.toLowerCase().replace(/\s+/g, '').substring(0, 20);
    const passwordHash = await bcrypt.hash(nombre_colaborador, 12); // Contraseña temporal por defecto: 123456

    // 3. Asignar rol según el puesto del colaborador
    const rolAsignado = puesto_colaborador.toLowerCase().includes('gerente') ? 'gerente' : 'vendedor';

    // 4. Crear el usuario de acceso vinculado en app_usuario sin dejar campos en NULL
    await connection.query(
      'INSERT INTO app_usuario (usuario, password_hash, rol, fk_Colaborador, activo) VALUES (?, ?, ?, ?, 1)',
      [usuarioGenerado, passwordHash, rolAsignado, idColaborador]
    );

    await connection.commit();
    connection.release();

    req.flash('success', `Colaborador registrado. Usuario generado automáticamente: ${usuarioGenerado} (Contraseña temporal:como su nombre).`);
    res.redirect('/colaboradores');
  } catch (err) {
    await connection.rollback();
    connection.release();
    req.flash('error', 'No se pudo registrar el colaborador: ' + (err.sqlMessage || err.message));
    res.redirect('/colaboradores');
  }
});

router.post('/:id/activo', puedeUsar, async (req, res) => {
  await req.db.query('UPDATE colaborador SET activo = ? WHERE idColaborador = ?', [req.body.activo === '1' ? 1 : 0, req.params.id]);
  res.redirect('/colaboradores');
});

module.exports = router;
