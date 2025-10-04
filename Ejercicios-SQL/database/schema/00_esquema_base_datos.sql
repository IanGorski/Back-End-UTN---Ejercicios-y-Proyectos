-- =====================================================
-- ESQUEMA CORREGIDO Y OPTIMIZADO PARA PRODUCCIÓN
-- PostgreSQL 14+
-- =====================================================

/*
MEJORAS APLICADAS:
✅ Estandarizado a PostgreSQL
✅ Índices optimizados para performance
✅ Constraints de validación de negocio
✅ Valores por defecto
✅ Triggers de auditoría
✅ Particionamiento para escalabilidad
✅ Tipos de datos optimizados
*/

-- =====================================================
-- EXTENSIONES NECESARIAS
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";     -- Para UUIDs
CREATE EXTENSION IF NOT EXISTS "pg_trgm";       -- Para búsquedas de texto

-- =====================================================
-- TABLAS PRINCIPALES
-- =====================================================

-- Tabla de departamentos
CREATE TABLE IF NOT EXISTS departamentos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    presupuesto DECIMAL(12,2) NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_presupuesto_positivo CHECK (presupuesto >= 0)
);

ALTER TABLE departamentos ADD COLUMN IF NOT EXISTS descripcion TEXT;

-- Índices para departamentos
CREATE INDEX IF NOT EXISTS idx_departamentos_activo ON departamentos(activo) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_departamentos_nombre ON departamentos(nombre) WHERE activo = TRUE;



-- Comentarios para documentación
COMMENT ON TABLE departamentos IS 'Departamentos de la organización';
COMMENT ON COLUMN departamentos.presupuesto IS 'Presupuesto anual del departamento';

-- =====================================================

-- Tabla de empleados
CREATE TABLE IF NOT EXISTS empleados (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE,
    departamento_id INTEGER NOT NULL,
    salario DECIMAL(10,2) NOT NULL,
    fecha_ingreso DATE NOT NULL,
    fecha_salida DATE,
    manager_id INTEGER,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_empleado_departamento FOREIGN KEY (departamento_id) 
        REFERENCES departamentos(id) ON DELETE RESTRICT,
    CONSTRAINT fk_empleado_manager FOREIGN KEY (manager_id) 
        REFERENCES empleados(id) ON DELETE SET NULL,
    
    -- Validaciones de negocio
    CONSTRAINT chk_salario_positivo CHECK (salario > 0),
    CONSTRAINT chk_fecha_ingreso_valida CHECK (fecha_ingreso <= CURRENT_DATE),
    CONSTRAINT chk_fecha_salida_valida CHECK (fecha_salida IS NULL OR fecha_salida >= fecha_ingreso),
    CONSTRAINT chk_no_autogestion CHECK (manager_id IS NULL OR manager_id != id)
);

-- Se agrega la columna 'cargo' a la tabla 'empleados'
ALTER TABLE empleados ADD COLUMN IF NOT EXISTS cargo VARCHAR(100);

-- Índices optimizados para empleados
CREATE INDEX IF NOT EXISTS idx_empleados_departamento ON empleados(departamento_id) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_empleados_manager ON empleados(manager_id) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_empleados_activo ON empleados(activo);
CREATE INDEX IF NOT EXISTS idx_empleados_fecha_ingreso ON empleados(fecha_ingreso);
CREATE INDEX IF NOT EXISTS idx_empleados_nombre_completo ON empleados(nombre, apellido) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_empleados_email ON empleados(email) WHERE activo = TRUE;

-- Índice de texto completo para búsquedas
CREATE INDEX IF NOT EXISTS idx_empleados_busqueda ON empleados USING gin(
    (nombre || ' ' || apellido) gin_trgm_ops
);

COMMENT ON TABLE empleados IS 'Empleados de la organización con histórico';

-- =====================================================

-- Tabla de productos
CREATE TABLE IF NOT EXISTS productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    categoria VARCHAR(50) NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    costo DECIMAL(10,2),
    stock INTEGER NOT NULL DEFAULT 0,
    stock_minimo INTEGER DEFAULT 10,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Validaciones
    CONSTRAINT chk_precio_positivo CHECK (precio > 0),
    CONSTRAINT chk_costo_no_negativo CHECK (costo IS NULL OR costo >= 0),
    CONSTRAINT chk_stock_no_negativo CHECK (stock >= 0),
    CONSTRAINT chk_stock_minimo_valido CHECK (stock_minimo >= 0),
    CONSTRAINT chk_precio_mayor_costo CHECK (costo IS NULL OR precio >= costo)
);

-- Índices para productos
CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos(categoria) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos(activo);
CREATE INDEX IF NOT EXISTS idx_productos_stock_bajo ON productos(stock) 
    WHERE activo = TRUE AND stock <= stock_minimo;
CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos(nombre) WHERE activo = TRUE;

-- Índice para búsquedas de texto
CREATE INDEX IF NOT EXISTS idx_productos_busqueda ON productos USING gin(
    (nombre || ' ' || COALESCE(descripcion, '')) gin_trgm_ops
);

COMMENT ON TABLE productos IS 'Catálogo de productos con control de inventario';
COMMENT ON COLUMN productos.stock_minimo IS 'Stock mínimo para alertas de reabastecimiento';

-- =====================================================

-- Tabla de clientes
CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    ciudad VARCHAR(50),
    pais VARCHAR(50) DEFAULT 'España',
    fecha_registro DATE NOT NULL DEFAULT CURRENT_DATE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_email_formato CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Índices para clientes
CREATE INDEX IF NOT EXISTS idx_clientes_email ON clientes(email) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_clientes_ciudad ON clientes(ciudad) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_clientes_fecha_registro ON clientes(fecha_registro);
CREATE INDEX IF NOT EXISTS idx_clientes_activo ON clientes(activo);

COMMENT ON TABLE clientes IS 'Clientes de la organización';

-- =====================================================

-- Tabla de ventas (PARTICIONADA por fecha)
CREATE TABLE IF NOT EXISTS ventas (
    id SERIAL,
    empleado_id INTEGER NOT NULL,
    producto_id INTEGER NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    descuento DECIMAL(5,2) DEFAULT 0,
    fecha_venta DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_venta_empleado FOREIGN KEY (empleado_id) 
        REFERENCES empleados(id) ON DELETE RESTRICT,
    CONSTRAINT fk_venta_producto FOREIGN KEY (producto_id) 
        REFERENCES productos(id) ON DELETE RESTRICT,
    
    -- Validaciones
    CONSTRAINT chk_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT chk_precio_unitario_positivo CHECK (precio_unitario > 0),
    CONSTRAINT chk_descuento_valido CHECK (descuento >= 0 AND descuento <= 100),
    CONSTRAINT chk_fecha_venta_valida CHECK (fecha_venta <= CURRENT_DATE)
) PARTITION BY RANGE (fecha_venta);

-- Crear particiones por año
CREATE TABLE IF NOT EXISTS ventas_2023 PARTITION OF ventas
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE IF NOT EXISTS ventas_2024 PARTITION OF ventas
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE IF NOT EXISTS ventas_2025 PARTITION OF ventas
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Índices en tabla particionada (se crean automáticamente en particiones)
CREATE INDEX IF NOT EXISTS idx_ventas_empleado ON ventas(empleado_id, fecha_venta);
CREATE INDEX IF NOT EXISTS idx_ventas_producto ON ventas(producto_id, fecha_venta);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha_venta);

-- Índice compuesto para análisis frecuente
CREATE INDEX IF NOT EXISTS idx_ventas_analisis ON ventas(fecha_venta, empleado_id, producto_id)
    INCLUDE (cantidad, precio_unitario, descuento);

COMMENT ON TABLE ventas IS 'Registro de ventas particionado por fecha';

-- =====================================================

-- Tabla de pedidos
CREATE TABLE IF NOT EXISTS pedidos (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    empleado_id INTEGER NOT NULL,
    fecha_pedido DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_entrega DATE,
    total DECIMAL(10,2) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    notas TEXT,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id) 
        REFERENCES clientes(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pedido_empleado FOREIGN KEY (empleado_id) 
        REFERENCES empleados(id) ON DELETE RESTRICT,
    
    -- Validaciones
    CONSTRAINT chk_total_positivo CHECK (total > 0),
    CONSTRAINT chk_estado_valido CHECK (estado IN ('pendiente', 'procesando', 'completado', 'cancelado')),
    CONSTRAINT chk_fecha_pedido_valida CHECK (fecha_pedido <= CURRENT_DATE),
    CONSTRAINT chk_fecha_entrega_valida CHECK (fecha_entrega IS NULL OR fecha_entrega >= fecha_pedido)
);

-- Índices para pedidos
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON pedidos(cliente_id, fecha_pedido DESC);
CREATE INDEX IF NOT EXISTS idx_pedidos_empleado ON pedidos(empleado_id, fecha_pedido DESC);
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha ON pedidos(fecha_pedido);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado ON pedidos(estado) WHERE estado != 'cancelado';

-- Índice parcial para pedidos activos
CREATE INDEX IF NOT EXISTS idx_pedidos_activos ON pedidos(fecha_pedido, cliente_id) 
    WHERE estado IN ('pendiente', 'procesando');

-- Índice para pedidos completados (más frecuente en análisis)
CREATE INDEX IF NOT EXISTS idx_pedidos_completados ON pedidos(cliente_id, fecha_pedido)
    WHERE estado = 'completado';

COMMENT ON TABLE pedidos IS 'Pedidos de clientes con seguimiento de estado';

-- =====================================================
-- TABLAS DE AUDITORÍA Y LOGGING
-- =====================================================

-- Tabla de historial de salarios
CREATE TABLE IF NOT EXISTS historial_salarios (
    id SERIAL PRIMARY KEY,
    empleado_id INTEGER NOT NULL,
    salario_anterior DECIMAL(10,2) NOT NULL,
    salario_nuevo DECIMAL(10,2) NOT NULL,
    motivo VARCHAR(100),
    fecha_cambio DATE NOT NULL DEFAULT CURRENT_DATE,
    usuario VARCHAR(100),
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_historial_empleado FOREIGN KEY (empleado_id) 
        REFERENCES empleados(id) ON DELETE CASCADE,
    CONSTRAINT chk_salarios_diferentes CHECK (salario_anterior != salario_nuevo)
);

CREATE INDEX IF NOT EXISTS idx_historial_empleado ON historial_salarios(empleado_id, fecha_cambio DESC);

-- Tabla de log de errores
CREATE TABLE IF NOT EXISTS log_errores (
    id SERIAL PRIMARY KEY,
    funcion VARCHAR(100),
    mensaje TEXT,
    detalle TEXT,
    usuario VARCHAR(100),
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_log_errores_fecha ON log_errores(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_log_errores_funcion ON log_errores(funcion);

-- =====================================================
-- TRIGGERS DE AUDITORÍA
-- =====================================================

-- Función para actualizar fecha_modificacion
CREATE OR REPLACE FUNCTION actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_modificacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a todas las tablas con fecha_modificacion
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_departamentos_fecha_mod'
    ) THEN
        CREATE TRIGGER trg_departamentos_fecha_mod
        BEFORE UPDATE ON departamentos
        FOR EACH ROW
        EXECUTE FUNCTION actualizar_fecha_modificacion();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_empleados_fecha_mod'
    ) THEN
        CREATE TRIGGER trg_empleados_fecha_mod
        BEFORE UPDATE ON empleados
        FOR EACH ROW
        EXECUTE FUNCTION actualizar_fecha_modificacion();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_productos_fecha_mod'
    ) THEN
        CREATE TRIGGER trg_productos_fecha_mod
        BEFORE UPDATE ON productos
        FOR EACH ROW
        EXECUTE FUNCTION actualizar_fecha_modificacion();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_clientes_fecha_mod'
    ) THEN
        CREATE TRIGGER trg_clientes_fecha_mod
        BEFORE UPDATE ON clientes
        FOR EACH ROW
        EXECUTE FUNCTION actualizar_fecha_modificacion();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_pedidos_fecha_mod'
    ) THEN
        CREATE TRIGGER trg_pedidos_fecha_mod
        BEFORE UPDATE ON pedidos
        FOR EACH ROW
        EXECUTE FUNCTION actualizar_fecha_modificacion();
    END IF;
END $$;

-- Trigger para historial de salarios
CREATE OR REPLACE FUNCTION registrar_cambio_salario()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.salario != OLD.salario THEN
        INSERT INTO historial_salarios (empleado_id, salario_anterior, salario_nuevo, usuario)
        VALUES (NEW.id, OLD.salario, NEW.salario, CURRENT_USER);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_empleados_salario'
    ) THEN
        CREATE TRIGGER trg_empleados_salario
        AFTER UPDATE ON empleados
        FOR EACH ROW
        WHEN (OLD.salario IS DISTINCT FROM NEW.salario)
        EXECUTE FUNCTION registrar_cambio_salario();
    END IF;
END $$;

-- =====================================================
-- VISTAS ÚTILES
-- =====================================================

-- Vista de empleados activos con información completa
CREATE OR REPLACE VIEW v_empleados_activos AS
SELECT 
    e.id,
    e.nombre,
    e.apellido,
    e.nombre || ' ' || e.apellido as nombre_completo,
    e.email,
    e.salario,
    e.fecha_ingreso,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.fecha_ingreso)) as años_empresa,
    d.nombre as departamento,
    m.nombre || ' ' || m.apellido as manager
FROM empleados e
INNER JOIN departamentos d ON e.departamento_id = d.id
LEFT JOIN empleados m ON e.manager_id = m.id
WHERE e.activo = TRUE;

-- Vista de productos con stock bajo
CREATE OR REPLACE VIEW v_productos_stock_bajo AS
SELECT 
    p.id,
    p.nombre,
    p.categoria,
    p.stock,
    p.stock_minimo,
    p.precio,
    (p.stock_minimo - p.stock) as unidades_faltantes,
    (p.stock_minimo - p.stock) * p.precio as valor_reposicion
FROM productos p
WHERE p.activo = TRUE 
AND p.stock <= p.stock_minimo
ORDER BY (p.stock_minimo - p.stock) DESC;

-- Vista de métricas de ventas diarias
CREATE OR REPLACE VIEW v_ventas_diarias AS
SELECT 
    fecha_venta,
    COUNT(*) as num_transacciones,
    SUM(cantidad) as unidades_vendidas,
    SUM(cantidad * precio_unitario * (1 - descuento/100)) as ingresos_totales,
    AVG(cantidad * precio_unitario * (1 - descuento/100)) as ticket_promedio,
    COUNT(DISTINCT empleado_id) as empleados_activos,
    COUNT(DISTINCT producto_id) as productos_vendidos
FROM ventas
GROUP BY fecha_venta
ORDER BY fecha_venta DESC;

-- =====================================================
-- FUNCIONES AUXILIARES
-- =====================================================

-- Función para calcular edad
CREATE OR REPLACE FUNCTION calcular_años_empresa(p_fecha_ingreso DATE)
RETURNS INTEGER AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, p_fecha_ingreso));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Función para validar stock disponible
CREATE OR REPLACE FUNCTION validar_stock_disponible(
    p_producto_id INTEGER,
    p_cantidad INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    v_stock_actual INTEGER;
BEGIN
    SELECT stock INTO v_stock_actual
    FROM productos
    WHERE id = p_producto_id AND activo = TRUE;
    
    IF v_stock_actual IS NULL THEN
        RAISE EXCEPTION 'Producto % no existe o está inactivo', p_producto_id;
    END IF;
    
    RETURN v_stock_actual >= p_cantidad;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- GRANTS Y PERMISOS (Opcional, para entornos con roles)
-- =====================================================

-- Crear roles si no existen (descomentar si es necesario)
-- CREATE ROLE app_readonly;
-- CREATE ROLE app_readwrite;
-- CREATE ROLE app_admin;

-- Permisos de lectura
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;
-- GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO app_readonly;

-- Permisos de lectura/escritura
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_readwrite;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_readwrite;

-- =====================================================
-- COMENTARIOS FINALES
-- =====================================================

COMMENT ON SCHEMA public IS 'Schema principal de la aplicación - Optimizado para producción';

-- Estadísticas de las tablas
ANALYZE departamentos;
ANALYZE empleados;
ANALYZE productos;
ANALYZE clientes;
ANALYZE ventas;
ANALYZE pedidos;

-- =====================================================
-- VERIFICACIÓN DE INSTALACIÓN
-- =====================================================

DO $$
DECLARE
    v_total_tablas INTEGER;
    v_total_indices INTEGER;
    v_total_constraints INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_tablas
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    
    SELECT COUNT(*) INTO v_total_indices
    FROM pg_indexes
    WHERE schemaname = 'public';
    
    SELECT COUNT(*) INTO v_total_constraints
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'public';
    
    RAISE NOTICE '================================================';
    RAISE NOTICE 'ESQUEMA INSTALADO EXITOSAMENTE';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Tablas creadas: %', v_total_tablas;
    RAISE NOTICE 'Índices creados: %', v_total_indices;
    RAISE NOTICE 'Constraints aplicados: %', v_total_constraints;
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Siguiente paso: Ejecutar 04_datos_prueba.sql';
    RAISE NOTICE '================================================';
END $$;
