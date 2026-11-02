-- =====================================================================
-- GameStop DB  |  09_consultas.sql
-- Consultas de negocio (JOIN + agregaciones). Todas filtran ventas
-- anuladas. Los filtros por fecha usan rangos (>= / <) y no funciones
-- sobre la columna, para poder usar los índices.
-- =====================================================================

USE gamestopdb;

-- 1. Ventas y facturación por sucursal
SELECT s.nombre_sucursal,
       COUNT(v.idVenta)                AS num_ventas,
       COALESCE(SUM(v.total_venta), 0) AS total_facturado
FROM sucursal s
LEFT JOIN venta v ON v.fk_Sucursal = s.idSucursal AND v.estado_venta = 'COMPLETADA'
GROUP BY s.idSucursal, s.nombre_sucursal
ORDER BY total_facturado DESC;

-- 2. Top 5 productos más vendidos (unidades)
SELECT p.codigo_sku, p.nombre_producto, SUM(d.cantidad) AS unidades, SUM(d.subtotal_venta) AS ingresos
FROM detalle_venta d
JOIN venta v    ON v.idVenta = d.fk_Venta AND v.estado_venta = 'COMPLETADA'
JOIN producto p ON p.idProducto = d.fk_Producto
GROUP BY p.idProducto, p.codigo_sku, p.nombre_producto
ORDER BY unidades DESC, ingresos DESC
LIMIT 5;

-- 3. Facturación mensual
SELECT DATE_FORMAT(fecha_venta, '%Y-%m') AS mes,
       COUNT(*)                          AS num_ventas,
       SUM(total_venta)                  AS total
FROM venta
WHERE estado_venta = 'COMPLETADA'
GROUP BY mes
ORDER BY mes;

-- 4. Ticket promedio por colaborador
SELECT co.nombre_colaborador, s.nombre_sucursal,
       COUNT(v.idVenta)            AS num_ventas,
       ROUND(AVG(v.total_venta), 2) AS ticket_promedio
FROM colaborador co
JOIN sucursal s ON s.idSucursal = co.fk_Sucursal
JOIN venta v    ON v.fk_Colaborador = co.idColaborador AND v.estado_venta = 'COMPLETADA'
GROUP BY co.idColaborador, co.nombre_colaborador, s.nombre_sucursal
ORDER BY ticket_promedio DESC;

-- 5. Productos con stock bajo (menos de 5 unidades) por sucursal
SELECT nombre_sucursal, codigo_sku, nombre_producto, stock_disponible
FROM v_inventario_sucursal
WHERE stock_disponible < 5
ORDER BY nombre_sucursal, stock_disponible;

-- 6. Clientes: número de compras y total gastado (incluye clientes sin compras)
SELECT c.nombre_cliente,
       COUNT(v.idVenta)                AS compras,
       COALESCE(SUM(v.total_venta), 0) AS total_gastado
FROM cliente c
LEFT JOIN venta v ON v.fk_Cliente = c.idCliente AND v.estado_venta = 'COMPLETADA'
GROUP BY c.idCliente, c.nombre_cliente
ORDER BY total_gastado DESC;

-- 7. Margen bruto por producto (precio promedio de venta vs costo promedio ponderado)
SELECT p.nombre_producto,
       ROUND(ve.ingresos / ve.unidades, 2)                       AS precio_prom_venta,
       ROUND(co.costo / co.unidades, 2)                          AS costo_prom_compra,
       ROUND(ve.ingresos - ve.unidades * co.costo / co.unidades, 2) AS margen_bruto
FROM producto p
JOIN (SELECT d.fk_Producto, SUM(d.cantidad) AS unidades, SUM(d.subtotal_venta) AS ingresos
      FROM detalle_venta d JOIN venta v ON v.idVenta = d.fk_Venta AND v.estado_venta = 'COMPLETADA'
      GROUP BY d.fk_Producto) ve ON ve.fk_Producto = p.idProducto
JOIN (SELECT fk_Producto, SUM(cantidad) AS unidades, SUM(subtotal) AS costo
      FROM detalle_compra GROUP BY fk_Producto) co ON co.fk_Producto = p.idProducto
ORDER BY margen_bruto DESC;

-- 8. Compras por proveedor
SELECT pr.nombre_proveedor,
       COUNT(c.idCompra_Proveedor)      AS num_compras,
       COALESCE(SUM(c.total_compra), 0) AS total_comprado
FROM proveedor pr
LEFT JOIN compra_proveedor c ON c.fk_Proveedor = pr.idProveedor
GROUP BY pr.idProveedor, pr.nombre_proveedor
ORDER BY total_comprado DESC;

-- 9. Productos activos que nunca se han vendido
SELECT p.codigo_sku, p.nombre_producto
FROM producto p
WHERE p.activo
  AND NOT EXISTS (SELECT 1 FROM detalle_venta d
                  JOIN venta v ON v.idVenta = d.fk_Venta AND v.estado_venta = 'COMPLETADA'
                  WHERE d.fk_Producto = p.idProducto);

-- 10. Ventas de una sucursal en un rango de fechas (usa idx_venta_sucursal_fecha)
SELECT v.idVenta, v.fecha_venta, c.nombre_cliente, v.total_venta
FROM venta v
JOIN cliente c ON c.idCliente = v.fk_Cliente
WHERE v.fk_Sucursal = 1
  AND v.fecha_venta >= '2026-06-01' AND v.fecha_venta < '2026-09-01'
  AND v.estado_venta = 'COMPLETADA'
ORDER BY v.fecha_venta;

-- 11. Valor del inventario por sucursal
SELECT nombre_sucursal, SUM(stock_disponible) AS unidades, SUM(stock_disponible * precio_producto) AS valor_venta
FROM v_inventario_sucursal
GROUP BY idSucursal, nombre_sucursal;

-- 12. Auditoría: historial de cambios de precio
SELECT b.fecha, b.usuario_db, p.nombre_producto,
       JSON_UNQUOTE(JSON_EXTRACT(b.datos_anteriores, '$.precio')) AS precio_anterior,
       JSON_UNQUOTE(JSON_EXTRACT(b.datos_nuevos,     '$.precio')) AS precio_nuevo
FROM bitacora b
JOIN producto p ON p.idProducto = b.id_registro
WHERE b.tabla = 'producto' AND b.operacion = 'UPDATE'
  AND JSON_EXTRACT(b.datos_anteriores, '$.precio') <> JSON_EXTRACT(b.datos_nuevos, '$.precio')
ORDER BY b.fecha DESC;

-- ---------------------------------------------------------------------
-- Planes de ejecución de las consultas más frecuentes.
-- Esperado en la 10: key = idx_venta_sucursal_fecha, type = range.
-- Con pocos datos el optimizador puede preferir un full scan; el plan
-- cambia al crecer la tabla. EXPLAIN ANALYZE requiere 8.0.18+.
-- ---------------------------------------------------------------------
EXPLAIN
SELECT v.idVenta, v.fecha_venta, v.total_venta
FROM venta v
WHERE v.fk_Sucursal = 1 AND v.fecha_venta >= '2026-06-01' AND v.fecha_venta < '2026-09-01';

EXPLAIN ANALYZE
SELECT p.codigo_sku, SUM(d.cantidad) AS unidades
FROM detalle_venta d
JOIN venta v    ON v.idVenta = d.fk_Venta AND v.estado_venta = 'COMPLETADA'
JOIN producto p ON p.idProducto = d.fk_Producto
GROUP BY p.idProducto, p.codigo_sku;
