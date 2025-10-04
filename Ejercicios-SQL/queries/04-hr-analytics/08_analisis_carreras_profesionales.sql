-- =====================================================
-- QUERY 8: ANÁLISIS DE CARRERAS PROFESIONALES
-- =====================================================

/*
PROBLEMA:
Analizar las trayectorias profesionales de empleados, identificando
patrones de promoción, retención, desarrollo salarial y potencial
de crecimiento para optimizar estrategias de RRHH.

TÉCNICAS UTILIZADAS:
- Análisis temporal de carreras
- Cálculo de métricas de crecimiento salarial
- Benchmarking interno por departamento
- Correlación entre rendimiento y desarrollo
- Clasificación de potencial profesional

CASOS DE USO:
- Planificación de sucesión
- Estrategias de retención de talento
- Evaluaciones de performance
- Planes de desarrollo profesional
- Análisis de equidad salarial
*/

WITH historial_empleados AS (
    -- PASO 1: Construir perfil base de cada empleado
    SELECT
        e.id,
        e.nombre || ' ' || e.apellido as empleado,
        e.departamento_id,
        d.nombre as departamento_actual,
        e.salario as salario_actual,
        e.fecha_ingreso,
        e.manager_id,

        -- Cálculos temporales
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.fecha_ingreso))::INTEGER as años_empresa,
        (EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.fecha_ingreso)) * 12 + 
         EXTRACT(MONTH FROM AGE(CURRENT_DATE, e.fecha_ingreso)))::INTEGER as meses_empresa,

        -- Simulación de datos históricos (en implementación real vendrían de tabla de historial)
        CASE
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.fecha_ingreso)) >= 5 THEN e.salario * 0.65  -- Simulamos salario inicial hace 5 años
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.fecha_ingreso)) >= 3 THEN e.salario * 0.75  -- Simulamos salario inicial hace 3 años
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.fecha_ingreso)) >= 1 THEN e.salario * 0.85  -- Simulamos salario inicial hace 1 año
            ELSE e.salario * 0.95   -- Empleados muy nuevos
        END as salario_inicial_estimado,

        -- Simulación de salario hace 2 años
        CASE
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.fecha_ingreso)) >= 3 THEN e.salario * 0.85
            WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.fecha_ingreso)) >= 2 THEN e.salario * 0.90
            ELSE e.salario * 0.95
        END as salario_hace_2_años

    FROM empleados e
    INNER JOIN departamentos d ON e.departamento_id = d.id
),

metricas_rendimiento AS (
    -- PASO 2: Agregar métricas de rendimiento en ventas
    SELECT
        h.*,
        COALESCE(v.total_ventas, 0) as total_ventas,
        COALESCE(v.num_ventas, 0) as num_ventas,
        COALESCE(v.promedio_venta, 0) as promedio_venta,
        COALESCE(v.ventas_ultimo_trimestre, 0) as ventas_ultimo_trimestre

    FROM historial_empleados h
    LEFT JOIN (
        SELECT
            empleado_id,
            SUM(cantidad * precio_unitario) as total_ventas,
            COUNT(*) as num_ventas,
            AVG(cantidad * precio_unitario) as promedio_venta,
            SUM(CASE
                WHEN fecha_venta >= CURRENT_DATE - INTERVAL '3 months'
                THEN cantidad * precio_unitario * (1 - descuento/100)
                ELSE 0
            END) as ventas_ultimo_trimestre
        FROM ventas
        GROUP BY empleado_id
    ) v ON h.id = v.empleado_id
),

percentiles_dept AS (
    -- PASO 3: Calcular percentiles por departamento
    SELECT
        departamento_actual,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salario_actual) as mediana_salarial_dept,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salario_actual) as percentil_75_dept,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salario_actual) as percentil_25_dept
    FROM metricas_rendimiento
    GROUP BY departamento_actual
),

analisis_carrera AS (
    -- PASO 4: Calcular métricas de desarrollo profesional
    SELECT 
        mr.*,
        -- Métricas de crecimiento salarial
        (mr.salario_actual - mr.salario_inicial_estimado) as crecimiento_salarial_absoluto,

        CASE
            WHEN mr.salario_inicial_estimado > 0
            THEN (mr.salario_actual - mr.salario_inicial_estimado) * 100.0 / mr.salario_inicial_estimado
            ELSE 0
        END as crecimiento_salarial_porcentual,

        CASE
            WHEN mr.años_empresa > 0
            THEN (mr.salario_actual - mr.salario_inicial_estimado) / mr.años_empresa
            ELSE 0
        END as crecimiento_anual_promedio,

        -- Crecimiento reciente (últimos 2 años)
        CASE
            WHEN mr.salario_hace_2_años > 0
            THEN (mr.salario_actual - mr.salario_hace_2_años) * 100.0 / mr.salario_hace_2_años
            ELSE 0
        END as crecimiento_reciente_porcentual,

        -- Benchmarking interno
        AVG(mr.salario_actual) OVER (PARTITION BY mr.departamento_actual) as salario_promedio_dept,
        pd.mediana_salarial_dept,
        pd.percentil_75_dept,
        pd.percentil_25_dept,

        -- Rankings dentro del departamento
        RANK() OVER (PARTITION BY mr.departamento_actual ORDER BY mr.salario_actual DESC) as ranking_salarial_dept,
        RANK() OVER (PARTITION BY mr.departamento_actual ORDER BY mr.años_empresa DESC) as ranking_antiguedad_dept,
        RANK() OVER (PARTITION BY mr.departamento_actual ORDER BY mr.total_ventas DESC) as ranking_ventas_dept,

        -- Percentiles dentro del departamento
        PERCENT_RANK() OVER (PARTITION BY mr.departamento_actual ORDER BY mr.salario_actual) * 100 as percentil_salarial_dept,

        -- Eficiencia (ventas por unidad de salario)
        CASE
            WHEN mr.salario_actual > 0
            THEN mr.total_ventas / mr.salario_actual
            ELSE 0
        END as ratio_ventas_salario,

        -- Clasificación de experiencia
        CASE
            WHEN mr.años_empresa < 1 THEN 'Novato'
            WHEN mr.años_empresa < 3 THEN 'Junior'
            WHEN mr.años_empresa < 7 THEN 'Senior'
            WHEN mr.años_empresa < 12 THEN 'Experto'
            ELSE 'Veterano'
        END as nivel_experiencia

    FROM metricas_rendimiento mr
    LEFT JOIN percentiles_dept pd ON mr.departamento_actual = pd.departamento_actual
),

clasificacion_potencial AS (
    -- PASO 4: Clasificar potencial y rendimiento
    SELECT *,
        -- Diferencia con promedio departamental
        salario_actual - salario_promedio_dept as diferencia_promedio_dept,

        -- Clasificación de rendimiento salarial
        CASE
            WHEN salario_actual >= percentil_75_dept THEN 'Alto'
            WHEN salario_actual >= salario_promedio_dept THEN 'Medio-Alto'
            WHEN salario_actual >= percentil_25_dept THEN 'Medio'
            ELSE 'Bajo'
        END as clasificacion_salarial,

        -- Clasificación de crecimiento
        CASE
            WHEN crecimiento_salarial_porcentual > 50 THEN 'Crecimiento Excepcional'
            WHEN crecimiento_salarial_porcentual > 30 THEN 'Crecimiento Alto'
            WHEN crecimiento_salarial_porcentual > 15 THEN 'Crecimiento Moderado'
            WHEN crecimiento_salarial_porcentual > 5 THEN 'Crecimiento Bajo'
            ELSE 'Sin Crecimiento Significativo'
        END as clasificacion_crecimiento,

        -- Potencial de desarrollo (combinando múltiples factores)
        CASE
            WHEN crecimiento_reciente_porcentual > 15 AND ratio_ventas_salario > AVG(ratio_ventas_salario) OVER (PARTITION BY departamento_actual) * 1.2
                THEN 'Alto Potencial'
            WHEN crecimiento_reciente_porcentual > 10 OR ratio_ventas_salario > AVG(ratio_ventas_salario) OVER (PARTITION BY departamento_actual) * 1.1
                THEN 'Potencial Medio'
            WHEN años_empresa > 5 AND crecimiento_reciente_porcentual < 5 AND percentil_salarial_dept < 30
                THEN 'Necesita Atención'
            WHEN años_empresa > 8 AND crecimiento_reciente_porcentual < 0
                THEN 'Riesgo de Rotación'
            ELSE 'Estable'
        END as clasificacion_potencial,

        -- Riesgo de fuga (flight risk)
        CASE
            WHEN años_empresa > 3 AND percentil_salarial_dept < 25 AND crecimiento_reciente_porcentual < 5
                THEN 'Alto'
            WHEN años_empresa > 2 AND percentil_salarial_dept < 40 AND crecimiento_reciente_porcentual < 10
                THEN 'Medio'
            ELSE 'Bajo'
        END as riesgo_fuga,

        -- Preparación para promoción
        CASE
            WHEN percentil_salarial_dept >= 75 AND años_empresa >= 2 AND ratio_ventas_salario > AVG(ratio_ventas_salario) OVER (PARTITION BY departamento_actual)
                THEN 'Listo para Promoción'
            WHEN percentil_salarial_dept >= 50 AND años_empresa >= 3
                THEN 'En Desarrollo para Promoción'
            WHEN años_empresa < 2
                THEN 'Muy Temprano'
            ELSE 'Necesita Desarrollo'
        END as preparacion_promocion

    FROM analisis_carrera
)

-- Crear tabla temporal para usar en múltiples consultas
SELECT * INTO TEMP TABLE clasificacion_potencial_temp FROM clasificacion_potencial;

-- RESULTADO PRINCIPAL: Análisis integral de carreras
SELECT
    empleado,
    departamento_actual,
    nivel_experiencia,
    años_empresa,
    meses_empresa,

    -- Información salarial
    '$' || ROUND(salario_inicial_estimado::NUMERIC, 2) as salario_inicial,
    '$' || ROUND(salario_actual::NUMERIC, 2) as salario_actual,
    '$' || ROUND(crecimiento_salarial_absoluto::NUMERIC, 2) as crecimiento_absoluto,
    ROUND(crecimiento_salarial_porcentual::NUMERIC, 2) as crecimiento_total_pct,
    ROUND(crecimiento_reciente_porcentual::NUMERIC, 2) as crecimiento_reciente_pct,
    clasificacion_crecimiento,

    -- Posición dentro del departamento
    ranking_salarial_dept,
    ranking_antiguedad_dept,
    ROUND(percentil_salarial_dept::NUMERIC, 1) as percentil_salarial,
    clasificacion_salarial,
    '$' || ROUND(diferencia_promedio_dept::NUMERIC, 2) as diferencia_vs_promedio,

    -- Rendimiento en ventas
    '$' || ROUND(total_ventas::NUMERIC, 2) as ventas_generadas,
    num_ventas,
    ranking_ventas_dept,
    ROUND(ratio_ventas_salario::NUMERIC, 2) as eficiencia_ventas,

    -- Análisis de potencial y desarrollo
    clasificacion_potencial,
    preparacion_promocion,
    riesgo_fuga,

    -- Recomendaciones personalizadas
    CASE
        WHEN clasificacion_potencial = 'Alto Potencial' AND preparacion_promocion = 'Listo para Promoción'
            THEN 'ACCIÓN INMEDIATA: Promoción y aumento salarial recomendados'
        WHEN clasificacion_potencial = 'Alto Potencial'
            THEN 'Desarrollo acelerado: Capacitación y mayores responsabilidades'
        WHEN riesgo_fuga = 'Alto'
            THEN 'RETENCIÓN URGENTE: Revisión salarial y plan de carrera'
        WHEN clasificacion_potencial = 'Necesita Atención'
            THEN 'Plan de mejora: Mentoría y objetivos específicos'
        WHEN preparacion_promocion = 'Listo para Promoción'
            THEN 'Evaluar oportunidades de promoción interna'
        WHEN riesgo_fuga = 'Medio'
            THEN 'Conversación de carrera y evaluación de satisfacción'
        ELSE 'Desarrollo profesional continuo'
    END as recomendacion_rrhh,

    -- Inversión recomendada en desarrollo
    CASE
        WHEN clasificacion_potencial = 'Alto Potencial'
            THEN 'Alta: 8-12% del salario anual'
        WHEN clasificacion_potencial = 'Potencial Medio'
            THEN 'Media: 4-8% del salario anual'
        WHEN riesgo_fuga != 'Bajo'
            THEN 'Específica: 5-10% en retención'
        ELSE 'Estándar: 2-4% del salario anual'
    END as inversion_desarrollo_recomendada,

    -- Timeline para próximas acciones
    CASE
        WHEN riesgo_fuga = 'Alto'
            THEN 'Inmediato (0-30 días)'
        WHEN clasificacion_potencial = 'Alto Potencial'
            THEN 'Corto plazo (1-3 meses)'
        WHEN preparacion_promocion = 'Listo para Promoción'
            THEN 'Mediano plazo (3-6 meses)'
        ELSE 'Planificación anual'
    END as timeline_accion

FROM clasificacion_potencial_temp
ORDER BY
    CASE clasificacion_potencial
        WHEN 'Alto Potencial' THEN 1
        WHEN 'Potencial Medio' THEN 2
        WHEN 'Estable' THEN 3
        WHEN 'Necesita Atención' THEN 4
        WHEN 'Riesgo de Rotación' THEN 5
    END,
    CASE riesgo_fuga
        WHEN 'Alto' THEN 1
        WHEN 'Medio' THEN 2
        WHEN 'Bajo' THEN 3
    END,
    total_ventas DESC;

-- =====================================================
-- RESUMEN EJECUTIVO POR DEPARTAMENTO
-- =====================================================

SELECT
    departamento_actual,
    COUNT(*) as total_empleados,

    -- Métricas salariales
    '$' || ROUND(AVG(salario_actual)::NUMERIC, 2) as salario_promedio,
    '$' || ROUND(MIN(salario_actual)::NUMERIC, 2) as salario_minimo,
    '$' || ROUND(MAX(salario_actual)::NUMERIC, 2) as salario_maximo,
    ROUND(AVG(crecimiento_salarial_porcentual)::NUMERIC, 2) as crecimiento_promedio_pct,

    -- Distribución de experiencia
    ROUND(AVG(años_empresa)::NUMERIC, 1) as antiguedad_promedio,
    COUNT(CASE WHEN años_empresa < 2 THEN 1 END) as empleados_nuevos,
    COUNT(CASE WHEN años_empresa >= 5 THEN 1 END) as empleados_veteranos,

    -- Análisis de potencial
    COUNT(CASE WHEN clasificacion_potencial = 'Alto Potencial' THEN 1 END) as alto_potencial,
    COUNT(CASE WHEN clasificacion_potencial = 'Necesita Atención' THEN 1 END) as necesitan_atencion,
    COUNT(CASE WHEN riesgo_fuga = 'Alto' THEN 1 END) as alto_riesgo_fuga,

    -- Preparación para promociones
    COUNT(CASE WHEN preparacion_promocion = 'Listo para Promoción' THEN 1 END) as listos_promocion,

    -- Métricas de rendimiento
    '$' || ROUND(SUM(total_ventas)::NUMERIC, 2) as ventas_totales_dept,
    ROUND(AVG(ratio_ventas_salario)::NUMERIC, 2) as eficiencia_promedio,

    -- Indicadores de salud organizacional
    ROUND(COUNT(CASE WHEN riesgo_fuga = 'Alto' THEN 1 END) * 100.0 / COUNT(*), 1) as porcentaje_riesgo_alto,
    ROUND(COUNT(CASE WHEN clasificacion_potencial = 'Alto Potencial' THEN 1 END) * 100.0 / COUNT(*), 1) as porcentaje_alto_potencial,

    -- Evaluación general del departamento
    CASE
        WHEN COUNT(CASE WHEN riesgo_fuga = 'Alto' THEN 1 END) * 100.0 / COUNT(*) > 20
            THEN 'DEPARTAMENTO EN RIESGO - Acción urgente requerida'
        WHEN COUNT(CASE WHEN clasificacion_potencial = 'Alto Potencial' THEN 1 END) * 100.0 / COUNT(*) > 25
            THEN 'Departamento con gran potencial - Invertir en desarrollo'
        WHEN AVG(crecimiento_salarial_porcentual) > 20
            THEN 'Departamento en crecimiento saludable'
        WHEN COUNT(CASE WHEN clasificacion_potencial = 'Necesita Atención' THEN 1 END) * 100.0 / COUNT(*) > 30
            THEN 'Departamento necesita atención en desarrollo'
        ELSE 'Departamento estable'
    END as evaluacion_departamento,

    -- Prioridades de RRHH
    CASE
        WHEN COUNT(CASE WHEN riesgo_fuga = 'Alto' THEN 1 END) > 0
            THEN '1. Retención urgente de talento'
        WHEN COUNT(CASE WHEN preparacion_promocion = 'Listo para Promoción' THEN 1 END) > 0
            THEN '1. Planificar promociones internas'
        WHEN COUNT(CASE WHEN clasificacion_potencial = 'Alto Potencial' THEN 1 END) > 0
            THEN '1. Desarrollo de alto potencial'
        ELSE '1. Desarrollo profesional continuo'
    END as prioridad_principal

FROM clasificacion_potencial_temp
GROUP BY departamento_actual
ORDER BY
    COUNT(CASE WHEN riesgo_fuga = 'Alto' THEN 1 END) DESC,
    COUNT(CASE WHEN clasificacion_potencial = 'Alto Potencial' THEN 1 END) DESC;

-- =====================================================
-- MATRIZ DE TALENTO (9-BOX GRID)
-- =====================================================

SELECT
    -- Crear matriz de rendimiento vs potencial
    CASE
        WHEN percentil_salarial_dept >= 66 THEN 'Alto Rendimiento'
        WHEN percentil_salarial_dept >= 33 THEN 'Rendimiento Medio'
        ELSE 'Bajo Rendimiento'
    END as rendimiento,

    CASE
        WHEN clasificacion_potencial IN ('Alto Potencial') THEN 'Alto Potencial'
        WHEN clasificacion_potencial IN ('Potencial Medio', 'Estable') THEN 'Potencial Medio'
        ELSE 'Bajo Potencial'
    END as potencial,

    COUNT(*) as num_empleados,
    '$' || ROUND(AVG(salario_actual)::NUMERIC, 2) as salario_promedio,
    ROUND(AVG(crecimiento_salarial_porcentual)::NUMERIC, 2) as crecimiento_promedio

FROM clasificacion_potencial_temp
GROUP BY
    CASE
        WHEN percentil_salarial_dept >= 66 THEN 'Alto Rendimiento'
        WHEN percentil_salarial_dept >= 33 THEN 'Rendimiento Medio'
        ELSE 'Bajo Rendimiento'
    END,
    CASE
        WHEN clasificacion_potencial IN ('Alto Potencial') THEN 'Alto Potencial'
        WHEN clasificacion_potencial IN ('Potencial Medio', 'Estable') THEN 'Potencial Medio'
        ELSE 'Bajo Potencial'
    END
ORDER BY rendimiento DESC, potencial DESC;

/*
RESULTADOS ESPERADOS:
- Análisis completo de trayectorias profesionales
- Identificación de empleados de alto potencial
- Estrategias de retención personalizadas
- Matriz de talento para planificación de sucesión

MÉTRICAS CLAVE:
- Crecimiento salarial histórico y proyectado
- Posicionamiento relativo dentro del departamento
- Correlación entre rendimiento y desarrollo
- Riesgo de rotación y estrategias de retención
*/