# GameStop GT — sistema integral de tienda

Sistema de gestión completo (catálogo, inventario, ventas, compras, reportes,
auditoría) sobre la base de datos `gamestopdb` ya auditada (ver `AUDITORIA.md`
original). Backend Node.js + Express 5, vistas renderizadas en el servidor
(EJS, sin build step), seguridad aplicada en dos capas: roles de MySQL con
privilegio mínimo (ya existentes en el diseño original) + sesión/CSRF/bcrypt
en la capa de aplicación.

## 1. Estructura

```
gamestop/
├── sql/            # Esquema, lógica de negocio y seguridad (MySQL 8.0)
│   ├── 00_build_all.sql       orquestador: ejecuta todo en orden
│   ├── 01_database.sql        CREATE DATABASE
│   ├── 02_tables.sql          14 tablas de negocio (del diseño original)
│   ├── 03_views.sql           vistas (incl. v_cliente_publico con correo enmascarado)
│   ├── 04_routines.sql        función + 4 stored procedures (ventas/compras/anulación/consulta)
│   ├── 05_triggers.sql        11 triggers de bitácora
│   ├── 06_security.sql        4 ROLES de MySQL (gs_admin/gerente/vendedor/auditor)
│   ├── 07_seed.sql            datos de ejemplo (3 sucursales, 10 productos, ventas, compras...)
│   ├── 08_validation.sql      45 aserciones automáticas de integridad y reglas de negocio
│   ├── 09_consultas.sql       12 consultas de negocio de referencia
│   ├── 10_app_usuarios.sql    tabla app_usuario (login de la aplicación, agregada por mí)
│   └── 11_app_service_accounts.sql  cuentas de servicio svc_* que la app usa para conectarse
└── app/            # Backend + frontend Node.js/Express
    ├── server.js
    ├── scripts/
    │   ├── seed_app_usuarios.js   crea/actualiza los 8 logins de la app (bcrypt)
    │   └── smoke_test.js          prueba end-to-end automatizada (18 aserciones)
    └── src/
        ├── app.js                 configuración de Express (sesión, CSRF, helmet, rutas)
        ├── db.js                  pools mysql2, uno por rol de MySQL
        ├── middleware/            auth, csrf, flash
        ├── lib/procs.js           wrappers de los stored procedures
        ├── routes/                una ruta por módulo (ventas, compras, catálogo...)
        ├── views/                 plantillas EJS
        └── public/css/            estilos (sin framework)
```

## 2. Por qué dos capas de seguridad

La base de datos original ya define 4 ROLES de MySQL con GRANTs mínimos
(`gs_admin`, `gs_gerente`, `gs_vendedor`, `gs_auditor`): por ejemplo
`gs_auditor` solo puede leer `bitacora` y la vista `v_venta_detalle`, nada
más. Decidí **no tocar esos GRANTs** y en vez de eso:

- Cada rol de la app abre su conexión a MySQL con una cuenta de *servicio*
  (`svc_admin`, `svc_gerente`, `svc_vendedor`, `svc_auditor`) que tiene
  asignado exactamente ese ROLE. Así, si un desarrollador comete un error en
  una consulta, **MySQL rechaza la operación aunque el código de Express no
  la hubiera bloqueado** — el motor de base de datos es la última línea de
  defensa, no solo el código.
- Por eso el módulo de reportes (`src/routes/reportes.js`) reescribe algunas
  consultas para pasar por `v_venta_detalle`/`bitacora` en vez de tablas
  base, así el rol `auditor` (solo lectura) puede ver reportes de ventas sin
  que le demos ningún GRANT nuevo sobre `venta`/`producto`.
- Por encima de eso, la aplicación añade su propia capa: login con
  usuario/contraseña (`app_usuario`, bcrypt costo 12, totalmente
  independiente de las contraseñas de MySQL), sesión de servidor, CSRF
  (doble-submit), `express-rate-limit` en login, y `helmet` para cabeceras
  HTTP.

La tabla `app_usuario` (`10_app_usuarios.sql`) es la única pieza nueva en el
esquema: conecta un login de la aplicación con un `colaborador` existente
(para saber en qué sucursal trabaja y qué nombre mostrar). Los usuarios
`admin`/`auditor` no están ligados a ningún colaborador: antes de vender o
comprar, el sistema les pide elegir con qué colaborador están actuando
("elegir colaborador").

## 3. Instalación desde cero

Requisitos: MySQL 8.0+, Node.js 18+.

```bash
# 1. Construir la base de datos completa (esquema + seed + 45 validaciones)
mysql -u root < sql/00_build_all.sql
# Debe terminar imprimiendo: pruebas_ok=45  pruebas_fallidas=0

# 2. Crear las cuentas de servicio de MySQL que usará la app
mysql -u root < sql/11_app_service_accounts.sql

# 3. Instalar dependencias de Node
cd app
npm install

# 4. Configurar variables de entorno
cp .env.example .env
# Editar .env: las contraseñas ya coinciden con las de 11_app_service_accounts.sql
# (son de desarrollo; cambiarlas en ambos archivos antes de producción).
# IMPORTANTE: cualquier valor que tenga '#' debe ir entre comillas dobles,
# porque dotenv trata '#' sin comillas como inicio de comentario.

# 5. Crear los logins de la aplicación (bcrypt)
node scripts/seed_app_usuarios.js

# 6. Arrancar
node server.js
# http://localhost:3000
```

## 4. Usuarios de prueba (todas las contraseñas son de desarrollo)

| Usuario   | Contraseña      | Rol       | Colaborador ligado        |
|-----------|-----------------|-----------|----------------------------|
| admin     | Admin#2026      | admin     | ninguno (elige al vender)  |
| auditor   | Auditor#2026    | auditor   | ninguno                    |
| mperez    | Gerente#2026    | gerente   | Mario Pérez (Zona 10)      |
| pajuc     | Gerente#2026    | gerente   | (Mixco/Xela)                |
| jgomez    | Vendedor#2026   | vendedor  | Julia Gómez (Zona 10)      |
| kmorales  | Vendedor#2026   | vendedor  | Karla Morales               |
| ltzul     | Vendedor#2026   | vendedor  | Luis Tzul                   |
| eruiz     | Vendedor#2026   | vendedor  | Esteban Ruiz — **inactivo**, usado a propósito para probar que el login se bloquea |

## 5. Verificación

```bash
# Con el servidor corriendo (node server.js):
node scripts/smoke_test.js
# Debe imprimir: 18 OK, 0 fallidas
```

Cubre: login correcto/incorrecto, bloqueo por rol (403) en cada módulo,
flujo completo de venta (incluye recibo vía SECURITY DEFINER), bloqueo de
login para colaborador inactivo, y rechazo de un POST sin token CSRF válido.

También puede volver a correrse `sql/08_validation.sql` solo, para
reconfirmar las 45 reglas de negocio e integridad sin reconstruir todo.

## 6. Problemas comunes al instalar

- **`Cannot find module '...\server.js'`**: `server.js` está dentro de
  `app/`, no en la raíz del proyecto. Hay que `cd app` antes de
  `node server.js`.
- **El servidor arranca pero el navegador muestra un error feo, o la
  consola dice "Falta configurar el archivo .env"**: falta el paso
  `cp .env.example .env` (o `copy .env.example .env` en Windows) dentro de
  `app/`. El servidor ahora valida esto al arrancar y lo dice explícito en
  la consola en vez de fallar a medias dentro de una petición.
- **`Access denied for user 'svc_...'`**: la base de datos no tiene las
  cuentas de servicio (paso 2, `11_app_service_accounts.sql`) o las
  contraseñas en `.env` no coinciden con las de ese script.

## 7. Qué quedó fuera a propósito (alcance MVP de este sistema completo)

Estas son simplificaciones conscientes, no bugs. Cada una tiene un
comentario `shortcut:` en el código donde aplica:

- **No hay UI de autoservicio** para crear/editar logins de `app_usuario`;
  se gestionan con el script `seed_app_usuarios.js` o SQL directo. Un admin
  real necesitaría una pantalla de gestión de usuarios de la app.
- **Sin "mis ventas"** para el vendedor (solo ve el recibo de la venta que
  acaba de registrar, no un historial propio) — por diseño, porque el rol
  `gs_vendedor` no tiene SELECT sobre `venta`/`detalle_venta` y no quise
  abrir ese GRANT; se resolvió el caso puntual (recibo inmediato) vía
  `SQL SECURITY DEFINER` en `sp_registrar_venta`, no un listado general.
- **Sin reporte "ventas por rango de fechas"** como pantalla propia (las 12
  consultas de `09_consultas.sql` están cubiertas por los reportes
  existentes, pero no se añadió un selector de fechas interactivo).
- **Contraseñas compartidas por rol** en los datos de ejemplo — para un
  despliegue real, cada colaborador necesita su propio login desde el día 1.
- **Token CSRF no rotado por formulario** (uno por sesión, no uno de un solo
  uso) — suficiente contra CSRF cross-site, no contra replay dentro de la
  misma sesión.
- **8 líneas de producto fijas** en el formulario de venta/compra
  (`NUM_LINEAS = 8`), en vez de filas dinámicas con JavaScript.
- **Sin paginación** en listados (ventas, compras, bitácora limitan a
  150–200 filas con `LIMIT`); para un catálogo con miles de ventas haría
  falta paginar.
- **Sin HTTPS/proxy inverso** configurado — `cookie.secure` ya está listo
  para producción (`NODE_ENV=production`), pero falta el reverse proxy
  (nginx/Caddy) con TLS real, que está fuera del alcance de este backend.

## 8. Diferencias respecto al diseño original

Solo dos cambios al esquema de base de datos, ambos aditivos (no se tocó
ninguna tabla, vista, procedimiento, trigger ni GRANT existente):

1. Tabla `app_usuario` (login de la aplicación, `10_app_usuarios.sql`).
2. Una sentencia `SELECT` añadida al final de `sp_registrar_venta` (después
   del `COMMIT`) para devolver el recibo de la venta recién creada —
   funciona sin GRANT adicional porque el procedimiento ya es
   `SQL SECURITY DEFINER` (el valor por defecto en MySQL).

`08_validation.sql` se actualizó únicamente en los conteos esperados de
tablas (14→15) y llaves foráneas (15→16) para reflejar la tabla nueva; las
45 reglas de negocio originales no cambiaron y siguen pasando.
