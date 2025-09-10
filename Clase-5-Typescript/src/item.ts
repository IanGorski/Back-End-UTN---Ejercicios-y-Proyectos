eliminarPorId(item_id: number): boolean {
    const index = this.items.findIndex(item => item.id === item_id);
    if (index !== -1) {
        this.items.splice(index, 1);
        return true;
    }
    return false;
}

modificarStockItem(item: ItemTienda, cantidad: number): boolean {
    if (cantidad <= item.stock) {
        item.setStock(item.stock - cantidad);
        return true;
    } else {
        console.log('no se puede decrementar la cantidad');
        return false;
    }
}

vender(id_item_a_vender: number, cantidad_vendida: number): void {
    const item = this.buscarItemPorId(id_item_a_vender);
    if (!item) {
        console.log('Producto no encontrado');
        return;
    }
    const venta = this.modificarStockItem(item, cantidad_vendida);
    if (venta) {
        this.cantidad_dinero_en_cuenta += item.precio * item.margen_ganancia * cantidad_vendida;
    } else {
        console.log('No hay stock suficiente');
    }
} CORREGIR


