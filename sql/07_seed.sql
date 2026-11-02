-- =====================================================================
-- GameStop DB  |  07_seed.sql
-- Datos de ejemplo ficticios (nombres y correos inventados, dominio
-- example.com reservado para pruebas). Compras y ventas se registran con
-- los procedimientos, igual que lo haría la aplicación, para que stock,
-- totales y bitácora queden consistentes.
-- =====================================================================

USE gamestopdb;

INSERT INTO sucursal (nombre_sucursal, direccion_sucursal, ciudad_sucursal) VALUES
  ('GameStop Zona 10', '12 calle 2-45 zona 10',        'Guatemala'),
  ('GameStop Mixco',   'Calzada San Juan 15-20 zona 7', 'Mixco'),
  ('GameStop Xela',    '4a calle 12-30 zona 3',         'Quetzaltenango');

INSERT INTO telefono_sucursal (telefono_sucursal, fk_Sucursal) VALUES
  ('22150001', 1), ('22150002', 1), ('24380010', 2), ('77610020', 3);

INSERT INTO categoria (nombre_categoria) VALUES
  ('Videojuegos'), ('Consolas'), ('Accesorios'), ('Tarjetas de regalo');

INSERT INTO plataforma (nombre_plataforma) VALUES
  ('PlayStation 5'), ('Xbox Series X|S'), ('Nintendo Switch'), ('PC');

INSERT INTO producto (codigo_sku, nombre_producto, marca_producto, fk_Categoria, fk_Plataforma, precio_producto) VALUES
  ('PS5-SPIDERMAN2',   'Marvel''s Spider-Man 2',                 'Sony',      1, 1,     549.00),
  ('PS5-SLIM',         'Consola PlayStation 5 Slim',             'Sony',      2, 1,    4299.00),
  ('XSX-HALOINF',      'Halo Infinite',                          'Microsoft', 1, 2,     399.00),
  ('XSX-CONSOLA',      'Consola Xbox Series X',                  'Microsoft', 2, 2,    4199.00),
  ('NSW-ZELDATOTK',    'The Legend of Zelda: Tears of the Kingdom', 'Nintendo', 1, 3,  529.00),
  ('NSW-MK8D',         'Mario Kart 8 Deluxe',                    'Nintendo',  1, 3,     469.00),
  ('PS5-DUALSENSE',    'Control inalámbrico DualSense',          'Sony',      3, 1,     579.00),
  ('NSW-PROCON',       'Nintendo Switch Pro Controller',         'Nintendo',  3, 3,     559.00),
  ('GC-GAMESTOP-250',  'Tarjeta de regalo GameStop Q250',        'GameStop',  4, NULL,  250.00),
  ('PC-HYPERX-CLOUD2', 'Audífonos HyperX Cloud II',              'HyperX',    3, 4,     699.00);

INSERT INTO proveedor (nombre_proveedor, telefono_proveedor, correo_proveedor) VALUES
  ('Distribuidora Digital Centroamericana', '23010000',     'ventas@distdigital.example.com'),
  ('Tech Import GT',                         '+50223020000', 'pedidos@techimport.example.com'),
  ('Coleccionables del Altiplano',           '77650000',     'contacto@altiplano.example.com');

INSERT INTO cliente (nombre_cliente, correo_cliente) VALUES
  ('Andrea López',     'andrea.lopez@example.com'),
  ('Carlos Méndez',    'carlos.mendez@example.com'),
  ('Lucía Ramírez',    'lucia.ramirez@example.com'),
  ('Diego Hernández',  'diego.hernandez@example.com'),
  ('Sofía Castillo',   'sofia.castillo@example.com');

INSERT INTO colaborador (nombre_colaborador, puesto_colaborador, fk_Sucursal, activo) VALUES
  ('Mario Pérez',     'Gerente',  1, TRUE),
  ('Julia Gómez',     'Vendedor', 1, TRUE),
  ('Pedro Ajú',       'Gerente',  2, TRUE),
  ('Karla Morales',   'Vendedor', 2, TRUE),
  ('Luis Tzul',       'Vendedor', 3, TRUE),
  ('Esteban Ruiz',    'Vendedor', 1, FALSE);   -- ya no labora: sirve para probar la validación

-- Compras (llenan el inventario mediante trigger)
CALL sp_registrar_compra(1, 1, '[{"producto":1,"cantidad":10,"precio":380.00},{"producto":2,"cantidad":5,"precio":3500.00},{"producto":7,"cantidad":8,"precio":420.00},{"producto":9,"cantidad":20,"precio":250.00}]', @c1);
CALL sp_registrar_compra(2, 1, '[{"producto":3,"cantidad":6,"precio":280.00},{"producto":4,"cantidad":4,"precio":3400.00},{"producto":10,"cantidad":5,"precio":500.00}]', @c2);
CALL sp_registrar_compra(1, 2, '[{"producto":1,"cantidad":6,"precio":380.00},{"producto":5,"cantidad":8,"precio":390.00},{"producto":6,"cantidad":8,"precio":340.00},{"producto":7,"cantidad":4,"precio":420.00}]', @c3);
CALL sp_registrar_compra(3, 3, '[{"producto":5,"cantidad":5,"precio":390.00},{"producto":6,"cantidad":5,"precio":340.00},{"producto":8,"cantidad":6,"precio":410.00},{"producto":9,"cantidad":10,"precio":250.00}]', @c4);

-- Ventas (descuentan inventario y calculan totales mediante triggers)
CALL sp_registrar_venta(1, 1, 2, '[{"producto":1,"cantidad":1},{"producto":7,"cantidad":2}]', @v1);
CALL sp_registrar_venta(1, 2, 2, '[{"producto":2,"cantidad":1}]', @v2);
CALL sp_registrar_venta(2, 3, 4, '[{"producto":5,"cantidad":1},{"producto":6,"cantidad":1}]', @v3);
CALL sp_registrar_venta(3, 4, 5, '[{"producto":8,"cantidad":1},{"producto":9,"cantidad":2}]', @v4);
CALL sp_registrar_venta(1, 5, 1, '[{"producto":3,"cantidad":1},{"producto":10,"cantidad":1}]', @v5);
CALL sp_registrar_venta(2, 1, 3, '[{"producto":1,"cantidad":2}]', @v6);

-- Una anulación (devuelve el stock de la venta 2)
CALL sp_anular_venta(@v2, 'El cliente desistió de la compra');

-- Distribuir fechas en varios meses para que los reportes tengan sentido.
-- (Ajuste exclusivo de datos de ejemplo.)
UPDATE compra_proveedor SET fecha_compra = '2026-06-01 09:00:00' WHERE idCompra_Proveedor IN (@c1, @c2, @c3, @c4);
UPDATE venta SET fecha_venta = '2026-06-14 11:20:00' WHERE idVenta = @v1;
UPDATE venta SET fecha_venta = '2026-06-20 16:45:00' WHERE idVenta = @v2;
UPDATE venta SET fecha_venta = '2026-07-03 10:05:00' WHERE idVenta = @v3;
UPDATE venta SET fecha_venta = '2026-07-18 18:30:00' WHERE idVenta = @v4;
UPDATE venta SET fecha_venta = '2026-08-09 13:10:00' WHERE idVenta = @v5;
UPDATE venta SET fecha_venta = '2026-08-27 15:55:00' WHERE idVenta = @v6;

-- Cambio de precio (queda en la bitácora)
UPDATE producto SET precio_producto = 349.00 WHERE codigo_sku = 'XSX-HALOINF';
