-- =====================================================================
-- GameStop DB  |  02_tables.sql
-- Tablas, PK, FK, UNIQUE, CHECK e índices (definidos junto a su tabla
-- para que cada tabla se lea completa en un solo lugar).
--
-- Convención de nombres (se conserva la del modelo original):
--   PK  idTabla            FK  fk_Tabla
--   uq_<tabla>_<cols>      chk_<tabla>_<regla>     idx_<tabla>_<cols>
--   fk_<Hija>_<Padre>
-- Reglas de FK: ON UPDATE se deja en el valor por defecto (RESTRICT)
-- porque las PK son AUTO_INCREMENT y nunca se modifican.
-- =====================================================================

USE gamestopdb;

-- ---------------------------------------------------------------------
-- Catálogos
-- ---------------------------------------------------------------------
CREATE TABLE sucursal (
  idSucursal          INT          NOT NULL AUTO_INCREMENT,
  nombre_sucursal     VARCHAR(100) NOT NULL,          -- corregido: antes "nombre_surcursal"
  direccion_sucursal  VARCHAR(150) NOT NULL,
  ciudad_sucursal     VARCHAR(50)  NOT NULL,
  activa              BOOLEAN      NOT NULL DEFAULT TRUE,   -- baja lógica: una sucursal con ventas no puede borrarse
  CONSTRAINT pk_sucursal PRIMARY KEY (idSucursal),
  CONSTRAINT uq_sucursal_nombre UNIQUE (nombre_sucursal)
) ENGINE = InnoDB;

CREATE TABLE telefono_sucursal (                     -- atributo multivaluado de sucursal (1FN)
  idTelefono_Sucursal INT     NOT NULL AUTO_INCREMENT,
  telefono_sucursal   CHAR(8) NOT NULL,
  fk_Sucursal         INT     NOT NULL,
  CONSTRAINT pk_telefono_sucursal PRIMARY KEY (idTelefono_Sucursal),
  CONSTRAINT uq_telefono_sucursal UNIQUE (fk_Sucursal, telefono_sucursal),   -- también sirve de índice para la FK
  CONSTRAINT chk_telefono_sucursal_formato CHECK (telefono_sucursal REGEXP '^[0-9]{8}$'),
  CONSTRAINT fk_Telefono_Sucursal_Sucursal FOREIGN KEY (fk_Sucursal)
    REFERENCES sucursal (idSucursal) ON DELETE CASCADE   -- entidad débil: sin sucursal el teléfono no tiene sentido
) ENGINE = InnoDB;

CREATE TABLE categoria (
  idCategoria      INT         NOT NULL AUTO_INCREMENT,
  nombre_categoria VARCHAR(45) NOT NULL,
  CONSTRAINT pk_categoria PRIMARY KEY (idCategoria),
  CONSTRAINT uq_categoria_nombre UNIQUE (nombre_categoria)
) ENGINE = InnoDB;

CREATE TABLE plataforma (
  idPlataforma      INT         NOT NULL AUTO_INCREMENT,
  nombre_plataforma VARCHAR(50) NOT NULL,
  CONSTRAINT pk_plataforma PRIMARY KEY (idPlataforma),
  CONSTRAINT uq_plataforma_nombre UNIQUE (nombre_plataforma)
) ENGINE = InnoDB;

CREATE TABLE producto (
  idProducto      INT           NOT NULL AUTO_INCREMENT,
  codigo_sku      VARCHAR(30)   NOT NULL,             -- identificador de negocio: evita productos duplicados
  nombre_producto VARCHAR(150)  NOT NULL,
  marca_producto  VARCHAR(60)   NOT NULL,
  fk_Categoria    INT           NOT NULL,
  fk_Plataforma   INT           NULL,                 -- NULL: tarjetas de regalo, coleccionables, etc.
  precio_producto DECIMAL(10,2) NOT NULL,
  activo          BOOLEAN       NOT NULL DEFAULT TRUE,  -- baja lógica: un producto vendido no puede borrarse
  CONSTRAINT pk_producto PRIMARY KEY (idProducto),
  CONSTRAINT uq_producto_sku UNIQUE (codigo_sku),
  CONSTRAINT chk_producto_precio CHECK (precio_producto > 0),
  CONSTRAINT fk_Producto_Categoria  FOREIGN KEY (fk_Categoria)  REFERENCES categoria  (idCategoria)  ON DELETE RESTRICT,
  CONSTRAINT fk_Producto_Plataforma FOREIGN KEY (fk_Plataforma) REFERENCES plataforma (idPlataforma) ON DELETE RESTRICT,
  INDEX idx_producto_nombre (nombre_producto)          -- búsqueda por nombre en punto de venta
) ENGINE = InnoDB;

CREATE TABLE proveedor (
  idProveedor        INT          NOT NULL AUTO_INCREMENT,
  nombre_proveedor   VARCHAR(100) NOT NULL,
  telefono_proveedor VARCHAR(20)  NOT NULL,
  correo_proveedor   VARCHAR(150) NOT NULL,
  activo             BOOLEAN      NOT NULL DEFAULT TRUE,
  CONSTRAINT pk_proveedor PRIMARY KEY (idProveedor),
  CONSTRAINT uq_proveedor_correo UNIQUE (correo_proveedor),
  CONSTRAINT chk_proveedor_telefono CHECK (telefono_proveedor REGEXP '^[+]?[0-9]{8,15}$'),
  CONSTRAINT chk_proveedor_correo   CHECK (correo_proveedor REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$')
) ENGINE = InnoDB;

CREATE TABLE cliente (
  idCliente      INT          NOT NULL AUTO_INCREMENT,
  nombre_cliente VARCHAR(100) NOT NULL,
  correo_cliente VARCHAR(120) NOT NULL,
  CONSTRAINT pk_cliente PRIMARY KEY (idCliente),
  CONSTRAINT uq_cliente_correo UNIQUE (correo_cliente),
  CONSTRAINT chk_cliente_correo CHECK (correo_cliente REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$')
) ENGINE = InnoDB;

CREATE TABLE colaborador (
  idColaborador      INT          NOT NULL AUTO_INCREMENT,
  nombre_colaborador VARCHAR(100) NOT NULL,
  puesto_colaborador VARCHAR(45)  NOT NULL,
  fk_Sucursal        INT          NOT NULL,
  activo             BOOLEAN      NOT NULL DEFAULT TRUE,  -- un colaborador que ya vendió no puede borrarse
  CONSTRAINT pk_colaborador PRIMARY KEY (idColaborador),
  CONSTRAINT fk_Colaborador_Sucursal FOREIGN KEY (fk_Sucursal) REFERENCES sucursal (idSucursal) ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Inventario (relación N:M sucursal-producto con atributo stock)
-- ---------------------------------------------------------------------
CREATE TABLE inventario (
  idInventario     INT NOT NULL AUTO_INCREMENT,
  fk_Sucursal      INT NOT NULL,
  fk_Producto      INT NOT NULL,
  stock_disponible INT NOT NULL DEFAULT 0,
  CONSTRAINT pk_inventario PRIMARY KEY (idInventario),
  CONSTRAINT uq_inventario_sucursal_producto UNIQUE (fk_Sucursal, fk_Producto),  -- cubre la FK a sucursal
  CONSTRAINT chk_inventario_stock CHECK (stock_disponible >= 0),                   -- nunca stock negativo
  CONSTRAINT fk_Inventario_Sucursal FOREIGN KEY (fk_Sucursal) REFERENCES sucursal (idSucursal) ON DELETE RESTRICT,
  CONSTRAINT fk_Inventario_Producto FOREIGN KEY (fk_Producto) REFERENCES producto (idProducto) ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Ventas
-- ---------------------------------------------------------------------
CREATE TABLE venta (
  idVenta        INT           NOT NULL AUTO_INCREMENT,
  fecha_venta    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total_venta    DECIMAL(12,2) NOT NULL DEFAULT 0,       -- desnormalización controlada: la mantiene un trigger
  estado_venta   ENUM('COMPLETADA','ANULADA') NOT NULL DEFAULT 'COMPLETADA',
  fk_Sucursal    INT           NOT NULL,
  fk_Cliente     INT           NOT NULL,
  fk_Colaborador INT           NOT NULL,
  CONSTRAINT pk_venta PRIMARY KEY (idVenta),
  CONSTRAINT chk_venta_total CHECK (total_venta >= 0),
  CONSTRAINT fk_Venta_Sucursal    FOREIGN KEY (fk_Sucursal)    REFERENCES sucursal    (idSucursal)    ON DELETE RESTRICT,
  CONSTRAINT fk_Venta_Cliente     FOREIGN KEY (fk_Cliente)     REFERENCES cliente     (idCliente)     ON DELETE RESTRICT,
  CONSTRAINT fk_Venta_Colaborador FOREIGN KEY (fk_Colaborador) REFERENCES colaborador (idColaborador) ON DELETE RESTRICT,
  INDEX idx_venta_sucursal_fecha (fk_Sucursal, fecha_venta),   -- reportes por sucursal y rango de fechas; cubre la FK
  INDEX idx_venta_fecha (fecha_venta),                          -- reportes globales por fecha
  INDEX idx_venta_cliente (fk_Cliente),
  INDEX idx_venta_colaborador (fk_Colaborador)
) ENGINE = InnoDB;

CREATE TABLE detalle_venta (
  idDetalle_Venta INT           NOT NULL AUTO_INCREMENT,
  cantidad        INT           NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,   -- precio histórico al momento de la venta (no es redundancia)
  subtotal_venta  DECIMAL(12,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,  -- ya no puede quedar inconsistente
  fk_Venta        INT           NOT NULL,
  fk_Producto     INT           NOT NULL,
  CONSTRAINT pk_detalle_venta PRIMARY KEY (idDetalle_Venta),
  CONSTRAINT uq_detalle_venta_producto UNIQUE (fk_Venta, fk_Producto),   -- una línea por producto; cubre la FK a venta
  CONSTRAINT chk_detalle_venta_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_detalle_venta_precio   CHECK (precio_unitario > 0),
  -- RESTRICT (antes CASCADE): un borrado en cascada NO dispara triggers en MySQL,
  -- así que borraba las líneas sin devolver el stock. Las ventas se anulan, no se borran.
  CONSTRAINT fk_Detalle_Venta_Venta    FOREIGN KEY (fk_Venta)    REFERENCES venta    (idVenta)    ON DELETE RESTRICT,
  CONSTRAINT fk_Detalle_Venta_Producto FOREIGN KEY (fk_Producto) REFERENCES producto (idProducto) ON DELETE RESTRICT,
  INDEX idx_detalle_venta_producto (fk_Producto)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Compras a proveedores
-- ---------------------------------------------------------------------
CREATE TABLE compra_proveedor (
  idCompra_Proveedor INT           NOT NULL AUTO_INCREMENT,
  fecha_compra       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total_compra       DECIMAL(12,2) NOT NULL DEFAULT 0,   -- antes DECIMAL(8,2): tope de Q999,999.99 por compra
  fk_Proveedor       INT           NOT NULL,
  fk_Sucursal        INT           NOT NULL,
  CONSTRAINT pk_compra_proveedor PRIMARY KEY (idCompra_Proveedor),
  CONSTRAINT chk_compra_total CHECK (total_compra >= 0),
  CONSTRAINT fk_Compra_Proveedor_Proveedor FOREIGN KEY (fk_Proveedor) REFERENCES proveedor (idProveedor) ON DELETE RESTRICT,
  CONSTRAINT fk_Compra_Proveedor_Sucursal  FOREIGN KEY (fk_Sucursal)  REFERENCES sucursal  (idSucursal)  ON DELETE RESTRICT,
  INDEX idx_compra_proveedor (fk_Proveedor),
  INDEX idx_compra_sucursal_fecha (fk_Sucursal, fecha_compra)
) ENGINE = InnoDB;

CREATE TABLE detalle_compra (
  idDetalle_Compra    INT           NOT NULL AUTO_INCREMENT,
  cantidad            INT           NOT NULL,
  precio_compra       DECIMAL(10,2) NOT NULL,
  subtotal            DECIMAL(12,2) GENERATED ALWAYS AS (cantidad * precio_compra) STORED,
  fk_Compra_Proveedor INT           NOT NULL,
  fk_Producto         INT           NOT NULL,
  CONSTRAINT pk_detalle_compra PRIMARY KEY (idDetalle_Compra),
  CONSTRAINT uq_detalle_compra_producto UNIQUE (fk_Compra_Proveedor, fk_Producto),
  CONSTRAINT chk_detalle_compra_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_detalle_compra_precio   CHECK (precio_compra > 0),
  CONSTRAINT fk_Detalle_Compra_Compra_Proveedor FOREIGN KEY (fk_Compra_Proveedor)
    REFERENCES compra_proveedor (idCompra_Proveedor) ON DELETE RESTRICT,   -- mismo motivo que detalle_venta
  CONSTRAINT fk_Detalle_Compra_Producto FOREIGN KEY (fk_Producto) REFERENCES producto (idProducto) ON DELETE RESTRICT,
  INDEX idx_detalle_compra_producto (fk_Producto)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Bitácora de auditoría (requisito de ciberseguridad)
-- Solo se escribe desde triggers y procedimientos; ningún rol de
-- negocio tiene UPDATE/DELETE sobre ella (ver 06_security.sql).
-- ---------------------------------------------------------------------
CREATE TABLE bitacora (
  idBitacora       BIGINT       NOT NULL AUTO_INCREMENT,   -- es la tabla que más crece
  fecha            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  usuario_db       VARCHAR(288) NOT NULL,                  -- USER(): usuario real conectado, no el DEFINER
  tabla            VARCHAR(64)  NOT NULL,
  operacion        ENUM('INSERT','UPDATE','DELETE','CONSULTA') NOT NULL,
  id_registro      INT          NULL,
  datos_anteriores JSON         NULL,
  datos_nuevos     JSON         NULL,
  detalle          VARCHAR(255) NULL,
  CONSTRAINT pk_bitacora PRIMARY KEY (idBitacora),
  INDEX idx_bitacora_tabla_registro (tabla, id_registro),
  INDEX idx_bitacora_fecha (fecha),
  INDEX idx_bitacora_usuario (usuario_db, fecha)
) ENGINE = InnoDB;
