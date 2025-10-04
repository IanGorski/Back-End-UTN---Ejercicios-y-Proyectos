# 📊 Sistema de Business Intelligence con PostgreSQL

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-316192.svg?logo=postgresql)](https://www.postgresql.org/)
[![SQL](https://img.shields.io/badge/SQL-Advanced-orange.svg)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Queries](https://img.shields.io/badge/Queries-8-blue.svg)]()
[![Lines](https://img.shields.io/badge/Lines-3500%2B-yellow.svg)]()

> Sistema completo de análisis empresarial y Business Intelligence para e-commerce, implementado con PostgreSQL y SQL avanzado.

---

## 🎯 Descripción del Proyecto

Este proyecto implementa un **sistema integral de análisis de negocio** que cubre 8 áreas críticas:

1. **Análisis de Cohortes** - Retención y comportamiento de clientes por cohorte
2. **Clasificación ABC de Productos** - Categorización por valor e impacto
3. **Detección de Anomalías** - Identificación automática de patrones inusuales en ventas
4. **Series Temporales** - Análisis de tendencias y proyecciones
5. **Segmentación RFM de Clientes** - Clasificación en 11 segmentos de valor
6. **Gestión de Talento** - Análisis de carreras y retención de empleados
7. **Optimización de Inventario** - Control de stock y reducción de costos
8. **Dashboard Ejecutivo** - KPIs integrados con sistema de alertas

---

## 🗄️ Diagrama del Esquema de Base de Datos

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│    CLIENTES     │       │    EMPLEADOS    │       │   PRODUCTOS     │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ id (PK)         │       │ id (PK)         │       │ id (PK)         │
│ nombre          │       │ nombre          │       │ nombre          │
│ email           │       │ apellido        │       │ categoria       │
│ ciudad          │       │ salario         │       │ precio          │
│ fecha_registro  │       │ fecha_ingreso   │       │ stock           │
│ activo          │       │ departamento_id │       │ proveedor_id    │
└────────┬────────┘       │ manager_id      │       └────────┬────────┘
         │                └────────┬────────┘                │
         │                         │                         │
         │                         │                         │
         │    ┌────────────────────┴─────────────┐          │
         │    │                                   │          │
         ├────┼───────────────────────────────────┼──────────┤
         │    │                                   │          │
┌────────▼────▼────┐       ┌──────────────────┐  │  ┌──────▼──────┐
│     PEDIDOS      │       │  DEPARTAMENTOS   │  │  │   VENTAS    │
├──────────────────┤       ├──────────────────┤  │  ├─────────────┤
│ id (PK)          │       │ id (PK)          │  │  │ id (PK)     │
│ cliente_id (FK)  │       │ nombre           │  │  │ producto_id │
│ empleado_id (FK) │       │ presupuesto      │  │  │ empleado_id │
│ fecha_pedido     │       │ ubicacion        │  │  │ cantidad    │
│ total            │       └──────────────────┘  │  │ precio_unit │
│ estado           │                             │  │ fecha_venta │
└──────────────────┘                             │  │ descuento   │
                                                 └──┴─────────────┘

RELACIONES:
- CLIENTES (1) ─── (N) PEDIDOS
- EMPLEADOS (1) ─── (N) PEDIDOS
- EMPLEADOS (1) ─── (N) VENTAS
- PRODUCTOS (1) ─── (N) VENTAS
- DEPARTAMENTOS (1) ─── (N) EMPLEADOS
```

---

## 🛠️ Tecnologías y Técnicas

### **Stack Tecnológico**
- **PostgreSQL 14+** - Motor de base de datos
- **SQL Avanzado** - Queries complejas y optimizadas
- **pgAdmin 4** - Herramienta de administración

### **Técnicas SQL Avanzadas Implementadas**

| Técnica | Uso en el Proyecto |
|---------|-------------------|
| **CTEs (Common Table Expressions)** | Organización de queries complejas en pasos lógicos |
| **Window Functions** | Cálculos de ranking, percentiles y tendencias |
| **PERCENTILE_CONT** | Análisis estadístico de distribuciones |
| **NTILE** | Segmentación en quintiles para análisis RFM |
| **LAG/LEAD** | Comparaciones temporales (mes anterior/año anterior) |
| **Subqueries Correlacionadas** | Análisis multi-dimensional |
| **Tablas Temporales** | Optimización de queries con múltiples consultas |
| **CASE Statements Complejos** | Lógica de negocio y clasificaciones |
| **Agregaciones Multi-nivel** | Métricas consolidadas por categorías |

---

## 📁 Estructura del Proyecto

```
Ejercicios-SQL/
│
├── 03_analisis_cohortes_clientes.sql          # Cohort Analysis
├── 04_analisis_abc_productos.sql              # ABC Classification
├── 05_deteccion_anomalias_ventas.sql          # Anomaly Detection
├── 06_series_temporales_tendencias.sql        # Time Series Analysis
├── 07_segmentacion_rfm_clientes.sql           # RFM Segmentation
├── 08_analisis_carreras_profesionales.sql     # Talent Management
├── 09_optimizacion_inventario.sql             # Inventory Optimization
├── 10_dashboard_ejecutivo_integral.sql        # Executive Dashboard
└── README.md                                   # Este archivo
```

---

## 🚀 Casos de Uso y Funcionalidades

### **1. Análisis de Cohortes de Clientes**
📄 `03_analisis_cohortes_clientes.sql`

#### **¿Qué hace?**
Analiza el comportamiento de retención de clientes agrupándolos por período de adquisición (cohortes).

#### **Métricas Calculadas:**
- 📅 Tasa de retención por mes
- 👥 Tamaño de cada cohorte
- 💰 Valor de vida del cliente por cohorte
- 📊 Análisis de churn por período

#### **Valor de Negocio:**
- ✅ **Identificar patrones de retención**: Qué cohortes tienen mejor retención
- ✅ **Optimizar onboarding**: Mejora en primeros meses = mejor retención
- ✅ **Predicción de churn**: Detectar períodos críticos de abandono
- ✅ **ROI de campañas**: Medir efectividad de marketing por período

---

### **2. Clasificación ABC de Productos**
📄 `04_analisis_abc_productos.sql`

#### **¿Qué hace?**
Clasifica productos en 3 categorías según su impacto en ingresos (Principio de Pareto 80/20).

#### **Clasificación:**
- 🅰️ **Clase A** (20% productos): 80% de ingresos - Alta prioridad
- 🅱️ **Clase B** (30% productos): 15% de ingresos - Media prioridad  
- 🅲️ **Clase C** (50% productos): 5% de ingresos - Baja prioridad

#### **Valor de Negocio:**
- ✅ **Optimización de recursos**: Enfocar esfuerzos en productos A
- ✅ **Gestión de inventario**: Más stock de A, menos de C
- ✅ **Estrategia de pricing**: Pricing dinámico por categoría
- ✅ **Decisiones de descontinuación**: Identificar productos C para eliminar

---

### **3. Detección de Anomalías en Ventas**
📄 `05_deteccion_anomalias_ventas.sql`

#### **¿Qué hace?**
Detecta automáticamente patrones inusuales en ventas usando análisis estadístico.

#### **Técnicas Utilizadas:**
- 📊 Desviación estándar y Z-scores
- 📈 Percentiles y rangos intercuartílicos
- 🔍 Detección de outliers multivariante
- ⚠️ Sistema de alertas automático

#### **Valor de Negocio:**
- ✅ **Detección de fraude**: Transacciones sospechosas
- ✅ **Control de calidad**: Errores en registro de datos
- ✅ **Oportunidades**: Picos de demanda no esperados
- ✅ **Prevención de problemas**: Caídas anormales de ventas

---

### **4. Análisis de Series Temporales y Tendencias**
📄 `06_series_temporales_tendencias.sql`

#### **¿Qué hace?**
Analiza patrones temporales y proyecta tendencias futuras de ventas.

#### **Métricas Calculadas:**
- 📅 Tendencias mensuales/trimestrales/anuales
- 🔄 Estacionalidad y ciclos
- 📈 Tasas de crecimiento
- 🔮 Proyecciones simples

#### **Valor de Negocio:**
- ✅ **Planificación estratégica**: Proyectar ingresos futuros
- ✅ **Gestión de inventario**: Anticipar demanda estacional
- ✅ **Presupuestación**: Forecasts para planificación financiera
- ✅ **Identificación de ciclos**: Patrones recurrentes de negocio

---

### **5. Segmentación RFM de Clientes** 
📄 `07_segmentacion_rfm_clientes.sql`

#### **¿Qué hace?**
Clasifica automáticamente a los clientes en 11 segmentos basándose en:
- **R**ecency: ¿Qué tan reciente fue su última compra?
- **F**requency: ¿Con qué frecuencia compra?
- **M**onetary: ¿Cuánto dinero gasta?

#### **Segmentos Identificados:**
- 🏆 **Champions** - Los mejores clientes
- 💎 **Loyal Customers** - Clientes leales
- 🌟 **Potential Loyalists** - Pueden volverse leales
- 🆕 **Recent Customers** - Compraron recientemente
- ⚠️ **At Risk** - Alto riesgo de pérdida
- 😴 **Hibernating** - Inactivos
- ❌ **Lost** - Perdidos

#### **Query de Ejemplo:**
```sql
-- Top 5 clientes Champions por valor de vida (CLV)
SELECT 
    nombre_completo,
    email,
    rfm_score,
    TO_CHAR(valor_total_gastado, 'L999,999,999') AS lifetime_value,
    total_compras,
    clv_estimado_2_anos
FROM 
    rfm_analysis
WHERE 
    segmento_rfm = 'Champions'
ORDER BY 
    rfm_weighted_score DESC
LIMIT 5;
```

#### **Resultado de Ejemplo:**
```
nombre_completo     | email                  | rfm_score | lifetime_value | total_compras | clv_estimado
--------------------|------------------------|-----------|----------------|---------------|-------------
María González      | maria.g@email.com      | 555       | $   125,450    | 48            | $   250,900
Carlos Rodríguez    | carlos.r@email.com     | 554       | $   118,230    | 42            | $   236,460
Ana Martínez        | ana.m@email.com        | 545       | $   115,890    | 39            | $   231,780
```

#### **Valor de Negocio:**
- ✅ **Retención**: Identifica clientes en riesgo antes de que abandonen
- ✅ **ROI Marketing**: Invierte recursos en segmentos con mayor retorno
- ✅ **Personalización**: Campañas específicas para cada segmento
- ✅ **CLV**: Calcula el valor de vida estimado a 2 años

---

### **6. Análisis de Carreras Profesionales**
📄 `08_analisis_carreras_profesionales.sql`

#### **¿Qué hace?**
Analiza el desarrollo profesional de empleados para optimizar la gestión de talento.

#### **Métricas Calculadas:**
- 📈 Crecimiento salarial (absoluto y porcentual)
- 🎯 Potencial de desarrollo (Alto/Medio/Bajo)
- ⚠️ Riesgo de rotación (fuga de talento)
- 🏅 Preparación para promoción
- 💰 Benchmarking salarial por departamento

#### **Query de Ejemplo:**
```sql
-- Empleados con alto riesgo de fuga (requieren atención urgente)
SELECT 
    empleado,
    departamento_actual,
    años_empresa,
    salario_actual,
    percentil_salarial AS posición_salarial,
    riesgo_fuga,
    recomendacion_rrhh
FROM 
    clasificacion_potencial_temp
WHERE 
    riesgo_fuga = 'Alto'
ORDER BY 
    valor_total_gastado DESC;
```

#### **Resultado de Ejemplo:**
```
empleado         | departamento | años_empresa | salario_actual | posición_salarial | riesgo_fuga | recomendacion_rrhh
-----------------|--------------|--------------|----------------|-------------------|-------------|-------------------
Juan Pérez       | Ventas       | 5            | $45,000        | 22%               | Alto        | RETENCIÓN URGENTE: Revisión salarial
Laura Sánchez    | IT           | 4            | $52,000        | 18%               | Alto        | RETENCIÓN URGENTE: Revisión salarial
```

#### **Valor de Negocio:**
- ✅ **Prevención de Rotación**: Costos de reemplazo = 150-200% del salario
- ✅ **Equidad Salarial**: Identifica disparidades y previene problemas legales
- ✅ **Planificación de Sucesión**: Identifica candidatos listos para promoción
- ✅ **Optimización de Inversión**: Prioriza desarrollo en talento de alto potencial

---

### **7. Optimización de Inventario**
📄 `09_optimizacion_inventario.sql`

#### **¿Qué hace?**
Optimiza niveles de inventario para minimizar costos y maximizar disponibilidad.

#### **Métricas Calculadas:**
- 📦 Stock óptimo y punto de reorden
- 🔄 Rotación de inventario
- 💰 Valor de inventario y costos de oportunidad
- ⚠️ Identificación de productos obsoletos
- 📊 Clasificación ABC de productos

#### **Query de Ejemplo:**
```sql
-- Productos que requieren reabastecimiento urgente
SELECT 
    nombre_producto,
    categoria,
    stock_actual,
    punto_reorden,
    cantidad_optima_pedido,
    dias_faltante_stock,
    costo_oportunidad_faltante,
    accion_recomendada,
    prioridad
FROM 
    analisis_inventario
WHERE 
    estado_inventario IN ('SIN STOCK', 'REABASTECER URGENTE')
ORDER BY 
    prioridad ASC
LIMIT 10;
```

#### **Resultado de Ejemplo:**
```
nombre_producto  | categoria    | stock | punto_reorden | cant_pedido | dias_faltante | costo_oportunidad | accion_recomendada
-----------------|--------------|-------|---------------|-------------|---------------|-------------------|--------------------
Laptop HP 15"    | Electrónicos | 0     | 15            | 50          | 12            | $15,200           | URGENTE: Pedido inmediato de 50 unidades
Mouse Logitech   | Accesorios   | 3     | 25            | 100         | 0             | $0                | Reabastecer 100 unidades esta semana
```

#### **Valor de Negocio:**
- ✅ **Reducción de Costos**: Optimiza capital inmovilizado en inventario
- ✅ **Prevención de Quiebres**: Evita pérdida de ventas por falta de stock
- ✅ **Detección de Obsolescencia**: Identifica productos de baja rotación
- ✅ **Automatización**: Cálculo automático de cantidades de pedido

---

### **8. Dashboard Ejecutivo Integral**
📄 `10_dashboard_ejecutivo_integral.sql`

#### **¿Qué hace?**
Consolida todas las métricas en un dashboard ejecutivo con **sistema de alertas automático**.

#### **KPIs Principales:**
- 💰 Ingresos totales y crecimiento (mensual/anual)
- 👥 Clientes activos, nuevos y recurrentes
- 👔 Eficiencia de personal (ingresos por empleado)
- 📦 Rotación de inventario
- 🎯 **Score de Salud del Negocio (0-100)**

#### **Sistema de Alertas:**
El sistema identifica automáticamente 7 tipos de alertas críticas:

| Alerta | Condición | Acción |
|--------|-----------|--------|
| 🚨 **CRÍTICO: Caída severa de ingresos** | Crecimiento < -15% | Análisis urgente de causas |
| ⚠️ **ALERTA: Pérdida masiva de clientes** | Crecimiento clientes < -20% | Campaña de retención |
| ⚠️ **ALERTA: Baja eficiencia de personal** | Ratio ingresos/costos < 2.5 | Optimización operativa |
| ⚠️ **ALERTA: Baja adquisición** | Tasa nuevos clientes < 3% | Intensificar marketing |
| ⚠️ **ALERTA: Inventario lento** | Rotación < 0.5 | Revisar pricing |

#### **Query de Ejemplo:**
```sql
-- Dashboard ejecutivo del último mes
SELECT 
    mes,
    año,
    ingresos_totales,
    clientes_activos,
    crecimiento_mensual,
    crecimiento_anual,
    score_salud_negocio,
    estado_salud_negocio,
    estado_alerta_principal,
    alertas_detalladas,
    recomendacion_estrategica_principal,
    accion_prioritaria_1,
    accion_prioritaria_2
FROM 
    sistema_alertas_temp
WHERE 
    año = EXTRACT(YEAR FROM CURRENT_DATE)
ORDER BY 
    año DESC, mes DESC
LIMIT 1;
```

#### **Resultado de Ejemplo:**
```
mes | año  | ingresos    | clientes | crec_mensual | crec_anual | score | estado      | alerta  | recomendacion
----|------|-------------|----------|--------------|------------|-------|-------------|---------|---------------
10  | 2025 | $1,245,780  | 342      | +8.5%        | +22.3%     | 87    | EXCELENTE 🟢 | NORMAL  | 🚀 ACELERAR: Aprovechar momentum
```

#### **Valor de Negocio:**
- ✅ **Toma de Decisiones Rápida**: Toda la información crítica en un solo lugar
- ✅ **Detección Proactiva**: Alertas antes de que los problemas escalen
- ✅ **Medición Objetiva**: Score cuantificable de salud del negocio
- ✅ **Recomendaciones Accionables**: No solo datos, sino qué hacer con ellos

---

## 📊 Score de Salud del Negocio (0-100)

El dashboard calcula un **score compuesto** basado en 4 pilares:

```
Score Total (100 puntos) = 
    ┌─ Crecimiento (25 pts)      - Crecimiento de ingresos anual
    ├─ Eficiencia (25 pts)       - Ratio ingresos/costos personal
    ├─ Clientes (25 pts)         - Retención y adquisición
    └─ Operaciones (25 pts)      - Rotación de inventario
```

### **Clasificación:**
- 🟢 **85-100**: Excelente - Acelerar expansión
- 🟡 **70-84**: Bueno - Optimizar y mantener
- 🟠 **55-69**: Regular - Ajustar procesos
- 🔴 **40-54**: Preocupante - Atención urgente
- ⚠️ **0-39**: Crítico - Reestructuración

---

## 🎓 Habilidades Demostradas

Este proyecto muestra competencia en:

### **SQL Avanzado**
- ✅ Queries complejas con múltiples CTEs
- ✅ Window functions (RANK, LAG, LEAD, NTILE, PERCENT_RANK)
- ✅ Funciones estadísticas (PERCENTILE_CONT, AVG OVER)
- ✅ Subqueries correlacionadas
- ✅ Optimización de queries con tablas temporales

### **Business Intelligence**
- ✅ Diseño de KPIs de negocio
- ✅ Análisis RFM y segmentación de clientes
- ✅ Métricas financieras y operativas
- ✅ Sistemas de alertas y scoring

### **Análisis de Datos**
- ✅ Análisis temporal y tendencias
- ✅ Análisis estadístico (percentiles, distribuciones)
- ✅ Análisis predictivo (riesgo de churn, CLV)
- ✅ Correlaciones multi-dimensionales

### **Pensamiento Estratégico**
- ✅ Traducción de requerimientos de negocio a queries
- ✅ Generación de insights accionables
- ✅ Priorización basada en impacto
- ✅ Recomendaciones estratégicas automatizadas

---

## 🚀 Cómo Usar Este Proyecto

### **Requisitos Previos**
- PostgreSQL 14 o superior
- pgAdmin 4 (o cualquier cliente PostgreSQL)

### **Pasos de Instalación**

1. **Clonar el repositorio**
```bash
git clone https://github.com/IanGorski/Back-End-UTN---Ejercicios-y-Proyectos.git
cd Ejercicios-SQL
```

2. **Crear la base de datos**
```sql
CREATE DATABASE empresa_analytics;
```

3. **Ejecutar scripts de creación de tablas** (si están disponibles)
```sql
-- Ejecutar scripts de schema en orden
\i database/schema/create_tables.sql
\i database/data/insert_sample_data.sql
```

4. **Ejecutar análisis**
```sql
-- Ejecutar cada análisis según necesidad
\i queries/07_segmentacion_rfm_clientes.sql
\i queries/08_analisis_carreras_profesionales.sql
\i queries/09_optimizacion_inventario.sql
\i queries/10_dashboard_ejecutivo_integral.sql
```

---

## 📈 Resultados y Métricas del Proyecto

### **Complejidad Técnica**
- **Líneas de código SQL**: ~3,500+
- **CTEs utilizados**: 40+
- **Window functions**: 20+ tipos diferentes
- **Tablas relacionadas**: 7 tablas principales
- **Métricas calculadas**: 150+ KPIs
- **Queries complejas**: 8 análisis completos

### **Impacto de Negocio Potencial**
- 🎯 **Reducción de churn**: 10-15% mediante análisis de cohortes y RFM
- 💰 **Optimización de inventario**: 20-30% reducción de capital inmovilizado
- 📊 **Foco estratégico**: 80/20 con clasificación ABC
- 🔍 **Detección proactiva**: Identificación automática de anomalías
- 👥 **Retención de talento**: Reducción de costos de rotación en 25%
- 📊 **Toma de decisiones**: 50% más rápida con dashboard automatizado

---

## 🎯 Casos de Uso Reales

Este tipo de análisis se usa en:

### **E-commerce y Retail**
- Amazon, MercadoLibre, Walmart
- Análisis de comportamiento de clientes
- Optimización de inventario multi-almacén

### **SaaS y Tecnología**
- Salesforce, HubSpot, Shopify
- Análisis de churn y retención
- Métricas de product-market fit

### **Recursos Humanos**
- LinkedIn, Workday, BambooHR
- Análisis de talento y compensaciones
- Planificación de sucesión

### **Finanzas y Consultoría**
- McKinsey, Deloitte, KPMG
- Dashboards ejecutivos
- Business intelligence para clientes

---

## 🔄 Próximas Mejoras

- [ ] Conexión a herramientas de visualización (Tableau/Power BI)
- [ ] Automatización de reportes con Python/R
- [ ] API REST para exponer métricas
- [ ] Implementación de Machine Learning para predicciones
- [ ] Dashboard web interactivo con React

---

## 📚 Recursos y Referencias

### **Documentación**
- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [Window Functions Guide](https://www.postgresql.org/docs/current/tutorial-window.html)
- [SQL Style Guide](https://www.sqlstyle.guide/)

### **Conceptos de Negocio**
- [RFM Analysis Guide](https://www.optimove.com/resources/learning-center/rfm-segmentation)
- [Business Intelligence KPIs](https://www.klipfolio.com/resources/kpi-examples)
- [Inventory Optimization](https://www.netsuite.com/portal/resource/articles/inventory-management/inventory-optimization.shtml)

---

## 👤 Autor

**Ian Gorski**
- GitHub: [@IanGorski](https://github.com/IanGorski)
- LinkedIn: [Tu perfil de LinkedIn]
- Portfolio: [Tu sitio web]

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

---

## ⭐ Agradecimientos

Este proyecto fue desarrollado como parte de mi formación en **Back End Development** en la **UTN (Universidad Tecnológica Nacional)**.

---

<div align="center">

**Si este proyecto te resultó útil, dale una ⭐ en GitHub!**

[![GitHub stars](https://img.shields.io/github/stars/IanGorski/Back-End-UTN---Ejercicios-y-Proyectos.svg?style=social)](https://github.com/IanGorski/Back-End-UTN---Ejercicios-y-Proyectos/stargazers)

</div>
