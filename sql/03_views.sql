-- =====================================================================
-- GameStop DB  |  03_views.sql
-- Las vistas usan SQL SECURITY DEFINER (valor por defecto): un rol puede
-- leer la vista sin tener SELECT sobre las tablas base.
-- =====================================================================

USE gamestopdb;

-- Detalle de ventas completadas, listo para reportes.
CREATE OR REPLACE VIEW v_venta_detalle AS
SELECT v.idVenta,
       v.fecha_venta,
       s.nombre_sucursal,
       c.nombre_cliente,
       co.nombre_colaborador,
       p.codigo_sku,
       p.nombre_producto,
       cat.nombre_categoria,
       pl.nombre_plataforma,
       d.cantidad,
       d.precio_unitario,
       d.subtotal_venta
FROM venta v
JOIN sucursal      s   ON s.idSucursal     = v.fk_Sucursal
JOIN cliente       c   ON c.idCliente      = v.fk_Cliente
JOIN colaborador   co  ON co.idColaborador = v.fk_Colaborador
JOIN detalle_venta d   ON d.fk_Venta       = v.idVenta
JOIN producto      p   ON p.idProducto     = d.fk_Producto
JOIN categoria     cat ON cat.idCategoria  = p.fk_Categoria
LEFT JOIN plataforma pl ON pl.idPlataforma = p.fk_Plataforma
WHERE v.estado_venta = 'COMPLETADA';

-- Existencias por sucursal (lo que consulta un vendedor).
CREATE OR REPLACE VIEW v_inventario_sucursal AS
SELECT s.idSucursal,
       s.nombre_sucursal,
       p.idProducto,
       p.codigo_sku,
       p.nombre_producto,
       cat.nombre_categoria,
       pl.nombre_plataforma,
       p.precio_producto,
       i.stock_disponible
FROM inventario i
JOIN sucursal  s   ON s.idSucursal    = i.fk_Sucursal
JOIN producto  p   ON p.idProducto    = i.fk_Producto
JOIN categoria cat ON cat.idCategoria = p.fk_Categoria
LEFT JOIN plataforma pl ON pl.idPlataforma = p.fk_Plataforma
WHERE p.activo = TRUE AND s.activa = TRUE;

-- Clientes con el correo enmascarado: el vendedor identifica al cliente
-- sin ver el dato personal completo. El dato completo solo se obtiene con
-- sp_consultar_cliente, que deja registro en la bitácora.
CREATE OR REPLACE VIEW v_cliente_publico AS
SELECT idCliente,
       nombre_cliente,
       CONCAT(LEFT(correo_cliente, 2), '***@', SUBSTRING_INDEX(correo_cliente, '@', -1)) AS correo_enmascarado
FROM cliente;
