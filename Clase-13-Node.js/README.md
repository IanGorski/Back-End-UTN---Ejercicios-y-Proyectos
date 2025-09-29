# Clase 13 - Node.js

## Resumen Teórico

En esta clase se profundizó en el desarrollo de aplicaciones con Node.js, abordando los siguientes temas:

### 1. ¿Qué es Node.js?
- Entorno de ejecución para JavaScript fuera del navegador.
- Permite crear aplicaciones del lado del servidor.

### 2. Módulos en Node.js
- Uso de módulos nativos (`fs`, `http`, `path`, etc.).
- Importación y exportación de módulos propios.

### 3. Manejo de archivos
- Lectura y escritura de archivos con el módulo `fs`.
- Ejemplo de creación y modificación de archivos.

### 4. Servidores HTTP
- Creación de un servidor básico con el módulo `http`.
- Manejo de rutas y respuestas.

### 5. NPM y paquetes
- Instalación y uso de paquetes externos.
- Ejemplo: Express para crear servidores web más robustos.

### 6. Asincronismo
- Callbacks, Promesas y `async/await`.
- Ejemplo de manejo de operaciones asíncronas.

### 7. Buenas prácticas
- Organización de código en módulos.
- Uso de control de versiones (Git).
- Manejo de errores y logs.

---

## Ejemplo de código básico

```js
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('¡Hola desde Node.js!');
});

server.listen(3000, () => {
  console.log('Servidor escuchando en puerto 3000');
});
```

---

## Conclusión

Node.js es una herramienta poderosa para crear aplicaciones escalables y rápidas del lado del servidor, aprovechando el ecosistema de JavaScript y la gran cantidad de módulos disponibles.
