'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');

const router = express.Router();
const puedeVer = requireRole('vendedor', 'gerente', 'admin');
const puedeEditar = requireRole('gerente', 'admin');

router.get('/productos', puedeVer, async (req, res) => {
  const [productos] = await req.db.query(
    `SELECT p.idProducto, p.codigo_sku, p.nombre_producto, p.marca_producto, p.precio_producto, p.activo,
            c.nombre_categoria, pl.nombre_plataforma
     FROM producto p
     JOIN categoria c ON c.idCategoria = p.fk_Categoria
     LEFT JOIN plataforma pl ON pl.idPlataforma = p.fk_Plataforma
     ORDER BY p.nombre_producto`
  );
  res.render('catalogo/productos', { title: 'Catálogo', productos, puedeEditar: ['gerente', 'admin'].includes(req.session.user.rol) });
});

router.get('/productos/nuevo', puedeEditar, async (req, res) => {
  const [categorias] = await req.db.query('SELECT idCategoria, nombre_categoria FROM categoria ORDER BY nombre_categoria');
  const [plataformas] = await req.db.query('SELECT idPlataforma, nombre_plataforma FROM plataforma ORDER BY nombre_plataforma');
  res.render('catalogo/form', { title: 'Nuevo producto', producto: null, categorias, plataformas });
});

router.get('/productos/:id/editar', puedeEditar, async (req, res) => {
  const [[producto]] = await req.db.query('SELECT * FROM producto WHERE idProducto = ?', [req.params.id]);
  if (!producto) return res.status(404).render('error', { title: 'No encontrado', message: 'Producto no encontrado.' });
  const [categorias] = await req.db.query('SELECT idCategoria, nombre_categoria FROM categoria ORDER BY nombre_categoria');
  const [plataformas] = await req.db.query('SELECT idPlataforma, nombre_plataforma FROM plataforma ORDER BY nombre_plataforma');
  res.render('catalogo/form', { title: 'Editar producto', producto, categorias, plataformas });
});

router.post('/productos', puedeEditar, async (req, res) => {
  const { codigo_sku, nombre_producto, marca_producto, fk_Categoria, fk_Plataforma, precio_producto } = req.body;
  await req.db.query(
    `INSERT INTO producto (codigo_sku, nombre_producto, marca_producto, fk_Categoria, fk_Plataforma, precio_producto)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [codigo_sku, nombre_producto, marca_producto, fk_Categoria, fk_Plataforma || null, precio_producto]
  );
  req.flash('success', 'Producto creado.');
  res.redirect('/catalogo/productos');
});

router.post('/productos/:id', puedeEditar, async (req, res) => {
  const { nombre_producto, marca_producto, fk_Categoria, fk_Plataforma, precio_producto, activo } = req.body;
  await req.db.query(
    `UPDATE producto SET nombre_producto = ?, marca_producto = ?, fk_Categoria = ?, fk_Plataforma = ?,
            precio_producto = ?, activo = ?
     WHERE idProducto = ?`,
    [nombre_producto, marca_producto, fk_Categoria, fk_Plataforma || null, precio_producto, activo ? 1 : 0, req.params.id]
  );
  req.flash('success', 'Producto actualizado.');
  res.redirect('/catalogo/productos');
});

router.get('/categorias', puedeEditar, async (req, res) => {
  const [categorias] = await req.db.query('SELECT * FROM categoria ORDER BY nombre_categoria');
  const [plataformas] = await req.db.query('SELECT * FROM plataforma ORDER BY nombre_plataforma');
  res.render('catalogo/categorias', { title: 'Categorías y plataformas', categorias, plataformas });
});

router.post('/categorias', puedeEditar, async (req, res) => {
  await req.db.query('INSERT INTO categoria (nombre_categoria) VALUES (?)', [req.body.nombre_categoria]);
  req.flash('success', 'Categoría creada.');
  res.redirect('/catalogo/categorias');
});

router.post('/plataformas', puedeEditar, async (req, res) => {
  await req.db.query('INSERT INTO plataforma (nombre_plataforma) VALUES (?)', [req.body.nombre_plataforma]);
  req.flash('success', 'Plataforma creada.');
  res.redirect('/catalogo/categorias');
});

module.exports = router;
