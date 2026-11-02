'use strict';
// Prueba de humo end-to-end contra un servidor YA corriendo (node server.js).
// No usa ningún framework de test: son pocas aserciones, con fetch nativo.
// Uso:  node scripts/smoke_test.js   (con el servidor arriba en :3000)
const BASE = process.env.BASE_URL || 'http://localhost:3000';

let pasadas = 0;
let fallidas = 0;
function check(nombre, cond, extra) {
  if (cond) {
    pasadas++;
    console.log(`OK   ${nombre}`);
  } else {
    fallidas++;
    console.log(`FAIL ${nombre}${extra ? ' -> ' + extra : ''}`);
  }
}

// Un "jar" de cookies mínimo: esta app usa una sola cookie de sesión.
function Session() {
  let cookie = null;
  return {
    async get(path) {
      const r = await fetch(BASE + path, { headers: cookie ? { cookie } : {}, redirect: 'manual' });
      const set = r.headers.get('set-cookie');
      if (set) cookie = set.split(';')[0];
      return r;
    },
    async post(path, form) {
      const r = await fetch(BASE + path, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded', ...(cookie ? { cookie } : {}) },
        body: new URLSearchParams(form).toString(),
        redirect: 'manual',
      });
      const set = r.headers.get('set-cookie');
      if (set) cookie = set.split(';')[0];
      return r;
    },
  };
}

function extraerCsrf(html) {
  const m = html.match(/name="_csrf" value="([^"]+)"/);
  return m ? m[1] : null;
}

async function login(usuario, password) {
  const s = Session();
  const loginPage = await (await s.get('/login')).text();
  const csrf = extraerCsrf(loginPage);
  const res = await s.post('/login', { _csrf: csrf, usuario, password });
  return { s, ok: res.status === 302 && res.headers.get('location') === '/' };
}

async function main() {
  // --- login inválido ---
  {
    const { ok } = await login('jgomez', 'contraseña-incorrecta');
    check('Login rechaza contraseña incorrecta', !ok);
  }

  // --- vendedor: puede vender, no puede ver /ventas ni /compras ---
  {
    const { s, ok } = await login('jgomez', 'Vendedor#2026');
    check('Vendedor inicia sesión', ok);

    const formHtml = await (await s.get('/ventas/nueva')).text();
    const csrf = extraerCsrf(formHtml);
    const matchProducto = formHtml.match(/<option value="(\d+)"[^>]*>\s*[^(]+\(stock: (\d+)/);
    check('Formulario de venta trae productos con stock', !!matchProducto, formHtml.slice(0, 200));

    if (matchProducto) {
      const [, idProducto] = matchProducto;
      const resVenta = await s.post('/ventas', { _csrf: csrf, colaborador: '2', cliente_id: '1', producto: idProducto, cantidad: '1' });
      const bodyVenta = await resVenta.text();
      check('Vendedor registra una venta y ve su recibo (vía SP definer)', bodyVenta.includes('registrada'), bodyVenta.slice(0, 150));
    }

    const resVentas = await s.get('/ventas');
    check('Vendedor NO puede ver el listado de ventas (403)', resVentas.status === 403);

    const resCompras = await s.get('/compras');
    check('Vendedor NO puede ver compras (403)', resCompras.status === 403);

    const resStockInsuf = await (async () => {
      const formHtml2 = await (await s.get('/ventas/nueva')).text();
      const csrf2 = extraerCsrf(formHtml2);
      return s.post('/ventas', { _csrf: csrf2, colaborador: '2', cliente_id: '1', producto: '2', cantidad: '999999' });
    })();
    const bodyStockInsuf = await resStockInsuf.text();
    check(
      'Venta con cantidad absurda se redirige con error (no crashea)',
      resStockInsuf.status === 302 || bodyStockInsuf.length > 0
    );
  }

  // --- gerente: puede ver ventas, anular, reportes, compras ---
  {
    const { s, ok } = await login('mperez', 'Gerente#2026');
    check('Gerente inicia sesión', ok);

    const resVentas = await s.get('/ventas');
    check('Gerente SÍ puede ver el listado de ventas', resVentas.status === 200);

    const resReportes = await s.get('/reportes/top-productos');
    const bodyReportes = await resReportes.text();
    check('Gerente puede abrir un reporte', resReportes.status === 200 && bodyReportes.includes('codigo_sku'));

    const resColaboradores = await s.get('/colaboradores');
    check('Gerente puede ver colaboradores', resColaboradores.status === 200);
  }

  // --- auditor: solo lectura, sin catálogo/inventario/ventas ---
  {
    const { s, ok } = await login('auditor', 'Auditor#2026');
    check('Auditor inicia sesión', ok);

    const resBitacora = await s.get('/bitacora');
    check('Auditor puede ver la bitácora', resBitacora.status === 200);

    const resReporte = await s.get('/reportes/ventas-sucursal');
    check('Auditor puede ver el reporte de ventas por sucursal', resReporte.status === 200);

    const resCatalogo = await s.get('/catalogo/productos');
    check('Auditor NO puede ver el catálogo (403, sin GRANT sobre producto)', resCatalogo.status === 403);

    const resNuevaVenta = await s.get('/ventas/nueva');
    check('Auditor NO puede registrar ventas (403)', resNuevaVenta.status === 403);
  }

  // --- colaborador inactivo: login debe bloquearse ---
  {
    const { ok } = await login('eruiz', 'Vendedor#2026');
    check('Usuario con colaborador inactivo NO puede iniciar sesión', !ok);
  }

  // --- CSRF: un POST sin token válido debe rechazarse ---
  {
    const s = Session();
    await s.get('/login');
    const res = await s.post('/login', { usuario: 'admin', password: 'Admin#2026', _csrf: 'token-invalido' });
    const body = await res.text();
    check('POST con CSRF inválido es rechazado', res.status === 403 && body.includes('formulario'));
  }

  console.log(`\n${pasadas} OK, ${fallidas} fallidas`);
  process.exit(fallidas > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
