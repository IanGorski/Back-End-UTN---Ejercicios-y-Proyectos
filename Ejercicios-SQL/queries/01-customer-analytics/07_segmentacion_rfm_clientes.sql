-- =============================================================================
-- 07. SEGMENTACIÓN RFM DE CLIENTES - Versión Corregida PostgreSQL
-- =============================================================================
-- Descripción: Análisis RFM (Recency, Frequency, Monetary) para segmentación
-- Base de Datos: PostgreSQL 14+
-- Autor: Ian Gorski
-- Última actualización: Octubre 2025
-- =============================================================================

-- Configuración de zona horaria (comentado - ejecutar si es necesario)
-- SET timezone = 'America/Argentina/Buenos_Aires';

-- -----------------------------------------------------------------------------
-- ANÁLISIS RFM COMPLETO
-- -----------------------------------------------------------------------------
-- RFM es una técnica de segmentación de clientes basada en:
-- - Recency (R): ¿Qué tan reciente fue su última compra?
-- - Frequency (F): ¿Con qué frecuencia compra?
-- - Monetary (M): ¿Cuánto dinero gasta?
-- -----------------------------------------------------------------------------

-- Crear tabla temporal para almacenar análisis RFM
DROP TABLE IF EXISTS rfm_analysis;

CREATE TEMP TABLE rfm_analysis AS
WITH datos_cliente AS (
    -- Calcular métricas base para cada cliente
    SELECT 
        c.id AS cliente_id,
        c.nombre AS nombre_completo,
        c.email,
        c.ciudad,
        c.fecha_registro,
        -- RECENCY: Días desde última compra
        CASE 
            WHEN MAX(p.fecha_pedido) IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (CURRENT_DATE::timestamp - MAX(p.fecha_pedido)::timestamp)) / 86400
            ELSE 999999
        END::int AS dias_desde_ultima_compra,
        -- FREQUENCY: Número total de compras
        COUNT(DISTINCT p.id) AS total_compras,
        COUNT(DISTINCT DATE_TRUNC('month', p.fecha_pedido)) AS meses_con_compras,
        -- MONETARY: Valor total gastado
        COALESCE(SUM(p.total), 0) AS valor_total_gastado,
        COALESCE(AVG(p.total), 0) AS ticket_promedio,
        -- Métricas adicionales
        MIN(p.fecha_pedido) AS primera_compra,
        MAX(p.fecha_pedido) AS ultima_compra,
        CASE 
            WHEN MAX(p.fecha_pedido) IS NOT NULL AND MIN(p.fecha_pedido) IS NOT NULL
            THEN EXTRACT(EPOCH FROM (MAX(p.fecha_pedido)::timestamp - MIN(p.fecha_pedido)::timestamp)) / 86400
            ELSE 0
        END AS dias_como_cliente_activo
    FROM 
        clientes c
        LEFT JOIN pedidos p ON c.id = p.cliente_id 
            AND p.estado = 'completado'
            AND p.fecha_pedido >= CURRENT_DATE - INTERVAL '24 months'  -- Últimos 2 años
    WHERE 
        c.activo = TRUE
    GROUP BY 
        c.id, c.nombre, c.email, c.ciudad, c.fecha_registro
    HAVING 
        COUNT(p.id) > 0  -- Solo clientes con al menos 1 compra
),
rfm_scores AS (
    -- Calcular scores RFM usando NTILE (divide en 5 grupos)
    SELECT 
        *,
        -- R: Menor días = Mayor score (más reciente)
        6 - NTILE(5) OVER (ORDER BY dias_desde_ultima_compra) AS r_score,
        -- F: Más compras = Mayor score
        NTILE(5) OVER (ORDER BY total_compras) AS f_score,
        -- M: Más gasto = Mayor score
        NTILE(5) OVER (ORDER BY valor_total_gastado) AS m_score
    FROM 
        datos_cliente
)
SELECT 
    cliente_id,
    nombre_completo,
    email,
    ciudad,
    fecha_registro,
    dias_desde_ultima_compra,
    total_compras,
    meses_con_compras,
    valor_total_gastado,
    ticket_promedio,
    primera_compra,
    ultima_compra,
    dias_como_cliente_activo,
    r_score,
    f_score,
    m_score,
    -- Score RFM combinado (concatenado)
    (r_score::text || f_score::text || m_score::text) AS rfm_score,
    -- Score RFM ponderado (suma)
    (r_score * 3 + f_score * 2 + m_score * 5) AS rfm_weighted_score,
    -- Segmentación basada en scores
    CASE 
        -- Champions: Los mejores clientes
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        -- Loyal Customers: Clientes leales
        WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal Customers'
        -- Potential Loyalists: Pueden volverse leales
        WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3 AND m_score >= 3 THEN 'Potential Loyalists'
        -- Recent Customers: Compraron recientemente
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
        -- Promising: Nuevos con potencial
        WHEN r_score >= 3 AND f_score <= 2 AND m_score <= 2 THEN 'Promising'
        -- Customers Needing Attention: Necesitan atención
        WHEN r_score BETWEEN 2 AND 3 AND f_score BETWEEN 2 AND 3 THEN 'Customers Needing Attention'
        -- About to Sleep: En riesgo
        WHEN r_score = 2 AND f_score <= 2 THEN 'About to Sleep'
        -- At Risk: Alto riesgo de pérdida
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        -- Can't Lose Them: Valiosos pero inactivos
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'Can''t Lose Them'
        -- Hibernating: Inactivos
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Hibernating'
        -- Lost: Perdidos
        ELSE 'Lost'
    END AS segmento_rfm,
    -- Valor de por vida del cliente (CLV estimado)
    CASE 
        WHEN dias_como_cliente_activo > 0 
        THEN ROUND((valor_total_gastado / dias_como_cliente_activo * 365 * 2)::numeric, 2)
        ELSE 0
    END AS clv_estimado_2_anos
FROM 
    rfm_scores;

-- -----------------------------------------------------------------------------
-- 1. RESUMEN GENERAL DE SEGMENTOS RFM
-- -----------------------------------------------------------------------------

SELECT 
    segmento_rfm,
    COUNT(*) AS num_clientes,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ())::numeric, 2) AS porcentaje_clientes,
    ROUND(AVG(r_score)::numeric, 2) AS avg_recency_score,
    ROUND(AVG(f_score)::numeric, 2) AS avg_frequency_score,
    ROUND(AVG(m_score)::numeric, 2) AS avg_monetary_score,
    ROUND(AVG(dias_desde_ultima_compra)::numeric, 1) AS avg_dias_ultima_compra,
    ROUND(AVG(total_compras)::numeric, 1) AS avg_num_compras,
    TO_CHAR(AVG(valor_total_gastado), 'L999,999,999') AS avg_valor_gastado,
    TO_CHAR(SUM(valor_total_gastado), 'L999,999,999') AS valor_total_segmento,
    ROUND((SUM(valor_total_gastado) * 100.0 / SUM(SUM(valor_total_gastado)) OVER ())::numeric, 2) AS porcentaje_ingresos,
    TO_CHAR(AVG(clv_estimado_2_anos), 'L999,999,999') AS avg_clv_estimado
FROM 
    rfm_analysis
GROUP BY 
    segmento_rfm
ORDER BY 
    SUM(valor_total_gastado) DESC;

-- -----------------------------------------------------------------------------
-- 2. TOP CLIENTES POR SEGMENTO
-- -----------------------------------------------------------------------------

WITH ranked_clientes AS (
    SELECT 
        segmento_rfm,
        nombre_completo,
        email,
        ciudad,
        rfm_score,
        r_score,
        f_score,
        m_score,
        dias_desde_ultima_compra,
        total_compras,
        TO_CHAR(valor_total_gastado, 'L999,999,999') AS valor_total,
        TO_CHAR(ticket_promedio, 'L999,999') AS ticket_promedio,
        TO_CHAR(clv_estimado_2_anos, 'L999,999,999') AS clv_estimado,
        ROW_NUMBER() OVER (PARTITION BY segmento_rfm ORDER BY rfm_weighted_score DESC) AS rank_en_segmento
    FROM 
        rfm_analysis
)
SELECT *
FROM ranked_clientes
WHERE rank_en_segmento <= 5  -- Top 5 por segmento
ORDER BY 
    segmento_rfm,
    rank_en_segmento;

-- -----------------------------------------------------------------------------
-- 3. MATRIZ RFM (Heatmap)
-- -----------------------------------------------------------------------------
-- Muestra distribución de clientes en matriz RFM

SELECT 
    r_score AS recency,
    f_score AS frequency,
    COUNT(*) AS num_clientes,
    TO_CHAR(SUM(valor_total_gastado), 'L999,999,999') AS valor_total,
    ROUND(AVG(m_score)::numeric, 2) AS avg_monetary_score,
    STRING_AGG(DISTINCT segmento_rfm, ', ') AS segmentos
FROM 
    rfm_analysis
GROUP BY 
    r_score, f_score
ORDER BY 
    r_score DESC, f_score DESC;

-- -----------------------------------------------------------------------------
-- 4. ANÁLISIS DE TRANSICIÓN (Cambios de Segmento)
-- -----------------------------------------------------------------------------
-- Compara segmentación actual vs hace 6 meses

WITH rfm_6_meses_atras AS (
    SELECT 
        c.id AS cliente_id,
        CASE 
            WHEN MAX(p.fecha_pedido) IS NOT NULL
            THEN 6 - NTILE(5) OVER (ORDER BY EXTRACT(EPOCH FROM ((CURRENT_DATE - INTERVAL '6 months')::timestamp - MAX(p.fecha_pedido)::timestamp)) / 86400)
            ELSE 1
        END AS r_score_6m,
        NTILE(5) OVER (ORDER BY COUNT(DISTINCT p.id)) AS f_score_6m,
        NTILE(5) OVER (ORDER BY COALESCE(SUM(p.total), 0)) AS m_score_6m
    FROM 
        clientes c
        LEFT JOIN pedidos p ON c.id = p.cliente_id 
            AND p.estado = 'completado'
            AND p.fecha_pedido BETWEEN CURRENT_DATE - INTERVAL '18 months' AND CURRENT_DATE - INTERVAL '6 months'
    WHERE 
        c.activo = TRUE
    GROUP BY 
        c.id
    HAVING 
        COUNT(p.id) > 0
)
SELECT 
    rf.segmento_rfm AS segmento_actual,
    COUNT(*) AS num_clientes,
    ROUND(AVG((rf.r_score - COALESCE(r6.r_score_6m, 0)))::numeric, 2) AS cambio_recency,
    ROUND(AVG((rf.f_score - COALESCE(r6.f_score_6m, 0)))::numeric, 2) AS cambio_frequency,
    ROUND(AVG((rf.m_score - COALESCE(r6.m_score_6m, 0)))::numeric, 2) AS cambio_monetary,
    CASE 
        WHEN AVG((rf.r_score + rf.f_score + rf.m_score) - 
                 COALESCE((r6.r_score_6m + r6.f_score_6m + r6.m_score_6m), 0)) > 2 
        THEN 'Mejorando ↑'
        WHEN AVG((rf.r_score + rf.f_score + rf.m_score) - 
                 COALESCE((r6.r_score_6m + r6.f_score_6m + r6.m_score_6m), 0)) < -2 
        THEN 'Empeorando ↓'
        ELSE 'Estable →'
    END AS tendencia
FROM 
    rfm_analysis rf
    LEFT JOIN rfm_6_meses_atras r6 ON rf.cliente_id = r6.cliente_id
GROUP BY 
    rf.segmento_rfm
ORDER BY 
    COUNT(*) DESC;

-- -----------------------------------------------------------------------------
-- 5. ACCIONES RECOMENDADAS POR SEGMENTO
-- -----------------------------------------------------------------------------

SELECT 
    segmento_rfm,
    COUNT(*) AS num_clientes,
    CASE segmento_rfm
        WHEN 'Champions' THEN 
            'Recompensar. Promociones exclusivas. Programas VIP. Feedback de productos.'
        WHEN 'Loyal Customers' THEN 
            'Upselling. Cross-selling. Programas de lealtad. Ofertas especiales.'
        WHEN 'Potential Loyalists' THEN 
            'Membresías. Recomendaciones personalizadas. Aumentar frecuencia de compra.'
        WHEN 'Recent Customers' THEN 
            'Onboarding. Productos complementarios. Crear awareness de marca.'
        WHEN 'Promising' THEN 
            'Crear awareness. Ofertas introductorias. Guías de productos.'
        WHEN 'Customers Needing Attention' THEN 
            'Campañas de reactivación. Encuestas. Ofertas limitadas.'
        WHEN 'About to Sleep' THEN 
            'Descuentos. Recordatorios. Productos nuevos. "Te extrañamos".'
        WHEN 'At Risk' THEN 
            'Reactivación urgente. Descuentos agresivos. Campañas personalizadas.'
        WHEN 'Can''t Lose Them' THEN 
            'Atención prioritaria. Win-back campaigns. Ofertas premium.'
        WHEN 'Hibernating' THEN 
            'Recrear interés. Nuevos productos. Ofertas limitadas.'
        ELSE 
            'Win-back campaigns. Encuestas. Descuentos significativos.'
    END AS acciones_recomendadas,
    CASE segmento_rfm
        WHEN 'Champions' THEN 'Email personal, SMS'
        WHEN 'Loyal Customers' THEN 'Email, SMS, Notificaciones'
        WHEN 'Potential Loyalists' THEN 'Email marketing'
        WHEN 'Recent Customers' THEN 'Email nurturing'
        WHEN 'Promising' THEN 'Email, Ads'
        WHEN 'Customers Needing Attention' THEN 'Email, Retargeting'
        WHEN 'About to Sleep' THEN 'Email urgente, SMS'
        WHEN 'At Risk' THEN 'Email, Llamadas, SMS'
        WHEN 'Can''t Lose Them' THEN 'Llamadas personales, Email'
        WHEN 'Hibernating' THEN 'Retargeting ads'
        ELSE 'Email masivo'
    END AS canales_comunicacion,
    CASE segmento_rfm
        WHEN 'Champions' THEN 'Alta'
        WHEN 'Loyal Customers' THEN 'Alta'
        WHEN 'Potential Loyalists' THEN 'Media-Alta'
        WHEN 'At Risk' THEN 'Alta'
        WHEN 'Can''t Lose Them' THEN 'Muy Alta'
        ELSE 'Media'
    END AS prioridad
FROM 
    rfm_analysis
GROUP BY 
    segmento_rfm
ORDER BY 
    CASE segmento_rfm
        WHEN 'Champions' THEN 1
        WHEN 'Can''t Lose Them' THEN 2
        WHEN 'At Risk' THEN 3
        WHEN 'Loyal Customers' THEN 4
        WHEN 'Potential Loyalists' THEN 5
        ELSE 6
    END;

-- -----------------------------------------------------------------------------
-- 6. EXPORTAR CLIENTES PARA CAMPAÑAS ESPECÍFICAS
-- -----------------------------------------------------------------------------

-- Champions - Para programa VIP
SELECT 
    cliente_id,
    nombre_completo,
    email,
    ciudad,
    rfm_score,
    TO_CHAR(valor_total_gastado, 'L999,999,999') AS lifetime_value,
    total_compras,
    dias_desde_ultima_compra,
    'VIP Program' AS campana_sugerida
FROM 
    rfm_analysis
WHERE 
    segmento_rfm = 'Champions'
ORDER BY 
    rfm_weighted_score DESC
LIMIT 50;

-- At Risk & Can't Lose Them - Para campaña de retención urgente
SELECT 
    cliente_id,
    nombre_completo,
    email,
    ciudad,
    rfm_score,
    TO_CHAR(valor_total_gastado, 'L999,999,999') AS lifetime_value,
    dias_desde_ultima_compra,
    'Retention Urgent' AS campana_sugerida,
    CASE 
        WHEN valor_total_gastado >= 500000 THEN 'Llamada personal + 30% descuento'
        WHEN valor_total_gastado >= 200000 THEN 'Email urgente + 20% descuento'
        ELSE 'Email + 15% descuento'
    END AS accion_inmediata
FROM 
    rfm_analysis
WHERE 
    segmento_rfm IN ('At Risk', 'Can''t Lose Them')
ORDER BY 
    valor_total_gastado DESC;

-- Recent Customers - Para onboarding y segunda compra
SELECT 
    cliente_id,
    nombre_completo,
    email,
    ciudad,
    rfm_score,
    dias_desde_ultima_compra,
    total_compras,
    'Onboarding + Second Purchase' AS campana_sugerida
FROM 
    rfm_analysis
WHERE 
    segmento_rfm = 'Recent Customers'
    AND total_compras = 1
ORDER BY 
    dias_desde_ultima_compra;

-- -----------------------------------------------------------------------------
-- 7. MÉTRICAS DE NEGOCIO POR SEGMENTO
-- -----------------------------------------------------------------------------

SELECT 
    segmento_rfm,
    COUNT(*) AS clientes,
    -- Valor actual
    TO_CHAR(SUM(valor_total_gastado), 'L999,999,999') AS valor_historico,
    TO_CHAR(AVG(valor_total_gastado), 'L999,999,999') AS avg_por_cliente,
    -- CLV
    TO_CHAR(SUM(clv_estimado_2_anos), 'L999,999,999') AS clv_total_estimado,
    TO_CHAR(AVG(clv_estimado_2_anos), 'L999,999,999') AS clv_avg_estimado,
    -- ROI potencial de campañas (asumiendo 5% conversión mejora)
    TO_CHAR(SUM(clv_estimado_2_anos) * 0.05, 'L999,999,999') AS roi_potencial_campana,
    -- Concentración
    ROUND((SUM(valor_total_gastado) * 100.0 / SUM(SUM(valor_total_gastado)) OVER ())::numeric, 2) AS concentracion_ingresos_pct
FROM 
    rfm_analysis
GROUP BY 
    segmento_rfm
ORDER BY 
    SUM(clv_estimado_2_anos) DESC;

-- -----------------------------------------------------------------------------
-- CREAR VISTA PARA USO CONTINUO
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_segmentacion_rfm AS
SELECT 
    cliente_id,
    nombre_completo,
    email,
    ciudad,
    fecha_registro,
    dias_desde_ultima_compra,
    total_compras,
    valor_total_gastado,
    ticket_promedio,
    r_score,
    f_score,
    m_score,
    rfm_score,
    rfm_weighted_score,
    segmento_rfm,
    clv_estimado_2_anos,
    CURRENT_DATE AS fecha_analisis
FROM 
    rfm_analysis;

-- Verificar que la vista funciona
SELECT COUNT(*), COUNT(DISTINCT segmento_rfm) 
FROM v_segmentacion_rfm;

-- =============================================================================
-- FIN DEL SCRIPT - 07_segmentacion_rfm_clientes_CORREGIDO.sql
-- =============================================================================
-- La segmentación RFM está lista para:
-- 1. Campañas de marketing dirigidas
-- 2. Programas de lealtad
-- 3. Prevención de churn
-- 4. Optimización de recursos de marketing
-- =============================================================================
