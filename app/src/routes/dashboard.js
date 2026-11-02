'use strict';
// Panel principal. Las cifras varían por rol porque respetan exactamente
// los mismos GRANTs de sql/06_security.sql que ya usa el resto de la app
// (vendedor no tiene SELECT sobre venta/cliente, por ejemplo) — ningún
// dato aquí se inventa; lo que un rol no puede leer, simplemente no se le
// muestra.
const express = require('express');
const router = express.Router();

router.get('/', async (req, res) => {
  const { user } = req.session;
  const data = { title: 'Panel', stats: null, charts: null, actividad: null };

  if (user.rol === 'vendedor') {
    const [[row]] = await req.db.query(
      `SELECT COUNT(*) AS productos, SUM(stock_disponible < 5) AS stockBajo
       FROM v_inventario_sucursal WHERE idSucursal = ?`,
      [user.fk_Sucursal]
    );
    data.stats = { vendedor: { productos: Number(row.productos) || 0, stockBajo: Number(row.stockBajo) || 0 } };
  } else if (user.rol === 'gerente' || user.rol === 'admin') {
    const [[hoy]] = await req.db.query(
      `SELECT COUNT(*) AS num, COALESCE(SUM(total_venta), 0) AS total
       FROM venta WHERE estado_venta = 'COMPLETADA' AND DATE(fecha_venta) = CURDATE()`
    );
    const [[mes]] = await req.db.query(
      `SELECT COALESCE(SUM(total_venta), 0) AS total FROM venta
       WHERE estado_venta = 'COMPLETADA' AND YEAR(fecha_venta) = YEAR(CURDATE()) AND MONTH(fecha_venta) = MONTH(CURDATE())`
    );
    const [[stockBajo]] = await req.db.query('SELECT COUNT(*) AS n FROM v_inventario_sucursal WHERE stock_disponible < 5');
    const [[clientes]] = await req.db.query('SELECT COUNT(*) AS n FROM cliente');
    data.stats = {
      gestion: {
        ventasHoy: hoy.num,
        totalHoy: Number(hoy.total),
        totalMes: Number(mes.total),
        stockBajo: stockBajo.n,
        clientes: clientes.n,
      },
    };
    data.charts = await cargarGraficos(req.db);
    const [actividad] = await req.db.query('SELECT fecha, usuario_db, tabla, operacion FROM bitacora ORDER BY fecha DESC LIMIT 6');
    data.actividad = actividad;
  } else if (user.rol === 'auditor') {
    const [[resumen]] = await req.db.query(
      'SELECT COUNT(DISTINCT idVenta) AS numVentas, COALESCE(SUM(subtotal_venta), 0) AS total FROM v_venta_detalle'
    );
    data.stats = { auditor: { numVentas: resumen.numVentas, total: Number(resumen.total) } };
    data.charts = await cargarGraficos(req.db);
    const [actividad] = await req.db.query('SELECT fecha, usuario_db, tabla, operacion FROM bitacora ORDER BY fecha DESC LIMIT 6');
    data.actividad = actividad;
  }

  res.render('dashboard', data);
});

// Facturación mensual y top-5 productos: las mismas dos consultas que ya
// expone /reportes (sobre v_venta_detalle, con GRANT para gerente/admin/
// auditor), reutilizadas aquí para los gráficos del panel.
async function cargarGraficos(db) {
  const [facturacionDesc] = await db.query(
    `SELECT DATE_FORMAT(fecha_venta, '%Y-%m') AS mes, SUM(subtotal_venta) AS total
     FROM v_venta_detalle GROUP BY mes ORDER BY mes DESC LIMIT 6`
  );
  const [topProductos] = await db.query(
    `SELECT nombre_producto, SUM(cantidad) AS unidades FROM v_venta_detalle
     GROUP BY nombre_producto ORDER BY unidades DESC LIMIT 5`
  );
  return { facturacion: facturacionDesc.reverse(), topProductos };
}

module.exports = router;
