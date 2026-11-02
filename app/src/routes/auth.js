'use strict';
const express = require('express');
const bcrypt = require('bcrypt');
const rateLimit = require('express-rate-limit');
const { pools } = require('../db');

const router = express.Router();

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10, // 10 intentos / 15 min por IP: suficiente para un error de tecleo, no para fuerza bruta
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Demasiados intentos de inicio de sesión. Intenta de nuevo en unos minutos.',
});

router.get('/login', (req, res) => {
  if (req.session.user) return res.redirect('/');
  res.render('login', { title: 'Iniciar sesión' });
});

router.post('/login', loginLimiter, async (req, res) => {
  const { usuario, password } = req.body;
  if (!usuario || !password) {
    req.flash('error', 'Usuario y contraseña son obligatorios.');
    return res.redirect('/login');
  }

  try {
    const [[fila]] = await pools.auth.query(
      'SELECT idUsuario, usuario, password_hash, rol, fk_Colaborador, activo FROM app_usuario WHERE usuario = ?',
      [usuario]
    );

    // Mismo mensaje genérico si el usuario no existe o la contraseña no
    // coincide: no revelamos cuál de las dos fue.
    const credencialesInvalidas = () => {
      req.flash('error', 'Usuario o contraseña incorrectos.');
      return res.redirect('/login');
    };

    if (!fila || !fila.activo) return credencialesInvalidas();

    const ok = await bcrypt.compare(password, fila.password_hash);
    if (!ok) return credencialesInvalidas();

    const sessionUser = {
      idUsuario: fila.idUsuario,
      usuario: fila.usuario,
      rol: fila.rol,
      fk_Colaborador: fila.fk_Colaborador,
      nombreColaborador: null,
      fk_Sucursal: null,
      nombreSucursal: null,
    };

    if (fila.fk_Colaborador) {
      const [[colab]] = await pools.auth.query(
        `SELECT co.nombre_colaborador, co.activo AS colaborador_activo, co.fk_Sucursal, s.nombre_sucursal
         FROM colaborador co JOIN sucursal s ON s.idSucursal = co.fk_Sucursal
         WHERE co.idColaborador = ?`,
        [fila.fk_Colaborador]
      );
      if (!colab || !colab.colaborador_activo) {
        req.flash('error', 'Tu usuario de colaborador está inactivo. Contacta al administrador.');
        return res.redirect('/login');
      }
      sessionUser.nombreColaborador = colab.nombre_colaborador;
      sessionUser.fk_Sucursal = colab.fk_Sucursal;
      sessionUser.nombreSucursal = colab.nombre_sucursal;
    }

    req.session.regenerate((err) => {
      if (err) throw err;
      req.session.user = sessionUser;
      const destino = req.session.returnTo || '/';
      delete req.session.returnTo;
      res.redirect(destino);
    });
  } catch (err) {
    console.error('Error en login:', err);
    req.flash('error', 'Ocurrió un error al iniciar sesión. Intenta de nuevo.');
    res.redirect('/login');
  }
});

router.post('/logout', (req, res) => {
  req.session.destroy(() => res.redirect('/login'));
});

module.exports = router;
