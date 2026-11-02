-- =====================================================================
-- GameStop DB  |  10_app_usuarios.sql
-- Cuentas de LOGIN de la aplicación web (distintas de las cuentas MySQL
-- gs_*1 de 06_security.sql, que son para demo/DBA). Cada usuario de app
-- tiene un rol de negocio y, si es personal de tienda, su colaborador:
-- así el backend sabe automáticamente su sucursal y puede exigir que
-- venda solo desde ahí (lo valida igual trg_venta_bi, esto es además).
--
-- Las contraseñas NO se guardan aquí: la tabla solo tiene el hash
-- (bcrypt, generado por Node). Ver scripts/seed_app_usuarios.js.
-- =====================================================================

USE gamestopdb;

CREATE TABLE app_usuario (
  idUsuario      INT          NOT NULL AUTO_INCREMENT,
  usuario        VARCHAR(50)  NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,
  rol            ENUM('admin','gerente','vendedor','auditor') NOT NULL,
  fk_Colaborador INT          NULL,        -- NULL: admin/auditor no son personal de una sucursal
  activo         BOOLEAN      NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_app_usuario PRIMARY KEY (idUsuario),
  CONSTRAINT uq_app_usuario_usuario UNIQUE (usuario),
  CONSTRAINT fk_App_Usuario_Colaborador FOREIGN KEY (fk_Colaborador)
    REFERENCES colaborador (idColaborador) ON DELETE RESTRICT
) ENGINE = InnoDB;
