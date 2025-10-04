-- =====================================================
-- QUERY 3: ANÁLISIS DE COHORTES DE CLIENTES (ADAPTADO PostgreSQL)
-- =====================================================

/*
PROBLEMA:
Analizar la retención de clientes por cohortes mensuales, mostrando 
qué porcentaje de clientes sigue activo en cada período posterior 
a su registro inicial.

TÉCNICAS UTILIZADAS:
- CTEs múltiples para estructura de análisis
- DATE_TRUNC para agrupación temporal
- LEFT JOIN para preservar cohortes sin actividad
- AGE/EXTRACT para cálculo de períodos
- Análisis de retención por cohortes

CASOS DE USO:
- Análisis de retención de clientes
- Evaluación de campañas de adquisición
- Predicción de LTV (Lifetime Value)
- Optimización de estrategias de retención
*/

SET timezone = 'America/Argentina/Buenos_Aires';

WITH cohortes_clientes AS (
    -- PASO 1: Identificar el mes de registro de cada cliente (cohorte)
    SELECT 
        id as cliente_id,
        DATE_TRUNC('month', fecha_registro) as mes_cohorte,
        fecha_registro as fecha_registro_original
    FROM clientes
),

actividad_mensual AS (
    -- PASO 2: Identificar actividad de pedidos por cliente y mes
    SELECT DISTINCT
        p.cliente_id,
        DATE_TRUNC('month', p.fecha_pedido) as mes_actividad
    FROM pedidos p
    WHERE p.estado = 'completado'
),

tabla_cohorte AS (
    -- PASO 3: Combinar cohortes con actividad mensual
    SELECT 
        c.mes_cohorte,
        a.mes_actividad,
        COUNT(DISTINCT c.cliente_id) as clientes_activos,
        -- Calcular el período transcurrido desde el registro
        EXTRACT(YEAR FROM AGE(a.mes_actividad, c.mes_cohorte))::INTEGER * 12 +
        EXTRACT(MONTH FROM AGE(a.mes_actividad, c.mes_cohorte))::INTEGER as periodo
    FROM cohortes_clientes c
    LEFT JOIN actividad_mensual a ON c.cliente_id = a.cliente_id
    GROUP BY c.mes_cohorte, a.mes_actividad
),

tamaño_cohorte AS (
    -- PASO 4: Calcular el tamaño inicial de cada cohorte
    SELECT 
        mes_cohorte,
        COUNT(DISTINCT cliente_id) as tamaño_inicial_cohorte
    FROM cohortes_clientes
    GROUP BY mes_cohorte
),

metricas_retencion AS (
    -- PASO 5: Calcular métricas de retención
    SELECT 
        tc.mes_cohorte,
        tc.periodo,
        tc.clientes_activos,
        t.tamaño_inicial_cohorte,
        
        -- Tasa de retención por período
        ROUND(
            tc.clientes_activos * 100.0 / t.tamaño_inicial_cohorte, 
            2
        ) as tasa_retencion,
        
        -- Clasificación temporal del período
        CASE 
            WHEN tc.periodo = 0 THEN 'Mes Inicial'
            WHEN tc.periodo = 1 THEN 'Mes 1'
            WHEN tc.periodo = 2 THEN 'Mes 2'
            WHEN tc.periodo = 3 THEN 'Mes 3'
            WHEN tc.periodo <= 6 THEN 'Trimestre 2'
            WHEN tc.periodo <= 12 THEN 'Segundo Semestre'
            ELSE 'Más de 1 año'
        END as segmento_tiempo,
        
        -- Calcular retención del período anterior
        LAG(tc.clientes_activos) OVER (
            PARTITION BY tc.mes_cohorte 
            ORDER BY tc.periodo
        ) as clientes_periodo_anterior,
        
        -- Tasa de abandono (churn) período a período
        CASE 
            WHEN LAG(tc.clientes_activos) OVER (
                PARTITION BY tc.mes_cohorte 
                ORDER BY tc.periodo
            ) IS NOT NULL 
            THEN ROUND(
                (LAG(tc.clientes_activos) OVER (
                    PARTITION BY tc.mes_cohorte 
                    ORDER BY tc.periodo
                ) - tc.clientes_activos) * 100.0 / 
                LAG(tc.clientes_activos) OVER (
                    PARTITION BY tc.mes_cohorte 
                    ORDER BY tc.periodo
                ), 2
            )
            ELSE 0
        END as tasa_churn_periodo
        
    FROM tabla_cohorte tc
    INNER JOIN tamaño_cohorte t ON tc.mes_cohorte = t.mes_cohorte
    WHERE tc.mes_actividad IS NOT NULL -- Solo períodos con actividad
)

-- RESULTADO PRINCIPAL: Análisis de retención por cohortes
SELECT 
    TO_CHAR(mes_cohorte, 'YYYY-MM') as cohorte,
    periodo,
    segmento_tiempo,
    tamaño_inicial_cohorte,
    clientes_activos,
    tasa_retencion || '%' as tasa_retencion,
    tasa_churn_periodo || '%' as churn_vs_periodo_anterior,
    
    -- Evaluación de la salud de la cohorte
    CASE 
        WHEN periodo = 0 THEN 'Registro inicial'
        WHEN tasa_retencion >= 60 THEN 'Retención excelente'
        WHEN tasa_retencion >= 40 THEN 'Retención buena'
        WHEN tasa_retencion >= 25 THEN 'Retención regular'
        WHEN tasa_retencion >= 15 THEN 'Retención baja'
        ELSE 'Retención crítica'
    END as evaluacion_retencion,
    
    -- Recomendaciones basadas en retención
    CASE 
        WHEN periodo = 1 AND tasa_retencion < 70 
        THEN 'Mejorar onboarding del primer mes'
        WHEN periodo = 3 AND tasa_retencion < 40 
        THEN 'Campaña de reactivación trimestral'
        WHEN periodo >= 6 AND tasa_retencion < 25 
        THEN 'Programa de lealtad a largo plazo'
        WHEN tasa_churn_periodo > 30 
        THEN 'Analizar causas de abandono específicas'
        ELSE 'Mantener estrategia actual'
    END as recomendacion
    
FROM metricas_retencion
ORDER BY mes_cohorte DESC, periodo;

-- =====================================================
-- ANÁLISIS COMPLEMENTARIO: RESUMEN POR COHORTES
-- =====================================================

WITH cohortes_clientes AS (
    -- Redefinir CTE para esta consulta independiente
    SELECT 
        id as cliente_id,
        DATE_TRUNC('month', fecha_registro) as mes_cohorte,
        fecha_registro as fecha_registro_original
    FROM clientes
),
resumen_cohortes AS (
    SELECT 
        c.mes_cohorte,
        COUNT(DISTINCT c.cliente_id) as tamaño_cohorte,
        
        -- Clientes activos en diferentes períodos
        COUNT(DISTINCT CASE 
            WHEN EXISTS (
                SELECT 1 FROM pedidos p 
                WHERE p.cliente_id = c.cliente_id 
                AND p.estado = 'completado'
                AND DATE_TRUNC('month', p.fecha_pedido) = c.mes_cohorte + INTERVAL '1 month'
            ) THEN c.cliente_id 
        END) as activos_mes_1,
        
        COUNT(DISTINCT CASE 
            WHEN EXISTS (
                SELECT 1 FROM pedidos p 
                WHERE p.cliente_id = c.cliente_id 
                AND p.estado = 'completado'
                AND DATE_TRUNC('month', p.fecha_pedido) = c.mes_cohorte + INTERVAL '3 months'
            ) THEN c.cliente_id 
        END) as activos_mes_3,
        
        COUNT(DISTINCT CASE 
            WHEN EXISTS (
                SELECT 1 FROM pedidos p 
                WHERE p.cliente_id = c.cliente_id 
                AND p.estado = 'completado'
                AND DATE_TRUNC('month', p.fecha_pedido) >= c.mes_cohorte + INTERVAL '6 months'
            ) THEN c.cliente_id 
        END) as activos_6_meses_plus
        
    FROM cohortes_clientes c
    GROUP BY c.mes_cohorte
)
SELECT 
    TO_CHAR(mes_cohorte, 'YYYY-MM') as cohorte,
    tamaño_cohorte,
    activos_mes_1,
    ROUND(activos_mes_1 * 100.0 / tamaño_cohorte, 1) || '%' as retencion_mes_1,
    activos_mes_3,
    ROUND(activos_mes_3 * 100.0 / tamaño_cohorte, 1) || '%' as retencion_mes_3,
    activos_6_meses_plus,
    ROUND(activos_6_meses_plus * 100.0 / tamaño_cohorte, 1) || '%' as retencion_6_meses,
    
    -- Puntuación de calidad de cohorte
    ROUND(
        (activos_mes_1 * 100.0 / tamaño_cohorte * 0.3) +
        (activos_mes_3 * 100.0 / tamaño_cohorte * 0.4) +
        (activos_6_meses_plus * 100.0 / tamaño_cohorte * 0.3)
    , 1) as score_calidad_cohorte
    
FROM resumen_cohortes
WHERE tamaño_cohorte >= 10  -- Solo cohortes con tamaño significativo
ORDER BY mes_cohorte DESC;

/*
RESULTADOS ESPERADOS:
- Análisis detallado de retención por cohortes mensuales
- Identificación de patrones de abandono de clientes
- Métricas de churn período a período
- Recomendaciones específicas para mejora de retención

MÉTRICAS CLAVE:
- Tasa de retención por período
- Tasa de churn período a período
- Tamaño y calidad de cohortes
- Puntos críticos de abandono
*/
