'use strict';
const path = require('path');
const express = require('express');
const session = require('express-session');
const helmet = require('helmet');

const { flash } = require('./middleware/flash');
const { csrfToken, csrfProtect } = require('./middleware/csrf');
const { requireLogin, attachDb } = require('./middleware/auth');

const authRoutes = require('./routes/auth');
const catalogoRoutes = require('./routes/catalogo');
const inventarioRoutes = require('./routes/inventario');
const ventasRoutes = require('./routes/ventas');
const comprasRoutes = require('./routes/compras');
const sucursalesRoutes = require('./routes/sucursales');
const proveedoresRoutes = require('./routes/proveedores');
const clientesRoutes = require('./routes/clientes');
const colaboradoresRoutes = require('./routes/colaboradores');
const reportesRoutes = require('./routes/reportes');
const bitacoraRoutes = require('./routes/bitacora');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(helmet({ contentSecurityPolicy: false })); // CSP relajado: no usamos CDNs ni inline-script-eval raros, pero esto es MVP
app.use(express.urlencoded({ extended: false }));
app.use(express.static(path.join(__dirname, 'public')));

app.use(
  session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production', // requiere HTTPS en producción
      maxAge: 8 * 60 * 60 * 1000, // 8 horas, como un turno de tienda
    },
  })
);

app.use(flash);
app.use((req, res, next) => {
  // Antes de csrfProtect/csrfToken a propósito: si uno de esos corta la
  // petición con res.render('error', ...), la vista ya necesita esta
  // variable (top.ejs la usa para decidir si muestra la barra de nav).
  res.locals.currentUser = req.session.user || null;
  next();
});
app.use(csrfToken);
app.use(csrfProtect);
app.use(attachDb);

// Rutas públicas (login) primero.
app.use('/', authRoutes);

// Todo lo demás requiere sesión iniciada.
app.use(requireLogin);

app.get('/', (req, res) => res.render('dashboard', { title: 'Panel' }));

app.use('/catalogo', catalogoRoutes);
app.use('/inventario', inventarioRoutes);
app.use('/ventas', ventasRoutes);
app.use('/compras', comprasRoutes);
app.use('/sucursales', sucursalesRoutes);
app.use('/proveedores', proveedoresRoutes);
app.use('/clientes', clientesRoutes);
app.use('/colaboradores', colaboradoresRoutes);
app.use('/reportes', reportesRoutes);
app.use('/bitacora', bitacoraRoutes);

app.use((req, res) => {
  res.status(404).render('error', { title: 'No encontrado', message: 'Esa página no existe.' });
});

// Manejador final: cualquier error de MySQL (p. ej. "Access denied" de un
// GRANT que de verdad falta) llega aquí en vez de tumbar el proceso.
app.use((err, req, res, next) => {
  console.error(err);
  // Defensivo: si el error ocurrió antes de que corriera el middleware que
  // fija currentUser (p. ej. sesión mal configurada), top.ejs no truena.
  res.locals.currentUser = res.locals.currentUser || null;
  const esPermisoDB = err && err.code === 'ER_TABLEACCESS_DENIED_ERROR' || err.code === 'ER_SPECIFIC_ACCESS_DENIED_ERROR' || err.code === 'ER_PROCACCESS_DENIED_ERROR';
  res.status(500).render('error', {
    title: 'Error',
    message: esPermisoDB
      ? 'Tu rol no tiene permiso en la base de datos para esta operación.'
      : 'Ocurrió un error inesperado. Intenta de nuevo.',
  });
});

module.exports = app;
