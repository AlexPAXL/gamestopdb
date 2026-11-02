-- =====================================================================
-- GameStop DB  |  11_app_service_accounts.sql
-- Cuentas técnicas para los pools de conexión del backend Node.
-- Separadas de gs_*1 (06_security.sql) a propósito: esas vencen
-- (PASSWORD EXPIRE) y son para que un humano las use manualmente
-- (demo/video); estas son para que un proceso quede conectado.
--
-- Mismo mínimo privilegio: cada svc_* hereda EXACTAMENTE el rol de
-- negocio ya definido, nada más. svc_auth solo puede leer las tablas
-- necesarias para el login (nunca datos de negocio).
--
-- Las contraseñas de abajo son MARCADORES de ejemplo para desarrollo.
-- En producción cámbielas aquí y en el .env del backend (ver README).
-- =====================================================================

USE gamestopdb;

-- Host '%' (no 'localhost'): el backend Node se conecta por TCP, y en
-- MySQL una cuenta @'localhost' solo autentica por socket Unix. Con '%'
-- funciona igual si el backend corre en la misma máquina que en otra.
-- Si su servidor necesita restringir el origen, cambie '%' por la IP/host
-- real del backend.
-- Se limpian ambos hosts por si una corrida anterior (u otro script) dejó
-- la variante @'localhost': de existir, MySQL la preferiría por ser más
-- específica que '%', y esa cuenta vieja no tendría el rol asignado.
DROP USER IF EXISTS 'svc_admin'@'%', 'svc_gerente'@'%',
                    'svc_vendedor'@'%', 'svc_auditor'@'%', 'svc_auth'@'%',
                    'svc_admin'@'localhost', 'svc_gerente'@'localhost',
                    'svc_vendedor'@'localhost', 'svc_auditor'@'localhost', 'svc_auth'@'localhost';

CREATE USER 'svc_admin'@'%'    IDENTIFIED BY 'DevOnly#svc_admin_2026';
CREATE USER 'svc_gerente'@'%'  IDENTIFIED BY 'DevOnly#svc_gerente_2026';
CREATE USER 'svc_vendedor'@'%' IDENTIFIED BY 'DevOnly#svc_vendedor_2026';
CREATE USER 'svc_auditor'@'%'  IDENTIFIED BY 'DevOnly#svc_auditor_2026';
CREATE USER 'svc_auth'@'%'     IDENTIFIED BY 'DevOnly#svc_auth_2026';

GRANT 'gs_admin'    TO 'svc_admin'@'%';
GRANT 'gs_gerente'  TO 'svc_gerente'@'%';
GRANT 'gs_vendedor' TO 'svc_vendedor'@'%';
GRANT 'gs_auditor'  TO 'svc_auditor'@'%';

SET DEFAULT ROLE ALL TO 'svc_admin'@'%', 'svc_gerente'@'%',
                        'svc_vendedor'@'%', 'svc_auditor'@'%';

-- Solo para el paso de login: leer credenciales de la app y el contexto
-- mínimo del colaborador (nombre, sucursal) para armar la sesión.
GRANT SELECT ON gamestopdb.app_usuario TO 'svc_auth'@'%';
GRANT SELECT ON gamestopdb.colaborador TO 'svc_auth'@'%';
GRANT SELECT ON gamestopdb.sucursal    TO 'svc_auth'@'%';
