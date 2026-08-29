// lib/features/ventas/models/cart_item_model.dart

import 'catalogo_model.dart';

/// Clase base abstracta para cualquier ítem dentro del Carrito Híbrido (HU-3.3).
/// Soporta tanto repuestos inventariados en BD como ventas libres / misceláneas.
abstract class CartItem {
  String get id;
  String get titulo;
  String get subtitulo;
  int get precioUnitario;
  int get cantidad;
  int get subtotal => precioUnitario * cantidad;
  bool get esInventariado;

  String get precioUnitarioFormateado => _formatearMoneda(precioUnitario);
  String get subtotalFormateado => _formatearMoneda(subtotal);

  Map<String, dynamic> toJson();

  static String _formatearMoneda(int monto) {
    final valor = monto.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '\$$valor';
  }
}

/// Representa un Activo Inventariado proveniente del catálogo.
/// Permite que el precio final sea negociado/modificado por el vendedor antes de generar la orden.
class InventariadoCartItem extends CartItem {
  final CatalogoItem catalogoItem;
  int precioFinal;
  String? notasPreparacion;

  InventariadoCartItem({
    required this.catalogoItem,
    required this.precioFinal,
    this.notasPreparacion,
  });

  @override
  String get id => catalogoItem.idActivo;

  @override
  String get titulo => catalogoItem.tituloRepuesto;

  String get sku => catalogoItem.skuQrFisico;
  String get nombreSucursal => catalogoItem.nombreSucursal;

  @override
  String get subtitulo => 'SKU: $sku | Sucursal: $nombreSucursal';

  @override
  int get precioUnitario => precioFinal;

  @override
  int get cantidad => 1; // Un activo físico inventariado es una pieza única (cantidad = 1)

  @override
  bool get esInventariado => true;

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'inventariado',
      'id_activo': catalogoItem.idActivo,
      'sku_qr_fisico': catalogoItem.skuQrFisico,
      'titulo': titulo,
      'precio_referencia_original': catalogoItem.precioReferencia,
      'precio_final': precioFinal,
      'cantidad': cantidad,
      'subtotal': subtotal,
      'notas_preparacion': notasPreparacion,
      'id_sucursal_actual': catalogoItem.idSucursalActual,
    };
  }
}

/// Representa un artículo de Venta Libre / Misceláneo no registrado previamente en el inventario.
/// Permite especificar una descripción abierta, monto acordado, cantidad y notas.
class VentaLibreCartItem extends CartItem {
  @override
  final String id;
  String descripcion;
  int monto;
  int _cantidad;
  String? observacion;

  VentaLibreCartItem({
    required this.id,
    required this.descripcion,
    required this.monto,
    int cantidad = 1,
    this.observacion,
  }) : _cantidad = cantidad > 0 ? cantidad : 1;

  @override
  String get titulo => descripcion;

  @override
  String get subtitulo =>
      observacion != null && observacion!.isNotEmpty
          ? observacion!
          : 'Venta Libre / Misceláneo';

  @override
  int get precioUnitario => monto;

  @override
  int get cantidad => _cantidad;

  set cantidad(int value) {
    if (value > 0) {
      _cantidad = value;
    }
  }

  @override
  bool get esInventariado => false;

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'venta_libre',
      'id_item': id,
      'descripcion': descripcion,
      'monto_unitario': monto,
      'cantidad': cantidad,
      'subtotal': subtotal,
      'observacion': observacion,
    };
  }
}

/// Representa una Reserva por Encargo (Compra en Verde / Backorder) en el carrito
class ReservaBackorderCartItem extends CartItem {
  @override
  final String id;
  final String marca;
  final String modelo;
  final int? anio;
  final String categoriaNombre;
  final int idCategoria;
  final int precioAcordado;
  final int montoAbonado;
  final String? notas;

  ReservaBackorderCartItem({
    required this.id,
    required this.marca,
    required this.modelo,
    this.anio,
    required this.categoriaNombre,
    required this.idCategoria,
    required this.precioAcordado,
    this.montoAbonado = 0,
    this.notas,
  });

  @override
  String get titulo => '[COMPRA EN VERDE] $categoriaNombre - $marca $modelo ${anio != null ? "($anio)" : ""}';

  @override
  String get subtitulo => 'Precio Acordado: \$$_montoFormateado(precioAcordado) | Abono: \$$_montoFormateado(montoAbonado)';

  static String _montoFormateado(int monto) {
    return monto.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  int get precioUnitario => precioAcordado;

  @override
  int get cantidad => 1;

  @override
  bool get esInventariado => false;

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'reserva_backorder',
      'id_reserva': id,
      'id_categoria_requerida': idCategoria,
      'categoria_nombre': categoriaNombre,
      'marca_requerida': marca,
      'modelo_requerido': modelo,
      'anio_requerido': anio,
      'precio_acordado': precioAcordado,
      'monto_abonado': montoAbonado,
      'notas_preparacion': notas,
    };
  }
}
