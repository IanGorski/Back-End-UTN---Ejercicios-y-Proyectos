-- =====================================================
-- QUERY 5: DETECCIÓN DE ANOMALÍAS EN VENTAS (ADAPTADO PostgreSQL)
-- =====================================================

/*
PROBLEMA:
Detectar ventas anómalas usando análisis estadístico mediante Z-scores,
identificando transacciones que están fuera del comportamiento normal
(outliers que están fuera de 2 desviaciones estándar).

TÉCNICAS UTILIZADAS:
- Funciones estadísticas: AVG(), STDDEV_SAMP()
- Z-score calculation para detección de anomalías
- Window functions con diferentes particiones
- Análisis estadístico multidimensional
- Clasificación de severidad de anomalías

CASOS DE USO:
- Detección de fraude en ventas
- Control de calidad de datos
- Identificación de oportunidades excepcionales
- Análisis de comportamientos atípicos
- Auditoría de transacciones
*/

SET timezone = 'America/Argentina/Buenos_Aires';

WITH estadisticas_ventas AS (
    -- PASO 1: Calcular estadísticas base para cada venta
    SELECT 
        v.id as venta_id,
        v.empleado_id,
        e.nombre || ' ' || e.apellido as vendedor,
        d.nombre as departamento,
        p.nombre as producto,
        p.categoria,
        v.cantidad,
        v.precio_unitario,
        v.cantidad * v.precio_unitario * (1 - v.descuento/100) as monto_venta,
        v.fecha_venta,
        
        -- Estadísticas por empleado
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY v.empleado_id
        ) as promedio_empleado,
        
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY v.empleado_id
        ) as desviacion_empleado,
        
        COUNT(*) OVER (PARTITION BY v.empleado_id) as num_ventas_empleado,
        
        -- Estadísticas por producto
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY v.producto_id
        ) as promedio_producto,
        
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY v.producto_id
        ) as desviacion_producto,
        
        -- Estadísticas por departamento
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY e.departamento_id
        ) as promedio_departamento,
        
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY e.departamento_id
        ) as desviacion_departamento,
        
        -- Estadísticas globales
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER () as promedio_global,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER () as desviacion_global,
        
        -- Estadísticas temporales (mismo mes)
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY EXTRACT(YEAR FROM v.fecha_venta), EXTRACT(MONTH FROM v.fecha_venta)
        ) as promedio_mensual,
        
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY EXTRACT(YEAR FROM v.fecha_venta), EXTRACT(MONTH FROM v.fecha_venta)
        ) as desviacion_mensual
        
    FROM ventas v
    INNER JOIN empleados e ON v.empleado_id = e.id
    INNER JOIN productos p ON v.producto_id = p.id
    INNER JOIN departamentos d ON e.departamento_id = d.id
),

ventas_con_z_scores AS (
    -- PASO 2: Calcular Z-scores para diferentes dimensiones
    SELECT *,
        -- Z-score por empleado
        CASE 
            WHEN desviacion_empleado > 0 
            THEN (monto_venta - promedio_empleado) / desviacion_empleado
            ELSE 0 
        END as z_score_empleado,
        
        -- Z-score por producto
        CASE 
            WHEN desviacion_producto > 0 
            THEN (monto_venta - promedio_producto) / desviacion_producto
            ELSE 0 
        END as z_score_producto,
        
        -- Z-score por departamento
        CASE 
            WHEN desviacion_departamento > 0 
            THEN (monto_venta - promedio_departamento) / desviacion_departamento
            ELSE 0 
        END as z_score_departamento,
        
        -- Z-score global
        CASE 
            WHEN desviacion_global > 0 
            THEN (monto_venta - promedio_global) / desviacion_global
            ELSE 0 
        END as z_score_global,
        
        -- Z-score temporal
        CASE 
            WHEN desviacion_mensual > 0 
            THEN (monto_venta - promedio_mensual) / desviacion_mensual
            ELSE 0 
        END as z_score_temporal
        
    FROM estadisticas_ventas
    WHERE num_ventas_empleado >= 5  -- Solo empleados con suficientes ventas
),

clasificacion_anomalias AS (
    -- PASO 3: Clasificar anomalías por severidad
    SELECT *,
        -- Puntuación compuesta de anomalía
        (ABS(z_score_empleado) + ABS(z_score_producto) + ABS(z_score_global)) / 3.0 as score_anomalia_compuesto,
        
        -- Clasificación principal de anomalía
        CASE 
            WHEN ABS(z_score_empleado) > 3 OR ABS(z_score_global) > 3 
            THEN 'ANOMALÍA SEVERA'
            WHEN ABS(z_score_empleado) > 2.5 OR ABS(z_score_global) > 2.5 
            THEN 'ANOMALÍA MODERADA'
            WHEN ABS(z_score_empleado) > 2 OR ABS(z_score_global) > 2 
            THEN 'ANOMALÍA LEVE'
            WHEN ABS(z_score_empleado) > 1.5 OR ABS(z_score_global) > 1.5 
            THEN 'SOSPECHOSO'
            ELSE 'NORMAL'
        END as clasificacion_anomalia,
        
        -- Tipo de anomalía (alta o baja)
        CASE 
            WHEN z_score_global > 2 THEN 'VENTA EXCEPCIONALMENTE ALTA'
            WHEN z_score_global < -2 THEN 'VENTA EXCEPCIONALMENTE BAJA'
            WHEN z_score_empleado > 2 THEN 'ALTA PARA ESTE EMPLEADO'
            WHEN z_score_empleado < -2 THEN 'BAJA PARA ESTE EMPLEADO'
            ELSE 'DENTRO DE RANGO NORMAL'
        END as tipo_anomalia,
        
        -- Nivel de confianza en la anomalía
        CASE 
            WHEN ABS(z_score_empleado) > 3 AND ABS(z_score_global) > 2 THEN 'MUY ALTA'
            WHEN ABS(z_score_empleado) > 2.5 OR ABS(z_score_global) > 2.5 THEN 'ALTA'
            WHEN ABS(z_score_empleado) > 2 OR ABS(z_score_global) > 2 THEN 'MEDIA'
            ELSE 'BAJA'
        END as confianza_anomalia
        
    FROM ventas_con_z_scores
)

-- RESULTADO PRINCIPAL: Detección de anomalías
SELECT 
    venta_id,
    fecha_venta,
    vendedor,
    departamento,
    producto,
    categoria,
    cantidad,
    '$' || ROUND(precio_unitario::NUMERIC, 2) as precio_unitario,
    '$' || ROUND(monto_venta::NUMERIC, 2) as monto_venta,
    
    -- Clasificación de la anomalía
    clasificacion_anomalia,
    tipo_anomalia,
    confianza_anomalia,
    
    -- Scores estadísticos (redondeados)
    ROUND(z_score_empleado::NUMERIC, 2) as z_score_empleado,
    ROUND(z_score_producto::NUMERIC, 2) as z_score_producto,
    ROUND(z_score_global::NUMERIC, 2) as z_score_global,
    ROUND(score_anomalia_compuesto::NUMERIC, 2) as score_anomalia,
    
    -- Contexto estadístico
    '$' || ROUND(promedio_empleado::NUMERIC, 2) as promedio_empleado,
    '$' || ROUND(promedio_global::NUMERIC, 2) as promedio_global,
    
    -- Explicación detallada de la anomalía
    CASE 
        WHEN monto_venta > promedio_empleado + 3 * desviacion_empleado 
        THEN 'Venta 3+ desviaciones por encima del promedio del empleado'
        WHEN monto_venta < promedio_empleado - 3 * desviacion_empleado 
        THEN 'Venta 3+ desviaciones por debajo del promedio del empleado'
        WHEN monto_venta > promedio_global + 3 * desviacion_global 
        THEN 'Venta 3+ desviaciones por encima del promedio global'
        WHEN monto_venta < promedio_global - 3 * desviacion_global 
        THEN 'Venta 3+ desviaciones por debajo del promedio global'
        WHEN monto_venta > promedio_empleado + 2 * desviacion_empleado 
        THEN 'Venta significativamente alta para este empleado'
        WHEN monto_venta < promedio_empleado - 2 * desviacion_empleado 
        THEN 'Venta significativamente baja para este empleado'
        ELSE 'Venta dentro de parámetros normales con variación menor'
    END as explicacion_detallada,
    
    -- Acciones recomendadas
    CASE 
        WHEN clasificacion_anomalia = 'ANOMALÍA SEVERA' 
        THEN 'REVISAR INMEDIATAMENTE: Validar transacción y verificar legitimidad'
        WHEN clasificacion_anomalia = 'ANOMALÍA MODERADA' 
        THEN 'INVESTIGAR: Confirmar detalles y documentar explicación'
        WHEN clasificacion_anomalia = 'ANOMALÍA LEVE' 
        THEN 'MONITOREAR: Seguimiento en próximas transacciones'
        WHEN tipo_anomalia = 'VENTA EXCEPCIONALMENTE ALTA' 
        THEN 'ANALIZAR OPORTUNIDAD: Replicar estrategia exitosa'
        ELSE 'Sin acción requerida'
    END as accion_recomendada
    
FROM clasificacion_anomalias
WHERE clasificacion_anomalia IN ('ANOMALÍA SEVERA', 'ANOMALÍA MODERADA', 'ANOMALÍA LEVE', 'SOSPECHOSO')
ORDER BY score_anomalia_compuesto DESC, monto_venta DESC;

-- =====================================================
-- RESUMEN EJECUTIVO DE ANOMALÍAS
-- =====================================================

WITH estadisticas_ventas AS (
    SELECT 
        v.id as venta_id,
        v.empleado_id,
        e.nombre || ' ' || e.apellido as vendedor,
        d.nombre as departamento,
        p.nombre as producto,
        p.categoria,
        v.cantidad,
        v.precio_unitario,
        v.cantidad * v.precio_unitario * (1 - v.descuento/100) as monto_venta,
        v.fecha_venta,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY v.empleado_id) as promedio_empleado,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY v.empleado_id) as desviacion_empleado,
        COUNT(*) OVER (PARTITION BY v.empleado_id) as num_ventas_empleado,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY v.producto_id) as promedio_producto,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY v.producto_id) as desviacion_producto,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY e.departamento_id) as promedio_departamento,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY e.departamento_id) as desviacion_departamento,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER () as promedio_global,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER () as desviacion_global,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY EXTRACT(YEAR FROM v.fecha_venta), EXTRACT(MONTH FROM v.fecha_venta)
        ) as promedio_mensual,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY EXTRACT(YEAR FROM v.fecha_venta), EXTRACT(MONTH FROM v.fecha_venta)
        ) as desviacion_mensual
    FROM ventas v
    INNER JOIN empleados e ON v.empleado_id = e.id
    INNER JOIN productos p ON v.producto_id = p.id
    INNER JOIN departamentos d ON e.departamento_id = d.id
),
ventas_con_z_scores AS (
    SELECT *,
        CASE WHEN desviacion_empleado > 0 THEN (monto_venta - promedio_empleado) / desviacion_empleado ELSE 0 END as z_score_empleado,
        CASE WHEN desviacion_producto > 0 THEN (monto_venta - promedio_producto) / desviacion_producto ELSE 0 END as z_score_producto,
        CASE WHEN desviacion_departamento > 0 THEN (monto_venta - promedio_departamento) / desviacion_departamento ELSE 0 END as z_score_departamento,
        CASE WHEN desviacion_global > 0 THEN (monto_venta - promedio_global) / desviacion_global ELSE 0 END as z_score_global,
        CASE WHEN desviacion_mensual > 0 THEN (monto_venta - promedio_mensual) / desviacion_mensual ELSE 0 END as z_score_temporal
    FROM estadisticas_ventas
    WHERE num_ventas_empleado >= 5
),
clasificacion_anomalias AS (
    SELECT *,
        (ABS(z_score_empleado) + ABS(z_score_producto) + ABS(z_score_global)) / 3.0 as score_anomalia_compuesto,
        CASE 
            WHEN ABS(z_score_empleado) > 3 OR ABS(z_score_global) > 3 THEN 'ANOMALÍA SEVERA'
            WHEN ABS(z_score_empleado) > 2.5 OR ABS(z_score_global) > 2.5 THEN 'ANOMALÍA MODERADA'
            WHEN ABS(z_score_empleado) > 2 OR ABS(z_score_global) > 2 THEN 'ANOMALÍA LEVE'
            WHEN ABS(z_score_empleado) > 1.5 OR ABS(z_score_global) > 1.5 THEN 'SOSPECHOSO'
            ELSE 'NORMAL'
        END as clasificacion_anomalia,
        CASE 
            WHEN z_score_global > 2 THEN 'VENTA EXCEPCIONALMENTE ALTA'
            WHEN z_score_global < -2 THEN 'VENTA EXCEPCIONALMENTE BAJA'
            WHEN z_score_empleado > 2 THEN 'ALTA PARA ESTE EMPLEADO'
            WHEN z_score_empleado < -2 THEN 'BAJA PARA ESTE EMPLEADO'
            ELSE 'DENTRO DE RANGO NORMAL'
        END as tipo_anomalia,
        CASE 
            WHEN ABS(z_score_empleado) > 3 AND ABS(z_score_global) > 2 THEN 'MUY ALTA'
            WHEN ABS(z_score_empleado) > 2.5 OR ABS(z_score_global) > 2.5 THEN 'ALTA'
            WHEN ABS(z_score_empleado) > 2 OR ABS(z_score_global) > 2 THEN 'MEDIA'
            ELSE 'BAJA'
        END as confianza_anomalia
    FROM ventas_con_z_scores
)
SELECT 
    clasificacion_anomalia,
    COUNT(*) as num_transacciones,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ())::NUMERIC, 2) as porcentaje_total,
    
    -- Métricas financieras de anomalías
    '$' || ROUND(SUM(monto_venta)::NUMERIC, 2) as monto_total_anomalias,
    '$' || ROUND(AVG(monto_venta)::NUMERIC, 2) as monto_promedio,
    '$' || ROUND(MIN(monto_venta)::NUMERIC, 2) as monto_minimo,
    '$' || ROUND(MAX(monto_venta)::NUMERIC, 2) as monto_maximo,
    
    -- Distribución por tipo
    COUNT(CASE WHEN tipo_anomalia LIKE '%ALTA%' THEN 1 END) as anomalias_altas,
    COUNT(CASE WHEN tipo_anomalia LIKE '%BAJA%' THEN 1 END) as anomalias_bajas,
    
    -- Análisis de empleados involucrados
    COUNT(DISTINCT empleado_id) as empleados_involucrados,
    COUNT(DISTINCT producto) as productos_involucrados,
    
    -- Recomendación general
    CASE 
        WHEN clasificacion_anomalia = 'ANOMALÍA SEVERA' 
        THEN 'Auditoría inmediata requerida'
        WHEN clasificacion_anomalia = 'ANOMALÍA MODERADA' 
        THEN 'Investigación recomendada'
        WHEN clasificacion_anomalia = 'ANOMALÍA LEVE' 
        THEN 'Monitoreo continuo'
        ELSE 'Seguimiento rutinario'
    END as recomendacion_general
    
FROM clasificacion_anomalias
WHERE clasificacion_anomalia != 'NORMAL'
GROUP BY clasificacion_anomalia
ORDER BY 
    CASE clasificacion_anomalia
        WHEN 'ANOMALÍA SEVERA' THEN 1
        WHEN 'ANOMALÍA MODERADA' THEN 2
        WHEN 'ANOMALÍA LEVE' THEN 3
        WHEN 'SOSPECHOSO' THEN 4
        ELSE 5
    END;

-- =====================================================
-- ANÁLISIS DE PATRONES DE ANOMALÍAS POR EMPLEADO
-- =====================================================

WITH estadisticas_ventas AS (
    SELECT 
        v.id as venta_id,
        v.empleado_id,
        e.nombre || ' ' || e.apellido as vendedor,
        d.nombre as departamento,
        p.nombre as producto,
        p.categoria,
        v.cantidad,
        v.precio_unitario,
        v.cantidad * v.precio_unitario * (1 - v.descuento/100) as monto_venta,
        v.fecha_venta,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY v.empleado_id) as promedio_empleado,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY v.empleado_id) as desviacion_empleado,
        COUNT(*) OVER (PARTITION BY v.empleado_id) as num_ventas_empleado,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY v.producto_id) as promedio_producto,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY v.producto_id) as desviacion_producto,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY e.departamento_id) as promedio_departamento,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (PARTITION BY e.departamento_id) as desviacion_departamento,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER () as promedio_global,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER () as desviacion_global,
        AVG(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY EXTRACT(YEAR FROM v.fecha_venta), EXTRACT(MONTH FROM v.fecha_venta)
        ) as promedio_mensual,
        STDDEV_SAMP(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) OVER (
            PARTITION BY EXTRACT(YEAR FROM v.fecha_venta), EXTRACT(MONTH FROM v.fecha_venta)
        ) as desviacion_mensual
    FROM ventas v
    INNER JOIN empleados e ON v.empleado_id = e.id
    INNER JOIN productos p ON v.producto_id = p.id
    INNER JOIN departamentos d ON e.departamento_id = d.id
),
ventas_con_z_scores AS (
    SELECT *,
        CASE WHEN desviacion_empleado > 0 THEN (monto_venta - promedio_empleado) / desviacion_empleado ELSE 0 END as z_score_empleado,
        CASE WHEN desviacion_producto > 0 THEN (monto_venta - promedio_producto) / desviacion_producto ELSE 0 END as z_score_producto,
        CASE WHEN desviacion_departamento > 0 THEN (monto_venta - promedio_departamento) / desviacion_departamento ELSE 0 END as z_score_departamento,
        CASE WHEN desviacion_global > 0 THEN (monto_venta - promedio_global) / desviacion_global ELSE 0 END as z_score_global,
        CASE WHEN desviacion_mensual > 0 THEN (monto_venta - promedio_mensual) / desviacion_mensual ELSE 0 END as z_score_temporal
    FROM estadisticas_ventas
    WHERE num_ventas_empleado >= 5
),
clasificacion_anomalias AS (
    SELECT *,
        (ABS(z_score_empleado) + ABS(z_score_producto) + ABS(z_score_global)) / 3.0 as score_anomalia_compuesto,
        CASE 
            WHEN ABS(z_score_empleado) > 3 OR ABS(z_score_global) > 3 THEN 'ANOMALÍA SEVERA'
            WHEN ABS(z_score_empleado) > 2.5 OR ABS(z_score_global) > 2.5 THEN 'ANOMALÍA MODERADA'
            WHEN ABS(z_score_empleado) > 2 OR ABS(z_score_global) > 2 THEN 'ANOMALÍA LEVE'
            WHEN ABS(z_score_empleado) > 1.5 OR ABS(z_score_global) > 1.5 THEN 'SOSPECHOSO'
            ELSE 'NORMAL'
        END as clasificacion_anomalia,
        CASE 
            WHEN z_score_global > 2 THEN 'VENTA EXCEPCIONALMENTE ALTA'
            WHEN z_score_global < -2 THEN 'VENTA EXCEPCIONALMENTE BAJA'
            WHEN z_score_empleado > 2 THEN 'ALTA PARA ESTE EMPLEADO'
            WHEN z_score_empleado < -2 THEN 'BAJA PARA ESTE EMPLEADO'
            ELSE 'DENTRO DE RANGO NORMAL'
        END as tipo_anomalia,
        CASE 
            WHEN ABS(z_score_empleado) > 3 AND ABS(z_score_global) > 2 THEN 'MUY ALTA'
            WHEN ABS(z_score_empleado) > 2.5 OR ABS(z_score_global) > 2.5 THEN 'ALTA'
            WHEN ABS(z_score_empleado) > 2 OR ABS(z_score_global) > 2 THEN 'MEDIA'
            ELSE 'BAJA'
        END as confianza_anomalia
    FROM ventas_con_z_scores
)
SELECT 
    vendedor,
    departamento,
    COUNT(*) as total_anomalias,
    COUNT(CASE WHEN clasificacion_anomalia = 'ANOMALÍA SEVERA' THEN 1 END) as anomalias_severas,
    COUNT(CASE WHEN tipo_anomalia LIKE '%ALTA%' THEN 1 END) as anomalias_altas,
    COUNT(CASE WHEN tipo_anomalia LIKE '%BAJA%' THEN 1 END) as anomalias_bajas,
    
    -- Tendencia de anomalías
    '$' || ROUND(AVG(monto_venta)::NUMERIC, 2) as monto_promedio_anomalias,
    ROUND(AVG(ABS(z_score_empleado))::NUMERIC, 2) as z_score_promedio,
    
    -- Evaluación del empleado
    CASE 
        WHEN COUNT(CASE WHEN clasificacion_anomalia = 'ANOMALÍA SEVERA' THEN 1 END) > 3 
        THEN 'REQUIERE ENTRENAMIENTO URGENTE'
        WHEN COUNT(CASE WHEN tipo_anomalia LIKE '%ALTA%' THEN 1 END) > 
             COUNT(CASE WHEN tipo_anomalia LIKE '%BAJA%' THEN 1 END) * 2 
        THEN 'ALTO POTENCIAL - ESTUDIAR TÉCNICAS'
        WHEN COUNT(*) > 10 
        THEN 'PATRÓN INCONSISTENTE - REVISAR METODOLOGÍA'
        ELSE 'VARIACIÓN NORMAL'
    END as evaluacion_empleado
    
FROM clasificacion_anomalias
WHERE clasificacion_anomalia != 'NORMAL'
GROUP BY vendedor, departamento, empleado_id
HAVING COUNT(*) >= 3  -- Solo empleados con 3+ anomalías
ORDER BY total_anomalias DESC, anomalias_severas DESC;

/*
RESULTADOS ESPERADOS:
- Identificación precisa de transacciones anómalas
- Clasificación por severidad y tipo de anomalía
- Análisis estadístico robusto con múltiples dimensiones
- Recomendaciones específicas para cada tipo de anomalía

MÉTRICAS CLAVE:
- Z-scores multidimensionales
- Clasificación de severidad
- Patrones por empleado y producto
- Acciones correctivas recomendadas
*/
