-- ================================================================
-- 01 - CONSULTAS BÁSICAS EN POSTGRESQL
-- ================================================================
-- Proyecto: PostgreSQL Business Analytics Suite
-- Propósito: Demostrar fundamentos sólidos de SQL
-- Nivel: Básico
-- Esquema: productos, clientes, empleados, departamentos, ventas, pedidos
-- ================================================================

-- ================================================================
-- SECCIÓN 1: CONSULTAS SIMPLES (SELECT, WHERE, ORDER BY)
-- ================================================================

-- 1.1 Obtener todos los productos activos
-- Muestra el catálogo completo de productos ordenados por categoría
SELECT 
    id,
    nombre,
    categoria,
    precio,
    stock,
    stock_minimo
FROM productos
WHERE activo = TRUE
ORDER BY categoria, nombre;

-- 1.2 Productos con bajo stock (alerta de inventario)
-- Identifica productos que necesitan reabastecimiento
SELECT 
    id,
    nombre,
    categoria,
    stock,
    stock_minimo,
    (stock_minimo - stock) AS unidades_faltantes
FROM productos
WHERE stock < stock_minimo
  AND activo = TRUE
ORDER BY (stock_minimo - stock) DESC;

-- 1.3 Productos premium (precio alto)
-- Análisis de productos de alta gama
SELECT 
    id,
    nombre,
    categoria,
    precio,
    ROUND(precio * 1.21, 2) AS precio_con_iva
FROM productos
WHERE precio > 500
  AND activo = TRUE
ORDER BY precio DESC;

-- 1.4 Buscar clientes por nombre
-- Sistema de búsqueda de clientes
SELECT 
    id,
    nombre,
    email,
    ciudad,
    fecha_registro
FROM clientes
WHERE nombre ILIKE '%Garcia%'  -- Búsqueda case-insensitive
  AND activo = TRUE
ORDER BY fecha_registro DESC;

-- ================================================================
-- SECCIÓN 2: FILTROS AVANZADOS (AND, OR, IN, BETWEEN)
-- ================================================================

-- 2.1 Pedidos de un rango de fechas específico
-- Análisis de ventas del último trimestre
SELECT 
    id,
    cliente_id,
    fecha_pedido,
    total,
    estado
FROM pedidos
WHERE fecha_pedido BETWEEN '2024-10-01' AND '2024-12-31'
  AND estado IN ('completado', 'procesando')
ORDER BY fecha_pedido DESC;

-- 2.2 Productos en categorías específicas con stock disponible
-- Inventario disponible para categorías populares
SELECT 
    id,
    nombre,
    categoria,
    precio,
    stock
FROM productos
WHERE categoria IN ('Electrónica', 'Ropa', 'Hogar')
  AND stock > 0
  AND precio BETWEEN 100 AND 1000
  AND activo = TRUE
ORDER BY categoria, precio;

-- 2.3 Clientes activos de ciudades principales
-- Segmentación geográfica de clientes
SELECT 
    id,
    nombre,
    email,
    ciudad,
    fecha_registro
FROM clientes
WHERE ciudad IN ('Madrid', 'Barcelona', 'Valencia', 'Sevilla')
  AND fecha_registro >= CURRENT_DATE - INTERVAL '6 months'
  AND activo = TRUE
ORDER BY ciudad, fecha_registro DESC;

-- ================================================================
-- SECCIÓN 3: FUNCIONES DE AGREGACIÓN (COUNT, SUM, AVG, MIN, MAX)
-- ================================================================

-- 3.1 Estadísticas generales de productos
-- Resumen del catálogo de productos
SELECT 
    COUNT(*) AS total_productos,
    COUNT(DISTINCT categoria) AS total_categorias,
    ROUND(AVG(precio), 2) AS precio_promedio,
    MIN(precio) AS precio_minimo,
    MAX(precio) AS precio_maximo,
    SUM(stock) AS inventario_total
FROM productos
WHERE activo = TRUE;

-- 3.2 Total de ventas por empleado
-- Análisis de desempeño de ventas
SELECT 
    empleado_id,
    COUNT(*) AS total_ventas,
    SUM(cantidad) AS unidades_vendidas,
    SUM(cantidad * precio_unitario * (1 - descuento/100)) AS monto_total,
    ROUND(AVG(cantidad * precio_unitario * (1 - descuento/100)), 2) AS venta_promedio
FROM ventas
WHERE fecha_venta >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY empleado_id
ORDER BY monto_total DESC;

-- 3.3 Productos más caros por categoría
-- Identificar productos premium en cada categoría
SELECT 
    categoria,
    COUNT(*) AS cantidad_productos,
    ROUND(AVG(precio), 2) AS precio_promedio,
    MAX(precio) AS precio_maximo,
    MIN(precio) AS precio_minimo
FROM productos
WHERE activo = TRUE
GROUP BY categoria
ORDER BY precio_promedio DESC;

-- ================================================================
-- SECCIÓN 4: GROUP BY Y HAVING
-- ================================================================

-- 4.1 Categorías con más de 5 productos
-- Análisis de diversidad de catálogo
SELECT 
    categoria,
    COUNT(*) AS cantidad_productos,
    ROUND(AVG(precio), 2) AS precio_promedio,
    SUM(stock) AS stock_total
FROM productos
WHERE activo = TRUE
GROUP BY categoria
HAVING COUNT(*) >= 5
ORDER BY cantidad_productos DESC;

-- 4.2 Clientes con compras superiores a $1000
-- Identificar clientes VIP
SELECT 
    c.id,
    c.nombre,
    COUNT(p.id) AS total_pedidos,
    SUM(p.total) AS monto_total_comprado,
    ROUND(AVG(p.total), 2) AS ticket_promedio
FROM clientes c
INNER JOIN pedidos p ON c.id = p.cliente_id
WHERE p.estado = 'completado'
GROUP BY c.id, c.nombre
HAVING SUM(p.total) > 1000
ORDER BY monto_total_comprado DESC;

-- 4.3 Productos vendidos más de 10 veces
-- Análisis de productos populares
SELECT 
    pr.id,
    pr.nombre,
    pr.categoria,
    COUNT(v.id) AS veces_vendido,
    SUM(v.cantidad) AS unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) AS ingresos_totales
FROM productos pr
INNER JOIN ventas v ON pr.id = v.producto_id
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY pr.id, pr.nombre, pr.categoria
HAVING COUNT(v.id) >= 10
ORDER BY unidades_vendidas DESC;

-- ================================================================
-- SECCIÓN 5: ORDENAMIENTO Y LIMITACIÓN (ORDER BY, LIMIT)
-- ================================================================

-- 5.1 Top 10 productos más caros
-- Catálogo premium
SELECT 
    id,
    nombre,
    categoria,
    precio,
    stock
FROM productos
WHERE activo = TRUE
ORDER BY precio DESC
LIMIT 10;

-- 5.2 Últimos 20 pedidos realizados
-- Actividad reciente de ventas
SELECT 
    id,
    cliente_id,
    empleado_id,
    fecha_pedido,
    total,
    estado
FROM pedidos
ORDER BY fecha_pedido DESC
LIMIT 20;

-- 5.3 Top 5 empleados con más ventas
-- Empleados más productivos
SELECT 
    e.id,
    e.nombre,
    e.apellido,
    COUNT(v.id) AS total_ventas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) AS monto_total
FROM empleados e
INNER JOIN ventas v ON e.id = v.empleado_id
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY e.id, e.nombre, e.apellido
ORDER BY monto_total DESC
LIMIT 5;

-- ================================================================
-- SECCIÓN 6: JOINS BÁSICOS (INNER JOIN)
-- ================================================================

-- 6.1 Pedidos con información del cliente
-- Vista completa de transacciones
SELECT 
    p.id AS pedido_id,
    p.fecha_pedido,
    c.nombre AS nombre_cliente,
    c.email,
    c.ciudad,
    p.total,
    p.estado
FROM pedidos p
INNER JOIN clientes c ON p.cliente_id = c.id
ORDER BY p.fecha_pedido DESC
LIMIT 50;

-- 6.2 Ventas con información del empleado y producto
-- Análisis detallado de ventas
SELECT 
    v.id AS venta_id,
    v.fecha_venta,
    e.nombre || ' ' || e.apellido AS empleado,
    pr.nombre AS producto,
    pr.categoria,
    v.cantidad,
    v.precio_unitario,
    v.cantidad * v.precio_unitario * (1 - v.descuento/100) AS subtotal
FROM ventas v
INNER JOIN empleados e ON v.empleado_id = e.id
INNER JOIN productos pr ON v.producto_id = pr.id
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY v.fecha_venta DESC;

-- 6.3 Ventas por categoría de producto
-- Análisis de categorías más rentables
SELECT 
    pr.categoria,
    COUNT(DISTINCT v.id) AS total_ventas,
    SUM(v.cantidad) AS unidades_vendidas,
    SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) AS ingresos_totales,
    ROUND(AVG(v.precio_unitario), 2) AS precio_promedio
FROM productos pr
INNER JOIN ventas v ON pr.id = v.producto_id
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY pr.categoria
ORDER BY ingresos_totales DESC;

-- ================================================================
-- SECCIÓN 7: FUNCIONES DE FECHA Y TEXTO
-- ================================================================

-- 7.1 Pedidos del mes actual
-- Análisis de ventas del mes en curso
SELECT 
    id,
    cliente_id,
    fecha_pedido,
    TO_CHAR(fecha_pedido, 'DD/MM/YYYY') AS fecha_formateada,
    total,
    estado
FROM pedidos
WHERE DATE_TRUNC('month', fecha_pedido) = DATE_TRUNC('month', CURRENT_DATE)
ORDER BY fecha_pedido DESC;

-- 7.2 Clientes registrados por mes
-- Tendencia de adquisición de clientes
SELECT 
    TO_CHAR(fecha_registro, 'YYYY-MM') AS mes,
    COUNT(*) AS nuevos_clientes,
    STRING_AGG(DISTINCT ciudad, ', ') AS ciudades
FROM clientes
WHERE activo = TRUE
GROUP BY TO_CHAR(fecha_registro, 'YYYY-MM')
ORDER BY mes DESC;

-- 7.3 Productos con nombres largos
-- Análisis de catálogo por descripción
SELECT 
    id,
    nombre,
    UPPER(categoria) AS categoria_mayuscula,
    LENGTH(nombre) AS longitud_nombre,
    SUBSTRING(nombre, 1, 20) AS nombre_corto
FROM productos
WHERE LENGTH(nombre) > 15
  AND activo = TRUE
ORDER BY categoria, nombre;

-- ================================================================
-- SECCIÓN 8: CONSULTAS CON SUBCONSULTAS SIMPLES
-- ================================================================

-- 8.1 Productos con precio mayor al promedio
-- Identificar productos por encima del precio promedio
SELECT 
    id,
    nombre,
    categoria,
    precio,
    ROUND(precio - (SELECT AVG(precio) FROM productos WHERE activo = TRUE), 2) AS diferencia_vs_promedio
FROM productos
WHERE precio > (SELECT AVG(precio) FROM productos WHERE activo = TRUE)
  AND activo = TRUE
ORDER BY precio DESC;

-- 8.2 Clientes que gastaron más que el promedio
-- Segmentación de clientes por gasto
SELECT 
    c.id,
    c.nombre,
    c.email,
    SUM(p.total) AS total_gastado,
    COUNT(p.id) AS cantidad_pedidos
FROM clientes c
INNER JOIN pedidos p ON c.id = p.cliente_id
WHERE p.estado = 'completado'
GROUP BY c.id, c.nombre, c.email
HAVING SUM(p.total) > (SELECT AVG(total) FROM pedidos WHERE estado = 'completado')
ORDER BY total_gastado DESC;

-- 8.3 Productos nunca vendidos
-- Identificar productos sin movimiento
SELECT 
    id,
    nombre,
    categoria,
    precio,
    stock
FROM productos
WHERE id NOT IN (
    SELECT DISTINCT producto_id 
    FROM ventas
)
AND activo = TRUE
ORDER BY categoria, nombre;

-- 8.4 Empleados por departamento
-- Vista organizacional
SELECT 
    d.nombre AS departamento,
    COUNT(e.id) AS total_empleados,
    ROUND(AVG(e.salario), 2) AS salario_promedio,
    MIN(e.salario) AS salario_minimo,
    MAX(e.salario) AS salario_maximo
FROM departamentos d
INNER JOIN empleados e ON d.id = e.departamento_id
WHERE e.activo = TRUE
GROUP BY d.nombre
ORDER BY total_empleados DESC;

-- ================================================================
-- FIN DEL ARCHIVO
-- ================================================================
-- Total de consultas: 24 queries básicas
-- Técnicas cubiertas:
--   ✅ SELECT, WHERE, ORDER BY
--   ✅ Filtros avanzados (AND, OR, IN, BETWEEN)
--   ✅ Funciones de agregación (COUNT, SUM, AVG, MIN, MAX)
--   ✅ GROUP BY y HAVING
--   ✅ LIMIT y ordenamiento
--   ✅ INNER JOINs
--   ✅ Funciones de fecha y texto
--   ✅ Subconsultas simples
-- ================================================================
