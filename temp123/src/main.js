import { connectionString, dbName } from './config/configMongoDB.config.js';
import mongoose from 'mongoose';
import User from './models/User.model.js';

async function connectToMongoDB() {
    try {
        await mongoose.connect(connectionString, { dbName });
        console.log('Conexion con DB exitosa!');
    } catch (error) {
        console.log('[SERVER ERROR]: Fallo en la conexion,', error);
    }
}


connectToMongoDB().then(() => {
    // Crear usuario de ejemplo al iniciar la app
    crearUsuario('Juan', 'juan@gmail.com', '123456');
});

async function crearUsuario(name, email, password) {
    try {
        await User.create({
            name,
            email,
            password
        });
        console.log('[SERVER]: Usuario creado exitosamente');
    } catch (error) {
        console.log('[SERVER ERROR]: No se pudo crear el usuario,', error);
    }
}

/* 
function procesarCarrito(usuario, productos, tiempo) {
    return new Promise(resolve => {
        setTimeout(() => {
            console.log(`Usuario ${usuario} terminó su carrito de ${productos} productos (${tiempo}s)`);
            resolve();
        }, tiempo * 1000);
    });
}

async function main() {
    await procesarCarrito(1, 10, 1);   // Usuario 1, 10 productos, tarda 1s
    await procesarCarrito(2, 20, 2);   // Usuario 2, 20 productos, tarda 2s
    await procesarCarrito(3, 100, 10); // Usuario 3, 100 productos, tarda 10s
    console.log('Todos los carritos fueron procesados');
}

main();
*/