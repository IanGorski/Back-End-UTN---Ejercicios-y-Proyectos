-- =====================================================
-- QUERY 4: ANÁLISIS ABC DE PRODUCTOS (ADAPTADO PostgreSQL)
-- =====================================================

/*
PROBLEMA:
Clasificar productos usando análisis ABC basado en ingresos generados,
donde A = 80% de ingresos, B = 15% de ingresos, C = 5% de ingresos.
Esta clasificación ayuda a priorizar la gestión de inventario y ventas.

TÉCNICAS UTILIZADAS:
- Window functions con SUM() OVER para acumulados
- CASE statements para clasificación
- Análisis de Pareto (regla 80/20)
- Percentiles y rankings
- Agregaciones complejas

CASOS DE USO:
- Gestión de inventario
- Estrategias de precios
- Análisis de portfolio de productos
- Optimización de recursos de ventas
*/

SET timezone = 'America/Argentina/Buenos_Aires';

WITH ventas_por_producto AS (
    -- PASO 1: Calcular métricas base por producto
    SELECT 
        p.id,
        p.nombre,
        p.categoria,
        p.precio as precio_actual,
        p.stock as stock_actual,
        
        -- Métricas de ventas
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as ingresos_total,
        SUM(v.cantidad) as unidades_vendidas,
        COUNT(v.id) as num_transacciones,
        COUNT(DISTINCT v.empleado_id) as num_vendedores,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as venta_promedio,
        
        -- Análisis temporal (últimos 12 meses)
        SUM(CASE 
            WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months'
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100)
            ELSE 0 
        END) as ingresos_ultimo_trimestre,
        
        SUM(CASE 
            WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months'
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100)
            ELSE 0 
        END) as ingresos_ultimo_año
        
    FROM productos p
    INNER JOIN ventas v ON p.id = v.producto_id
    GROUP BY p.id, p.nombre, p.categoria, p.precio, p.stock
),

productos_con_acumulado AS (
    -- PASO 2: Calcular acumulados y percentiles
    SELECT *,
        -- Total de ingresos de todos los productos
        SUM(ingresos_total) OVER () as ingresos_totales_empresa,
        
        -- Ingresos acumulados (ordenados de mayor a menor)
        SUM(ingresos_total) OVER (
            ORDER BY ingresos_total DESC 
            ROWS UNBOUNDED PRECEDING
        ) as ingresos_acumulados,
        
        -- Ranking por ingresos
        ROW_NUMBER() OVER (ORDER BY ingresos_total DESC) as ranking_ingresos,
        
        -- Ranking por unidades
        ROW_NUMBER() OVER (ORDER BY unidades_vendidas DESC) as ranking_unidades,
        
        -- Percentil de ingresos
        PERCENT_RANK() OVER (ORDER BY ingresos_total) * 100 as percentil_ingresos,
        
        -- Decil (división en 10 grupos)
        NTILE(10) OVER (ORDER BY ingresos_total DESC) as decil_ingresos
        
    FROM ventas_por_producto
),

productos_clasificados AS (
    -- PASO 3: Aplicar clasificación ABC
    SELECT *,
        -- Porcentaje acumulado de ingresos
        ROUND(ingresos_acumulados * 100.0 / ingresos_totales_empresa, 2) as porcentaje_acumulado,
        
        -- Clasificación ABC basada en regla de Pareto
        CASE 
            WHEN ingresos_acumulados * 100.0 / ingresos_totales_empresa <= 80 THEN 'A'
            WHEN ingresos_acumulados * 100.0 / ingresos_totales_empresa <= 95 THEN 'B'
            ELSE 'C'
        END as clasificacion_abc,
        
        -- Clasificación por deciles (más granular)
        CASE 
            WHEN decil_ingresos <= 2 THEN 'A+'
            WHEN decil_ingresos <= 4 THEN 'A'
            WHEN decil_ingresos <= 6 THEN 'B+'
            WHEN decil_ingresos <= 8 THEN 'B'
            ELSE 'C'
        END as clasificacion_abc_extendida,
        
        -- Velocidad de rotación (ventas vs stock)
        CASE 
            WHEN stock_actual > 0 
            THEN unidades_vendidas::NUMERIC / stock_actual 
            ELSE unidades_vendidas 
        END as ratio_rotacion,
        
        -- Tendencia de ventas
        CASE 
            WHEN ingresos_ultimo_trimestre > (ingresos_ultimo_año / 4.0) * 1.2 
            THEN 'Creciente'
            WHEN ingresos_ultimo_trimestre < (ingresos_ultimo_año / 4.0) * 0.8 
            THEN 'Decreciente'
            ELSE 'Estable'
        END as tendencia_ventas
        
    FROM productos_con_acumulado
)

-- RESULTADO PRINCIPAL: Análisis ABC detallado por producto
SELECT 
    ranking_ingresos,
    nombre,
    categoria,
    clasificacion_abc,
    clasificacion_abc_extendida,
    
    -- Métricas financieras
    '$' || ROUND(ingresos_total::NUMERIC, 2) as ingresos_totales,
    '$' || ROUND(precio_actual::NUMERIC, 2) as precio_actual,
    ROUND(porcentaje_acumulado, 2) as porcentaje_acumulado,
    
    -- Métricas de volumen
    unidades_vendidas,
    num_transacciones,
    stock_actual,
    ROUND(ratio_rotacion, 2) as ratio_rotacion,
    
    -- Análisis de rendimiento
    '$' || ROUND(venta_promedio::NUMERIC, 2) as venta_promedio,
    num_vendedores,
    tendencia_ventas,
    
    -- Estrategias recomendadas basadas en clasificación
    CASE 
        WHEN clasificacion_abc = 'A' AND tendencia_ventas = 'Creciente' 
        THEN 'PRIORIDAD MÁXIMA: Asegurar stock, promocionar agresivamente'
        WHEN clasificacion_abc = 'A' AND tendencia_ventas = 'Decreciente' 
        THEN 'ALERTA: Investigar causas de declive, revisar estrategia'
        WHEN clasificacion_abc = 'A' 
        THEN 'MANTENER: Stock alto, seguimiento cercano'
        WHEN clasificacion_abc = 'B' AND ratio_rotacion > 2 
        THEN 'OPORTUNIDAD: Potencial para subir a categoría A'
        WHEN clasificacion_abc = 'B' 
        THEN 'GESTIÓN NORMAL: Stock moderado, monitoreo regular'
        WHEN clasificacion_abc = 'C' AND ratio_rotacion < 0.5 
        THEN 'CONSIDERAR: Descontinuar o liquidar'
        ELSE 'GESTIÓN MÍNIMA: Stock bajo, revisión periódica'
    END as estrategia_recomendada,
    
    -- Impacto potencial si se descontinúa
    ROUND(ingresos_total * 100.0 / ingresos_totales_empresa, 2) as impacto_descontinuacion
    
FROM productos_clasificados
ORDER BY ranking_ingresos;

-- =====================================================
-- RESUMEN EJECUTIVO POR CLASIFICACIÓN ABC
-- =====================================================

WITH ventas_por_producto AS (
    SELECT 
        p.id,
        p.nombre,
        p.categoria,
        p.precio as precio_actual,
        p.stock as stock_actual,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as ingresos_total,
        SUM(v.cantidad) as unidades_vendidas,
        COUNT(v.id) as num_transacciones,
        COUNT(DISTINCT v.empleado_id) as num_vendedores,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as venta_promedio,
        SUM(CASE 
            WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months'
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100)
            ELSE 0 
        END) as ingresos_ultimo_trimestre,
        SUM(CASE 
            WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months'
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100)
            ELSE 0 
        END) as ingresos_ultimo_año
    FROM productos p
    INNER JOIN ventas v ON p.id = v.producto_id
    GROUP BY p.id, p.nombre, p.categoria, p.precio, p.stock
),
productos_con_acumulado AS (
    SELECT *,
        SUM(ingresos_total) OVER () as ingresos_totales_empresa,
        SUM(ingresos_total) OVER (
            ORDER BY ingresos_total DESC 
            ROWS UNBOUNDED PRECEDING
        ) as ingresos_acumulados,
        ROW_NUMBER() OVER (ORDER BY ingresos_total DESC) as ranking_ingresos,
        ROW_NUMBER() OVER (ORDER BY unidades_vendidas DESC) as ranking_unidades,
        PERCENT_RANK() OVER (ORDER BY ingresos_total) * 100 as percentil_ingresos,
        NTILE(10) OVER (ORDER BY ingresos_total DESC) as decil_ingresos
    FROM ventas_por_producto
),
productos_clasificados AS (
    SELECT *,
        ROUND(ingresos_acumulados * 100.0 / ingresos_totales_empresa, 2) as porcentaje_acumulado,
        CASE 
            WHEN ingresos_acumulados * 100.0 / ingresos_totales_empresa <= 80 THEN 'A'
            WHEN ingresos_acumulados * 100.0 / ingresos_totales_empresa <= 95 THEN 'B'
            ELSE 'C'
        END as clasificacion_abc,
        CASE 
            WHEN decil_ingresos <= 2 THEN 'A+'
            WHEN decil_ingresos <= 4 THEN 'A'
            WHEN decil_ingresos <= 6 THEN 'B+'
            WHEN decil_ingresos <= 8 THEN 'B'
            ELSE 'C'
        END as clasificacion_abc_extendida,
        CASE 
            WHEN stock_actual > 0 
            THEN unidades_vendidas::NUMERIC / stock_actual 
            ELSE unidades_vendidas 
        END as ratio_rotacion,
        CASE 
            WHEN ingresos_ultimo_trimestre > (ingresos_ultimo_año / 4.0) * 1.2 
            THEN 'Creciente'
            WHEN ingresos_ultimo_trimestre < (ingresos_ultimo_año / 4.0) * 0.8 
            THEN 'Decreciente'
            ELSE 'Estable'
        END as tendencia_ventas
    FROM productos_con_acumulado
)
SELECT 
    clasificacion_abc,
    COUNT(*) as num_productos,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as porcentaje_productos,
    
    -- Métricas financieras por categoría
    '$' || ROUND(SUM(ingresos_total)::NUMERIC, 2) as ingresos_categoria,
    ROUND(SUM(ingresos_total) * 100.0 / SUM(SUM(ingresos_total)) OVER (), 1) as porcentaje_ingresos,
    
    -- Métricas operativas
    SUM(unidades_vendidas) as unidades_categoria,
    ROUND(AVG(ingresos_total)::NUMERIC, 2) as ingreso_promedio_producto,
    ROUND(SUM(stock_actual * precio_actual)::NUMERIC, 2) as valor_inventario_categoria,
    
    -- Análisis de eficiencia
    ROUND(AVG(ratio_rotacion), 2) as rotacion_promedio,
    COUNT(CASE WHEN tendencia_ventas = 'Creciente' THEN 1 END) as productos_crecimiento,
    COUNT(CASE WHEN tendencia_ventas = 'Decreciente' THEN 1 END) as productos_declive,
    
    -- Recomendaciones estratégicas por categoría
    CASE 
        WHEN clasificacion_abc = 'A' 
        THEN 'Foco principal: máxima atención, recursos prioritarios'
        WHEN clasificacion_abc = 'B' 
        THEN 'Gestión equilibrada: monitoreo regular, oportunidades de mejora'
        ELSE 'Gestión eficiente: minimizar costos, evaluar continuidad'
    END as enfoque_estrategico
    
FROM productos_clasificados
GROUP BY clasificacion_abc
ORDER BY clasificacion_abc;

-- =====================================================
-- ANÁLISIS POR CATEGORÍA DE PRODUCTO
-- =====================================================

WITH ventas_por_producto AS (
    SELECT 
        p.id,
        p.nombre,
        p.categoria,
        p.precio as precio_actual,
        p.stock as stock_actual,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as ingresos_total,
        SUM(v.cantidad) as unidades_vendidas,
        COUNT(v.id) as num_transacciones,
        COUNT(DISTINCT v.empleado_id) as num_vendedores,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as venta_promedio,
        SUM(CASE 
            WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months'
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100)
            ELSE 0 
        END) as ingresos_ultimo_trimestre,
        SUM(CASE 
            WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months'
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100)
            ELSE 0 
        END) as ingresos_ultimo_año
    FROM productos p
    INNER JOIN ventas v ON p.id = v.producto_id
    GROUP BY p.id, p.nombre, p.categoria, p.precio, p.stock
),
productos_con_acumulado AS (
    SELECT *,
        SUM(ingresos_total) OVER () as ingresos_totales_empresa,
        SUM(ingresos_total) OVER (
            ORDER BY ingresos_total DESC 
            ROWS UNBOUNDED PRECEDING
        ) as ingresos_acumulados,
        ROW_NUMBER() OVER (ORDER BY ingresos_total DESC) as ranking_ingresos,
        ROW_NUMBER() OVER (ORDER BY unidades_vendidas DESC) as ranking_unidades,
        PERCENT_RANK() OVER (ORDER BY ingresos_total) * 100 as percentil_ingresos,
        NTILE(10) OVER (ORDER BY ingresos_total DESC) as decil_ingresos
    FROM ventas_por_producto
),
productos_clasificados AS (
    SELECT *,
        ROUND(ingresos_acumulados * 100.0 / ingresos_totales_empresa, 2) as porcentaje_acumulado,
        CASE 
            WHEN ingresos_acumulados * 100.0 / ingresos_totales_empresa <= 80 THEN 'A'
            WHEN ingresos_acumulados * 100.0 / ingresos_totales_empresa <= 95 THEN 'B'
            ELSE 'C'
        END as clasificacion_abc,
        CASE 
            WHEN decil_ingresos <= 2 THEN 'A+'
            WHEN decil_ingresos <= 4 THEN 'A'
            WHEN decil_ingresos <= 6 THEN 'B+'
            WHEN decil_ingresos <= 8 THEN 'B'
            ELSE 'C'
        END as clasificacion_abc_extendida,
        CASE 
            WHEN stock_actual > 0 
            THEN unidades_vendidas::NUMERIC / stock_actual 
            ELSE unidades_vendidas 
        END as ratio_rotacion,
        CASE 
            WHEN ingresos_ultimo_trimestre > (ingresos_ultimo_año / 4.0) * 1.2 
            THEN 'Creciente'
            WHEN ingresos_ultimo_trimestre < (ingresos_ultimo_año / 4.0) * 0.8 
            THEN 'Decreciente'
            ELSE 'Estable'
        END as tendencia_ventas
    FROM productos_con_acumulado
)
SELECT 
    categoria,
    COUNT(*) as total_productos,
    
    -- Distribución ABC por categoría
    COUNT(CASE WHEN clasificacion_abc = 'A' THEN 1 END) as productos_A,
    COUNT(CASE WHEN clasificacion_abc = 'B' THEN 1 END) as productos_B,
    COUNT(CASE WHEN clasificacion_abc = 'C' THEN 1 END) as productos_C,
    
    -- Concentración de valor
    '$' || ROUND(SUM(ingresos_total)::NUMERIC, 2) as ingresos_totales_categoria,
    '$' || ROUND(AVG(ingresos_total)::NUMERIC, 2) as ingreso_promedio,
    
    -- Análisis de portfolio
    ROUND(
        COUNT(CASE WHEN clasificacion_abc = 'A' THEN 1 END) * 100.0 / COUNT(*), 
        1
    ) as porcentaje_productos_alta_performance,
    
    -- Salud de la categoría
    CASE 
        WHEN COUNT(CASE WHEN clasificacion_abc = 'A' THEN 1 END) * 100.0 / COUNT(*) > 30 
        THEN 'Categoría muy fuerte'
        WHEN COUNT(CASE WHEN clasificacion_abc = 'A' THEN 1 END) * 100.0 / COUNT(*) > 15 
        THEN 'Categoría sólida'
        WHEN COUNT(CASE WHEN clasificacion_abc = 'C' THEN 1 END) * 100.0 / COUNT(*) > 60 
        THEN 'Categoría en riesgo'
        ELSE 'Categoría promedio'
    END as evaluacion_categoria
    
FROM productos_clasificados
GROUP BY categoria
ORDER BY SUM(ingresos_total) DESC;

/*
RESULTADOS ESPERADOS:
- Clasificación ABC completa de productos
- Identificación de productos de alta prioridad
- Estrategias diferenciadas por categoría
- Análisis de portfolio y oportunidades de optimización

MÉTRICAS CLAVE:
- Distribución 80/15/5 de ingresos
- Ratio de rotación de inventario
- Tendencias de ventas por producto
- Concentración de valor por categoría
*/
