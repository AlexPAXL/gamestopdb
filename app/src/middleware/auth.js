'use strict';
const { poolForRole } = require('../db');

// Exige sesión iniciada; si no, manda a /login (y recuerda a dónde iba).
function requireLogin(req, res, next) {
  if (!req.session.user) {
    req.session.returnTo = req.originalUrl;
    return res.redirect('/login');
  }
  next();
}

// Cuelga req.db = el pool de conexión que corresponde al ROL de la sesión.
// Todas las rutas de negocio consultan a través de req.db: así cada query
// corre con los privilegios reales de ese rol en MySQL (no un chequeo que
// el código podría olvidar hacer).
function attachDb(req, res, next) {
  if (req.session.user) {
    req.db = poolForRole(req.session.user.rol);
  }
  next();
}

// Restringe una ruta a ciertos roles de negocio (chequeo de UX: el
// verdadero límite de seguridad es el GRANT en MySQL, visto arriba).
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.session.user) return res.redirect('/login');
    if (!roles.includes(req.session.user.rol)) {
      return res.status(403).render('error', {
        title: 'Acceso denegado',
        message: 'Tu rol no tiene permiso para ver esta página.',
      });
    }
    next();
  };
}

module.exports = { requireLogin, attachDb, requireRole };
