- Toda APP de node.js tiene un archivo llamado `package.json` que contiene la información del proyecto y las dependencias que utiliza.

- Este archivo se puede crear de forma manual o automática con el comando `npm init` en la terminal.

- node --watch solo es estable en versiones mayores a la 20.0 de Node.js

- Si estás en una versión menor a 20.0 puedo instalar nodemon como devDependency mediante el comando `npm install -D nodemon` y luego ejecutar la app con `npx nodemon ./src/app.js`

- /src es el directorio donde se encuentran los archivos fuente de la aplicación, con todo el código que escribimos.

- Las devDependencies son dependencias (código externo) que se instalaron solamente en entorno de desarrollo, cuando nuestra app sea desplegada y pase a puesta en producción, estas dependencias no se van a instalar.

- CTRL + c para detener la ejecución de la app en la terminal.