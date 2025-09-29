
# Clase 14 - Node.js

## Resumen detallado

En la clase 14 se trabajó principalmente con Express.js y Handlebars para crear aplicaciones web dinámicas. Los temas y prácticas incluyeron:

### 1. Express.js
- Instalación y configuración básica de Express.
- Creación de un servidor HTTP.
- Definición de rutas simples con `app.get()`.

### 2. Motor de vistas Handlebars
- Instalación de `express-handlebars`.
- Configuración del motor de vistas:
  - `app.engine('handlebars', handlebars.engine());`
  - `app.set('view engine', 'handlebars');`
  - `app.set('views', './views');`
- Creación de la carpeta `views` y de archivos `.handlebars` para las vistas.

### 3. Renderizado de vistas
- Uso de `res.render()` para mostrar páginas dinámicas.
- Ejemplo de vista:
  ```handlebars
  <h1>Bienvenido a Home</h1>
  <h2>Usted es: {{user}}</h2>
  ```

### 4. Middlewares
- Introducción a middlewares en Express.
- Uso de middlewares personalizados para procesar peticiones.

### 5. Práctica
- Creación de rutas como `/home` que renderizan vistas con datos enviados desde el backend.
- Ejemplo de código:
  ```js
  import express from 'express';
  import handlebars from 'express-handlebars';

  const app = express();
  app.engine('handlebars', handlebars.engine());
  app.set('view engine', 'handlebars');
  app.set('views', './views');

  app.get('/home', (req, res) => {
    res.render('home', { user: 'Juan' });
  });

  app.listen(8080, () => {
    console.log('Servidor corriendo en puerto 8080');
  });
  ```

## Buenas prácticas
- Separar rutas y vistas en carpetas distintas.
- Documentar el código y los endpoints.
- Usar motores de vistas para mantener el código limpio y escalable.
