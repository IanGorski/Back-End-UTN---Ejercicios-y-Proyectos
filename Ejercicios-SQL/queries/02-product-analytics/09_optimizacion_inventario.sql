-- =====================================================
-- QUERY 9: OPTIMIZACIÓN DE INVENTARIO Y PRONÓSTICO
-- =====================================================

/*
PROBLEMA:
Optimizar niveles de inventario basado en patrones de venta,
estacionalidad, lead times y costos, con alertas automáticas
de reabastecimiento y análisis de punto de reorden.

TÉCNICAS UTILIZADAS:
- Análisis de demanda histórica
- Cálculo de EOQ (Economic Order Quantity)
- Análisis de velocidad de rotación
- Clasificación ABC de productos
- Modelos de punto de reorden
- Detección de sobrestock y faltantes

CASOS DE USO:
- Gestión de inventario
- Planificación de compras
- Optimización de costos de almacenamiento
- Prevención de stockouts
- Análisis de obsolescencia
*/

WITH analisis_demanda AS (
    -- PASO 1: Analizar patrones de demanda histórica
    SELECT 
        p.id as producto_id,
        p.nombre as producto,
        p.categoria,
        p.stock as stock_actual,
        p.precio,
        
        -- Métricas de venta agregadas
        COUNT(v.id) as num_transacciones,
        SUM(v.cantidad) as total_vendido_historico,
        AVG(v.cantidad) as promedio_por_transaccion,
        STDDEV_SAMP(v.cantidad) as desviacion_cantidad,
        
        -- Análisis temporal detallado
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '7 days' THEN v.cantidad ELSE 0 END) as ventas_ultima_semana,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '1 month' THEN v.cantidad ELSE 0 END) as ventas_ultimo_mes,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_trimestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '6 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_semestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_año,
        
        -- Análisis de ingresos
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as ingresos_totales,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months' 
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100) ELSE 0 END) as ingresos_trimestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months' 
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100) ELSE 0 END) as ingresos_año,
            
        -- Fechas de referencia
        MAX(v.fecha_venta) as ultima_venta,
        MIN(v.fecha_venta) as primera_venta,
        
        -- Conteo de meses con ventas
        COUNT(DISTINCT DATE_TRUNC('month', v.fecha_venta)) as meses_con_ventas
        
    FROM productos p
    LEFT JOIN ventas v ON p.id = v.producto_id
    GROUP BY p.id, p.nombre, p.categoria, p.stock, p.precio
),

metricas_inventario AS (
    -- PASO 2: Calcular métricas clave de inventario
    SELECT *,
        -- Demanda promedio en diferentes períodos
        CASE WHEN meses_con_ventas > 0 THEN ventas_ultimo_año / 12.0 ELSE 0 END as demanda_mensual_promedio,
        CASE WHEN ventas_ultimo_trimestre > 0 THEN ventas_ultimo_trimestre / 3.0 ELSE 0 END as demanda_mensual_reciente,
        CASE WHEN ventas_ultima_semana > 0 THEN ventas_ultima_semana ELSE 0 END as demanda_semanal_actual,
        
        -- Velocidad de rotación
        CASE 
            WHEN stock_actual > 0 AND ventas_ultimo_mes > 0
            THEN ventas_ultimo_mes / stock_actual
            ELSE 0
        END as rotacion_mensual,
        
        CASE 
            WHEN stock_actual > 0 AND ventas_ultimo_año > 0
            THEN ventas_ultimo_año / stock_actual
            ELSE 0
        END as rotacion_anual,
        
        -- Días de inventario restante
        CASE 
            WHEN ventas_ultimo_mes > 0 
            THEN stock_actual * 30.0 / ventas_ultimo_mes
            WHEN ventas_ultimo_trimestre > 0
            THEN stock_actual * 90.0 / ventas_ultimo_trimestre
            ELSE 999
        END as dias_inventario_restante,
        
        -- Tendencia de demanda (comparando trimestres)
        CASE 
            WHEN ventas_ultimo_trimestre > 0 AND ventas_ultimo_año > ventas_ultimo_trimestre
            THEN (ventas_ultimo_trimestre * 4.0) / (ventas_ultimo_año - ventas_ultimo_trimestre) * 3.0 - 1
            ELSE 0
        END as tendencia_demanda_ratio,
        
        -- Valor del inventario
        stock_actual * precio as valor_inventario_actual,
        
        -- Clasificación ABC por volumen e ingresos
        NTILE(3) OVER (ORDER BY total_vendido_historico DESC) as clasificacion_volumen,
        NTILE(3) OVER (ORDER BY ingresos_totales DESC) as clasificacion_ingresos
        
    FROM analisis_demanda
),

calculos_optimizacion AS (
    -- PASO 3: Cálculos de optimización de inventario
    SELECT *,
        -- Clasificación de tendencia
        CASE 
            WHEN tendencia_demanda_ratio > 0.2 THEN 'Creciente'
            WHEN tendencia_demanda_ratio < -0.2 THEN 'Decreciente'
            ELSE 'Estable'
        END as tendencia_demanda,
        
        -- Lead time estimado (simulado - en realidad vendría de datos de proveedores)
        CASE 
            WHEN categoria = 'Electrónicos' THEN 14  -- 2 semanas
            WHEN categoria = 'Accesorios' THEN 7     -- 1 semana
            WHEN categoria = 'Oficina' THEN 10       -- 1.5 semanas
            ELSE 10  -- Default
        END as lead_time_dias,
        
        -- Demanda durante lead time
        CASE 
            WHEN demanda_mensual_reciente > 0
            THEN (CASE 
                WHEN categoria = 'Electrónicos' THEN demanda_mensual_reciente * 14.0 / 30.0
                WHEN categoria = 'Accesorios' THEN demanda_mensual_reciente * 7.0 / 30.0
                WHEN categoria = 'Oficina' THEN demanda_mensual_reciente * 10.0 / 30.0
                ELSE demanda_mensual_reciente * 10.0 / 30.0
            END)
            ELSE 0
        END as demanda_lead_time,
        
        -- Stock de seguridad (1.5x la demanda semanal para productos A, menos para otros)
        CASE 
            WHEN clasificacion_volumen = 1 AND clasificacion_ingresos = 1  -- Productos A
            THEN demanda_mensual_reciente * 7.0 / 30.0 * 2.0  -- 2 semanas de seguridad
            WHEN clasificacion_volumen <= 2 AND clasificacion_ingresos <= 2  -- Productos B
            THEN demanda_mensual_reciente * 7.0 / 30.0 * 1.5  -- 1.5 semanas de seguridad
            ELSE demanda_mensual_reciente * 7.0 / 30.0 * 1.0  -- 1 semana de seguridad
        END as stock_seguridad,
        
        -- Costo de mantener inventario (estimado como % del precio)
        precio * 0.25 as costo_mantenimiento_anual_unitario,  -- 25% del precio por año
        
        -- Costo de pedido (estimado)
        CASE 
            WHEN clasificacion_volumen = 1 THEN 200  -- Productos A: mayor costo de gestión
            WHEN clasificacion_volumen = 2 THEN 150  -- Productos B
            ELSE 100  -- Productos C
        END as costo_pedido_estimado
        
    FROM metricas_inventario
),

optimizacion_final AS (
    -- PASO 4: Cálculos finales de optimización
    SELECT *,
        -- Punto de reorden
        CEILING(demanda_lead_time + stock_seguridad) as punto_reorden,
        
        -- Cantidad óptima de pedido (EOQ simplificado)
        CASE 
            WHEN demanda_mensual_reciente > 0 AND costo_mantenimiento_anual_unitario > 0
            THEN CEILING(
                SQRT(
                    2 * (demanda_mensual_reciente * 12) * costo_pedido_estimado / 
                    costo_mantenimiento_anual_unitario
                )
            )
            ELSE CEILING(demanda_mensual_reciente * 2)  -- Fallback: 2 meses de demanda
        END as cantidad_optima_pedido,
        
        -- Stock máximo recomendado
        CEILING(demanda_lead_time + stock_seguridad) + 
        CASE 
            WHEN demanda_mensual_reciente > 0 AND costo_mantenimiento_anual_unitario > 0
            THEN CEILING(
                SQRT(
                    2 * (demanda_mensual_reciente * 12) * costo_pedido_estimado / 
                    costo_mantenimiento_anual_unitario
                )
            )
            ELSE CEILING(demanda_mensual_reciente * 2)
        END as stock_maximo_recomendado,
        
        -- Criticidad del producto
        CASE 
            WHEN clasificacion_volumen = 1 AND clasificacion_ingresos = 1 THEN 'CRÍTICO'
            WHEN clasificacion_volumen <= 2 AND clasificacion_ingresos <= 2 THEN 'IMPORTANTE'
            ELSE 'NORMAL'
        END as criticidad_producto,
        
        -- Estado actual del inventario
        CASE 
            WHEN stock_actual <= 0 THEN 'SIN STOCK'
            WHEN stock_actual <= (demanda_lead_time + stock_seguridad) THEN 'REABASTECER URGENTE'
            WHEN dias_inventario_restante <= 14 THEN 'REABASTECER PRONTO'
            WHEN stock_actual > (demanda_lead_time + stock_seguridad) * 3 THEN 'SOBRESTOCK'
            WHEN dias_inventario_restante > 120 THEN 'POSIBLE OBSOLESCENCIA'
            ELSE 'NORMAL'
        END as estado_inventario,
        
        -- Costo de oportunidad por faltantes
        (demanda_mensual_reciente * precio * 0.1) as costo_oportunidad_mensual_faltante
        
    FROM calculos_optimizacion
)

-- RESULTADO PRINCIPAL: Dashboard de optimización de inventario
SELECT 
    producto,
    categoria,
    criticidad_producto,
    estado_inventario,
    
    -- Estado actual
    stock_actual,
    '$' || ROUND(valor_inventario_actual::NUMERIC, 2) as valor_inventario,
    ROUND(dias_inventario_restante, 1) as dias_restantes,
    tendencia_demanda,
    
    -- Métricas de demanda
    ROUND(demanda_mensual_reciente, 2) as demanda_mensual,
    ROUND(demanda_mensual_promedio, 2) as demanda_promedio_historica,
    ROUND(rotacion_mensual, 2) as rotacion_mensual,
    ROUND(rotacion_anual, 2) as rotacion_anual,
    
    -- Parámetros de reorden
    punto_reorden,
    cantidad_optima_pedido,
    stock_maximo_recomendado,
    ROUND(stock_seguridad, 0) as stock_seguridad,
    lead_time_dias,
    
    -- Análisis financiero
    '$' || ROUND(ingresos_trimestre::NUMERIC, 2) as ingresos_trimestre,
    '$' || ROUND(costo_oportunidad_mensual_faltante::NUMERIC, 2) as costo_oportunidad_faltante,
    
    -- Recomendaciones específicas
    CASE 
        WHEN estado_inventario = 'SIN STOCK' 
        THEN 'URGENTE: Pedido inmediato de ' || CAST(cantidad_optima_pedido AS VARCHAR) || ' unidades'
        WHEN estado_inventario = 'REABASTECER URGENTE' 
        THEN 'Reabastecer ' || CAST(cantidad_optima_pedido AS VARCHAR) || ' unidades esta semana'
        WHEN estado_inventario = 'REABASTECER PRONTO' 
        THEN 'Planificar pedido de ' || CAST(cantidad_optima_pedido AS VARCHAR) || ' unidades'
        WHEN estado_inventario = 'SOBRESTOCK' 
        THEN 'Reducir pedidos, promocionar para acelerar rotación'
        WHEN estado_inventario = 'POSIBLE OBSOLESCENCIA' 
        THEN 'ALERTA: Evaluar descontinuación o liquidación'
        ELSE 'Mantener nivel actual, monitoreo rutinario'
    END as accion_recomendada,
    
    -- Prioridad de acción
    CASE 
        WHEN estado_inventario = 'SIN STOCK' AND criticidad_producto = 'CRÍTICO' THEN 1
        WHEN estado_inventario = 'SIN STOCK' THEN 2
        WHEN estado_inventario = 'REABASTECER URGENTE' AND criticidad_producto = 'CRÍTICO' THEN 3
        WHEN estado_inventario = 'REABASTECER URGENTE' THEN 4
        WHEN estado_inventario = 'POSIBLE OBSOLESCENCIA' THEN 5
        WHEN estado_inventario = 'SOBRESTOCK' THEN 6
        WHEN estado_inventario = 'REABASTECER PRONTO' THEN 7
        ELSE 8
    END as prioridad_accion,
    
    -- Impacto financiero estimado de la acción
    CASE 
        WHEN estado_inventario IN ('SIN STOCK', 'REABASTECER URGENTE')
        THEN '$' || ROUND(costo_oportunidad_mensual_faltante::NUMERIC, 2)
        WHEN estado_inventario = 'SOBRESTOCK'
        THEN '$' || ROUND(((stock_actual - stock_maximo_recomendado) * precio * 0.02)::NUMERIC, 2)  -- 2% costo mensual de exceso
        ELSE '$0'
    END as impacto_financiero_mensual
    
FROM optimizacion_final
WHERE total_vendido_historico > 0  -- Solo productos con ventas históricas
ORDER BY prioridad_accion, costo_oportunidad_mensual_faltante DESC;

-- =====================================================
-- RESUMEN EJECUTIVO DE INVENTARIO
-- =====================================================

-- Redefinir CTEs necesarios para esta query independiente
WITH analisis_demanda AS (
    -- PASO 1: Analizar patrones de demanda histórica
    SELECT 
        p.id as producto_id,
        p.nombre as producto,
        p.categoria,
        p.stock as stock_actual,
        p.precio,
        
        -- Métricas de venta agregadas
        COUNT(v.id) as num_transacciones,
        SUM(v.cantidad) as total_vendido_historico,
        AVG(v.cantidad) as promedio_por_transaccion,
        STDDEV_SAMP(v.cantidad) as desviacion_cantidad,
        
        -- Análisis temporal detallado
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '7 days' THEN v.cantidad ELSE 0 END) as ventas_ultima_semana,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '1 month' THEN v.cantidad ELSE 0 END) as ventas_ultimo_mes,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_trimestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '6 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_semestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_año,
        
        -- Análisis de ingresos
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as ingresos_totales,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months' 
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100) ELSE 0 END) as ingresos_trimestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months' 
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100) ELSE 0 END) as ingresos_año,
            
        -- Fechas de referencia
        MAX(v.fecha_venta) as ultima_venta,
        MIN(v.fecha_venta) as primera_venta,
        
        -- Conteo de meses con ventas
        COUNT(DISTINCT DATE_TRUNC('month', v.fecha_venta)) as meses_con_ventas
        
    FROM productos p
    LEFT JOIN ventas v ON p.id = v.producto_id
    GROUP BY p.id, p.nombre, p.categoria, p.stock, p.precio
),

metricas_inventario AS (
    -- PASO 2: Calcular métricas clave de inventario
    SELECT *,
        -- Demanda promedio en diferentes períodos
        CASE WHEN meses_con_ventas > 0 THEN ventas_ultimo_año / 12.0 ELSE 0 END as demanda_mensual_promedio,
        CASE WHEN ventas_ultimo_trimestre > 0 THEN ventas_ultimo_trimestre / 3.0 ELSE 0 END as demanda_mensual_reciente,
        CASE WHEN ventas_ultima_semana > 0 THEN ventas_ultima_semana ELSE 0 END as demanda_semanal_actual,
        
        -- Velocidad de rotación
        CASE 
            WHEN stock_actual > 0 AND ventas_ultimo_mes > 0
            THEN ventas_ultimo_mes / stock_actual
            ELSE 0
        END as rotacion_mensual,
        
        CASE 
            WHEN stock_actual > 0 AND ventas_ultimo_año > 0
            THEN ventas_ultimo_año / stock_actual
            ELSE 0
        END as rotacion_anual,
        
        -- Días de inventario restante
        CASE 
            WHEN ventas_ultimo_mes > 0 
            THEN stock_actual * 30.0 / ventas_ultimo_mes
            WHEN ventas_ultimo_trimestre > 0
            THEN stock_actual * 90.0 / ventas_ultimo_trimestre
            ELSE 999
        END as dias_inventario_restante,
        
        -- Tendencia de demanda (comparando trimestres)
        CASE 
            WHEN ventas_ultimo_trimestre > 0 AND ventas_ultimo_año > ventas_ultimo_trimestre
            THEN (ventas_ultimo_trimestre * 4.0) / (ventas_ultimo_año - ventas_ultimo_trimestre) * 3.0 - 1
            ELSE 0
        END as tendencia_demanda_ratio,
        
        -- Valor del inventario
        stock_actual * precio as valor_inventario_actual,
        
        -- Clasificación ABC por volumen e ingresos
        NTILE(3) OVER (ORDER BY total_vendido_historico DESC) as clasificacion_volumen,
        NTILE(3) OVER (ORDER BY ingresos_totales DESC) as clasificacion_ingresos
        
    FROM analisis_demanda
),

calculos_optimizacion AS (
    -- PASO 3: Cálculos de optimización de inventario
    SELECT *,
        -- Clasificación de tendencia
        CASE 
            WHEN tendencia_demanda_ratio > 0.2 THEN 'Creciente'
            WHEN tendencia_demanda_ratio < -0.2 THEN 'Decreciente'
            ELSE 'Estable'
        END as tendencia_demanda,
        
        -- Lead time estimado (simulado - en realidad vendría de datos de proveedores)
        CASE 
            WHEN categoria = 'Electrónicos' THEN 14  -- 2 semanas
            WHEN categoria = 'Accesorios' THEN 7     -- 1 semana
            WHEN categoria = 'Oficina' THEN 10       -- 1.5 semanas
            ELSE 10  -- Default
        END as lead_time_dias,
        
        -- Demanda durante lead time
        CASE 
            WHEN demanda_mensual_reciente > 0
            THEN (CASE 
                WHEN categoria = 'Electrónicos' THEN demanda_mensual_reciente * 14.0 / 30.0
                WHEN categoria = 'Accesorios' THEN demanda_mensual_reciente * 7.0 / 30.0
                WHEN categoria = 'Oficina' THEN demanda_mensual_reciente * 10.0 / 30.0
                ELSE demanda_mensual_reciente * 10.0 / 30.0
            END)
            ELSE 0
        END as demanda_lead_time,
        
        -- Stock de seguridad (1.5x la demanda semanal para productos A, menos para otros)
        CASE 
            WHEN clasificacion_volumen = 1 AND clasificacion_ingresos = 1  -- Productos A
            THEN demanda_mensual_reciente * 7.0 / 30.0 * 2.0  -- 2 semanas de seguridad
            WHEN clasificacion_volumen <= 2 AND clasificacion_ingresos <= 2  -- Productos B
            THEN demanda_mensual_reciente * 7.0 / 30.0 * 1.5  -- 1.5 semanas de seguridad
            ELSE demanda_mensual_reciente * 7.0 / 30.0 * 1.0  -- 1 semana de seguridad
        END as stock_seguridad,
        
        -- Costo de mantener inventario (estimado como % del precio)
        precio * 0.25 as costo_mantenimiento_anual_unitario,  -- 25% del precio por año
        
        -- Costo de pedido (estimado)
        CASE 
            WHEN clasificacion_volumen = 1 THEN 200  -- Productos A: mayor costo de gestión
            WHEN clasificacion_volumen = 2 THEN 150  -- Productos B
            ELSE 100  -- Productos C
        END as costo_pedido_estimado
        
    FROM metricas_inventario
),

optimizacion_final AS (
    -- PASO 4: Cálculos finales de optimización
    SELECT *,
        -- Punto de reorden
        CEILING(demanda_lead_time + stock_seguridad) as punto_reorden,
        
        -- Cantidad óptima de pedido (EOQ simplificado)
        CASE 
            WHEN demanda_mensual_reciente > 0 AND costo_mantenimiento_anual_unitario > 0
            THEN CEILING(
                SQRT(
                    2 * (demanda_mensual_reciente * 12) * costo_pedido_estimado / 
                    costo_mantenimiento_anual_unitario
                )
            )
            ELSE CEILING(demanda_mensual_reciente * 2)  -- Fallback: 2 meses de demanda
        END as cantidad_optima_pedido,
        
        -- Stock máximo recomendado
        CEILING(demanda_lead_time + stock_seguridad) + 
        CASE 
            WHEN demanda_mensual_reciente > 0 AND costo_mantenimiento_anual_unitario > 0
            THEN CEILING(
                SQRT(
                    2 * (demanda_mensual_reciente * 12) * costo_pedido_estimado / 
                    costo_mantenimiento_anual_unitario
                )
            )
            ELSE CEILING(demanda_mensual_reciente * 2)
        END as stock_maximo_recomendado,
        
        -- Criticidad del producto
        CASE 
            WHEN clasificacion_volumen = 1 AND clasificacion_ingresos = 1 THEN 'CRÍTICO'
            WHEN clasificacion_volumen <= 2 AND clasificacion_ingresos <= 2 THEN 'IMPORTANTE'
            ELSE 'NORMAL'
        END as criticidad_producto,
        
        -- Estado actual del inventario
        CASE 
            WHEN stock_actual <= 0 THEN 'SIN STOCK'
            WHEN stock_actual <= (demanda_lead_time + stock_seguridad) THEN 'REABASTECER URGENTE'
            WHEN dias_inventario_restante <= 14 THEN 'REABASTECER PRONTO'
            WHEN stock_actual > (demanda_lead_time + stock_seguridad) * 3 THEN 'SOBRESTOCK'
            WHEN dias_inventario_restante > 120 THEN 'POSIBLE OBSOLESCENCIA'
            ELSE 'NORMAL'
        END as estado_inventario,
        
        -- Costo de oportunidad por faltantes
        (demanda_mensual_reciente * precio * 0.1) as costo_oportunidad_mensual_faltante
        
    FROM calculos_optimizacion
)

SELECT 
    estado_inventario,
    COUNT(*) as num_productos,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) as porcentaje_productos,
    
    -- Métricas financieras
    '$' || ROUND(SUM(valor_inventario_actual)::NUMERIC, 2) as valor_total_inventario,
    '$' || ROUND(AVG(valor_inventario_actual)::NUMERIC, 2) as valor_promedio_producto,
    '$' || ROUND(SUM(ingresos_trimestre)::NUMERIC, 2) as ingresos_trimestre_categoria,
    
    -- Métricas operativas
    SUM(stock_actual) as unidades_totales,
    ROUND(AVG(dias_inventario_restante), 1) as dias_promedio_restantes,
    ROUND(AVG(rotacion_anual), 2) as rotacion_promedio,
    
    -- Impacto financiero
    '$' || ROUND(SUM(costo_oportunidad_mensual_faltante)::NUMERIC, 2) as costo_oportunidad_total,
    
    -- Distribución por criticidad
    COUNT(CASE WHEN criticidad_producto = 'CRÍTICO' THEN 1 END) as productos_criticos,
    COUNT(CASE WHEN criticidad_producto = 'IMPORTANTE' THEN 1 END) as productos_importantes,
    
    -- Recomendaciones por categoría
    CASE 
        WHEN estado_inventario = 'SIN STOCK' 
        THEN 'Acción inmediata: Revisar procesos de reabastecimiento'
        WHEN estado_inventario = 'REABASTECER URGENTE' 
        THEN 'Acelerar pedidos pendientes y ajustar puntos de reorden'
        WHEN estado_inventario = 'SOBRESTOCK' 
        THEN 'Implementar promociones y revisar pronósticos de demanda'
        WHEN estado_inventario = 'POSIBLE OBSOLESCENCIA' 
        THEN 'Evaluar descontinuación y estrategias de liquidación'
        ELSE 'Mantener monitoreo regular'
    END as recomendacion_categoria
    
FROM optimizacion_final
WHERE total_vendido_historico > 0
GROUP BY estado_inventario
ORDER BY 
    CASE estado_inventario
        WHEN 'SIN STOCK' THEN 1
        WHEN 'REABASTECER URGENTE' THEN 2
        WHEN 'REABASTECER PRONTO' THEN 3
        WHEN 'NORMAL' THEN 4
        WHEN 'SOBRESTOCK' THEN 5
        WHEN 'POSIBLE OBSOLESCENCIA' THEN 6
        ELSE 7
    END;

-- =====================================================
-- ANÁLISIS DE OBSOLESCENCIA Y PRODUCTOS LENTOS
-- =====================================================

-- Redefinir CTEs necesarios para esta query independiente
WITH analisis_demanda AS (
    -- PASO 1: Analizar patrones de demanda histórica
    SELECT 
        p.id as producto_id,
        p.nombre as producto,
        p.categoria,
        p.stock as stock_actual,
        p.precio,
        
        -- Métricas de venta agregadas
        COUNT(v.id) as num_transacciones,
        SUM(v.cantidad) as total_vendido_historico,
        AVG(v.cantidad) as promedio_por_transaccion,
        STDDEV_SAMP(v.cantidad) as desviacion_cantidad,
        
        -- Análisis temporal detallado
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '7 days' THEN v.cantidad ELSE 0 END) as ventas_ultima_semana,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '1 month' THEN v.cantidad ELSE 0 END) as ventas_ultimo_mes,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_trimestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '6 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_semestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months' THEN v.cantidad ELSE 0 END) as ventas_ultimo_año,
        
        -- Análisis de ingresos
        SUM(v.cantidad * v.precio_unitario * (1 - v.descuento/100)) as ingresos_totales,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '3 months' 
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100) ELSE 0 END) as ingresos_trimestre,
        SUM(CASE WHEN v.fecha_venta >= CURRENT_DATE - INTERVAL '12 months' 
            THEN v.cantidad * v.precio_unitario * (1 - v.descuento/100) ELSE 0 END) as ingresos_año,
            
        -- Fechas de referencia
        MAX(v.fecha_venta) as ultima_venta,
        MIN(v.fecha_venta) as primera_venta,
        
        -- Conteo de meses con ventas
        COUNT(DISTINCT DATE_TRUNC('month', v.fecha_venta)) as meses_con_ventas
        
    FROM productos p
    LEFT JOIN ventas v ON p.id = v.producto_id
    GROUP BY p.id, p.nombre, p.categoria, p.stock, p.precio
),

metricas_inventario AS (
    -- PASO 2: Calcular métricas clave de inventario
    SELECT *,
        -- Demanda promedio en diferentes períodos
        CASE WHEN meses_con_ventas > 0 THEN ventas_ultimo_año / 12.0 ELSE 0 END as demanda_mensual_promedio,
        CASE WHEN ventas_ultimo_trimestre > 0 THEN ventas_ultimo_trimestre / 3.0 ELSE 0 END as demanda_mensual_reciente,
        CASE WHEN ventas_ultima_semana > 0 THEN ventas_ultima_semana ELSE 0 END as demanda_semanal_actual,
        
        -- Velocidad de rotación
        CASE 
            WHEN stock_actual > 0 AND ventas_ultimo_mes > 0
            THEN ventas_ultimo_mes / stock_actual
            ELSE 0
        END as rotacion_mensual,
        
        CASE 
            WHEN stock_actual > 0 AND ventas_ultimo_año > 0
            THEN ventas_ultimo_año / stock_actual
            ELSE 0
        END as rotacion_anual,
        
        -- Días de inventario restante
        CASE 
            WHEN ventas_ultimo_mes > 0 
            THEN stock_actual * 30.0 / ventas_ultimo_mes
            WHEN ventas_ultimo_trimestre > 0
            THEN stock_actual * 90.0 / ventas_ultimo_trimestre
            ELSE 999
        END as dias_inventario_restante,
        
        -- Tendencia de demanda (comparando trimestres)
        CASE 
            WHEN ventas_ultimo_trimestre > 0 AND ventas_ultimo_año > ventas_ultimo_trimestre
            THEN (ventas_ultimo_trimestre * 4.0) / (ventas_ultimo_año - ventas_ultimo_trimestre) * 3.0 - 1
            ELSE 0
        END as tendencia_demanda_ratio,
        
        -- Valor del inventario
        stock_actual * precio as valor_inventario_actual,
        
        -- Clasificación ABC por volumen e ingresos
        NTILE(3) OVER (ORDER BY total_vendido_historico DESC) as clasificacion_volumen,
        NTILE(3) OVER (ORDER BY ingresos_totales DESC) as clasificacion_ingresos
        
    FROM analisis_demanda
),

calculos_optimizacion AS (
    -- PASO 3: Cálculos de optimización de inventario
    SELECT *,
        -- Clasificación de tendencia
        CASE 
            WHEN tendencia_demanda_ratio > 0.2 THEN 'Creciente'
            WHEN tendencia_demanda_ratio < -0.2 THEN 'Decreciente'
            ELSE 'Estable'
        END as tendencia_demanda,
        
        -- Lead time estimado (simulado - en realidad vendría de datos de proveedores)
        CASE 
            WHEN categoria = 'Electrónicos' THEN 14  -- 2 semanas
            WHEN categoria = 'Accesorios' THEN 7     -- 1 semana
            WHEN categoria = 'Oficina' THEN 10       -- 1.5 semanas
            ELSE 10  -- Default
        END as lead_time_dias,
        
        -- Demanda durante lead time
        CASE 
            WHEN demanda_mensual_reciente > 0
            THEN (CASE 
                WHEN categoria = 'Electrónicos' THEN demanda_mensual_reciente * 14.0 / 30.0
                WHEN categoria = 'Accesorios' THEN demanda_mensual_reciente * 7.0 / 30.0
                WHEN categoria = 'Oficina' THEN demanda_mensual_reciente * 10.0 / 30.0
                ELSE demanda_mensual_reciente * 10.0 / 30.0
            END)
            ELSE 0
        END as demanda_lead_time,
        
        -- Stock de seguridad (1.5x la demanda semanal para productos A, menos para otros)
        CASE 
            WHEN clasificacion_volumen = 1 AND clasificacion_ingresos = 1  -- Productos A
            THEN demanda_mensual_reciente * 7.0 / 30.0 * 2.0  -- 2 semanas de seguridad
            WHEN clasificacion_volumen <= 2 AND clasificacion_ingresos <= 2  -- Productos B
            THEN demanda_mensual_reciente * 7.0 / 30.0 * 1.5  -- 1.5 semanas de seguridad
            ELSE demanda_mensual_reciente * 7.0 / 30.0 * 1.0  -- 1 semana de seguridad
        END as stock_seguridad,
        
        -- Costo de mantener inventario (estimado como % del precio)
        precio * 0.25 as costo_mantenimiento_anual_unitario,  -- 25% del precio por año
        
        -- Costo de pedido (estimado)
        CASE 
            WHEN clasificacion_volumen = 1 THEN 200  -- Productos A: mayor costo de gestión
            WHEN clasificacion_volumen = 2 THEN 150  -- Productos B
            ELSE 100  -- Productos C
        END as costo_pedido_estimado
        
    FROM metricas_inventario
),

optimizacion_final AS (
    -- PASO 4: Cálculos finales de optimización
    SELECT *,
        -- Punto de reorden
        CEILING(demanda_lead_time + stock_seguridad) as punto_reorden,
        
        -- Cantidad óptima de pedido (EOQ simplificado)
        CASE 
            WHEN demanda_mensual_reciente > 0 AND costo_mantenimiento_anual_unitario > 0
            THEN CEILING(
                SQRT(
                    2 * (demanda_mensual_reciente * 12) * costo_pedido_estimado / 
                    costo_mantenimiento_anual_unitario
                )
            )
            ELSE CEILING(demanda_mensual_reciente * 2)  -- Fallback: 2 meses de demanda
        END as cantidad_optima_pedido,
        
        -- Stock máximo recomendado
        CEILING(demanda_lead_time + stock_seguridad) + 
        CASE 
            WHEN demanda_mensual_reciente > 0 AND costo_mantenimiento_anual_unitario > 0
            THEN CEILING(
                SQRT(
                    2 * (demanda_mensual_reciente * 12) * costo_pedido_estimado / 
                    costo_mantenimiento_anual_unitario
                )
            )
            ELSE CEILING(demanda_mensual_reciente * 2)
        END as stock_maximo_recomendado,
        
        -- Criticidad del producto
        CASE 
            WHEN clasificacion_volumen = 1 AND clasificacion_ingresos = 1 THEN 'CRÍTICO'
            WHEN clasificacion_volumen <= 2 AND clasificacion_ingresos <= 2 THEN 'IMPORTANTE'
            ELSE 'NORMAL'
        END as criticidad_producto,
        
        -- Estado actual del inventario
        CASE 
            WHEN stock_actual <= 0 THEN 'SIN STOCK'
            WHEN stock_actual <= (demanda_lead_time + stock_seguridad) THEN 'REABASTECER URGENTE'
            WHEN dias_inventario_restante <= 14 THEN 'REABASTECER PRONTO'
            WHEN stock_actual > (demanda_lead_time + stock_seguridad) * 3 THEN 'SOBRESTOCK'
            WHEN dias_inventario_restante > 120 THEN 'POSIBLE OBSOLESCENCIA'
            ELSE 'NORMAL'
        END as estado_inventario,
        
        -- Costo de oportunidad por faltantes
        (demanda_mensual_reciente * precio * 0.1) as costo_oportunidad_mensual_faltante
        
    FROM calculos_optimizacion
),

analisis_obsolescencia AS (
    SELECT 
        producto,
        categoria,
        stock_actual,
        '$' || ROUND(valor_inventario_actual::NUMERIC, 2) as valor_inventario,
        dias_inventario_restante,
        ultima_venta,
        EXTRACT(DAY FROM AGE(CURRENT_DATE, ultima_venta)) as dias_sin_venta,
        rotacion_anual,
        tendencia_demanda,
        
        -- Puntuación de riesgo de obsolescencia
        (
            CASE WHEN dias_inventario_restante > 365 THEN 40 ELSE dias_inventario_restante / 365.0 * 40 END +
            CASE WHEN EXTRACT(DAY FROM AGE(CURRENT_DATE, ultima_venta)) > 180 THEN 30 ELSE EXTRACT(DAY FROM AGE(CURRENT_DATE, ultima_venta)) / 180.0 * 30 END +
            CASE WHEN rotacion_anual < 2 THEN 20 ELSE (4 - rotacion_anual) / 2.0 * 20 END +
            CASE WHEN tendencia_demanda = 'Decreciente' THEN 10 ELSE 0 END
        ) as score_riesgo_obsolescencia,
        
        -- Valor en riesgo
        valor_inventario_actual as valor_en_riesgo
        
    FROM optimizacion_final
    WHERE total_vendido_historico > 0
      AND (dias_inventario_restante > 90 OR rotacion_anual < 4 OR EXTRACT(DAY FROM AGE(CURRENT_DATE, ultima_venta)) > 60)
)
SELECT 
    producto,
    categoria,
    stock_actual,
    valor_inventario,
    dias_inventario_restante,
    dias_sin_venta,
    ROUND(rotacion_anual, 2) as rotacion_anual,
    tendencia_demanda,
    ROUND(score_riesgo_obsolescencia, 1) as score_riesgo,
    
    -- Clasificación de riesgo
    CASE 
        WHEN score_riesgo_obsolescencia >= 80 THEN 'RIESGO MUY ALTO'
        WHEN score_riesgo_obsolescencia >= 60 THEN 'RIESGO ALTO'
        WHEN score_riesgo_obsolescencia >= 40 THEN 'RIESGO MEDIO'
        ELSE 'RIESGO BAJO'
    END as clasificacion_riesgo,
    
    -- Acciones recomendadas
    CASE 
        WHEN score_riesgo_obsolescencia >= 80 
        THEN 'Liquidar inmediatamente con descuentos agresivos'
        WHEN score_riesgo_obsolescencia >= 60 
        THEN 'Promoción intensiva o considerar liquidación'
        WHEN score_riesgo_obsolescencia >= 40 
        THEN 'Reducir precio y acelerar rotación'
        ELSE 'Monitoreo cercano y ajuste de inventario'
    END as accion_recomendada_obsolescencia,
    
    -- Descuento sugerido para acelerar rotación
    CASE 
        WHEN score_riesgo_obsolescencia >= 80 THEN '40-60%'
        WHEN score_riesgo_obsolescencia >= 60 THEN '25-40%'
        WHEN score_riesgo_obsolescencia >= 40 THEN '15-25%'
        ELSE '5-15%'
    END as descuento_sugerido
    
FROM analisis_obsolescencia
ORDER BY score_riesgo_obsolescencia DESC, valor_en_riesgo DESC;

/*
RESULTADOS ESPERADOS:
- Optimización completa de niveles de inventario
- Alertas automáticas de reabastecimiento
- Identificación de productos con riesgo de obsolescencia
- Cálculos de EOQ y puntos de reorden optimizados

MÉTRICAS CLAVE:
- Punto de reorden y cantidad óptima de pedido
- Velocidad de rotación y días de inventario
- Clasificación ABC de productos
- Análisis de tendencias de demanda
- Costos de oportunidad por faltantes
*/