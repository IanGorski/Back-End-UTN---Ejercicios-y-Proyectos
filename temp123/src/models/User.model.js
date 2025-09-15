import mongoose from 'mongoose';

//Se usa para crear/definir esquemas
const userschema = new mongoose.Schema({
    name: { type: String, required: true },
    email: { type: String, required: true },
    password: { type: String, required: true },
    modified_at: { type: Date, default: Date.now },
    create_at: { type: Date, default: Date.now },
    active: { type: Boolean, default: true }
});

//El modelo registra el schema para cierta entidad que luego será guardada en la colección
//Ejemplo: Quiero guardar usuarios, mi entidad es usuario, y registro en mongoose que para la entidad de usuario se deberá cumplir con 'x' schema
const User = mongoose.model('User', userschema);

export default User;