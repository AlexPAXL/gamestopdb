-- =====================================================================
-- GameStop DB  |  08_validation.sql
-- Pruebas automáticas. Ejecutar DESPUÉS de 07_seed.sql sobre una base
-- recién construida (los id esperados asumen AUTO_INCREMENT desde 1).
-- Resultado: una tabla con cada prueba y OK / FALLO. Todo debe dar OK.
--
-- Los casos inválidos se ejecutan con tst_espera_error, que captura el
-- error y lo registra en vez de detener el script.
-- =====================================================================

USE gamestopdb;

DROP TEMPORARY TABLE IF EXISTS tst_resultado;
CREATE TEMPORARY TABLE tst_resultado (
  n         INT AUTO_INCREMENT PRIMARY KEY,
  prueba    VARCHAR(200) NOT NULL,
  esperado  VARCHAR(20)  NOT NULL,
  obtenido  TEXT,
  resultado VARCHAR(5)   NOT NULL
);

DROP PROCEDURE IF EXISTS tst_espera_error;
DROP PROCEDURE IF EXISTS tst_verifica;

DELIMITER //
CREATE PROCEDURE tst_espera_error(IN p_prueba VARCHAR(200), IN p_sql TEXT)
BEGIN
  DECLARE v_msg TEXT DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;

  SET @tst_sql = p_sql;
  PREPARE tst_stmt FROM @tst_sql;
  EXECUTE tst_stmt;
  DEALLOCATE PREPARE tst_stmt;

  INSERT INTO tst_resultado (prueba, esperado, obtenido, resultado)
  VALUES (p_prueba, 'Rechazo', COALESCE(v_msg, 'Se aceptó el dato inválido'), IF(v_msg IS NULL, 'FALLO', 'OK'));
END //

CREATE PROCEDURE tst_verifica(IN p_prueba VARCHAR(200), IN p_condicion BOOLEAN, IN p_obtenido TEXT)
BEGIN
  INSERT INTO tst_resultado (prueba, esperado, obtenido, resultado)
  VALUES (p_prueba, 'Verdadero', p_obtenido, IF(COALESCE(p_condicion, FALSE), 'OK', 'FALLO'));
END //
DELIMITER ;

-- ---------------------------------------------------------------------
-- 1. Estructura
-- ---------------------------------------------------------------------
SET @n = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'gamestopdb' AND table_type = 'BASE TABLE');
CALL tst_verifica('15 tablas creadas (14 de negocio + app_usuario)', @n = 15, @n);

SET @n = (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'gamestopdb' AND table_type = 'BASE TABLE'
          AND (engine <> 'InnoDB' OR table_collation <> 'utf8mb4_0900_ai_ci'));
CALL tst_verifica('Todas las tablas InnoDB + utf8mb4_0900_ai_ci', @n = 0, @n);

SET @n = (SELECT COUNT(*) FROM information_schema.tables t
          WHERE t.table_schema = 'gamestopdb' AND t.table_type = 'BASE TABLE'
            AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints c
                            WHERE c.table_schema = t.table_schema AND c.table_name = t.table_name
                              AND c.constraint_type = 'PRIMARY KEY'));
CALL tst_verifica('Ninguna tabla sin PRIMARY KEY', @n = 0, @n);

SET @n = (SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema = 'gamestopdb');
CALL tst_verifica('16 claves foráneas (15 de negocio + app_usuario->colaborador)', @n = 16, @n);

SET @n = (SELECT COUNT(*) FROM information_schema.check_constraints WHERE constraint_schema = 'gamestopdb');
CALL tst_verifica('12 restricciones CHECK', @n = 12, @n);

SET @n = (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = 'gamestopdb');
CALL tst_verifica('11 triggers', @n = 11, @n);

SET @n = (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'gamestopdb' AND routine_name NOT LIKE 'tst\_%');
CALL tst_verifica('5 rutinas (1 función + 4 procedimientos)', @n = 5, @n);

SET @n = (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'gamestopdb');
CALL tst_verifica('3 vistas', @n = 3, @n);

SET @n = (SELECT COUNT(*) FROM mysql.tables_priv
          WHERE User = 'gs_vendedor' AND Db = 'gamestopdb' AND Table_name = 'cliente' AND FIND_IN_SET('Select', Table_priv));
CALL tst_verifica('Rol vendedor SIN SELECT sobre cliente', @n = 0, @n);

SET @n = (SELECT COUNT(*) FROM mysql.tables_priv
          WHERE User IN ('gs_gerente','gs_vendedor','gs_auditor') AND Db = 'gamestopdb' AND Table_name = 'bitacora'
            AND (FIND_IN_SET('Update', Table_priv) OR FIND_IN_SET('Delete', Table_priv)));
CALL tst_verifica('Ningún rol de negocio puede alterar la bitácora', @n = 0, @n);

-- ---------------------------------------------------------------------
-- 2. Consistencia de los datos de ejemplo
-- ---------------------------------------------------------------------
SET @n = (SELECT total_venta FROM venta WHERE idVenta = 1);
CALL tst_verifica('Total venta 1 = 549 + 2*579 = 1707.00', @n = 1707.00, @n);

SET @n = fn_stock_disponible(1, 1);
CALL tst_verifica('Stock Spider-Man 2 en Zona 10 = 10 - 1 = 9', @n = 9, @n);

SET @n = (SELECT estado_venta FROM venta WHERE idVenta = 2);
CALL tst_verifica('Venta 2 anulada', @n = 'ANULADA', @n);

SET @n = fn_stock_disponible(1, 2);
CALL tst_verifica('Anulación devolvió el stock de la PS5 (5)', @n = 5, @n);

SET @n = (SELECT precio_unitario FROM detalle_venta WHERE fk_Venta = 5 AND fk_Producto = 3);
CALL tst_verifica('Precio histórico se conserva tras cambio de precio (399.00)', @n = 399.00, @n);

SET @n = (SELECT COUNT(*) FROM venta v
          WHERE v.total_venta <> (SELECT COALESCE(SUM(subtotal_venta), 0) FROM detalle_venta d WHERE d.fk_Venta = v.idVenta));
CALL tst_verifica('Total de cada venta = suma de sus líneas', @n = 0, @n);

SET @n = (SELECT COUNT(*) FROM compra_proveedor c
          WHERE c.total_compra <> (SELECT COALESCE(SUM(subtotal), 0) FROM detalle_compra d WHERE d.fk_Compra_Proveedor = c.idCompra_Proveedor));
CALL tst_verifica('Total de cada compra = suma de sus líneas', @n = 0, @n);

-- Invariante de inventario: stock = comprado - vendido (ventas completadas)
SET @n = (SELECT COUNT(*) FROM inventario i
          WHERE i.stock_disponible <>
                (SELECT COALESCE(SUM(dc.cantidad), 0) FROM detalle_compra dc
                 JOIN compra_proveedor c ON c.idCompra_Proveedor = dc.fk_Compra_Proveedor
                 WHERE c.fk_Sucursal = i.fk_Sucursal AND dc.fk_Producto = i.fk_Producto)
              - (SELECT COALESCE(SUM(dv.cantidad), 0) FROM detalle_venta dv
                 JOIN venta v ON v.idVenta = dv.fk_Venta
                 WHERE v.estado_venta = 'COMPLETADA' AND v.fk_Sucursal = i.fk_Sucursal AND dv.fk_Producto = i.fk_Producto));
CALL tst_verifica('Inventario = compras - ventas completadas (todas las filas)', @n = 0, @n);

SET @n = (SELECT COUNT(*) FROM bitacora WHERE tabla = 'cliente' AND operacion = 'INSERT');
CALL tst_verifica('Bitácora registró los 5 clientes insertados', @n = 5, @n);

SET @n = (SELECT COUNT(*) FROM bitacora WHERE tabla = 'producto' AND operacion = 'UPDATE'
          AND JSON_EXTRACT(datos_anteriores, '$.precio') = 399.00 AND JSON_EXTRACT(datos_nuevos, '$.precio') = 349.00);
CALL tst_verifica('Bitácora registró el cambio de precio 399 -> 349', @n = 1, @n);

-- ---------------------------------------------------------------------
-- 3. Operaciones válidas
-- ---------------------------------------------------------------------
CALL sp_registrar_venta(3, 2, 5, '[{"producto":6,"cantidad":2}]', @vt);
SET @n = fn_stock_disponible(3, 6);
CALL tst_verifica('Venta válida descuenta stock (Mario Kart en Xela: 5 -> 3)', @n = 3, @n);
SET @n = (SELECT total_venta FROM venta WHERE idVenta = @vt);
CALL tst_verifica('Venta válida calcula total (2 x 469 = 938.00)', @n = 938.00, @n);

SET @antes = (SELECT COUNT(*) FROM bitacora WHERE operacion = 'CONSULTA');
CALL sp_consultar_cliente(1);
SET @n = (SELECT COUNT(*) FROM bitacora WHERE operacion = 'CONSULTA') - @antes;
CALL tst_verifica('Consulta de dato sensible queda en bitácora', @n = 1, @n);

SET @n = (SELECT correo_enmascarado FROM v_cliente_publico WHERE idCliente = 1);
CALL tst_verifica('Vista pública enmascara el correo', @n = 'an***@example.com', @n);

-- ---------------------------------------------------------------------
-- 4. Datos inválidos (todos deben ser RECHAZADOS)
-- ---------------------------------------------------------------------
CALL tst_espera_error('Precio de producto negativo',
  'INSERT INTO producto (codigo_sku, nombre_producto, marca_producto, fk_Categoria, precio_producto) VALUES (''T-NEG'', ''X'', ''X'', 1, -10)');
CALL tst_espera_error('SKU duplicado',
  'INSERT INTO producto (codigo_sku, nombre_producto, marca_producto, fk_Categoria, precio_producto) VALUES (''PS5-SLIM'', ''X'', ''X'', 1, 10)');
CALL tst_espera_error('Correo de cliente duplicado (distinto uso de mayúsculas)',
  'INSERT INTO cliente (nombre_cliente, correo_cliente) VALUES (''Otra'', ''ANDREA.LOPEZ@example.com'')');
CALL tst_espera_error('Correo de cliente con formato inválido',
  'INSERT INTO cliente (nombre_cliente, correo_cliente) VALUES (''Otra'', ''sin-arroba.com'')');
CALL tst_espera_error('Teléfono de sucursal con letras',
  'INSERT INTO telefono_sucursal (telefono_sucursal, fk_Sucursal) VALUES (''22AB0001'', 1)');
CALL tst_espera_error('Stock negativo',
  'UPDATE inventario SET stock_disponible = -1 WHERE idInventario = 1');
CALL tst_espera_error('FK huérfana: colaborador en sucursal inexistente',
  'INSERT INTO colaborador (nombre_colaborador, puesto_colaborador, fk_Sucursal) VALUES (''X'', ''Vendedor'', 999)');
CALL tst_espera_error('Venta con cantidad 0',
  'CALL sp_registrar_venta(1, 1, 2, ''[{"producto":1,"cantidad":0}]'', @x)');
CALL tst_espera_error('Venta con stock insuficiente',
  'CALL sp_registrar_venta(1, 1, 2, ''[{"producto":2,"cantidad":99}]'', @x)');
CALL tst_espera_error('Venta con colaborador de otra sucursal',
  'CALL sp_registrar_venta(2, 1, 2, ''[{"producto":1,"cantidad":1}]'', @x)');
CALL tst_espera_error('Venta con colaborador inactivo',
  'CALL sp_registrar_venta(1, 1, 6, ''[{"producto":1,"cantidad":1}]'', @x)');
CALL tst_espera_error('Venta con producto inexistente',
  'CALL sp_registrar_venta(1, 1, 2, ''[{"producto":999,"cantidad":1}]'', @x)');
CALL tst_espera_error('Venta sin productos',
  'CALL sp_registrar_venta(1, 1, 2, ''[]'', @x)');
CALL tst_espera_error('Mismo producto dos veces en una venta',
  'CALL sp_registrar_venta(1, 1, 2, ''[{"producto":1,"cantidad":1},{"producto":1,"cantidad":1}]'', @x)');
CALL tst_espera_error('Borrar cliente con ventas',
  'DELETE FROM cliente WHERE idCliente = 1');
CALL tst_espera_error('Borrar venta con detalle (se debe anular)',
  'DELETE FROM venta WHERE idVenta = 1');
CALL tst_espera_error('Anular una venta ya anulada',
  'CALL sp_anular_venta(2, ''Prueba'')');
CALL tst_espera_error('Compra a proveedor inexistente',
  'CALL sp_registrar_compra(999, 1, ''[{"producto":1,"cantidad":1,"precio":10}]'', @x)');

-- Atomicidad: la 1.ª línea es válida, la 2.ª no. No debe quedar nada.
SET @ventas_antes = (SELECT COUNT(*) FROM venta);
SET @stock_antes  = fn_stock_disponible(1, 7);
CALL tst_espera_error('Venta con una línea inválida (atomicidad)',
  'CALL sp_registrar_venta(1, 1, 2, ''[{"producto":7,"cantidad":1},{"producto":2,"cantidad":999}]'', @x)');
SET @n = (SELECT COUNT(*) FROM venta) - @ventas_antes;
CALL tst_verifica('Rollback: no quedó encabezado de venta huérfano', @n = 0, @n);
SET @n = fn_stock_disponible(1, 7) - @stock_antes;
CALL tst_verifica('Rollback: el stock de la línea válida no cambió', @n = 0, @n);

-- ---------------------------------------------------------------------
-- Resultado
-- ---------------------------------------------------------------------
SELECT n, prueba, esperado, resultado, obtenido FROM tst_resultado ORDER BY n;
SELECT SUM(resultado = 'OK') AS pruebas_ok, SUM(resultado = 'FALLO') AS pruebas_fallidas FROM tst_resultado;

DROP PROCEDURE tst_espera_error;
DROP PROCEDURE tst_verifica;
DROP TEMPORARY TABLE tst_resultado;
