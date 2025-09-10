let edad : number;

function obtenerEdad(mensaje_para_usuario: string): number {
let dato : string | null = prompt(mensaje_para_usuario);
while (!dato || isNaN(Number(dato))) {
  alert("Error: Dato no numerico");
  dato = prompt(mensaje_para_usuario);
}
return Number(dato);
}

// Calcula el precio con IVA (21%)
function calcularPrecioConIVA(precio: number): number {
  let iva = 0.21;
  return precio * (1 + iva);
}


const precios_db = [100, 400, 450, 321, 500];

// Va a recibir una lista de precios y va a devolver el IVA total de la lista
// Usar la funcion de calcularPrecioConIVA
function calcularIvaTotalAListaDePrecios(lista_de_precios: number[]): number {
  let ivaTotal = 0;
  for (let precio of lista_de_precios) {
    ivaTotal += calcularPrecioConIVA(precio) - precio;
  }
  return ivaTotal;
}

// Ejemplo de uso:
console.log(`IVA total de la lista: $${calcularIvaTotalAListaDePrecios(precios_db)}`);


const persona = {
  nombre: "Ian",
  edad: 30,
  apellido: "Kety"
};