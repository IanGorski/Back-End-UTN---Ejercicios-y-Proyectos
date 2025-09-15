import mongoose from 'mongoose'
//Que retorna si es async? Una promesa

export const connectionString = 'mongodb://localhost:27017';
export const dbName = 'miBaseDeDatos';

async function connectToMongoDB() {
    try {
        await mongoose.connect(connectionString, { dbName })
        //Await hara que se espere a que se resuelva la promesa para continuar la ejecucion 
        console.log('Conexion con DB exitosa!');
    } catch (error) {
        console.log('[SERVER ERROR]: Fallo en la conexion,', error);
    }
}

export default connectToMongoDB;