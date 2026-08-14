// lib/features/ventas/controllers/cart_controller.dart

import 'package:flutter/foundation.dart';
import '../models/cart_item_model.dart';
import '../models/catalogo_model.dart';

/// Controlador Reactivo de Estado Global para el Carrito Híbrido (HU-3.3).
/// Implementado como Singleton con ChangeNotifier (100% Flutter nativo).
/// Persiste en memoria durante toda la sesión y notifica a los widgets suscritos.
class CartController extends ChangeNotifier {
  static final CartController _instance = CartController._internal();
  factory CartController() => _instance;
  static CartController get instance => _instance;

  CartController._internal();

  final List<CartItem> _items = [];

  /// Lista inmutable de ítems en el carrito
  List<CartItem> get items => List.unmodifiable(_items);

  /// Cantidad total de unidades de productos en el carrito
  int get totalItems => _items.fold(0, (sum, item) => sum + item.cantidad);

  /// Monto total acumulado en pesos chilenos (CLP)
  int get totalMonto => _items.fold(0, (sum, item) => sum + item.subtotal);

  /// Monto total formateado en moneda CLP (ej. "$1.250.000")
  String get totalMontoFormateado {
    final valor = totalMonto.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '\$$valor';
  }

  /// Indica si el carrito está actualmente vacío
  bool get estaVacio => _items.isEmpty;

  /// Verifica si un activo inventariado específico ya se encuentra en el carrito
  bool estaEnCarrito(String idActivo) {
    return _items.any((item) => item.esInventariado && item.id == idActivo);
  }

  /// Agrega un Activo Inventariado al carrito.
  /// Retorna `true` si se agregó exitosamente, o `false` si ya existía en el carrito.
  bool agregarInventariado(
    CatalogoItem item, {
    int? precioFinal,
    String? notas,
  }) {
    if (estaEnCarrito(item.idActivo)) {
      return false;
    }

    final cartItem = InventariadoCartItem(
      catalogoItem: item,
      precioFinal: precioFinal ?? item.precioReferencia ?? 0,
      notasPreparacion: notas,
    );

    _items.add(cartItem);
    notifyListeners();
    return true;
  }

  /// Agrega un artículo de Venta Libre / Misceláneo al carrito
  void agregarVentaLibre({
    required String descripcion,
    required int monto,
    int cantidad = 1,
    String? observacion,
  }) {
    final cartItem = VentaLibreCartItem(
      id: 'VL-${DateTime.now().millisecondsSinceEpoch}',
      descripcion: descripcion.trim(),
      monto: monto,
      cantidad: cantidad > 0 ? cantidad : 1,
      observacion: observacion?.trim(),
    );

    _items.add(cartItem);
    notifyListeners();
  }

  /// Actualiza el precio acordado de un ítem (inventariado o venta libre)
  void actualizarPrecio(String itemId, int nuevoPrecio) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    final item = _items[index];
    if (item is InventariadoCartItem) {
      item.precioFinal = nuevoPrecio;
    } else if (item is VentaLibreCartItem) {
      item.monto = nuevoPrecio;
    }
    notifyListeners();
  }

  /// Actualiza la cantidad de un ítem de venta libre (si es 0 se elimina)
  void actualizarCantidad(String itemId, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      eliminarItem(itemId);
      return;
    }

    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    final item = _items[index];
    if (item is VentaLibreCartItem) {
      item.cantidad = nuevaCantidad;
      notifyListeners();
    }
  }

  /// Actualiza las notas / observaciones de preparación de un ítem
  void actualizarNotas(String itemId, String? notas) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    final item = _items[index];
    if (item is InventariadoCartItem) {
      item.notasPreparacion = notas;
    } else if (item is VentaLibreCartItem) {
      item.observacion = notas;
    }
    notifyListeners();
  }

  /// Elimina un ítem específico del carrito por su ID
  void eliminarItem(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    notifyListeners();
  }

  /// Vacía por completo el carrito
  void vaciarCarrito() {
    _items.clear();
    notifyListeners();
  }
}
