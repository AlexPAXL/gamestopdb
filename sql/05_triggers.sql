-- =====================================================================
-- GameStop DB  |  05_triggers.sql
--
-- Por qué hacen falta estos triggers (y no solo la aplicación):
--  * Inventario y totales: cualquier INSERT en un detalle, venga de un
--    procedimiento, de Workbench o de otra aplicación, mueve el stock y
--    el total. Sin el trigger, un INSERT directo deja datos inconsistentes.
--  * Bitácora: registra quién cambió datos personales (cliente) y precios
--    (producto) sin depender de que el programador se acuerde de hacerlo.
--
-- Notas técnicas:
--  * Se usa USER() y no CURRENT_USER(): dentro de un trigger
--    CURRENT_USER() devuelve el DEFINER, no la persona conectada.
--  * Los borrados en cascada de FK NO disparan triggers en MySQL; por eso
--    los detalles usan ON DELETE RESTRICT (ver 02_tables.sql).
--  * Los detalles son registros inmutables: no se otorga UPDATE/DELETE
--    sobre ellos a ningún rol de negocio (ver 06_security.sql). Una venta
--    se corrige anulándola con sp_anular_venta.
-- =====================================================================

USE gamestopdb;

DROP TRIGGER IF EXISTS trg_venta_bi;
DROP TRIGGER IF EXISTS trg_detalle_venta_bi;
DROP TRIGGER IF EXISTS trg_detalle_venta_ai;
DROP TRIGGER IF EXISTS trg_compra_proveedor_bi;
DROP TRIGGER IF EXISTS trg_detalle_compra_ai;
DROP TRIGGER IF EXISTS trg_cliente_ai;
DROP TRIGGER IF EXISTS trg_cliente_au;
DROP TRIGGER IF EXISTS trg_cliente_ad;
DROP TRIGGER IF EXISTS trg_producto_ai;
DROP TRIGGER IF EXISTS trg_producto_au;
DROP TRIGGER IF EXISTS trg_producto_ad;

DELIMITER //

-- ---------------------------------------------------------------------
-- Ventas
-- ---------------------------------------------------------------------

-- El colaborador debe estar activo y trabajar en la sucursal de la venta.
-- (No se usa FK compuesta porque un traslado del colaborador alteraría
--  el historial de ventas anteriores.)
CREATE TRIGGER trg_venta_bi BEFORE INSERT ON venta
FOR EACH ROW
BEGIN
  DECLARE v_sucursal INT;
  DECLARE v_activo   BOOLEAN;

  SELECT MAX(fk_Sucursal), MAX(activo) INTO v_sucursal, v_activo
  FROM colaborador WHERE idColaborador = NEW.fk_Colaborador;

  IF v_sucursal IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El colaborador no existe';
  ELSEIF v_sucursal <> NEW.fk_Sucursal THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El colaborador no pertenece a la sucursal de la venta';
  ELSEIF NOT v_activo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El colaborador está inactivo';
  END IF;

  SET NEW.total_venta  = 0;              -- el total solo lo calculan las líneas
  SET NEW.estado_venta = 'COMPLETADA';
END //

-- Valida la línea antes de insertarla: venta vigente, producto activo,
-- precio vigente y stock suficiente (con bloqueo de fila).
CREATE TRIGGER trg_detalle_venta_bi BEFORE INSERT ON detalle_venta
FOR EACH ROW
BEGIN
  DECLARE v_sucursal INT;
  DECLARE v_estado   VARCHAR(10);
  DECLARE v_precio   DECIMAL(10,2);
  DECLARE v_activo   BOOLEAN;
  DECLARE v_stock    INT;
  DECLARE v_msg      VARCHAR(200);

  SELECT MAX(fk_Sucursal), MAX(estado_venta) INTO v_sucursal, v_estado
  FROM venta WHERE idVenta = NEW.fk_Venta;

  IF v_sucursal IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta no existe';
  ELSEIF v_estado <> 'COMPLETADA' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se pueden agregar productos a una venta anulada';
  END IF;

  SELECT MAX(precio_producto), MAX(activo) INTO v_precio, v_activo
  FROM producto WHERE idProducto = NEW.fk_Producto;

  IF v_activo IS NULL OR NOT v_activo THEN
    SET v_msg = CONCAT('El producto ', COALESCE(NEW.fk_Producto, 'NULL'), ' no existe o está descontinuado');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.precio_unitario IS NULL THEN
    SET NEW.precio_unitario = v_precio;
  END IF;

  SELECT COALESCE(MAX(stock_disponible), 0) INTO v_stock
  FROM inventario
  WHERE fk_Sucursal = v_sucursal AND fk_Producto = NEW.fk_Producto
  FOR UPDATE;

  IF v_stock < NEW.cantidad THEN
    SET v_msg = CONCAT('Stock insuficiente para el producto ', NEW.fk_Producto,
                       ': disponible ', v_stock, ', solicitado ', NEW.cantidad);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END //

-- Descuenta el stock y acumula el total de la venta.
CREATE TRIGGER trg_detalle_venta_ai AFTER INSERT ON detalle_venta
FOR EACH ROW
BEGIN
  UPDATE inventario i
  JOIN venta v ON v.fk_Sucursal = i.fk_Sucursal
  SET i.stock_disponible = i.stock_disponible - NEW.cantidad
  WHERE v.idVenta = NEW.fk_Venta AND i.fk_Producto = NEW.fk_Producto;

  UPDATE venta
  SET total_venta = total_venta + NEW.subtotal_venta
  WHERE idVenta = NEW.fk_Venta;
END //

-- ---------------------------------------------------------------------
-- Compras
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_compra_proveedor_bi BEFORE INSERT ON compra_proveedor
FOR EACH ROW
BEGIN
  SET NEW.total_compra = 0;              -- el total solo lo calculan las líneas
END //

-- Suma la mercadería a la sucursal (crea el registro de inventario si es
-- el primer ingreso de ese producto) y acumula el total de la compra.
CREATE TRIGGER trg_detalle_compra_ai AFTER INSERT ON detalle_compra
FOR EACH ROW
BEGIN
  INSERT INTO inventario (fk_Sucursal, fk_Producto, stock_disponible)
  SELECT c.fk_Sucursal, NEW.fk_Producto, NEW.cantidad
  FROM compra_proveedor c
  WHERE c.idCompra_Proveedor = NEW.fk_Compra_Proveedor
  ON DUPLICATE KEY UPDATE stock_disponible = stock_disponible + NEW.cantidad;

  UPDATE compra_proveedor
  SET total_compra = total_compra + NEW.subtotal
  WHERE idCompra_Proveedor = NEW.fk_Compra_Proveedor;
END //

-- ---------------------------------------------------------------------
-- Bitácora: cliente (datos personales)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_cliente_ai AFTER INSERT ON cliente
FOR EACH ROW
BEGIN
  INSERT INTO bitacora (usuario_db, tabla, operacion, id_registro, datos_nuevos)
  VALUES (USER(), 'cliente', 'INSERT', NEW.idCliente,
          JSON_OBJECT('nombre', NEW.nombre_cliente, 'correo', NEW.correo_cliente));
END //

CREATE TRIGGER trg_cliente_au AFTER UPDATE ON cliente
FOR EACH ROW
BEGIN
  INSERT INTO bitacora (usuario_db, tabla, operacion, id_registro, datos_anteriores, datos_nuevos)
  VALUES (USER(), 'cliente', 'UPDATE', NEW.idCliente,
          JSON_OBJECT('nombre', OLD.nombre_cliente, 'correo', OLD.correo_cliente),
          JSON_OBJECT('nombre', NEW.nombre_cliente, 'correo', NEW.correo_cliente));
END //

CREATE TRIGGER trg_cliente_ad AFTER DELETE ON cliente
FOR EACH ROW
BEGIN
  INSERT INTO bitacora (usuario_db, tabla, operacion, id_registro, datos_anteriores)
  VALUES (USER(), 'cliente', 'DELETE', OLD.idCliente,
          JSON_OBJECT('nombre', OLD.nombre_cliente, 'correo', OLD.correo_cliente));
END //

-- ---------------------------------------------------------------------
-- Bitácora: producto (cambios de precio y catálogo)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_producto_ai AFTER INSERT ON producto
FOR EACH ROW
BEGIN
  INSERT INTO bitacora (usuario_db, tabla, operacion, id_registro, datos_nuevos)
  VALUES (USER(), 'producto', 'INSERT', NEW.idProducto,
          JSON_OBJECT('sku', NEW.codigo_sku, 'nombre', NEW.nombre_producto,
                      'precio', NEW.precio_producto, 'activo', NEW.activo));
END //

CREATE TRIGGER trg_producto_au AFTER UPDATE ON producto
FOR EACH ROW
BEGIN
  INSERT INTO bitacora (usuario_db, tabla, operacion, id_registro, datos_anteriores, datos_nuevos)
  VALUES (USER(), 'producto', 'UPDATE', NEW.idProducto,
          JSON_OBJECT('sku', OLD.codigo_sku, 'nombre', OLD.nombre_producto,
                      'precio', OLD.precio_producto, 'activo', OLD.activo),
          JSON_OBJECT('sku', NEW.codigo_sku, 'nombre', NEW.nombre_producto,
                      'precio', NEW.precio_producto, 'activo', NEW.activo));
END //

CREATE TRIGGER trg_producto_ad AFTER DELETE ON producto
FOR EACH ROW
BEGIN
  INSERT INTO bitacora (usuario_db, tabla, operacion, id_registro, datos_anteriores)
  VALUES (USER(), 'producto', 'DELETE', OLD.idProducto,
          JSON_OBJECT('sku', OLD.codigo_sku, 'nombre', OLD.nombre_producto,
                      'precio', OLD.precio_producto, 'activo', OLD.activo));
END //

DELIMITER ;
