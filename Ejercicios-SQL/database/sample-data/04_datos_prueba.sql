-- =============================================================================
-- SCRIPT DE CARGA DE DATOS DE PRUEBA
-- =============================================================================
-- Descripción: Genera 1000+ registros realistas para testing y demos
-- Base de Datos: PostgreSQL 14+
-- Autor: Ian Gorski
-- Última actualización: Octubre 2025
-- =============================================================================

SET client_encoding = 'UTF8';

-- -----------------------------------------------------------------------------
-- CONFIGURACIÓN INICIAL
-- -----------------------------------------------------------------------------

-- Deshabilitar triggers temporalmente para carga rápida
ALTER TABLE ventas DISABLE TRIGGER ALL;
ALTER TABLE pedidos DISABLE TRIGGER ALL;

-- Comenzar transacción
BEGIN;

-- Limpiar datos existentes (CUIDADO: Esto borra todo)
-- Comentar estas líneas si quieres mantener datos existentes
TRUNCATE TABLE ventas CASCADE;
TRUNCATE TABLE pedidos CASCADE;
TRUNCATE TABLE clientes CASCADE;
TRUNCATE TABLE productos CASCADE;
TRUNCATE TABLE empleados CASCADE;
TRUNCATE TABLE departamentos CASCADE;

-- Reiniciar secuencias
ALTER SEQUENCE departamentos_id_seq RESTART WITH 1;
ALTER SEQUENCE empleados_id_seq RESTART WITH 1;
ALTER SEQUENCE productos_id_seq RESTART WITH 1;
ALTER SEQUENCE clientes_id_seq RESTART WITH 1;
ALTER SEQUENCE ventas_id_seq RESTART WITH 1;
ALTER SEQUENCE pedidos_id_seq RESTART WITH 1;

-- -----------------------------------------------------------------------------
-- 1. DEPARTAMENTOS (10 registros)
-- -----------------------------------------------------------------------------

INSERT INTO departamentos (nombre, presupuesto, descripcion) VALUES
('Ventas', 500000.00, 'Departamento de ventas y atención al cliente'),
('Marketing', 350000.00, 'Marketing digital y comunicaciones'),
('Tecnología', 600000.00, 'Desarrollo y soporte técnico'),
('Recursos Humanos', 250000.00, 'Gestión de personal y capacitación'),
('Finanzas', 400000.00, 'Contabilidad y análisis financiero'),
('Operaciones', 450000.00, 'Logística y operaciones'),
('Compras', 300000.00, 'Adquisiciones y proveedores'),
('Legal', 200000.00, 'Asesoría legal y cumplimiento'),
('Atención al Cliente', 280000.00, 'Servicio postventa y soporte'),
('Dirección', 800000.00, 'Dirección ejecutiva y estrategia');

-- -----------------------------------------------------------------------------
-- 2. EMPLEADOS (100 registros)
-- -----------------------------------------------------------------------------

-- Insertar empleados de Ventas (15)
INSERT INTO empleados (nombre, apellido, email, fecha_ingreso, departamento_id, cargo, salario, activo) VALUES
('Juan', 'Pérez', 'juan.perez@empresa.com', '2020-01-15', 1, 'Gerente de Ventas', 85000, TRUE),
('María', 'González', 'maria.gonzalez@empresa.com', '2020-03-22', 1, 'Vendedor Senior', 65000, TRUE),
('Carlos', 'López', 'carlos.lopez@empresa.com', '2021-05-10', 1, 'Vendedor', 50000, TRUE),
('Ana', 'Martínez', 'ana.martinez@empresa.com', '2021-07-18', 1, 'Vendedor', 48000, TRUE),
('Luis', 'Rodríguez', 'luis.rodriguez@empresa.com', '2022-01-20', 1, 'Vendedor Junior', 42000, TRUE),
('Laura', 'Fernández', 'laura.fernandez@empresa.com', '2022-03-15', 1, 'Vendedor', 50000, TRUE),
('Diego', 'García', 'diego.garcia@empresa.com', '2022-06-01', 1, 'Vendedor', 51000, TRUE),
('Sofía', 'Sánchez', 'sofia.sanchez@empresa.com', '2022-09-10', 1, 'Vendedor Senior', 62000, TRUE),
('Pablo', 'Ruiz', 'pablo.ruiz@empresa.com', '2023-01-05', 1, 'Vendedor', 49000, TRUE),
('Valentina', 'Díaz', 'valentina.diaz@empresa.com', '2023-03-20', 1, 'Vendedor', 48500, TRUE),
('Martín', 'Torres', 'martin.torres@empresa.com', '2023-06-15', 1, 'Vendedor Junior', 43000, TRUE),
('Camila', 'Romero', 'camila.romero@empresa.com', '2023-08-22', 1, 'Vendedor', 47000, TRUE),
('Facundo', 'Silva', 'facundo.silva@empresa.com', '2023-11-01', 1, 'Vendedor Junior', 44000, TRUE),
('Lucía', 'Castro', 'lucia.castro@empresa.com', '2024-02-10', 1, 'Vendedor', 46000, TRUE),
('Nicolás', 'Moreno', 'nicolas.moreno@empresa.com', '2024-05-15', 1, 'Vendedor Junior', 42500, TRUE);

-- Insertar empleados de otros departamentos (85 más)
-- Marketing (10)
INSERT INTO empleados (nombre, apellido, email, fecha_ingreso, departamento_id, cargo, salario, activo)
SELECT 
    'Empleado' || (n + 15),
    'Apellido' || (n + 15),
    'emp' || (n + 15) || '@empresa.com',
    CURRENT_DATE - (random() * 1460)::int,
    2,
    CASE WHEN n = 1 THEN 'Gerente de Marketing' ELSE 'Especialista Marketing' END,
    CASE WHEN n = 1 THEN 80000 ELSE 55000 + (random() * 15000)::int END,
    TRUE
FROM generate_series(1, 10) n;

-- Tecnología (15)
INSERT INTO empleados (nombre, apellido, email, fecha_ingreso, departamento_id, cargo, salario, activo)
SELECT 
    'Dev' || (n + 25),
    'Developer' || (n + 25),
    'dev' || (n + 25) || '@empresa.com',
    CURRENT_DATE - (random() * 1460)::int,
    3,
    CASE 
        WHEN n = 1 THEN 'CTO'
        WHEN n <= 3 THEN 'Tech Lead'
        WHEN n <= 8 THEN 'Developer Senior'
        ELSE 'Developer'
    END,
    CASE 
        WHEN n = 1 THEN 120000
        WHEN n <= 3 THEN 90000
        WHEN n <= 8 THEN 70000
        ELSE 55000
    END,
    TRUE
FROM generate_series(1, 15) n;

-- Resto de departamentos (60)
INSERT INTO empleados (nombre, apellido, email, fecha_ingreso, departamento_id, cargo, salario, activo)
SELECT 
    'Empleado' || (n + 40),
    'Apellido' || (n + 40),
    'emp' || (n + 40) || '@empresa.com',
    CURRENT_DATE - (random() * 1825)::int,
    CASE 
        WHEN n <= 12 THEN 4  -- RRHH
        WHEN n <= 24 THEN 5  -- Finanzas
        WHEN n <= 36 THEN 6  -- Operaciones
        WHEN n <= 45 THEN 7  -- Compras
        WHEN n <= 51 THEN 8  -- Legal
        WHEN n <= 59 THEN 9  -- Atención Cliente
        ELSE 10              -- Dirección
    END,
    'Empleado ' || (n + 40),
    45000 + (random() * 40000)::int,
    TRUE
FROM generate_series(1, 60) n;

-- -----------------------------------------------------------------------------
-- 3. PRODUCTOS (200 registros)
-- -----------------------------------------------------------------------------

-- Electrónica (50 productos)
INSERT INTO productos (nombre, descripcion, categoria, precio, costo, stock, stock_minimo, activo) VALUES
-- Smartphones
('iPhone 14 Pro', 'Smartphone Apple última generación', 'Electrónica', 899000, 650000, 45, 10, TRUE),
('Samsung Galaxy S23', 'Smartphone Samsung flagship', 'Electrónica', 749000, 520000, 38, 10, TRUE),
('Xiaomi 13 Pro', 'Smartphone Xiaomi alta gama', 'Electrónica', 599000, 420000, 52, 10, TRUE),
('Motorola Edge 40', 'Smartphone Motorola gama media', 'Electrónica', 349000, 240000, 65, 15, TRUE),
('iPhone SE 2023', 'iPhone económico', 'Electrónica', 449000, 310000, 55, 12, TRUE),
-- Notebooks
('MacBook Air M2', 'Laptop Apple Silicon M2', 'Electrónica', 1299000, 920000, 28, 8, TRUE),
('Dell XPS 15', 'Laptop Dell profesional', 'Electrónica', 1150000, 800000, 22, 6, TRUE),
('Lenovo ThinkPad X1', 'Laptop empresarial', 'Electrónica', 1050000, 730000, 18, 5, TRUE),
('HP Pavilion 15', 'Laptop HP uso general', 'Electrónica', 699000, 480000, 42, 10, TRUE),
('ASUS ROG Strix', 'Laptop gaming', 'Electrónica', 1450000, 1020000, 15, 5, TRUE),
-- Tablets
('iPad Pro 12.9"', 'Tablet Apple profesional', 'Electrónica', 949000, 665000, 32, 8, TRUE),
('Samsung Galaxy Tab S9', 'Tablet Samsung premium', 'Electrónica', 649000, 450000, 28, 8, TRUE),
('iPad Air', 'Tablet Apple intermedia', 'Electrónica', 599000, 420000, 35, 10, TRUE),
-- Accesorios
('AirPods Pro 2', 'Auriculares Apple', 'Electrónica', 249000, 175000, 88, 20, TRUE),
('Samsung Buds Pro', 'Auriculares Samsung', 'Electrónica', 149000, 105000, 95, 25, TRUE),
('Apple Watch Series 9', 'Smartwatch Apple', 'Electrónica', 399000, 280000, 42, 12, TRUE),
('Samsung Galaxy Watch 6', 'Smartwatch Samsung', 'Electrónica', 299000, 210000, 38, 10, TRUE),
('Magic Keyboard iPad', 'Teclado Apple para iPad', 'Electrónica', 349000, 245000, 22, 8, TRUE),
('Logitech MX Master 3', 'Mouse inalámbrico profesional', 'Electrónica', 89000, 62000, 72, 20, TRUE),
('Webcam Logitech C920', 'Cámara web HD', 'Electrónica', 79000, 55000, 58, 15, TRUE);

-- Generar más productos de Electrónica (30 adicionales)
INSERT INTO productos (nombre, descripcion, categoria, precio, costo, stock, stock_minimo, activo)
SELECT 
    'Producto Electrónica ' || n,
    'Descripción producto electrónica ' || n,
    'Electrónica',
    GREATEST((50000 + random() * 500000)::numeric(10,2), costo_base * 1.3),
    costo_base,
    (10 + random() * 90)::int,
    (5 + random() * 15)::int,
    TRUE
FROM generate_series(1, 30) n,
     LATERAL (SELECT (30000 + random() * 300000)::numeric(10,2) AS costo_base) c;

-- Hogar (40 productos)
INSERT INTO productos (nombre, descripcion, categoria, precio, costo, stock, stock_minimo, activo)
SELECT 
    'Producto Hogar ' || n,
    'Artículo para el hogar ' || n,
    'Hogar',
    GREATEST((10000 + random() * 200000)::numeric(10,2), costo_base * 1.3),
    costo_base,
    (20 + random() * 100)::int,
    (10 + random() * 20)::int,
    TRUE
FROM generate_series(1, 40) n,
     LATERAL (SELECT (5000 + random() * 100000)::numeric(10,2) AS costo_base) c;

-- Indumentaria (40 productos)
INSERT INTO productos (nombre, descripcion, categoria, precio, costo, stock, stock_minimo, activo)
SELECT 
    'Producto Indumentaria ' || n,
    'Ropa y accesorios ' || n,
    'Indumentaria',
    GREATEST((5000 + random() * 100000)::numeric(10,2), costo_base * 1.3),
    costo_base,
    (30 + random() * 150)::int,
    (15 + random() * 25)::int,
    TRUE
FROM generate_series(1, 40) n,
     LATERAL (SELECT (2000 + random() * 50000)::numeric(10,2) AS costo_base) c;

-- Deportes (35 productos)
INSERT INTO productos (nombre, descripcion, categoria, precio, costo, stock, stock_minimo, activo)
SELECT 
    'Producto Deportes ' || n,
    'Artículo deportivo ' || n,
    'Deportes',
    GREATEST((8000 + random() * 150000)::numeric(10,2), costo_base * 1.3),
    costo_base,
    (15 + random() * 80)::int,
    (8 + random() * 18)::int,
    TRUE
FROM generate_series(1, 35) n,
     LATERAL (SELECT (4000 + random() * 80000)::numeric(10,2) AS costo_base) c;

-- Juguetes (35 productos)
INSERT INTO productos (nombre, descripcion, categoria, precio, costo, stock, stock_minimo, activo)
SELECT 
    'Producto Juguetes ' || n,
    'Juguete para niños ' || n,
    'Juguetes',
    GREATEST((3000 + random() * 80000)::numeric(10,2), costo_base * 1.3),
    costo_base,
    (25 + random() * 120)::int,
    (12 + random() * 22)::int,
    TRUE
FROM generate_series(1, 35) n,
     LATERAL (SELECT (1500 + random() * 40000)::numeric(10,2) AS costo_base) c;

-- -----------------------------------------------------------------------------
-- 4. CLIENTES (500 registros)
-- -----------------------------------------------------------------------------

-- Crear arrays con nombres y apellidos argentinos comunes
WITH nombres AS (
    SELECT unnest(ARRAY[
        'Juan', 'María', 'Carlos', 'Ana', 'Luis', 'Laura', 'Diego', 'Sofía',
        'Pablo', 'Valentina', 'Martín', 'Camila', 'Facundo', 'Lucía', 'Nicolás',
        'Micaela', 'Agustín', 'Florencia', 'Matías', 'Rocío', 'Ezequiel', 'Daniela',
        'Sebastián', 'Antonella', 'Federico', 'Victoria', 'Maximiliano', 'Brenda',
        'Gonzalo', 'Natalia', 'Santiago', 'Carolina', 'Rodrigo', 'Gabriela', 'Alejandro'
    ]) AS nombre
),
apellidos AS (
    SELECT unnest(ARRAY[
        'González', 'Rodríguez', 'Fernández', 'López', 'Martínez', 'García',
        'Pérez', 'Sánchez', 'Romero', 'Díaz', 'Torres', 'Silva', 'Castro',
        'Ruiz', 'Moreno', 'Álvarez', 'Giménez', 'Molina', 'Navarro', 'Suárez',
        'Vega', 'Ortiz', 'Medina', 'Rojas', 'Herrera', 'Vargas', 'Domínguez',
        'Benítez', 'Acosta', 'Ríos', 'Cabrera', 'Flores', 'Ibáñez', 'Miranda', 'Luna'
    ]) AS apellido
),
ciudades AS (
    SELECT unnest(ARRAY[
        'Buenos Aires', 'Córdoba', 'Rosario', 'Mendoza', 'La Plata', 'San Miguel de Tucumán',
        'Mar del Plata', 'Salta', 'Santa Fe', 'San Juan', 'Resistencia', 'Neuquén',
        'Posadas', 'Bahía Blanca', 'Paraná', 'San Salvador de Jujuy', 'Corrientes',
        'San Luis', 'Formosa', 'La Rioja'
    ]) AS ciudad
)
INSERT INTO clientes (nombre, email, telefono, ciudad, fecha_registro, activo)
SELECT 
    n.nombre || ' ' || a.apellido,
    LOWER(
        TRANSLATE(
            n.nombre || '.' || a.apellido || (1000 + random() * 9000)::int || '@' ||
            (ARRAY['gmail.com', 'hotmail.com', 'yahoo.com', 'outlook.com'])[floor(random() * 4 + 1)],
            'áéíóúÁÉÍÓÚñÑ',
            'aeiouAEIOUnN'
        )
    ),
    '11' || (10000000 + random() * 89999999)::bigint,
    c.ciudad,
    CURRENT_DATE - (random() * 1825)::int,  -- Últimos 5 años
    CASE WHEN random() < 0.95 THEN TRUE ELSE FALSE END  -- 95% activos
FROM 
    nombres n
    CROSS JOIN apellidos a
    CROSS JOIN ciudades c
WHERE random() < 0.042  -- Seleccionar ~500 registros (35*35*20 * 0.042 ≈ 500)
LIMIT 500;

-- -----------------------------------------------------------------------------
-- 5. VENTAS (2000 registros - últimos 2 años)
-- -----------------------------------------------------------------------------

INSERT INTO ventas (
    producto_id, 
    empleado_id, 
    cantidad, 
    precio_unitario, 
    descuento,
    fecha_venta
)
SELECT 
    (1 + random() * 199)::int AS producto_id,
    (1 + random() * 99)::int AS empleado_id,
    (1 + random() * 5)::int AS cantidad,
    p.precio,
    (random() * 20)::numeric(5,2) AS descuento,
    CURRENT_DATE - (random() * 730)::int AS fecha_venta  -- Últimos 2 años
FROM 
    generate_series(1, 2000) n
    CROSS JOIN LATERAL (
        SELECT precio 
        FROM productos 
        WHERE id = (1 + random() * 199)::int 
        LIMIT 1
    ) p;

-- -----------------------------------------------------------------------------
-- 6. PEDIDOS (1500 registros)
-- -----------------------------------------------------------------------------

INSERT INTO pedidos (
    cliente_id,
    empleado_id,
    fecha_pedido,
    fecha_entrega,
    estado,
    total,
    notas
)
SELECT 
    (1 + random() * 499)::int,
    (1 + random() * 99)::int,
    fecha_pedido,
    CASE 
        WHEN estado IN ('completado') 
        THEN fecha_pedido + (2 + random() * 12)::int
        ELSE NULL
    END,
    estado,
    (10000 + random() * 990000)::numeric(10,2),
    'Pedido generado automáticamente'
FROM (
    SELECT 
        CURRENT_DATE - (random() * 730)::int AS fecha_pedido,
        (ARRAY['pendiente', 'procesando', 'completado', 'completado', 
               'completado', 'completado', 'cancelado'])[floor(random() * 7 + 1)] AS estado
    FROM generate_series(1, 1500)
) sub;

-- -----------------------------------------------------------------------------
-- FINALIZACIÓN Y VERIFICACIÓN
-- -----------------------------------------------------------------------------

-- Habilitar triggers nuevamente
ALTER TABLE ventas ENABLE TRIGGER ALL;
ALTER TABLE pedidos ENABLE TRIGGER ALL;

-- Commit de la transacción
COMMIT;

-- Actualizar estadísticas para el optimizador
ANALYZE departamentos;
ANALYZE empleados;
ANALYZE productos;
ANALYZE clientes;
ANALYZE ventas;
ANALYZE pedidos;

-- -----------------------------------------------------------------------------
-- VERIFICACIÓN DE CARGA
-- -----------------------------------------------------------------------------

SELECT 
    'departamentos' AS tabla,
    COUNT(*) AS registros,
    pg_size_pretty(pg_total_relation_size('departamentos')) AS tamaño
FROM departamentos
UNION ALL
SELECT 
    'empleados',
    COUNT(*),
    pg_size_pretty(pg_total_relation_size('empleados'))
FROM empleados
UNION ALL
SELECT 
    'productos',
    COUNT(*),
    pg_size_pretty(pg_total_relation_size('productos'))
FROM productos
UNION ALL
SELECT 
    'clientes',
    COUNT(*),
    pg_size_pretty(pg_total_relation_size('clientes'))
FROM clientes
UNION ALL
SELECT 
    'ventas',
    COUNT(*),
    pg_size_pretty(pg_total_relation_size('ventas'))
FROM ventas
UNION ALL
SELECT 
    'pedidos',
    COUNT(*),
    pg_size_pretty(pg_total_relation_size('pedidos'))
FROM pedidos;

-- Verificar rango de fechas en ventas
SELECT 
    MIN(fecha_venta) AS fecha_minima,
    MAX(fecha_venta) AS fecha_maxima,
    COUNT(*) AS total_ventas,
    SUM(cantidad * precio_unitario * (1 - descuento/100)) AS total_ingresos
FROM ventas;

-- Verificar distribución por categoría
SELECT 
    categoria,
    COUNT(*) AS num_productos,
    SUM(stock) AS stock_total,
    ROUND(AVG(precio)::numeric, 2) AS precio_promedio
FROM productos
GROUP BY categoria
ORDER BY num_productos DESC;

-- =============================================================================
-- FIN DEL SCRIPT - Datos de prueba cargados exitosamente
-- =============================================================================
-- Total de registros generados:
-- - 10 Departamentos
-- - 100 Empleados
-- - 200 Productos
-- - 500 Clientes
-- - 2000 Ventas
-- - 1500 Pedidos
-- =============================================================================

-- Corrección de datos para cumplir con la restricción chk_precio_mayor_costo
UPDATE productos
SET precio = costo + 1000
WHERE precio < costo;

-- Ajustar precios generados dinámicamente para cumplir con la restricción
UPDATE productos
SET precio = costo + 1000
WHERE precio < costo;
