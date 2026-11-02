'use strict';
const crypto = require('crypto');

// CSRF mínimo (doble-submit con token en sesión): genera un token por
// sesión, lo expone a las vistas como csrfToken, y rechaza cualquier POST
// cuyo campo oculto _csrf no coincida con el de la sesión.
// shortcut: un token fijo por sesión (no rota por formulario); suficiente
// para esta app, no para algo con APIs públicas de terceros.
function csrfToken(req, res, next) {
  if (!req.session.csrfToken) {
    req.session.csrfToken = crypto.randomBytes(24).toString('hex');
  }
  res.locals.csrfToken = req.session.csrfToken;
  next();
}

function csrfProtect(req, res, next) {
  if (req.method === 'POST') {
    const sent = req.body && req.body._csrf;
    if (!sent || sent !== req.session.csrfToken) {
      return res.status(403).render('error', {
        title: 'Formulario inválido',
        message: 'La sesión del formulario expiró. Vuelve a intentarlo.',
      });
    }
  }
  next();
}

module.exports = { csrfToken, csrfProtect };
