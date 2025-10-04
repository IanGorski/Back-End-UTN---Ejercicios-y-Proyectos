-- =====================================================
-- QUERY 6: ANÁLISIS DE SERIES TEMPORALES CON TENDENCIAS
-- =====================================================

/*
PROBLEMA:
Analizar tendencias de ventas mensuales con pronósticos usando
regresión lineal simple, análisis de estacionalidad y detección
de patrones temporales para planificación estratégica.

TÉCNICAS UTILIZADAS:
- Análisis de series temporales
- Medias móviles para suavizado
- Cálculo de índices estacionales
- Regresión lineal simple
- Análisis de crecimiento y tendencias
- Clasificación de períodos

CASOS DE USO:
- Planificación de demanda
- Presupuestos y forecasting
- Análisis de estacionalidad
- Estrategias de marketing temporal
- Optimización de recursos
*/

WITH ventas_mensuales AS (
    -- PASO 1: Agregar ventas por mes
    SELECT 
        EXTRACT(YEAR FROM fecha_venta)::INTEGER as año,
        EXTRACT(MONTH FROM fecha_venta)::INTEGER as mes,
        DATE_TRUNC('month', fecha_venta)::DATE as fecha_mes,
        SUM(cantidad * precio_unitario * (1 - descuento/100)) as ventas_mes,
        COUNT(*) as num_transacciones,
        COUNT(DISTINCT empleado_id) as empleados_activos,
        AVG(cantidad * precio_unitario * (1 - descuento/100)) as ticket_promedio,
        SUM(cantidad) as unidades_vendidas
    FROM ventas
    GROUP BY EXTRACT(YEAR FROM fecha_venta), EXTRACT(MONTH FROM fecha_venta), DATE_TRUNC('month', fecha_venta)
),

series_con_periodo AS (
    -- PASO 2: Agregar numeración secuencial y períodos anteriores
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY fecha_mes) as periodo,
        LAG(ventas_mes, 1) OVER (ORDER BY fecha_mes) as ventas_mes_anterior,
        LAG(ventas_mes, 12) OVER (ORDER BY fecha_mes) as ventas_año_anterior,
        LAG(ventas_mes, 3) OVER (ORDER BY fecha_mes) as ventas_3_meses_atras
    FROM ventas_mensuales
),

calculos_tendencia AS (
    -- PASO 3: Calcular tendencias y crecimientos
    SELECT *,
        -- Crecimiento mensual
        CASE 
            WHEN ventas_mes_anterior IS NOT NULL AND ventas_mes_anterior > 0
            THEN (ventas_mes - ventas_mes_anterior) * 100.0 / ventas_mes_anterior
            ELSE NULL 
        END as crecimiento_mensual,
        
        -- Crecimiento anual
        CASE 
            WHEN ventas_año_anterior IS NOT NULL AND ventas_año_anterior > 0
            THEN (ventas_mes - ventas_año_anterior) * 100.0 / ventas_año_anterior
            ELSE NULL 
        END as crecimiento_anual,
        
        -- Media móvil de 3 meses
        AVG(ventas_mes) OVER (
            ORDER BY fecha_mes 
            ROWS 2 PRECEDING
        ) as media_movil_3,
        
        -- Media móvil de 6 meses
        AVG(ventas_mes) OVER (
            ORDER BY fecha_mes 
            ROWS 5 PRECEDING
        ) as media_movil_6,
        
        -- Media móvil de 12 meses
        AVG(ventas_mes) OVER (
            ORDER BY fecha_mes 
            ROWS 11 PRECEDING
        ) as media_movil_12
        
    FROM series_con_periodo
),

calculos_pendiente AS (
    -- Calcular valores necesarios para la pendiente
    SELECT *,
        -- Promedios para cálculo de regresión lineal
        AVG(periodo) OVER () as periodo_promedio,
        AVG(ventas_mes) OVER () as ventas_promedio,
        AVG(periodo * periodo) OVER () as periodo_cuadrado_promedio
    FROM calculos_tendencia
),

calculos_con_pendiente AS (
    -- Calcular pendiente de tendencia lineal
    SELECT *,
        -- Pendiente: (período * ventas - promedio_período * promedio_ventas) / (período² - promedio_período²)
        (periodo * ventas_mes - periodo_promedio * ventas_promedio) /
        NULLIF((periodo * periodo - periodo_cuadrado_promedio), 0) as pendiente_tendencia
    FROM calculos_pendiente
),

analisis_estacional AS (
    -- PASO 4: Análisis de estacionalidad
    SELECT *,
        -- Índice estacional (comparación con promedio anual)
        CASE 
            WHEN AVG(ventas_mes) OVER (PARTITION BY año) > 0
            THEN ventas_mes / AVG(ventas_mes) OVER (PARTITION BY año)
            ELSE 1
        END as indice_estacional,
        
        -- Promedio histórico por mes del año
        AVG(ventas_mes) OVER (PARTITION BY mes) as promedio_historico_mes,
        
        -- Desviación de la tendencia
        ventas_mes - media_movil_6 as desviacion_tendencia,
        
        -- Coeficiente de variación mensual
        CASE 
            WHEN AVG(ventas_mes) OVER (PARTITION BY mes) > 0
            THEN STDDEV_SAMP(ventas_mes) OVER (PARTITION BY mes) / AVG(ventas_mes) OVER (PARTITION BY mes)
            ELSE 0
        END as coef_variacion_mes,
        
        -- Volatilidad (desviación estándar móvil)
        STDDEV_SAMP(ventas_mes) OVER (
            ORDER BY fecha_mes 
            ROWS 5 PRECEDING
        ) as volatilidad_6_meses
        
    FROM calculos_con_pendiente
),

clasificacion_periodos AS (
    -- PASO 5: Clasificar períodos según rendimiento
    SELECT *,
        -- Clasificación de rendimiento vs tendencia
        CASE 
            WHEN ventas_mes > media_movil_6 * 1.15 THEN 'EXCELENTE'
            WHEN ventas_mes > media_movil_6 * 1.10 THEN 'MUY BUENO'
            WHEN ventas_mes > media_movil_6 * 1.05 THEN 'BUENO'
            WHEN ventas_mes > media_movil_6 * 0.95 THEN 'NORMAL'
            WHEN ventas_mes > media_movil_6 * 0.90 THEN 'BAJO'
            ELSE 'CRÍTICO'
        END as clasificacion_rendimiento,
        
        -- Clasificación estacional
        CASE 
            WHEN indice_estacional > 1.3 THEN 'TEMPORADA ALTA'
            WHEN indice_estacional > 1.15 THEN 'TEMPORADA MEDIA-ALTA'
            WHEN indice_estacional > 0.85 THEN 'TEMPORADA NORMAL'
            WHEN indice_estacional > 0.7 THEN 'TEMPORADA MEDIA-BAJA'
            ELSE 'TEMPORADA BAJA'
        END as clasificacion_estacional,
        
        -- Tendencia direccional
        CASE 
            WHEN crecimiento_anual > 20 THEN 'CRECIMIENTO ACELERADO'
            WHEN crecimiento_anual > 10 THEN 'CRECIMIENTO FUERTE'
            WHEN crecimiento_anual > 5 THEN 'CRECIMIENTO MODERADO'
            WHEN crecimiento_anual > -5 THEN 'ESTABLE'
            WHEN crecimiento_anual > -15 THEN 'DECLIVE MODERADO'
            ELSE 'DECLIVE FUERTE'
        END as tendencia_direccional,
        
        -- Predicción simple para próximo mes (basada en tendencia)
        media_movil_3 + (pendiente_tendencia * (periodo + 1)) as prediccion_proximo_mes
        
    FROM analisis_estacional
)

-- RESULTADO PRINCIPAL: Análisis completo de series temporales
SELECT 
    año,
    mes,
    '$' || ROUND(ventas_mes::NUMERIC, 2) as ventas_mes,
    num_transacciones,
    empleados_activos,
    '$' || ROUND(ticket_promedio::NUMERIC, 2) as ticket_promedio,
    
    -- Análisis de crecimiento
    ROUND(crecimiento_mensual::NUMERIC, 2) as crecimiento_mensual_pct,
    ROUND(crecimiento_anual::NUMERIC, 2) as crecimiento_anual_pct,
    tendencia_direccional,
    
    -- Medias móviles para suavizado
    '$' || ROUND(media_movil_3::NUMERIC, 2) as media_movil_3_meses,
    '$' || ROUND(media_movil_6::NUMERIC, 2) as media_movil_6_meses,
    '$' || ROUND(media_movil_12::NUMERIC, 2) as media_movil_12_meses,
    
    -- Análisis estacional
    ROUND(indice_estacional::NUMERIC, 3) as indice_estacional,
    clasificacion_estacional,
    '$' || ROUND(promedio_historico_mes::NUMERIC, 2) as promedio_historico_mes,
    
    -- Evaluación de rendimiento
    clasificacion_rendimiento,
    ROUND(ABS(desviacion_tendencia)::NUMERIC, 0) as desviacion_tendencia,
    ROUND(volatilidad_6_meses::NUMERIC, 0) as volatilidad,
    
    -- Predicción y pronóstico
    '$' || ROUND(prediccion_proximo_mes::NUMERIC, 2) as prediccion_proximo_mes,
    
    -- Interpretaciones y recomendaciones
    CASE 
        WHEN clasificacion_rendimiento IN ('EXCELENTE', 'MUY BUENO') AND 
             clasificacion_estacional = 'TEMPORADA ALTA'
        THEN 'Aprovechar momentum: intensificar marketing y stock'
        WHEN clasificacion_rendimiento = 'CRÍTICO' 
        THEN 'Acción urgente: revisar estrategia y causas del declive'
        WHEN tendencia_direccional LIKE '%CRECIMIENTO%' 
        THEN 'Mantener estrategia actual y preparar escalamiento'
        WHEN tendencia_direccional LIKE '%DECLIVE%' 
        THEN 'Revisar estrategia de mercado y optimizar operaciones'
        WHEN clasificacion_estacional = 'TEMPORADA BAJA' 
        THEN 'Período de preparación: capacitación y mejoras'
        ELSE 'Monitoreo continuo y ajustes tácticos'
    END as recomendacion_estrategica,
    
    -- Alertas automáticas
    CASE 
        WHEN ABS(desviacion_tendencia) > volatilidad_6_meses * 2 
        THEN 'ALERTA: Desviación significativa de tendencia'
        WHEN crecimiento_mensual < -25 
        THEN 'ALERTA: Caída drástica mensual'
        WHEN crecimiento_anual < -20 
        THEN 'ALERTA: Declive anual preocupante'
        WHEN volatilidad_6_meses > media_movil_6 * 0.3 
        THEN 'ALERTA: Alta volatilidad detectada'
        ELSE 'Sin alertas'
    END as alertas_automaticas
    
FROM clasificacion_periodos
ORDER BY año DESC, mes DESC;

-- =====================================================
-- ANÁLISIS ESTACIONAL DETALLADO
-- =====================================================

WITH ventas_mensuales AS (
    SELECT 
        EXTRACT(YEAR FROM fecha_venta)::INTEGER as año,
        EXTRACT(MONTH FROM fecha_venta)::INTEGER as mes,
        DATE_TRUNC('month', fecha_venta)::DATE as fecha_mes,
        SUM(cantidad * precio_unitario * (1 - descuento/100)) as ventas_mes,
        COUNT(*) as num_transacciones,
        COUNT(DISTINCT empleado_id) as empleados_activos,
        AVG(cantidad * precio_unitario * (1 - descuento/100)) as ticket_promedio,
        SUM(cantidad) as unidades_vendidas
    FROM ventas
    GROUP BY EXTRACT(YEAR FROM fecha_venta), EXTRACT(MONTH FROM fecha_venta), DATE_TRUNC('month', fecha_venta)
),
series_con_periodo AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY fecha_mes) as periodo,
        LAG(ventas_mes, 1) OVER (ORDER BY fecha_mes) as ventas_mes_anterior,
        LAG(ventas_mes, 12) OVER (ORDER BY fecha_mes) as ventas_año_anterior,
        LAG(ventas_mes, 3) OVER (ORDER BY fecha_mes) as ventas_3_meses_atras
    FROM ventas_mensuales
),
calculos_tendencia AS (
    SELECT *,
        CASE 
            WHEN ventas_mes_anterior IS NOT NULL AND ventas_mes_anterior > 0
            THEN (ventas_mes - ventas_mes_anterior) * 100.0 / ventas_mes_anterior
            ELSE NULL 
        END as crecimiento_mensual,
        CASE 
            WHEN ventas_año_anterior IS NOT NULL AND ventas_año_anterior > 0
            THEN (ventas_mes - ventas_año_anterior) * 100.0 / ventas_año_anterior
            ELSE NULL 
        END as crecimiento_anual,
        AVG(ventas_mes) OVER (ORDER BY fecha_mes ROWS 2 PRECEDING) as media_movil_3,
        AVG(ventas_mes) OVER (ORDER BY fecha_mes ROWS 5 PRECEDING) as media_movil_6,
        AVG(ventas_mes) OVER (ORDER BY fecha_mes ROWS 11 PRECEDING) as media_movil_12
    FROM series_con_periodo
),
calculos_pendiente AS (
    SELECT *,
        AVG(periodo) OVER () as periodo_promedio,
        AVG(ventas_mes) OVER () as ventas_promedio,
        AVG(periodo * periodo) OVER () as periodo_cuadrado_promedio
    FROM calculos_tendencia
),
calculos_con_pendiente AS (
    SELECT *,
        (periodo * ventas_mes - periodo_promedio * ventas_promedio) /
        NULLIF((periodo * periodo - periodo_cuadrado_promedio), 0) as pendiente_tendencia
    FROM calculos_pendiente
),
analisis_estacional AS (
    SELECT *,
        CASE 
            WHEN AVG(ventas_mes) OVER (PARTITION BY año) > 0
            THEN ventas_mes / AVG(ventas_mes) OVER (PARTITION BY año)
            ELSE 1
        END as indice_estacional,
        AVG(ventas_mes) OVER (PARTITION BY mes) as promedio_historico_mes,
        ventas_mes - media_movil_6 as desviacion_tendencia,
        CASE 
            WHEN AVG(ventas_mes) OVER (PARTITION BY mes) > 0
            THEN STDDEV_SAMP(ventas_mes) OVER (PARTITION BY mes) / AVG(ventas_mes) OVER (PARTITION BY mes)
            ELSE 0
        END as coef_variacion_mes,
        STDDEV_SAMP(ventas_mes) OVER (ORDER BY fecha_mes ROWS 5 PRECEDING) as volatilidad_6_meses
    FROM calculos_con_pendiente
),
clasificacion_periodos AS (
    SELECT *,
        CASE 
            WHEN ventas_mes > media_movil_6 * 1.15 THEN 'EXCELENTE'
            WHEN ventas_mes > media_movil_6 * 1.10 THEN 'MUY BUENO'
            WHEN ventas_mes > media_movil_6 * 1.05 THEN 'BUENO'
            WHEN ventas_mes > media_movil_6 * 0.95 THEN 'NORMAL'
            WHEN ventas_mes > media_movil_6 * 0.90 THEN 'BAJO'
            ELSE 'CRÍTICO'
        END as clasificacion_rendimiento,
        CASE 
            WHEN indice_estacional > 1.3 THEN 'TEMPORADA ALTA'
            WHEN indice_estacional > 1.15 THEN 'TEMPORADA MEDIA-ALTA'
            WHEN indice_estacional > 0.85 THEN 'TEMPORADA NORMAL'
            WHEN indice_estacional > 0.7 THEN 'TEMPORADA MEDIA-BAJA'
            ELSE 'TEMPORADA BAJA'
        END as clasificacion_estacional,
        CASE 
            WHEN crecimiento_anual > 20 THEN 'CRECIMIENTO ACELERADO'
            WHEN crecimiento_anual > 10 THEN 'CRECIMIENTO FUERTE'
            WHEN crecimiento_anual > 5 THEN 'CRECIMIENTO MODERADO'
            WHEN crecimiento_anual > -5 THEN 'ESTABLE'
            WHEN crecimiento_anual > -15 THEN 'DECLIVE MODERADO'
            ELSE 'DECLIVE FUERTE'
        END as tendencia_direccional,
        media_movil_3 + (pendiente_tendencia * (periodo + 1)) as prediccion_proximo_mes
    FROM analisis_estacional
)
SELECT 
    mes,
    CASE mes
        WHEN 1 THEN 'Enero'
        WHEN 2 THEN 'Febrero'
        WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Mayo'
        WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre'
        WHEN 11 THEN 'Noviembre'
        WHEN 12 THEN 'Diciembre'
    END as nombre_mes,
    
    COUNT(*) as años_datos,
    '$' || ROUND(AVG(ventas_mes)::NUMERIC, 2) as promedio_historico,
    ROUND(AVG(indice_estacional)::NUMERIC, 3) as indice_estacional_promedio,
    ROUND(STDDEV_SAMP(ventas_mes)::NUMERIC, 0) as desviacion_estandar,
    '$' || ROUND(MIN(ventas_mes)::NUMERIC, 2) as minimo_historico,
    '$' || ROUND(MAX(ventas_mes)::NUMERIC, 2) as maximo_historico,
    
    -- Clasificación del mes
    CASE 
        WHEN AVG(indice_estacional) > 1.2 THEN 'MES DE ALTA TEMPORADA'
        WHEN AVG(indice_estacional) > 1.1 THEN 'MES SOBRE PROMEDIO'
        WHEN AVG(indice_estacional) > 0.9 THEN 'MES NORMAL'
        WHEN AVG(indice_estacional) > 0.8 THEN 'MES BAJO PROMEDIO'
        ELSE 'MES DE BAJA TEMPORADA'
    END as caracterizacion_mes,
    
    -- Recomendaciones por mes
    CASE 
        WHEN AVG(indice_estacional) > 1.2 
        THEN 'Mes clave: maximizar inventario y marketing'
        WHEN AVG(indice_estacional) < 0.8 
        THEN 'Mes bajo: enfoque en eficiencia y preparación'
        ELSE 'Mes estándar: operaciones normales'
    END as estrategia_mensual
    
FROM clasificacion_periodos
GROUP BY mes
ORDER BY AVG(indice_estacional) DESC;

-- =====================================================
-- RESUMEN EJECUTIVO DE TENDENCIAS
-- =====================================================

WITH ventas_mensuales AS (
    SELECT 
        EXTRACT(YEAR FROM fecha_venta)::INTEGER as año,
        EXTRACT(MONTH FROM fecha_venta)::INTEGER as mes,
        DATE_TRUNC('month', fecha_venta)::DATE as fecha_mes,
        SUM(cantidad * precio_unitario * (1 - descuento/100)) as ventas_mes,
        COUNT(*) as num_transacciones,
        COUNT(DISTINCT empleado_id) as empleados_activos,
        AVG(cantidad * precio_unitario * (1 - descuento/100)) as ticket_promedio,
        SUM(cantidad) as unidades_vendidas
    FROM ventas
    GROUP BY EXTRACT(YEAR FROM fecha_venta), EXTRACT(MONTH FROM fecha_venta), DATE_TRUNC('month', fecha_venta)
),
series_con_periodo AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY fecha_mes) as periodo,
        LAG(ventas_mes, 1) OVER (ORDER BY fecha_mes) as ventas_mes_anterior,
        LAG(ventas_mes, 12) OVER (ORDER BY fecha_mes) as ventas_año_anterior,
        LAG(ventas_mes, 3) OVER (ORDER BY fecha_mes) as ventas_3_meses_atras
    FROM ventas_mensuales
),
calculos_tendencia AS (
    SELECT *,
        CASE 
            WHEN ventas_mes_anterior IS NOT NULL AND ventas_mes_anterior > 0
            THEN (ventas_mes - ventas_mes_anterior) * 100.0 / ventas_mes_anterior
            ELSE NULL 
        END as crecimiento_mensual,
        CASE 
            WHEN ventas_año_anterior IS NOT NULL AND ventas_año_anterior > 0
            THEN (ventas_mes - ventas_año_anterior) * 100.0 / ventas_año_anterior
            ELSE NULL 
        END as crecimiento_anual,
        AVG(ventas_mes) OVER (ORDER BY fecha_mes ROWS 2 PRECEDING) as media_movil_3,
        AVG(ventas_mes) OVER (ORDER BY fecha_mes ROWS 5 PRECEDING) as media_movil_6,
        AVG(ventas_mes) OVER (ORDER BY fecha_mes ROWS 11 PRECEDING) as media_movil_12
    FROM series_con_periodo
),
calculos_pendiente AS (
    SELECT *,
        AVG(periodo) OVER () as periodo_promedio,
        AVG(ventas_mes) OVER () as ventas_promedio,
        AVG(periodo * periodo) OVER () as periodo_cuadrado_promedio
    FROM calculos_tendencia
),
calculos_con_pendiente AS (
    SELECT *,
        (periodo * ventas_mes - periodo_promedio * ventas_promedio) /
        NULLIF((periodo * periodo - periodo_cuadrado_promedio), 0) as pendiente_tendencia
    FROM calculos_pendiente
),
analisis_estacional AS (
    SELECT *,
        CASE 
            WHEN AVG(ventas_mes) OVER (PARTITION BY año) > 0
            THEN ventas_mes / AVG(ventas_mes) OVER (PARTITION BY año)
            ELSE 1
        END as indice_estacional,
        AVG(ventas_mes) OVER (PARTITION BY mes) as promedio_historico_mes,
        ventas_mes - media_movil_6 as desviacion_tendencia,
        CASE 
            WHEN AVG(ventas_mes) OVER (PARTITION BY mes) > 0
            THEN STDDEV_SAMP(ventas_mes) OVER (PARTITION BY mes) / AVG(ventas_mes) OVER (PARTITION BY mes)
            ELSE 0
        END as coef_variacion_mes,
        STDDEV_SAMP(ventas_mes) OVER (ORDER BY fecha_mes ROWS 5 PRECEDING) as volatilidad_6_meses
    FROM calculos_con_pendiente
),
clasificacion_periodos AS (
    SELECT *,
        CASE 
            WHEN ventas_mes > media_movil_6 * 1.15 THEN 'EXCELENTE'
            WHEN ventas_mes > media_movil_6 * 1.10 THEN 'MUY BUENO'
            WHEN ventas_mes > media_movil_6 * 1.05 THEN 'BUENO'
            WHEN ventas_mes > media_movil_6 * 0.95 THEN 'NORMAL'
            WHEN ventas_mes > media_movil_6 * 0.90 THEN 'BAJO'
            ELSE 'CRÍTICO'
        END as clasificacion_rendimiento,
        CASE 
            WHEN indice_estacional > 1.3 THEN 'TEMPORADA ALTA'
            WHEN indice_estacional > 1.15 THEN 'TEMPORADA MEDIA-ALTA'
            WHEN indice_estacional > 0.85 THEN 'TEMPORADA NORMAL'
            WHEN indice_estacional > 0.7 THEN 'TEMPORADA MEDIA-BAJA'
            ELSE 'TEMPORADA BAJA'
        END as clasificacion_estacional,
        CASE 
            WHEN crecimiento_anual > 20 THEN 'CRECIMIENTO ACELERADO'
            WHEN crecimiento_anual > 10 THEN 'CRECIMIENTO FUERTE'
            WHEN crecimiento_anual > 5 THEN 'CRECIMIENTO MODERADO'
            WHEN crecimiento_anual > -5 THEN 'ESTABLE'
            WHEN crecimiento_anual > -15 THEN 'DECLIVE MODERADO'
            ELSE 'DECLIVE FUERTE'
        END as tendencia_direccional,
        media_movil_3 + (pendiente_tendencia * (periodo + 1)) as prediccion_proximo_mes
    FROM analisis_estacional
),
metricas_resumen AS (
    SELECT 
        COUNT(*) as periodos_analizados,
        AVG(crecimiento_anual) as crecimiento_promedio_anual,
        STDDEV_SAMP(crecimiento_anual) as volatilidad_crecimiento,
        AVG(pendiente_tendencia) as tendencia_general,
        
        COUNT(CASE WHEN clasificacion_rendimiento IN ('EXCELENTE', 'MUY BUENO') THEN 1 END) as periodos_excelentes,
        COUNT(CASE WHEN clasificacion_rendimiento IN ('BAJO', 'CRÍTICO') THEN 1 END) as periodos_problematicos,
        
        MAX(ventas_mes) as pico_ventas,
        MIN(ventas_mes) as valle_ventas,
        AVG(volatilidad_6_meses) as volatilidad_promedio
        
    FROM clasificacion_periodos
    WHERE año >= EXTRACT(YEAR FROM CURRENT_DATE) - 2  -- Últimos 2 años
)
SELECT 
    periodos_analizados,
    ROUND(crecimiento_promedio_anual::NUMERIC, 2) as crecimiento_promedio_anual,
    ROUND(volatilidad_crecimiento::NUMERIC, 2) as volatilidad_crecimiento,
    
    '$' || ROUND(pico_ventas::NUMERIC, 2) as pico_ventas_historico,
    '$' || ROUND(valle_ventas::NUMERIC, 2) as valle_ventas_historico,
    '$' || ROUND((pico_ventas - valle_ventas)::NUMERIC, 2) as rango_variacion,
    
    ROUND((periodos_excelentes * 100.0 / periodos_analizados)::NUMERIC, 1) as porcentaje_periodos_excelentes,
    ROUND((periodos_problematicos * 100.0 / periodos_analizados)::NUMERIC, 1) as porcentaje_periodos_problematicos,
    
    -- Evaluación general del negocio
    CASE 
        WHEN crecimiento_promedio_anual > 15 AND volatilidad_crecimiento < 20 
        THEN 'NEGOCIO EN CRECIMIENTO SOSTENIBLE'
        WHEN crecimiento_promedio_anual > 5 
        THEN 'NEGOCIO EN CRECIMIENTO MODERADO'
        WHEN crecimiento_promedio_anual > -5 AND volatilidad_crecimiento < 30 
        THEN 'NEGOCIO ESTABLE'
        WHEN volatilidad_crecimiento > 40 
        THEN 'NEGOCIO VOLÁTIL - REQUIERE ESTABILIZACIÓN'
        ELSE 'NEGOCIO EN DECLIVE - ACCIÓN URGENTE'
    END as evaluacion_general_negocio,
    
    -- Recomendación estratégica principal
    CASE 
        WHEN crecimiento_promedio_anual > 10 
        THEN 'Acelerar crecimiento: invertir en expansión'
        WHEN crecimiento_promedio_anual > 0 
        THEN 'Consolidar posición: optimizar operaciones'
        WHEN volatilidad_crecimiento > 30 
        THEN 'Estabilizar operaciones: reducir volatilidad'
        ELSE 'Reestructurar estrategia: cambio fundamental requerido'
    END as recomendacion_estrategica_principal
    
FROM metricas_resumen;

/*
RESULTADOS ESPERADOS:
- Análisis completo de tendencias temporales
- Identificación de patrones estacionales
- Predicciones simples basadas en tendencias históricas
- Alertas automáticas para desviaciones significativas

MÉTRICAS CLAVE:
- Medias móviles para suavizado de tendencias
- Índices estacionales para planificación
- Tasas de crecimiento período a período
- Volatilidad y estabilidad del negocio
*/