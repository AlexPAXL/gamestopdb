'use strict';
// Mensajes de una sola lectura (éxito/error) guardados en la sesión.
// Evita la dependencia connect-flash para algo de 10 líneas.
function flash(req, res, next) {
  req.flash = (type, message) => {
    req.session.flash = { type, message };
  };
  res.locals.flash = req.session.flash || null;
  delete req.session.flash;
  next();
}

module.exports = { flash };
