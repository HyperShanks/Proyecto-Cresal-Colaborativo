import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/cobro_pendiente_model.dart';
import '../../services/caja_service.dart';

/// Proveedor de estado reactivo para la Bandeja de Cobros de Caja (SPEC-HU-4.2 / CRES-214).
/// Maneja la lista de cobros pendientes, la selección activa Master-Detail,
/// el selector de píldoras y la búsqueda reactiva con debounce de 300 ms.
class CajaProvider extends ChangeNotifier {
  final ICajaService _cajaService;

  List<CobroPendienteModel> _cobros = [];
  CobroPendienteModel? _ordenSeleccionada;
  String _filtroTipo = 'TODOS'; // 'TODOS' | 'VENTA' | 'BACKORDER'
  String _terminoBusqueda = '';
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  int? _sucursalId;

  Timer? _debounceTimer;

  CajaProvider({ICajaService? cajaService})
      : _cajaService = cajaService ?? CajaService();

  List<CobroPendienteModel> get cobros => _cobros;
  CobroPendienteModel? get ordenSeleccionada => _ordenSeleccionada;
  String get filtroTipo => _filtroTipo;
  String get terminoBusqueda => _terminoBusqueda;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  int get totalCobros => _cobros.length;

  int get totalVentasCount => _cobros.where((c) => c.esVenta).length;
  int get totalBackordersCount => _cobros.where((c) => c.esBackorder).length;

  int get montoTotalPendiente =>
      _cobros.fold(0, (sum, item) => sum + item.montoACobrar);

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Carga la lista de cobros pendientes desde la API.
  Future<void> cargarCobrosPendientes({
    bool refresh = false,
    int? sucursalId,
  }) async {
    if (refresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      if (sucursalId != null) {
        _sucursalId = sucursalId;
      } else {
        _sucursalId ??= await AuthService.getSucursalId() ?? 1;
      }

      final items = await _cajaService.obtenerCobrosPendientes(
        sucursalId: _sucursalId!,
        busqueda: _terminoBusqueda.isNotEmpty ? _terminoBusqueda : null,
        tipoOperacion: _filtroTipo != 'TODOS' ? _filtroTipo : null,
      );

      _cobros = items;

      // Mantener seleccionada la orden actual si aún existe en la lista, o resetear
      if (_ordenSeleccionada != null) {
        final encontrada = _cobros.where((o) => o.idReferencia == _ordenSeleccionada!.idReferencia);
        if (encontrada.isNotEmpty) {
          _ordenSeleccionada = encontrada.first;
        } else {
          _ordenSeleccionada = null;
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Selecciona una orden para desplegar en el panel de detalle derecho (Master-Detail).
  void seleccionarOrden(CobroPendienteModel? orden) {
    if (_ordenSeleccionada?.idReferencia == orden?.idReferencia) return;
    _ordenSeleccionada = orden;
    notifyListeners();
  }

  /// Cambia el filtro de píldoras ('TODOS', 'VENTA', 'BACKORDER') y recarga.
  void setFiltroTipo(String nuevoTipo) {
    final tipoNorm = nuevoTipo.toUpperCase();
    if (_filtroTipo == tipoNorm) return;
    _filtroTipo = tipoNorm;
    cargarCobrosPendientes();
  }

  /// Ejecuta búsqueda con debounce de 300 ms.
  void buscar(String query) {
    _debounceTimer?.cancel();
    _terminoBusqueda = query;

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      cargarCobrosPendientes();
    });
  }

  /// Limpia el campo de búsqueda inmediatamente.
  void limpiarBusqueda() {
    _debounceTimer?.cancel();
    if (_terminoBusqueda.isEmpty) return;
    _terminoBusqueda = '';
    cargarCobrosPendientes();
  }
}
