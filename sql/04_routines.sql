-- =====================================================================
-- GameStop DB  |  04_routines.sql
-- Funciones y procedimientos almacenados.
-- Toda operación que toca varias tablas corre en una transacción con
-- manejador de errores: si algo falla se hace ROLLBACK y se relanza el
-- error original (RESIGNAL). Nunca queda una venta a medias.
--
-- Los detalles se reciben como JSON (MySQL 8.0.4+ por JSON_TABLE):
--   venta : '[{"producto":1,"cantidad":2}, ...]'
--   compra: '[{"producto":1,"cantidad":10,"precio":350.00}, ...]'
-- =====================================================================

USE gamestopdb;

DROP FUNCTION  IF EXISTS fn_stock_disponible;
DROP PROCEDURE IF EXISTS sp_registrar_venta;
DROP PROCEDURE IF EXISTS sp_registrar_compra;
DROP PROCEDURE IF EXISTS sp_anular_venta;
DROP PROCEDURE IF EXISTS sp_consultar_cliente;

DELIMITER //

-- Stock de un producto en una sucursal (0 si no existe registro).
CREATE FUNCTION fn_stock_disponible(p_sucursal INT, p_producto INT)
RETURNS INT
READS SQL DATA
BEGIN
  RETURN (SELECT COALESCE(MAX(stock_disponible), 0)
          FROM inventario
          WHERE fk_Sucursal = p_sucursal AND fk_Producto = p_producto);
END //

-- Registra una venta completa (encabezado + líneas) de forma atómica.
-- El precio se toma del catálogo (trigger), el stock y el total los
-- actualizan los triggers de detalle_venta.
CREATE PROCEDURE sp_registrar_venta(
  IN  p_sucursal    INT,
  IN  p_cliente     INT,
  IN  p_colaborador INT,
  IN  p_detalle     JSON,
  OUT p_idVenta     INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_detalle IS NULL OR JSON_TYPE(p_detalle) <> 'ARRAY' OR JSON_LENGTH(p_detalle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta debe incluir al menos un producto';
  END IF;

  START TRANSACTION;

  INSERT INTO venta (fk_Sucursal, fk_Cliente, fk_Colaborador)
  VALUES (p_sucursal, p_cliente, p_colaborador);
  SET p_idVenta = LAST_INSERT_ID();

  INSERT INTO detalle_venta (fk_Venta, fk_Producto, cantidad, precio_unitario)
  SELECT p_idVenta, j.producto, j.cantidad, NULL          -- NULL: el trigger pone el precio vigente
  FROM JSON_TABLE(p_detalle, '$[*]' COLUMNS (
         producto INT PATH '$.producto',
         cantidad INT PATH '$.cantidad')) AS j;

  COMMIT;

  -- AGREGADO: recibo de la venta recién creada. El procedimiento es
  -- SQL SECURITY DEFINER (valor por defecto), así que esto funciona
  -- aunque el vendedor no tenga SELECT directo sobre venta/detalle_venta.
  SELECT v.idVenta, v.fecha_venta, v.total_venta,
         p.nombre_producto, d.cantidad, d.precio_unitario, d.subtotal_venta
  FROM venta v
  JOIN detalle_venta d ON d.fk_Venta = v.idVenta
  JOIN producto p      ON p.idProducto = d.fk_Producto
  WHERE v.idVenta = p_idVenta;
END //

-- Registra una compra a proveedor; el trigger suma el stock a la sucursal.
CREATE PROCEDURE sp_registrar_compra(
  IN  p_proveedor INT,
  IN  p_sucursal  INT,
  IN  p_detalle   JSON,
  OUT p_idCompra  INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_detalle IS NULL OR JSON_TYPE(p_detalle) <> 'ARRAY' OR JSON_LENGTH(p_detalle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La compra debe incluir al menos un producto';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM proveedor WHERE idProveedor = p_proveedor AND activo) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe o está inactivo';
  END IF;

  START TRANSACTION;

  INSERT INTO compra_proveedor (fk_Proveedor, fk_Sucursal) VALUES (p_proveedor, p_sucursal);
  SET p_idCompra = LAST_INSERT_ID();

  INSERT INTO detalle_compra (fk_Compra_Proveedor, fk_Producto, cantidad, precio_compra)
  SELECT p_idCompra, j.producto, j.cantidad, j.precio
  FROM JSON_TABLE(p_detalle, '$[*]' COLUMNS (
         producto INT           PATH '$.producto',
         cantidad INT           PATH '$.cantidad',
         precio   DECIMAL(10,2) PATH '$.precio')) AS j;

  COMMIT;
END //

-- Anula una venta y devuelve el stock. Las ventas no se borran:
-- se conservan para historial contable y auditoría.
CREATE PROCEDURE sp_anular_venta(IN p_idVenta INT, IN p_motivo VARCHAR(200))
BEGIN
  DECLARE v_estado VARCHAR(10);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Debe indicar el motivo de la anulación';
  END IF;

  START TRANSACTION;

  SELECT MAX(estado_venta) INTO v_estado FROM venta WHERE idVenta = p_idVenta FOR UPDATE;

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no existe';
  ELSEIF v_estado = 'ANULADA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta ya estaba anulada';
  END IF;

  UPDATE inventario i
  JOIN venta v         ON v.fk_Sucursal = i.fk_Sucursal
  JOIN detalle_venta d ON d.fk_Venta = v.idVenta AND d.fk_Producto = i.fk_Producto
  SET i.stock_disponible = i.stock_disponible + d.cantidad
  WHERE v.idVenta = p_idVenta;

  UPDATE venta SET estado_venta = 'ANULADA' WHERE idVenta = p_idVenta;

  INSERT INTO bitacora (usuario_db, tabla, operacion, id_registro, detalle)
  VALUES (USER(), 'venta', 'UPDATE', p_idVenta, CONCAT('Venta anulada. Motivo: ', LEFT(p_motivo, 200)));

  COMMIT;
END //

-- Única vía para que un vendedor vea el correo completo de un cliente.
-- Cada consulta queda registrada en la bitácora (acceso a dato sensible).
CREATE PROCEDURE sp_consultar_cliente(IN p_idCliente INT)
SQL SECURITY DEFINER
BEGIN
  INSERT INTO bitacora (usuario_db, tabla, operacion, id_registro, detalle)
  VALUES (USER(), 'cliente', 'CONSULTA', p_idCliente, 'Consulta de datos personales del cliente');

  SELECT idCliente, nombre_cliente, correo_cliente
  FROM cliente
  WHERE idCliente = p_idCliente;
END //

DELIMITER ;
