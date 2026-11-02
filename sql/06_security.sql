-- =====================================================================
-- GameStop DB  |  06_security.sql
-- Roles y usuarios con mínimo privilegio. Requiere un usuario con
-- CREATE ROLE / CREATE USER / GRANT OPTION (p. ej. root).
--
--   gs_admin    : todo sobre gamestopdb (DBA del proyecto).
--   gs_gerente  : lee todo, mantiene catálogos, registra compras/ventas.
--   gs_vendedor : consulta catálogo e inventario, registra ventas SOLO
--                 mediante sp_registrar_venta; ve clientes enmascarados.
--   gs_auditor  : solo lectura de la bitácora y del reporte de ventas.
--
-- Nadie (salvo gs_admin) tiene UPDATE/DELETE sobre bitacora ni sobre
-- los detalles de venta/compra: son registros inmutables.
--
-- Las contraseñas son MARCADORES: vencen en el primer inicio de sesión
-- (PASSWORD EXPIRE) y el usuario debe definir una propia.
-- =====================================================================

USE gamestopdb;

DROP USER IF EXISTS 'gs_admin1'@'localhost', 'gs_gerente1'@'localhost',
                    'gs_vendedor1'@'localhost', 'gs_auditor1'@'localhost';
DROP ROLE IF EXISTS 'gs_admin', 'gs_gerente', 'gs_vendedor', 'gs_auditor';

CREATE ROLE 'gs_admin', 'gs_gerente', 'gs_vendedor', 'gs_auditor';

-- Administrador
GRANT ALL PRIVILEGES ON gamestopdb.* TO 'gs_admin';

-- Gerente
GRANT SELECT  ON gamestopdb.*                 TO 'gs_gerente';
GRANT EXECUTE ON gamestopdb.*                 TO 'gs_gerente';
GRANT INSERT, UPDATE ON gamestopdb.sucursal          TO 'gs_gerente';
GRANT INSERT, UPDATE, DELETE ON gamestopdb.telefono_sucursal TO 'gs_gerente';
GRANT INSERT, UPDATE ON gamestopdb.categoria         TO 'gs_gerente';
GRANT INSERT, UPDATE ON gamestopdb.plataforma        TO 'gs_gerente';
GRANT INSERT, UPDATE ON gamestopdb.producto          TO 'gs_gerente';
GRANT INSERT, UPDATE ON gamestopdb.proveedor         TO 'gs_gerente';
GRANT INSERT, UPDATE ON gamestopdb.cliente           TO 'gs_gerente';
GRANT INSERT, UPDATE ON gamestopdb.colaborador       TO 'gs_gerente';

-- Vendedor: sin SELECT sobre cliente ni sobre tablas de venta.
GRANT SELECT ON gamestopdb.producto              TO 'gs_vendedor';
GRANT SELECT ON gamestopdb.categoria             TO 'gs_vendedor';
GRANT SELECT ON gamestopdb.plataforma            TO 'gs_vendedor';
GRANT SELECT ON gamestopdb.v_inventario_sucursal TO 'gs_vendedor';
GRANT SELECT ON gamestopdb.v_cliente_publico     TO 'gs_vendedor';
GRANT INSERT ON gamestopdb.cliente               TO 'gs_vendedor';   -- registrar clientes nuevos
GRANT EXECUTE ON PROCEDURE gamestopdb.sp_registrar_venta   TO 'gs_vendedor';
GRANT EXECUTE ON PROCEDURE gamestopdb.sp_consultar_cliente TO 'gs_vendedor';
GRANT EXECUTE ON FUNCTION  gamestopdb.fn_stock_disponible  TO 'gs_vendedor';

-- Auditor
GRANT SELECT ON gamestopdb.bitacora        TO 'gs_auditor';
GRANT SELECT ON gamestopdb.v_venta_detalle TO 'gs_auditor';

-- Usuarios de ejemplo (uno por rol)
CREATE USER 'gs_admin1'@'localhost'    IDENTIFIED BY 'Cambiar#Admin2026'    PASSWORD EXPIRE;
CREATE USER 'gs_gerente1'@'localhost'  IDENTIFIED BY 'Cambiar#Gerente2026'  PASSWORD EXPIRE;
CREATE USER 'gs_vendedor1'@'localhost' IDENTIFIED BY 'Cambiar#Vendedor2026' PASSWORD EXPIRE;
CREATE USER 'gs_auditor1'@'localhost'  IDENTIFIED BY 'Cambiar#Auditor2026'  PASSWORD EXPIRE;

GRANT 'gs_admin'    TO 'gs_admin1'@'localhost';
GRANT 'gs_gerente'  TO 'gs_gerente1'@'localhost';
GRANT 'gs_vendedor' TO 'gs_vendedor1'@'localhost';
GRANT 'gs_auditor'  TO 'gs_auditor1'@'localhost';

SET DEFAULT ROLE ALL TO 'gs_admin1'@'localhost', 'gs_gerente1'@'localhost',
                        'gs_vendedor1'@'localhost', 'gs_auditor1'@'localhost';
