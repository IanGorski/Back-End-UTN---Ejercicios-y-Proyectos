## DDL SQL de referencia (PostgreSQL)

```sql
-- 1) usuarios
CREATE TABLE usuarios (
	id BIGSERIAL PRIMARY KEY,
	email VARCHAR(255) NOT NULL UNIQUE,
	password VARCHAR(255) NOT NULL,
	nombre VARCHAR(120) NOT NULL
);

-- 2) contactos
CREATE TABLE contactos (
	id BIGSERIAL PRIMARY KEY,
	usuario_id BIGINT NOT NULL REFERENCES usuarios(id),
	contacto_id BIGINT NOT NULL REFERENCES usuarios(id),
	CONSTRAINT contactos_no_autocontacto CHECK (usuario_id <> contacto_id),
	CONSTRAINT contactos_unicos UNIQUE (usuario_id, contacto_id)
);

-- 3) mensajes_privados
CREATE TABLE mensajes_privados (
	id BIGSERIAL PRIMARY KEY,
	remitente_id BIGINT NOT NULL REFERENCES usuarios(id),
	receptor_id BIGINT NOT NULL REFERENCES usuarios(id),
	contenido TEXT NOT NULL,
	fecha_envio TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4) grupos
CREATE TABLE grupos (
	id BIGSERIAL PRIMARY KEY,
	nombre VARCHAR(120) NOT NULL,
	creador_id BIGINT NOT NULL REFERENCES usuarios(id)
);

-- 5) miembros_grupo (PK compuesta)
CREATE TABLE miembros_grupo (
	grupo_id BIGINT NOT NULL REFERENCES grupos(id),
	usuario_id BIGINT NOT NULL REFERENCES usuarios(id),
	rol TEXT NOT NULL DEFAULT 'miembro',
	CONSTRAINT miembros_grupo_pk PRIMARY KEY (grupo_id, usuario_id),
	CONSTRAINT miembros_grupo_rol_chk CHECK (rol IN ('miembro','coadmin'))
);

-- 6) mensajes_grupo
CREATE TABLE mensajes_grupo (
	id BIGSERIAL PRIMARY KEY,
	grupo_id BIGINT NOT NULL REFERENCES grupos(id),
	usuario_id BIGINT NOT NULL REFERENCES usuarios(id),
	contenido TEXT NOT NULL,
	fecha_envio TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- (Opcional) Índices útiles
CREATE INDEX idx_contactos_usuario ON contactos(usuario_id);
CREATE INDEX idx_mp_receptor_fecha ON mensajes_privados(receptor_id, fecha_envio DESC);
CREATE INDEX idx_mg_grupo_fecha ON mensajes_grupo(grupo_id, fecha_envio DESC);
```
