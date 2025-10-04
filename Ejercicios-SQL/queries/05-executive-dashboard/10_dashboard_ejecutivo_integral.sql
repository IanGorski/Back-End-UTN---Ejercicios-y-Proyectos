-- =====================================================
-- QUERY 10: DASHBOARD EJECUTIVO INTEGRAL
-- =====================================================

/*
PROBLEMA:
Crear un dashboard ejecutivo que integre múltiples métricas de negocio
con KPIs, tendencias, alertas y recomendaciones estratégicas para
toma de decisiones en tiempo real.

TÉCNICAS UTILIZADAS:
- Integración de múltiples fuentes de datos
- Cálculo d    '📏 RESUMEN EJECUTIVO - ÚLTIMO PERÍODO' as seccion,
    mes || '/' || año as periodo,
    '$' || ROUND(ingresos_totales::NUMERIC, 2) as ingresos,
    clientes_activos as clientes,
    total_empleados_periodo as empleados,
    ROUND(crecimiento_mensual_ingresos, 1) || '%' as crecimiento_mensual,
    ROUND(crecimiento_anual_ingresos, 1) || '%' as crecimiento_anual,complejos
- Sistema de alertas automatizadas
- Análisis de tendencias multidimensional
- Scoring de salud del negocio
- Benchmarking temporal

CASOS DE USO:
- Reporting ejecutivo
- Monitoreo de KPIs en tiempo real
- Detección temprana de problemas
- Análisis de performance integral
- Soporte para toma de decisiones estratégicas
*/

WITH metricas_financieras AS (
    -- PASO 1: Métricas financieras consolidadas por período
    SELECT 
        EXTRACT(YEAR FROM v.fecha_venta) as año,
        EXTRACT(MONTH FROM v.fecha_venta) as mes,
        DATE_TRUNC('month', v.fecha_venta) as periodo,
        
        -- KPIs de ingresos
        SUM(v.cantidad * v.precio_unitario) as ingresos_totales,
        COUNT(DISTINCT v.id) as num_transacciones,
        AVG(v.cantidad * v.precio_unitario) as ticket_promedio,
        SUM(v.cantidad) as unidades_vendidas,
        
        -- KPIs de productos y empleados
        COUNT(DISTINCT v.producto_id) as productos_vendidos,
        COUNT(DISTINCT v.empleado_id) as empleados_activos_ventas,
        
        -- Distribución por categorías
        SUM(CASE WHEN p.categoria = 'Electrónicos' THEN v.cantidad * v.precio_unitario ELSE 0 END) as ingresos_electronicos,
        SUM(CASE WHEN p.categoria = 'Accesorios' THEN v.cantidad * v.precio_unitario ELSE 0 END) as ingresos_accesorios,
        SUM(CASE WHEN p.categoria = 'Oficina' THEN v.cantidad * v.precio_unitario ELSE 0 END) as ingresos_oficina
        
    FROM ventas v
    INNER JOIN productos p ON v.producto_id = p.id
    GROUP BY EXTRACT(YEAR FROM v.fecha_venta), EXTRACT(MONTH FROM v.fecha_venta), DATE_TRUNC('month', v.fecha_venta)
),

metricas_empleados AS (
    -- PASO 2: Métricas de recursos humanos
    SELECT 
        DATE_TRUNC('month', v.fecha_venta) as periodo,
        
        -- KPIs de empleados
        COUNT(DISTINCT e.id) as total_empleados_periodo,
        SUM(v.cantidad * v.precio_unitario) / COUNT(DISTINCT e.id) as ingresos_por_empleado,
        AVG(e.salario) as salario_promedio_periodo,
        SUM(e.salario) as costo_total_personal,
        
        -- Eficiencia del personal
        SUM(v.cantidad * v.precio_unitario) / SUM(e.salario) as ratio_ingresos_costos_personal,
        
        -- Distribución por departamentos
        COUNT(DISTINCT CASE WHEN d.nombre = 'Ventas' THEN e.id END) as empleados_ventas,
        COUNT(DISTINCT CASE WHEN d.nombre = 'Marketing' THEN e.id END) as empleados_marketing,
        COUNT(DISTINCT CASE WHEN d.nombre = 'IT' THEN e.id END) as empleados_it
        
    FROM ventas v
    INNER JOIN empleados e ON v.empleado_id = e.id
    INNER JOIN departamentos d ON e.departamento_id = d.id
    GROUP BY DATE_TRUNC('month', v.fecha_venta)
),

metricas_clientes AS (
    -- PASO 3: Métricas de clientes y pedidos
    SELECT 
        DATE_TRUNC('month', p.fecha_pedido) as periodo,
        
        -- KPIs de clientes
        COUNT(DISTINCT p.cliente_id) as clientes_activos,
        COUNT(p.id) as total_pedidos,
        AVG(p.total) as valor_promedio_pedido,
        SUM(p.total) as ingresos_pedidos,
        
        -- Nuevos clientes (primera compra en el período)
        COUNT(DISTINCT CASE 
            WHEN p.fecha_pedido = (
                SELECT MIN(p2.fecha_pedido) 
                FROM pedidos p2 
                WHERE p2.cliente_id = p.cliente_id AND p2.estado = 'completado'
            ) THEN p.cliente_id 
        END) as clientes_nuevos,
        
        -- Clientes recurrentes
        COUNT(DISTINCT CASE 
            WHEN EXISTS (
                SELECT 1 FROM pedidos p2 
                WHERE p2.cliente_id = p.cliente_id 
                AND p2.fecha_pedido < p.fecha_pedido 
                AND p2.estado = 'completado'
            ) THEN p.cliente_id 
        END) as clientes_recurrentes,
        
        -- Estados de pedidos
        COUNT(CASE WHEN p.estado = 'completado' THEN 1 END) as pedidos_completados,
        COUNT(CASE WHEN p.estado = 'pendiente' THEN 1 END) as pedidos_pendientes,
        COUNT(CASE WHEN p.estado = 'cancelado' THEN 1 END) as pedidos_cancelados
        
    FROM pedidos p
    GROUP BY DATE_TRUNC('month', p.fecha_pedido)
),

metricas_productos AS (
    -- PASO 4: Métricas de productos e inventario
    SELECT 
        DATE_TRUNC('month', v.fecha_venta) as periodo,
        
        -- KPIs de productos
        COUNT(DISTINCT v.producto_id) as productos_activos,
        AVG(p.stock) as stock_total_periodo,
        AVG(p.stock * p.precio) as valor_inventario_periodo,
        
        -- Rotación promedio (simplificado)
        AVG(
            CASE WHEN p.stock > 0 
            THEN v.cantidad / NULLIF(p.stock, 0)
            ELSE 0 END
        ) as rotacion_promedio_mensual,
        
        -- Top productos (se calculará en otro CTE)
        NULL::VARCHAR as producto_top_ingresos
        
    FROM ventas v
    INNER JOIN productos p ON v.producto_id = p.id
    GROUP BY DATE_TRUNC('month', v.fecha_venta)
),

top_productos_mes AS (
    -- CTE auxiliar para obtener el top producto por mes
    SELECT DISTINCT ON (DATE_TRUNC('month', v.fecha_venta))
        DATE_TRUNC('month', v.fecha_venta) as periodo,
        p.nombre as producto_top_ingresos
    FROM ventas v
    INNER JOIN productos p ON v.producto_id = p.id
    GROUP BY DATE_TRUNC('month', v.fecha_venta), p.id, p.nombre
    ORDER BY DATE_TRUNC('month', v.fecha_venta), SUM(v.cantidad * v.precio_unitario) DESC
),

dashboard_consolidado AS (
    -- PASO 5: Consolidar todas las métricas
    SELECT 
        mf.año,
        mf.mes,
        mf.periodo,
        
        -- KPIs Financieros Principales
        mf.ingresos_totales,
        mf.num_transacciones,
        mf.ticket_promedio,
        mf.unidades_vendidas,
        
        -- KPIs de Empleados
        me.total_empleados_periodo,
        me.ingresos_por_empleado,
        me.salario_promedio_periodo,
        me.ratio_ingresos_costos_personal,
        
        -- KPIs de Clientes
        mc.clientes_activos,
        mc.clientes_nuevos,
        mc.clientes_recurrentes,
        mc.valor_promedio_pedido,
        mc.total_pedidos,
        
        -- KPIs de Productos
        mp.productos_activos,
        mp.valor_inventario_periodo,
        mp.rotacion_promedio_mensual,
        tp.producto_top_ingresos,
        
        -- Distribución por categorías
        mf.ingresos_electronicos,
        mf.ingresos_accesorios,
        mf.ingresos_oficina,
        
        -- Métricas de comparación temporal
        LAG(mf.ingresos_totales, 1) OVER (ORDER BY mf.periodo) as ingresos_mes_anterior,
        LAG(mf.ingresos_totales, 12) OVER (ORDER BY mf.periodo) as ingresos_año_anterior,
        LAG(mc.clientes_activos, 1) OVER (ORDER BY mf.periodo) as clientes_mes_anterior,
        
        -- Medias móviles para tendencias
        AVG(mf.ingresos_totales) OVER (
            ORDER BY mf.periodo ROWS 2 PRECEDING
        ) as tendencia_ingresos_3m,
        
        AVG(mc.clientes_activos) OVER (
            ORDER BY mf.periodo ROWS 2 PRECEDING
        ) as tendencia_clientes_3m,
        
        AVG(me.ingresos_por_empleado) OVER (
            ORDER BY mf.periodo ROWS 2 PRECEDING
        ) as tendencia_productividad_3m
        
    FROM metricas_financieras mf
    LEFT JOIN metricas_empleados me ON mf.periodo = me.periodo
    LEFT JOIN metricas_clientes mc ON mf.periodo = mc.periodo
    LEFT JOIN metricas_productos mp ON mf.periodo = mp.periodo
    LEFT JOIN top_productos_mes tp ON mf.periodo = tp.periodo
),

kpis_calculados AS (
    -- PASO 6: Calcular KPIs derivados y crecimientos
    SELECT *,
        -- Crecimientos mensuales
        CASE 
            WHEN ingresos_mes_anterior IS NOT NULL AND ingresos_mes_anterior > 0
            THEN (ingresos_totales - ingresos_mes_anterior) * 100.0 / ingresos_mes_anterior
            ELSE NULL 
        END as crecimiento_mensual_ingresos,
        
        -- Crecimientos anuales
        CASE 
            WHEN ingresos_año_anterior IS NOT NULL AND ingresos_año_anterior > 0
            THEN (ingresos_totales - ingresos_año_anterior) * 100.0 / ingresos_año_anterior
            ELSE NULL 
        END as crecimiento_anual_ingresos,
        
        -- Crecimiento de clientes
        CASE 
            WHEN clientes_mes_anterior IS NOT NULL AND clientes_mes_anterior > 0
            THEN (clientes_activos - clientes_mes_anterior) * 100.0 / clientes_mes_anterior
            ELSE NULL 
        END as crecimiento_mensual_clientes,
        
        -- Tasa de conversión de nuevos clientes
        CASE 
            WHEN clientes_activos > 0 
            THEN clientes_nuevos * 100.0 / clientes_activos
            ELSE 0 
        END as tasa_nuevos_clientes,
        
        -- Tasa de retención
        CASE 
            WHEN clientes_activos > 0 
            THEN clientes_recurrentes * 100.0 / clientes_activos
            ELSE 0 
        END as tasa_retencion_clientes,
        
        -- Productividad por transacción
        CASE 
            WHEN num_transacciones > 0
            THEN ingresos_totales / num_transacciones
            ELSE 0
        END as ingresos_por_transaccion,
        
        -- Desviación de tendencia
        (ingresos_totales - tendencia_ingresos_3m) / NULLIF(tendencia_ingresos_3m, 0) * 100 as desviacion_tendencia_ingresos
        
    FROM dashboard_consolidado
),

sistema_alertas AS (
    -- PASO 7: Sistema de alertas y scoring
    SELECT *,
        -- Sistema de alertas múltiples
        CASE 
            WHEN crecimiento_mensual_ingresos < -15 THEN 'CRÍTICO: Caída severa de ingresos'
            WHEN crecimiento_mensual_ingresos < -10 THEN 'ALERTA: Caída significativa de ingresos'
            WHEN crecimiento_mensual_clientes < -20 THEN 'CRÍTICO: Pérdida masiva de clientes'
            WHEN ratio_ingresos_costos_personal < 2.5 THEN 'ALERTA: Baja eficiencia de personal'
            WHEN tasa_nuevos_clientes < 3 THEN 'ALERTA: Baja adquisición de clientes'
            WHEN ABS(desviacion_tendencia_ingresos) > 25 THEN 'ALERTA: Desviación extrema de tendencia'
            WHEN rotacion_promedio_mensual < 0.5 THEN 'ALERTA: Inventario lento'
            ELSE 'NORMAL'
        END as estado_alerta_principal,
        
        -- Puntuación de salud del negocio (0-100)
        LEAST(100, GREATEST(0,
            -- Componente de crecimiento (25 puntos)
            CASE 
                WHEN crecimiento_anual_ingresos > 25 THEN 25
                WHEN crecimiento_anual_ingresos > 15 THEN 20
                WHEN crecimiento_anual_ingresos > 5 THEN 15
                WHEN crecimiento_anual_ingresos > -5 THEN 10
                ELSE 5
            END +
            -- Componente de eficiencia (25 puntos)
            CASE 
                WHEN ratio_ingresos_costos_personal > 6 THEN 25
                WHEN ratio_ingresos_costos_personal > 4 THEN 20
                WHEN ratio_ingresos_costos_personal > 3 THEN 15
                WHEN ratio_ingresos_costos_personal > 2 THEN 10
                ELSE 5
            END +
            -- Componente de clientes (25 puntos)
            CASE 
                WHEN tasa_retencion_clientes > 70 AND tasa_nuevos_clientes > 10 THEN 25
                WHEN tasa_retencion_clientes > 60 OR tasa_nuevos_clientes > 8 THEN 20
                WHEN tasa_retencion_clientes > 50 OR tasa_nuevos_clientes > 5 THEN 15
                WHEN tasa_retencion_clientes > 40 OR tasa_nuevos_clientes > 3 THEN 10
                ELSE 5
            END +
            -- Componente de operaciones (25 puntos)
            CASE 
                WHEN rotacion_promedio_mensual > 2 AND productos_activos > 5 THEN 25
                WHEN rotacion_promedio_mensual > 1.5 THEN 20
                WHEN rotacion_promedio_mensual > 1 THEN 15
                WHEN rotacion_promedio_mensual > 0.5 THEN 10
                ELSE 5
            END
        )) as puntuacion_salud_negocio,
        
        -- Alertas específicas por área
        CONCAT_WS('; ',
            CASE WHEN crecimiento_mensual_ingresos < -10 THEN 'Ingresos↓' END,
            CASE WHEN crecimiento_mensual_clientes < -15 THEN 'Clientes↓' END,
            CASE WHEN ratio_ingresos_costos_personal < 3 THEN 'Eficiencia↓' END,
            CASE WHEN rotacion_promedio_mensual < 0.8 THEN 'Inventario↓' END,
            CASE WHEN tasa_nuevos_clientes < 5 THEN 'Adquisición↓' END
        ) as alertas_areas_especificas
        
    FROM kpis_calculados
)

-- Crear tabla temporal para usar en múltiples consultas
SELECT * INTO TEMP TABLE sistema_alertas_temp FROM sistema_alertas;

-- RESULTADO PRINCIPAL: Dashboard Ejecutivo Integral
SELECT 
    año,
    mes,
    
    -- === SECCIÓN 1: KPIs PRINCIPALES ===
    '$' || ROUND(ingresos_totales::NUMERIC, 2) as ingresos_totales,
    '$' || ROUND(ticket_promedio::NUMERIC, 2) as ticket_promedio,
    num_transacciones,
    clientes_activos,
    clientes_nuevos,
    total_empleados_periodo as empleados_activos,
    productos_activos,
    
    -- === SECCIÓN 2: MÉTRICAS DE CRECIMIENTO ===
    ROUND(crecimiento_mensual_ingresos, 1) || '%' as crecimiento_mensual,
    ROUND(crecimiento_anual_ingresos, 1) || '%' as crecimiento_anual,
    ROUND(crecimiento_mensual_clientes, 1) || '%' as crecimiento_clientes,
    
    -- === SECCIÓN 3: EFICIENCIA OPERATIVA ===
    '$' || ROUND(ingresos_por_empleado::NUMERIC, 2) as ingresos_por_empleado,
    ROUND(ratio_ingresos_costos_personal, 2) as ratio_eficiencia_personal,
    ROUND(tasa_nuevos_clientes, 1) || '%' as tasa_adquisicion_clientes,
    ROUND(tasa_retencion_clientes, 1) || '%' as tasa_retencion,
    ROUND(rotacion_promedio_mensual, 2) as rotacion_inventario,
    
    -- === SECCIÓN 4: ANÁLISIS FINANCIERO ===
    '$' || ROUND(valor_promedio_pedido::NUMERIC, 2) as valor_promedio_pedido,
    '$' || ROUND(valor_inventario_periodo::NUMERIC, 2) as valor_inventario,
    '$' || ROUND(salario_promedio_periodo::NUMERIC, 2) as costo_promedio_empleado,
    
    -- === SECCIÓN 5: DISTRIBUCIÓN POR CATEGORÍAS ===
    ROUND(ingresos_electronicos * 100.0 / NULLIF(ingresos_totales, 0), 1) as pct_electronicos,
    ROUND(ingresos_accesorios * 100.0 / NULLIF(ingresos_totales, 0), 1) as pct_accesorios,
    ROUND(ingresos_oficina * 100.0 / NULLIF(ingresos_totales, 0), 1) as pct_oficina,
    
    -- === SECCIÓN 6: SALUD DEL NEGOCIO ===
    puntuacion_salud_negocio as score_salud_negocio,
    CASE 
        WHEN puntuacion_salud_negocio >= 85 THEN 'EXCELENTE 🟢'
        WHEN puntuacion_salud_negocio >= 70 THEN 'BUENO 🟡'
        WHEN puntuacion_salud_negocio >= 55 THEN 'REGULAR 🟠'
        WHEN puntuacion_salud_negocio >= 40 THEN 'PREOCUPANTE 🔴'
        ELSE 'CRÍTICO ⚠️'
    END as estado_salud_negocio,
    
    -- === SECCIÓN 7: ALERTAS Y RECOMENDACIONES ===
    estado_alerta_principal,
    COALESCE(NULLIF(alertas_areas_especificas, ''), 'Sin alertas específicas') as alertas_detalladas,
    
    -- === SECCIÓN 8: RECOMENDACIONES ESTRATÉGICAS ===
    CASE 
        WHEN estado_alerta_principal LIKE 'CRÍTICO%' 
        THEN '🚨 ACCIÓN INMEDIATA: Revisión estratégica urgente y plan de contingencia'
        WHEN estado_alerta_principal LIKE 'ALERTA%' 
        THEN '⚠️ ATENCIÓN REQUERIDA: Monitoreo cercano y ajustes tácticos'
        WHEN puntuacion_salud_negocio >= 85 
        THEN '🚀 ACELERAR: Aprovechar momentum para expansión y crecimiento'
        WHEN puntuacion_salud_negocio >= 70 
        THEN '📈 OPTIMIZAR: Mantener estrategia actual y buscar eficiencias'
        WHEN puntuacion_salud_negocio >= 55 
        THEN '🔧 AJUSTAR: Revisar procesos y mejorar áreas débiles'
        ELSE '🔄 REESTRUCTURAR: Cambio estratégico fundamental requerido'
    END as recomendacion_estrategica_principal,
    
    -- === SECCIÓN 9: PRODUCTOS Y TENDENCIAS ===
    producto_top_ingresos as producto_estrella,
    ROUND(desviacion_tendencia_ingresos, 1) as desviacion_tendencia_pct,
    
    -- === SECCIÓN 10: PREDICCIONES SIMPLES ===
    '$' || ROUND(tendencia_ingresos_3m::NUMERIC, 2) as tendencia_ingresos_3m,
    CASE 
        WHEN crecimiento_mensual_ingresos > 5 
        THEN '$' || ROUND((ingresos_totales * (1 + crecimiento_mensual_ingresos/100))::NUMERIC, 2)
        ELSE '$' || ROUND(tendencia_ingresos_3m::NUMERIC, 2)
    END as proyeccion_proximo_mes,
    
    -- === SECCIÓN 11: ACCIONES PRIORITARIAS ===
    CASE 
        WHEN crecimiento_mensual_ingresos < -15 THEN '1️⃣ Análisis urgente de causas de caída de ingresos'
        WHEN crecimiento_mensual_clientes < -20 THEN '1️⃣ Campaña intensiva de retención de clientes'
        WHEN ratio_ingresos_costos_personal < 2.5 THEN '1️⃣ Optimización de eficiencia operativa'
        WHEN tasa_nuevos_clientes < 3 THEN '1️⃣ Intensificar estrategias de adquisición'
        WHEN puntuacion_salud_negocio >= 85 THEN '1️⃣ Planificar estrategias de escalamiento'
        ELSE '1️⃣ Monitoreo continuo y mejora incremental'
    END as accion_prioritaria_1,
    
    CASE 
        WHEN rotacion_promedio_mensual < 0.5 THEN '2️⃣ Revisar gestión de inventario y pricing'
        WHEN ABS(desviacion_tendencia_ingresos) > 25 THEN '2️⃣ Investigar factores de volatilidad'
        WHEN tasa_retencion_clientes < 50 THEN '2️⃣ Mejorar experiencia y satisfacción del cliente'
        ELSE '2️⃣ Desarrollo de nuevas oportunidades de negocio'
    END as accion_prioritaria_2
    
FROM sistema_alertas_temp
WHERE año >= EXTRACT(YEAR FROM CURRENT_DATE) - 1  -- Último año
ORDER BY año DESC, mes DESC;

-- =====================================================
-- RESUMEN EJECUTIVO ÚLTIMO PERÍODO
-- =====================================================

WITH ultimo_periodo AS (
    SELECT *
    FROM sistema_alertas_temp
    WHERE año >= EXTRACT(YEAR FROM CURRENT_DATE) - 1
    ORDER BY año DESC, mes DESC
    LIMIT 1
)
SELECT 
    '📊 RESUMEN EJECUTIVO - ÚLTIMO PERÍODO' as seccion,
    CONCAT(mes, '/', año) as periodo,
    '$' || ROUND(ingresos_totales::NUMERIC, 2) as ingresos,
    clientes_activos as clientes,
    total_empleados_periodo as empleados,
    CONCAT(ROUND(crecimiento_mensual_ingresos, 1), '%') as crecimiento_mensual,
    CONCAT(ROUND(crecimiento_anual_ingresos, 1), '%') as crecimiento_anual,
    puntuacion_salud_negocio as score_salud,
    CASE 
        WHEN puntuacion_salud_negocio >= 85 THEN 'EXCELENTE 🟢'
        WHEN puntuacion_salud_negocio >= 70 THEN 'BUENO 🟡'
        WHEN puntuacion_salud_negocio >= 55 THEN 'REGULAR 🟠'
        WHEN puntuacion_salud_negocio >= 40 THEN 'PREOCUPANTE 🔴'
        ELSE 'CRÍTICO ⚠️'
    END as estado_general,
    estado_alerta_principal as alertas_principales,
    CASE 
        WHEN estado_alerta_principal LIKE 'CRÍTICO%' 
        THEN '🚨 ACCIÓN INMEDIATA REQUERIDA'
        WHEN estado_alerta_principal LIKE 'ALERTA%' 
        THEN '⚠️ ATENCIÓN Y MONITOREO'
        WHEN puntuacion_salud_negocio >= 85 
        THEN '🚀 APROVECHAR MOMENTUM'
        ELSE '📈 MANTENER CURSO'
    END as accion_requerida_inmediata
FROM ultimo_periodo;

-- =====================================================
-- COMPARATIVO TRIMESTRAL
-- =====================================================

SELECT 
    'Q' || CEILING(mes/3.0) || '-' || año as trimestre,
    '$' || ROUND(AVG(ingresos_totales)::NUMERIC, 2) as ingresos_promedio_mensual,
    ROUND(AVG(crecimiento_mensual_ingresos), 1) as crecimiento_promedio,
    ROUND(AVG(puntuacion_salud_negocio), 1) as score_salud_promedio,
    ROUND(AVG(clientes_activos), 0) as clientes_promedio,
    ROUND(AVG(ratio_ingresos_costos_personal), 2) as eficiencia_promedio,
    
    -- Evaluación trimestral
    CASE 
        WHEN AVG(puntuacion_salud_negocio) >= 80 THEN 'Trimestre Excelente'
        WHEN AVG(puntuacion_salud_negocio) >= 65 THEN 'Trimestre Sólido'
        WHEN AVG(puntuacion_salud_negocio) >= 50 THEN 'Trimestre Regular'
        ELSE 'Trimestre Desafiante'
    END as evaluacion_trimestral
    
FROM sistema_alertas_temp
WHERE año >= EXTRACT(YEAR FROM CURRENT_DATE) - 1
GROUP BY año, CEILING(mes/3.0)
ORDER BY año DESC, CEILING(mes/3.0) DESC;

/*
RESULTADOS ESPERADOS:
- Dashboard ejecutivo completo con KPIs integrados
- Sistema de alertas automáticas por área de negocio
- Puntuación de salud del negocio con componentes específicos
- Recomendaciones estratégicas basadas en datos
- Análisis comparativo temporal y tendencias

MÉTRICAS CLAVE:
- Score de salud del negocio (0-100)
- Crecimientos período a período
- Eficiencia operativa multidimensional
- Alertas automáticas por umbral
- Recomendaciones estratégicas priorizadas
*/