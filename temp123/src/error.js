class CustomError extends Error {
    constructor(message, status) {
        super(message);
        this.status = status;
    }
}

export { CustomError };
//Archivo main.js de práctica
// import { sumar } from './math.js';
// try {
//     //Try intenta ejecutar este bloque de codigo
//     console.log(sumar(2, 1));
// }
// catch (error) {
//     if (error.status) {
//         console.log('CLIENT ERROR');
//         message, 'status:' + error.status;
//     } else {
//         console.log('SERVER ERROR');
//         console.log('message:' + error.message);
//     }
//     //En caso de que el bloque falle
//     //catch atrapara el error y ejecutara su bloque de codigo
//     console.log('la operacion sumar ha fallado');
//     console.log('RAZON:', error);
// }
// finally {
//     //Finalmente, o independientemente de lo que pase, ejecuta esto
//     console.log('Finalizo el intento de ejecucion de sumar');
// }

// console.log('accion super importante');
