'use strict';
const express = require('express');
const { requireRole } = require('../middleware/auth');

const router = express.Router();

// Cada reporte declara qué roles pueden verlo, EXACTAMENTE según lo que
// ese rol puede leer en sql/06_security.sql (no se inventa ningún GRANT
// nuevo). La mayoría de reportes de ventas usan v_venta_detalle porque es
// la única vía por la que el rol auditor puede leer datos de ventas.
//
// shortcut: se omite el reporte "ventas de una sucursal en un rango de
// fechas" de 09_consultas.sql (ya cubierto, para gerente/admin, por el
// listado con filtro en /ventas); si hace falta como reporte aparte, es
// una query más en este mismo archivo.
const REPORTES = [
  {
    key: 'ventas-sucursal',
    titulo: 'Ventas y facturación por sucursal',
    roles: ['gerente', 'admin', 'auditor'],
    sql: `SELECT nombre_sucursal, COUNT(DISTINCT idVenta) AS num_ventas, SUM(subtotal_venta) AS total_facturado
          FROM v_venta_detalle GROUP BY nombre_sucursal ORDER BY total_facturado DESC`,
  },
  {
    key: 'top-productos',
    titulo: 'Top 5 productos más vendidos',
    roles: ['gerente', 'admin', 'auditor'],
    sql: `SELECT codigo_sku, nombre_producto, SUM(cantidad) AS unidades, SUM(subtotal_venta) AS ingresos
          FROM v_venta_detalle GROUP BY codigo_sku, nombre_producto ORDER BY unidades DESC, ingresos DESC LIMIT 5`,
  },
  {
    key: 'facturacion-mensual',
    titulo: 'Facturación mensual',
    roles: ['gerente', 'admin', 'auditor'],
    sql: `SELECT DATE_FORMAT(fecha_venta, '%Y-%m') AS mes, COUNT(DISTINCT idVenta) AS num_ventas, SUM(subtotal_venta) AS total
          FROM v_venta_detalle GROUP BY mes ORDER BY mes`,
  },
  {
    key: 'ticket-colaborador',
    titulo: 'Ticket promedio por colaborador',
    roles: ['gerente', 'admin', 'auditor'],
    sql: `SELECT nombre_colaborador, nombre_sucursal, COUNT(DISTINCT idVenta) AS num_ventas,
                 ROUND(SUM(subtotal_venta) / COUNT(DISTINCT idVenta), 2) AS ticket_promedio
          FROM v_venta_detalle GROUP BY nombre_colaborador, nombre_sucursal ORDER BY ticket_promedio DESC`,
  },
  {
    key: 'clientes-gasto',
    titulo: 'Clientes: compras y total gastado',
    roles: ['gerente', 'admin', 'auditor'],
    nota: 'Solo incluye clientes con al menos una compra completada.',
    sql: `SELECT nombre_cliente, COUNT(DISTINCT idVenta) AS compras, SUM(subtotal_venta) AS total_gastado
          FROM v_venta_detalle GROUP BY nombre_cliente ORDER BY total_gastado DESC`,
  },
  {
    key: 'stock-bajo',
    titulo: 'Productos con stock bajo (< 5 unidades)',
    roles: ['gerente', 'admin'],
    sql: `SELECT nombre_sucursal, codigo_sku, nombre_producto, stock_disponible
          FROM v_inventario_sucursal WHERE stock_disponible < 5 ORDER BY nombre_sucursal, stock_disponible`,
  },
  {
    key: 'valor-inventario',
    titulo: 'Valor del inventario por sucursal',
    roles: ['gerente', 'admin'],
    sql: `SELECT nombre_sucursal, SUM(stock_disponible) AS unidades, SUM(stock_disponible * precio_producto) AS valor_venta
          FROM v_inventario_sucursal GROUP BY idSucursal, nombre_sucursal`,
  },
  {
    key: 'margen-bruto',
    titulo: 'Margen bruto por producto',
    roles: ['gerente', 'admin'],
    sql: `SELECT p.nombre_producto,
                 ROUND(ve.ingresos / ve.unidades, 2) AS precio_prom_venta,
                 ROUND(co.costo / co.unidades, 2) AS costo_prom_compra,
                 ROUND(ve.ingresos - ve.unidades * co.costo / co.unidades, 2) AS margen_bruto
          FROM producto p
          JOIN (SELECT d.fk_Producto, SUM(d.cantidad) AS unidades, SUM(d.subtotal_venta) AS ingresos
                FROM detalle_venta d JOIN venta v ON v.idVenta = d.fk_Venta AND v.estado_venta = 'COMPLETADA'
                GROUP BY d.fk_Producto) ve ON ve.fk_Producto = p.idProducto
          JOIN (SELECT fk_Producto, SUM(cantidad) AS unidades, SUM(subtotal) AS costo
                FROM detalle_compra GROUP BY fk_Producto) co ON co.fk_Producto = p.idProducto
          ORDER BY margen_bruto DESC`,
  },
  {
    key: 'compras-proveedor',
    titulo: 'Compras por proveedor',
    roles: ['gerente', 'admin'],
    sql: `SELECT pr.nombre_proveedor, COUNT(c.idCompra_Proveedor) AS num_compras, COALESCE(SUM(c.total_compra), 0) AS total_comprado
          FROM proveedor pr LEFT JOIN compra_proveedor c ON c.fk_Proveedor = pr.idProveedor
          GROUP BY pr.idProveedor, pr.nombre_proveedor ORDER BY total_comprado DESC`,
  },
  {
    key: 'nunca-vendidos',
    titulo: 'Productos activos que nunca se han vendido',
    roles: ['gerente', 'admin'],
    sql: `SELECT p.codigo_sku, p.nombre_producto FROM producto p
          WHERE p.activo AND NOT EXISTS (
            SELECT 1 FROM detalle_venta d JOIN venta v ON v.idVenta = d.fk_Venta AND v.estado_venta = 'COMPLETADA'
            WHERE d.fk_Producto = p.idProducto)`,
  },
  {
    key: 'historial-precios',
    titulo: 'Auditoría: historial de cambios de precio',
    roles: ['gerente', 'admin', 'auditor'],
    nota: 'Solo usa la bitácora (no se une a producto) para que también funcione con el rol auditor.',
    sql: `SELECT fecha, usuario_db, id_registro AS idProducto,
                 JSON_UNQUOTE(JSON_EXTRACT(datos_anteriores, '$.nombre')) AS producto,
                 JSON_UNQUOTE(JSON_EXTRACT(datos_anteriores, '$.precio')) AS precio_anterior,
                 JSON_UNQUOTE(JSON_EXTRACT(datos_nuevos, '$.precio')) AS precio_nuevo
          FROM bitacora
          WHERE tabla = 'producto' AND operacion = 'UPDATE'
            AND JSON_EXTRACT(datos_anteriores, '$.precio') <> JSON_EXTRACT(datos_nuevos, '$.precio')
          ORDER BY fecha DESC`,
  },
];

router.get('/', requireRole('gerente', 'admin', 'auditor'), (req, res) => {
  const rol = req.session.user.rol;
  res.render('reportes/indice', { title: 'Reportes', reportes: REPORTES.filter((r) => r.roles.includes(rol)) });
});

router.get('/:key', requireRole('gerente', 'admin', 'auditor'), async (req, res) => {
  const rol = req.session.user.rol;
  const reporte = REPORTES.find((r) => r.key === req.params.key);
  if (!reporte || !reporte.roles.includes(rol)) {
    return res.status(403).render('error', { title: 'Acceso denegado', message: 'Tu rol no tiene permiso para ver este reporte.' });
  }
  const [filas] = await req.db.query(reporte.sql);
  res.render('reportes/ver', { title: reporte.titulo, reporte, filas });
});

module.exports = router;
