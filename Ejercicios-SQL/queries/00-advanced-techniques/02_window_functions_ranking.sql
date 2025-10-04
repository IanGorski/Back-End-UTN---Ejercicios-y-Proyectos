-- =====================================================
-- QUERY 2: WINDOW FUNCTIONS - RANKING Y ANÁLISIS DE VENTAS (ADAPTADO PostgreSQL)
-- =====================================================

/*
PROBLEMA:
Analizar el rendimiento de ventas por empleado mostrando:
- Ranking de ventas por departamento
- Diferencia con el mejor vendedor del departamento
- Porcentaje de contribución a las ventas totales
- Media móvil de ventas de los últimos 3 meses
- Comparación con período anterior

TÉCNICAS UTILIZADAS:
- Window Functions: RANK(), FIRST_VALUE(), LAG(), AVG()
- PARTITION BY para análisis por grupos
- ORDER BY dentro de window functions
- ROWS/RANGE para definir ventanas de datos
- Funciones de agregación con OVER clause

CASOS DE USO:
- Dashboards de ventas
- Evaluación de performance de empleados
- Análisis de tendencias temporales
- Benchmarking interno
*/

SET timezone = 'America/Argentina/Buenos_Aires';

WITH ventas_empleado AS (
    SELECT 
        e.id,
        e.nombre || ' ' || e.apellido as empleado,
        d.nombre as departamento,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as total_ventas,
        COUNT(v.id) as num_ventas,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as ticket_promedio,
        EXTRACT(MONTH FROM v.fecha_venta)::INTEGER as mes,
        EXTRACT(YEAR FROM v.fecha_venta)::INTEGER as año
    FROM empleados e
    INNER JOIN departamentos d ON e.departamento_id = d.id
    INNER JOIN ventas v ON e.id = v.empleado_id
    GROUP BY e.id, e.nombre, e.apellido, d.nombre, 
             EXTRACT(MONTH FROM v.fecha_venta), EXTRACT(YEAR FROM v.fecha_venta)
),
ventas_con_rankings AS (
    SELECT 
        empleado,
        departamento,
        año,
        mes,
        total_ventas,
        num_ventas,
        ticket_promedio,
        
        -- RANKING dentro del departamento
        RANK() OVER (
            PARTITION BY departamento, año, mes 
            ORDER BY total_ventas DESC
        ) as ranking_dept_mensual,
        
        -- Ranking general (todos los empleados)
        RANK() OVER (
            ORDER BY total_ventas DESC
        ) as ranking_general,
        
        -- DIFERENCIA con el mejor vendedor del departamento
        total_ventas - FIRST_VALUE(total_ventas) OVER (
            PARTITION BY departamento, año, mes
            ORDER BY total_ventas DESC 
            ROWS UNBOUNDED PRECEDING
        ) as diferencia_con_mejor,
        
        -- PORCENTAJE de contribución al departamento
        ROUND(
            total_ventas * 100.0 / SUM(total_ventas) OVER (
                PARTITION BY departamento, año, mes
            ), 2
        ) as porcentaje_contribucion_dept,
        
        -- PORCENTAJE de contribución total
        ROUND(
            total_ventas * 100.0 / SUM(total_ventas) OVER (
                PARTITION BY año, mes
            ), 2
        ) as porcentaje_contribucion_total,
        
        -- PERCENTIL dentro del departamento
        ROUND((PERCENT_RANK() OVER (
            PARTITION BY departamento, año, mes
            ORDER BY total_ventas
        ) * 100)::NUMERIC, 2) as percentil_departamento,
        
        -- CUARTIL de rendimiento
        NTILE(4) OVER (
            PARTITION BY departamento, año, mes
            ORDER BY total_ventas
        ) as cuartil_rendimiento
        
    FROM ventas_empleado
),
ventas_con_tendencias AS (
    SELECT 
        *,
        -- MEDIA MÓVIL de 3 meses
        ROUND(AVG(total_ventas) OVER (
            PARTITION BY empleado 
            ORDER BY año, mes 
            ROWS 2 PRECEDING
        )::NUMERIC, 2) as media_movil_3_meses,
        
        -- COMPARACIÓN con mes anterior
        LAG(total_ventas, 1) OVER (
            PARTITION BY empleado 
            ORDER BY año, mes
        ) as ventas_mes_anterior
        
    FROM ventas_con_rankings
)
SELECT 
    empleado,
    departamento,
    año,
    mes,
    '$' || ROUND(total_ventas::NUMERIC, 2) as total_ventas,
    num_ventas,
    '$' || ROUND(ticket_promedio::NUMERIC, 2) as ticket_promedio,
    ranking_dept_mensual,
    ranking_general,
    ROUND(diferencia_con_mejor::NUMERIC, 2) as diferencia_con_mejor,
    porcentaje_contribucion_dept,
    porcentaje_contribucion_total,
    media_movil_3_meses,
    ROUND(ventas_mes_anterior::NUMERIC, 2) as ventas_mes_anterior,
    
    -- CRECIMIENTO mensual
    ROUND((total_ventas - ventas_mes_anterior)::NUMERIC, 2) as crecimiento_absoluto,
    
    -- CRECIMIENTO porcentual
    ROUND(
        (total_ventas - ventas_mes_anterior) * 100.0 / NULLIF(ventas_mes_anterior, 0), 2
    ) as crecimiento_porcentual,
    
    percentil_departamento,
    cuartil_rendimiento,
    
    -- CLASIFICACIÓN de rendimiento
    CASE 
        WHEN ranking_dept_mensual = 1 THEN 'TOP PERFORMER'
        WHEN percentil_departamento >= 80 THEN 'HIGH PERFORMER'
        WHEN percentil_departamento >= 50 THEN 'AVERAGE PERFORMER'
        WHEN percentil_departamento >= 20 THEN 'BELOW AVERAGE'
        ELSE 'NEEDS IMPROVEMENT'
    END as clasificacion_rendimiento
    
FROM ventas_con_tendencias
ORDER BY departamento, año DESC, mes DESC, ranking_dept_mensual;

-- =====================================================
-- ANÁLISIS COMPLEMENTARIO: TOP PERFORMERS POR DEPARTAMENTO
-- =====================================================

WITH top_performers AS (
    SELECT 
        e.nombre || ' ' || e.apellido as empleado,
        d.nombre as departamento,
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as total_ventas_año,
        COUNT(v.id) as total_transacciones,
        
        -- Ranking anual por departamento
        RANK() OVER (
            PARTITION BY d.nombre 
            ORDER BY SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) DESC
        ) as ranking_anual_dept
        
    FROM empleados e
    INNER JOIN departamentos d ON e.departamento_id = d.id
    INNER JOIN ventas v ON e.id = v.empleado_id
    WHERE EXTRACT(YEAR FROM v.fecha_venta) = EXTRACT(YEAR FROM CURRENT_DATE)
    GROUP BY e.id, e.nombre, e.apellido, d.nombre
)
SELECT 
    departamento,
    empleado,
    '$' || ROUND(total_ventas_año::NUMERIC, 2) as ventas_anuales,
    total_transacciones,
    ranking_anual_dept,
    
    -- Brecha con el siguiente empleado
    ROUND((total_ventas_año - LEAD(total_ventas_año) OVER (
        PARTITION BY departamento 
        ORDER BY ranking_anual_dept
    ))::NUMERIC, 2) as brecha_con_siguiente
    
FROM top_performers
WHERE ranking_anual_dept <= 3  -- Top 3 por departamento
ORDER BY departamento, ranking_anual_dept;

/*
RESULTADOS ESPERADOS:
- Ranking detallado de empleados por período y departamento
- Análisis de tendencias y crecimiento individual
- Identificación de top performers y empleados que necesitan mejora
- Métricas comparativas para evaluación de rendimiento

MÉTRICAS CLAVE:
- Rankings múltiples (departamental y general)
- Medias móviles para suavizar tendencias
- Percentiles para comparación relativa
- Crecimiento período a período
*/
