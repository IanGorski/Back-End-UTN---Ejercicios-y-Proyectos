-- =============================================================================
-- 02. CONSULTAS INTERMEDIAS - Versión Adaptada al Esquema Real
-- =============================================================================
-- Descripción: Análisis avanzado con CTEs, subqueries y joins complejos
-- Base de Datos: PostgreSQL 14+
-- Autor: Ian Gorski
-- Última actualización: Octubre 2025
-- =============================================================================

SET timezone = 'America/Argentina/Buenos_Aires';

-- -----------------------------------------------------------------------------
-- 1. ANÁLISIS DE TENDENCIAS DE VENTAS CON CTEs
-- -----------------------------------------------------------------------------
-- Objetivo: Calcular crecimiento acumulado y proyecciones

WITH ventas_mensuales AS (
    SELECT 
        DATE_TRUNC('month', v.fecha_venta)::date AS mes,
        COUNT(DISTINCT v.id) AS num_ventas,
        SUM(v.cantidad) AS unidades_vendidas,
        COUNT(DISTINCT v.empleado_id) AS empleados_activos,
        ROUND(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100))::numeric, 2) AS ingresos,
        ROUND(AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100))::numeric, 2) AS ticket_promedio
    FROM ventas v
    GROUP BY DATE_TRUNC('month', v.fecha_venta)
)
SELECT 
    TO_CHAR(mes, 'YYYY-MM') AS periodo,
    TO_CHAR(mes, 'TMMonth YYYY') AS mes_nombre,
    num_ventas AS ventas,
    unidades_vendidas AS unidades,
    empleados_activos,
    TO_CHAR(ingresos, 'L999,999,999.99') AS ingresos,
    TO_CHAR(ticket_promedio, 'L999,999.99') AS ticket_avg,
    -- Crecimiento vs mes anterior
    ROUND(
        (ingresos - LAG(ingresos) OVER (ORDER BY mes)) /
        NULLIF(LAG(ingresos) OVER (ORDER BY mes), 0) * 100, 2
    ) AS crecimiento_pct,
    -- Acumulado del año
    TO_CHAR(
        SUM(ingresos) OVER (
            PARTITION BY EXTRACT(YEAR FROM mes) 
            ORDER BY mes
        ), 'L999,999,999.99'
    ) AS acumulado_anual,
    -- Media móvil 3 meses
    ROUND(
        AVG(ingresos) OVER (
            ORDER BY mes 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )::numeric, 2
    ) AS media_movil_3m,
    -- Comparación con mismo mes año anterior
    ROUND(
        (ingresos - LAG(ingresos, 12) OVER (ORDER BY mes)) /
        NULLIF(LAG(ingresos, 12) OVER (ORDER BY mes), 0) * 100, 2
    ) AS vs_ano_anterior_pct
FROM ventas_mensuales
ORDER BY mes DESC
LIMIT 24;

-- -----------------------------------------------------------------------------
-- 2. ANÁLISIS DE PRODUCTOS MÁS VENDIDOS POR CATEGORÍA
-- -----------------------------------------------------------------------------
-- Objetivo: Identificar top productos en cada categoría

WITH ranking_productos AS (
    SELECT 
        p.categoria,
        p.nombre AS producto,
        COUNT(v.id) AS total_ventas,
        SUM(v.cantidad) AS unidades_vendidas,
        ROUND(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100))::numeric, 2) AS ingresos_totales,
        ROUND(AVG(v.precio_unitario)::numeric, 2) AS precio_promedio,
        RANK() OVER (PARTITION BY p.categoria ORDER BY SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) DESC) AS ranking
    FROM 
        productos p
        INNER JOIN ventas v ON p.id = v.producto_id
    WHERE 
        v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months'
        AND p.activo = TRUE
    GROUP BY 
        p.categoria, p.id, p.nombre
)
SELECT 
    categoria,
    producto,
    total_ventas,
    unidades_vendidas,
    TO_CHAR(ingresos_totales, 'L999,999,999.99') AS ingresos,
    TO_CHAR(precio_promedio, 'L999,999.99') AS precio_avg,
    ranking,
    CASE 
        WHEN ranking = 1 THEN '🥇 Top 1'
        WHEN ranking = 2 THEN '🥈 Top 2'
        WHEN ranking = 3 THEN '🥉 Top 3'
        ELSE '⭐ Top ' || ranking
    END AS medalla
FROM ranking_productos
WHERE ranking <= 5
ORDER BY categoria, ranking;

-- -----------------------------------------------------------------------------
-- 3. ANÁLISIS DE CLIENTES: RFM (Recency, Frequency, Monetary)
-- -----------------------------------------------------------------------------
-- Objetivo: Segmentar clientes según comportamiento de compra

WITH metricas_cliente AS (
    SELECT 
        c.id,
        c.nombre,
        c.email,
        c.ciudad,
        -- Recency: días desde última compra
        CURRENT_DATE - MAX(p.fecha_pedido) AS dias_ultima_compra,
        -- Frequency: número de pedidos
        COUNT(DISTINCT p.id) AS total_pedidos,
        -- Monetary: valor total de compras
        COALESCE(SUM(p.total), 0) AS valor_total
    FROM 
        clientes c
        LEFT JOIN pedidos p ON c.id = p.cliente_id
    WHERE 
        c.activo = TRUE
    GROUP BY 
        c.id, c.nombre, c.email, c.ciudad
    HAVING 
        COUNT(DISTINCT p.id) > 0
),
rfm_scores AS (
    SELECT 
        *,
        -- Calcular quintiles para cada métrica (1=peor, 5=mejor)
        NTILE(5) OVER (ORDER BY dias_ultima_compra DESC) AS r_score,  -- Menos días = mejor
        NTILE(5) OVER (ORDER BY total_pedidos) AS f_score,
        NTILE(5) OVER (ORDER BY valor_total) AS m_score
    FROM metricas_cliente
)
SELECT 
    nombre,
    email,
    ciudad,
    dias_ultima_compra,
    total_pedidos,
    TO_CHAR(valor_total, 'L999,999,999.99') AS valor_total,
    r_score || '-' || f_score || '-' || m_score AS rfm_score,
    -- Segmentación basada en RFM
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '💎 Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 4 THEN '🏆 Leales'
        WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 3 THEN '🎯 Potenciales'
        WHEN r_score <= 2 AND f_score >= 3 THEN '⚠️ En riesgo'
        WHEN r_score <= 2 AND f_score <= 2 THEN '😴 Hibernando'
        WHEN r_score >= 4 AND f_score <= 2 THEN '🆕 Nuevos'
        ELSE '📊 Promedio'
    END AS segmento
FROM rfm_scores
ORDER BY r_score DESC, f_score DESC, m_score DESC
LIMIT 50;

-- -----------------------------------------------------------------------------
-- 4. ANÁLISIS DE EMPLEADOS: PERFORMANCE COMPARATIVO
-- -----------------------------------------------------------------------------
-- Objetivo: Comparar empleados dentro de su departamento

WITH performance_empleados AS (
    SELECT 
        e.id,
        e.nombre || ' ' || e.apellido AS empleado,
        e.cargo,
        d.nombre AS departamento,
        e.salario,
        COUNT(DISTINCT v.id) AS total_ventas,
        COALESCE(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)), 0) AS ingresos_generados,
        COUNT(DISTINCT p.cliente_id) AS clientes_atendidos
    FROM 
        empleados e
        INNER JOIN departamentos d ON e.departamento_id = d.id
        LEFT JOIN ventas v ON e.id = v.empleado_id 
            AND v.fecha_venta >= CURRENT_DATE - INTERVAL '6 months'
        LEFT JOIN pedidos p ON e.id = p.empleado_id
            AND p.fecha_pedido >= CURRENT_DATE - INTERVAL '6 months'
    WHERE 
        e.activo = TRUE
    GROUP BY 
        e.id, e.nombre, e.apellido, e.cargo, d.nombre, e.salario, d.id
)
SELECT 
    empleado,
    cargo,
    departamento,
    TO_CHAR(salario, 'L999,999,999.99') AS salario,
    total_ventas,
    TO_CHAR(ingresos_generados, 'L999,999,999.99') AS ingresos,
    clientes_atendidos,
    -- Ranking dentro del departamento
    RANK() OVER (PARTITION BY departamento ORDER BY ingresos_generados DESC) AS rank_depto,
    -- Comparación con promedio del departamento
    ROUND(
        (ingresos_generados / NULLIF(AVG(ingresos_generados) OVER (PARTITION BY departamento), 0) - 1) * 100, 2
    ) AS vs_promedio_depto_pct,
    -- ROI del empleado
    ROUND((ingresos_generados / NULLIF(salario * 6, 0))::numeric, 2) AS roi_6_meses,
    -- Categoría de desempeño
    CASE 
        WHEN ingresos_generados >= AVG(ingresos_generados) OVER (PARTITION BY departamento) * 1.5 THEN '⭐⭐⭐ Excelente'
        WHEN ingresos_generados >= AVG(ingresos_generados) OVER (PARTITION BY departamento) THEN '⭐⭐ Bueno'
        WHEN ingresos_generados >= AVG(ingresos_generados) OVER (PARTITION BY departamento) * 0.5 THEN '⭐ Regular'
        ELSE '⚠️ Bajo'
    END AS categoria
FROM performance_empleados
ORDER BY departamento, rank_depto;

-- -----------------------------------------------------------------------------
-- 5. ANÁLISIS DE VENTAS: PRODUCTOS COMPLEMENTARIOS
-- -----------------------------------------------------------------------------
-- Objetivo: Identificar productos que se venden juntos

WITH ventas_por_dia AS (
    SELECT 
        v1.producto_id AS producto_1,
        v2.producto_id AS producto_2,
        COUNT(DISTINCT v1.fecha_venta) AS veces_juntos
    FROM 
        ventas v1
        INNER JOIN ventas v2 ON v1.fecha_venta = v2.fecha_venta 
            AND v1.empleado_id = v2.empleado_id
            AND v1.producto_id < v2.producto_id  -- Evitar duplicados
    WHERE 
        v1.fecha_venta >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY 
        v1.producto_id, v2.producto_id
    HAVING 
        COUNT(DISTINCT v1.fecha_venta) >= 3  -- Al menos 3 veces juntos
)
SELECT 
    p1.nombre AS producto_principal,
    p1.categoria AS cat_principal,
    p2.nombre AS producto_complementario,
    p2.categoria AS cat_complementaria,
    vpd.veces_juntos,
    TO_CHAR(p1.precio, 'L999,999.99') AS precio_1,
    TO_CHAR(p2.precio, 'L999,999.99') AS precio_2,
    TO_CHAR(p1.precio + p2.precio, 'L999,999.99') AS precio_combo,
    CASE 
        WHEN vpd.veces_juntos >= 10 THEN '🔥 Alta frecuencia'
        WHEN vpd.veces_juntos >= 5 THEN '📊 Media frecuencia'
        ELSE '💡 Baja frecuencia'
    END AS nivel_asociacion
FROM 
    ventas_por_dia vpd
    INNER JOIN productos p1 ON vpd.producto_1 = p1.id
    INNER JOIN productos p2 ON vpd.producto_2 = p2.id
ORDER BY 
    vpd.veces_juntos DESC
LIMIT 30;

-- -----------------------------------------------------------------------------
-- 6. ANÁLISIS DE INVENTARIO: PRODUCTOS CON BAJO STOCK
-- -----------------------------------------------------------------------------
-- Objetivo: Identificar productos que necesitan reabastecimiento urgente

WITH analisis_stock AS (
    SELECT 
        p.id,
        p.nombre,
        p.categoria,
        p.precio,
        p.stock,
        p.stock_minimo,
        -- Ventas últimos 30 días
        COALESCE(SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '30 days' 
                     THEN v.cantidad ELSE 0 END), 0) AS ventas_30d,
        -- Ventas últimos 90 días
        COALESCE(SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '90 days' 
                     THEN v.cantidad ELSE 0 END), 0) AS ventas_90d,
        -- Velocidad de venta (unidades/día)
        COALESCE(SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '30 days' 
                     THEN v.cantidad ELSE 0 END) / 30.0, 0) AS velocidad_venta
    FROM 
        productos p
        LEFT JOIN ventas v ON p.id = v.producto_id
    WHERE 
        p.activo = TRUE
    GROUP BY 
        p.id, p.nombre, p.categoria, p.precio, p.stock, p.stock_minimo
)
SELECT 
    nombre,
    categoria,
    TO_CHAR(precio, 'L999,999.99') AS precio,
    stock AS stock_actual,
    stock_minimo,
    ventas_30d,
    ventas_90d,
    ROUND(velocidad_venta::numeric, 2) AS unidades_por_dia,
    -- Días de stock restante
    CASE 
        WHEN velocidad_venta > 0 THEN ROUND((stock / velocidad_venta)::numeric, 1)
        ELSE NULL
    END AS dias_stock_restante,
    -- Cantidad recomendada a pedir
    CASE 
        WHEN velocidad_venta > 0 THEN 
            GREATEST(0, ROUND((velocidad_venta * 30) - stock)::int)  -- Stock para 30 días
        ELSE stock_minimo - stock
    END AS cantidad_a_pedir,
    -- Prioridad de reabastecimiento
    CASE 
        WHEN stock <= stock_minimo * 0.5 THEN '🔴 URGENTE'
        WHEN stock <= stock_minimo THEN '🟠 Alta'
        WHEN stock <= stock_minimo * 1.5 THEN '🟡 Media'
        WHEN stock >= stock_minimo * 5 THEN '🟢 Exceso'
        ELSE '⚪ Normal'
    END AS prioridad
FROM analisis_stock
WHERE 
    stock <= stock_minimo * 2  -- Solo productos con stock bajo o crítico
ORDER BY 
    CASE 
        WHEN stock <= stock_minimo * 0.5 THEN 1
        WHEN stock <= stock_minimo THEN 2
        ELSE 3
    END,
    velocidad_venta DESC;

-- -----------------------------------------------------------------------------
-- 7. ANÁLISIS DE PEDIDOS: ESTADOS Y TIEMPOS DE ENTREGA
-- -----------------------------------------------------------------------------
-- Objetivo: Analizar eficiencia en procesamiento de pedidos

WITH metricas_pedidos AS (
    SELECT 
        p.id,
        p.cliente_id,
        c.nombre AS cliente,
        p.empleado_id,
        e.nombre || ' ' || e.apellido AS empleado,
        p.fecha_pedido,
        p.fecha_entrega,
        p.estado,
        p.total,
        -- Calcular días de procesamiento
        CASE 
            WHEN p.fecha_entrega IS NOT NULL 
            THEN p.fecha_entrega - p.fecha_pedido
            ELSE NULL
        END AS dias_procesamiento
    FROM 
        pedidos p
        INNER JOIN clientes c ON p.cliente_id = c.id
        INNER JOIN empleados e ON p.empleado_id = e.id
    WHERE 
        p.fecha_pedido >= CURRENT_DATE - INTERVAL '6 months'
)
SELECT 
    estado,
    COUNT(*) AS total_pedidos,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ())::numeric, 2) AS porcentaje,
    TO_CHAR(SUM(total), 'L999,999,999.99') AS valor_total,
    TO_CHAR(AVG(total), 'L999,999.99') AS valor_promedio,
    -- Tiempo de procesamiento promedio
    ROUND(AVG(dias_procesamiento)::numeric, 1) AS dias_promedio_entrega,
    MIN(dias_procesamiento) AS dias_min_entrega,
    MAX(dias_procesamiento) AS dias_max_entrega,
    -- Pedidos por estado
    CASE 
        WHEN estado = 'completado' THEN '✅'
        WHEN estado = 'procesando' THEN '⏳'
        WHEN estado = 'pendiente' THEN '📋'
        WHEN estado = 'cancelado' THEN '❌'
        ELSE '❓'
    END AS icono
FROM metricas_pedidos
GROUP BY estado
ORDER BY total_pedidos DESC;

-- -----------------------------------------------------------------------------
-- RESUMEN EJECUTIVO
-- -----------------------------------------------------------------------------

SELECT 
    '📊 RESUMEN DEL NEGOCIO - ÚLTIMOS 6 MESES' AS titulo,
    '' AS valor;

SELECT 
    'Total Ventas' AS metrica,
    TO_CHAR(COUNT(DISTINCT v.id), '999,999') AS valor
FROM ventas v
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '6 months'

UNION ALL

SELECT 
    'Ingresos Totales',
    TO_CHAR(SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)), 'L999,999,999.99')
FROM ventas v
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '6 months'

UNION ALL

SELECT 
    'Ticket Promedio',
    TO_CHAR(AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)), 'L999,999.99')
FROM ventas v
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '6 months'

UNION ALL

SELECT 
    'Clientes Activos',
    TO_CHAR(COUNT(DISTINCT p.cliente_id), '999,999')
FROM pedidos p
WHERE p.fecha_pedido >= CURRENT_DATE - INTERVAL '6 months'

UNION ALL

SELECT 
    'Productos Vendidos',
    TO_CHAR(COUNT(DISTINCT v.producto_id), '999,999')
FROM ventas v
WHERE v.fecha_venta >= CURRENT_DATE - INTERVAL '6 months'

UNION ALL

SELECT 
    'Empleados Activos',
    TO_CHAR(COUNT(DISTINCT e.id), '999,999')
FROM empleados e
WHERE e.activo = TRUE;

-- =============================================================================
-- FIN DEL SCRIPT - Consultas Intermedias Adaptadas
-- =============================================================================
