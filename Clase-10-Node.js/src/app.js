console.log('¡Hola Node.js!');
console.log('hola');
console.log('chau');
console.log('chau');
console.log('chau');

//DOM no existe en Node.js
//BOM no existe en Node.js
//Ejemplos:
//document.getElementById()
//window.alert()
//window.prompt() 

//Ganamos poder hacer cualquier cosa que se pueda hacer con una PC
//Por ejemplo podemos usar el sistema de archivos (fs)
// const fs = require('fs');
//require es la forma antigua de importar en node.js, se usa cuando estamos en commonjs


const filesystem = require('fs');
const { parse } = require('path');

/*
filesystem.writeFileSync(
    'test.txt', //dirección, nombre y extensión del archivo
    'Hola mundo.', //contenido
    {
        encoding: 'utf8' //codificación
    }
)
*/

//Nos permite leer un archivo
const package_data = filesystem.readFileSync(
    './package.json',
    {
        encoding: 'utf8'
    }
)

//para transformar un string en un objeto JSON usamos JSON.parse()

const package_data_obj = JSON.parse(package_data);
/* console.log(package_data_obj.name); */

const new_user = {
    name: 'Ian',
    last_name: 'Gorski',
    id: 1,
    version: package_data_obj.version
}

console.log(new_user);

//JSON.parse nos permite transformar un string en un objeto JSON
//JSON.stringify nos permite transformar un objeto JSON en un string

//Quiero crear un JSON string con el objeto new_user

const json_string_user = JSON.stringify(new_user);
console.log(json_string_user);


//Crear 2 variables 
//Variable 'a' que va a ser un número 'x'
//Variable 'b' que va a ser un número 'y'
//Guardar cada número en archivo de txt (Ejemplo: número_1.txt, y número_2.txt) //writeFileSync
//Leer el archivo número_1.txt y guardarlo en una variable //readFileSync
//Leer el archivo número_2.txt y guardarlo en una variable //readFileSync
//Sumar entre sí ambos números


const a = 7;
const b = 13;

filesystem.writeFileSync('numero_1.txt', a.toString(), { encoding: 'utf8' });
filesystem.writeFileSync('numero_2.txt', b.toString(), { encoding: 'utf8' });

const a_leido = parseInt(filesystem.readFileSync('numero_1.txt', { encoding: 'utf8' }));

const b_leido = parseInt(filesystem.readFileSync('numero_2.txt', { encoding: 'utf8' }));

const suma = a_leido + b_leido;
console.log('La suma es:', suma);

console.log(parseInt(7.999999))
console.log(parseFloat(7.999999))
console.log(Math.round(10.6))
let result = 0.1 + 0.2;
result = result.toFixed(1); 
console.log(result);
console.log( Number(result) );



