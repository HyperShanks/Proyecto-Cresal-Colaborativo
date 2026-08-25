import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/cobro_pendiente_model.dart';
import '../../models/cobro_model.dart';
import '../../services/caja_service.dart';

/// Proveedor de estado reactivo para la Bandeja de Cobros y Panel de Cobro de Caja (SPEC-HU-03).
/// Maneja la lista de cobros pendientes, la selección activa Master-Detail,
/// el selector de píldoras, la búsqueda reactiva y la pasarela reactiva de pagos divididos (Split).
class CajaProvider extends ChangeNotifier {
  final ICajaService _cajaService;

  List<CobroPendienteModel> _cobros = [];
  CobroPendienteModel? _ordenSeleccionada;
  String _filtroTipo = 'TODOS'; // 'TODOS' | 'VENTA' | 'BACKORDER'
  String _terminoBusqueda = '';
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _sucursalId = 1;

  Timer? _debounceTimer;

  // ── ESTADO REACTIVO DE COBRO ACTIVO (SPEC-HU-03) ──
  String _modalidad = 'LIQUIDACION'; // 'LIQUIDACION' | 'ABONO'
  int _montoDeclarado = 0;
  List<TransaccionPagoItemModel> _pagosDivididos = [];
  bool _isProcesandoCobro = false;
  RegistrarCobroResponseModel? _ultimoResultadoCobro;

  CajaProvider({
    ICajaService? cajaService,
  }) : _cajaService = cajaService ?? CajaService();

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

  // ── GETTERS DE COBRO & CUADRATURA (SPEC-HU-03) ──
  String get modalidad => _modalidad;
  int get montoDeclarado => _montoDeclarado;
  List<TransaccionPagoItemModel> get pagosDivididos =>
      List.unmodifiable(_pagosDivididos);
  bool get isProcesandoCobro => _isProcesandoCobro;
  RegistrarCobroResponseModel? get ultimoResultadoCobro =>
      _ultimoResultadoCobro;

  int get totalPagosIngresados =>
      _pagosDivididos.fold(0, (sum, p) => sum + p.monto);

  int get diferenciaCuadratura => _montoDeclarado - totalPagosIngresados;

  bool get esCuadraturaValida =>
      diferenciaCuadratura == 0 &&
      _montoDeclarado > 0 &&
      _pagosDivididos.isNotEmpty &&
      _pagosDivididos.every((p) => p.monto > 0);

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
      }

      final items = await _cajaService.obtenerCobrosPendientes(
        sucursalId: _sucursalId,
        busqueda: _terminoBusqueda.isNotEmpty ? _terminoBusqueda : null,
        tipoOperacion: _filtroTipo != 'TODOS' ? _filtroTipo : null,
      );

      _cobros = items;

      // Mantener seleccionada la orden actual si aún existe en la lista, o resetear
      if (_ordenSeleccionada != null) {
        final encontrada = _cobros
            .where((o) => o.idReferencia == _ordenSeleccionada!.idReferencia);
        if (encontrada.isNotEmpty) {
          _ordenSeleccionada = encontrada.first;
        } else {
          _ordenSeleccionada = null;
          _montoDeclarado = 0;
          _pagosDivididos = [];
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
  /// Inicializa automáticamente la pasarela en Liquidación total con Efectivo.
  void seleccionarOrden(CobroPendienteModel? orden) {
    if (_ordenSeleccionada?.idReferencia == orden?.idReferencia &&
        orden != null) {
      return;
    }
    _ordenSeleccionada = orden;
    _ultimoResultadoCobro = null;
    if (orden != null) {
      _modalidad = 'LIQUIDACION';
      _montoDeclarado = orden.montoACobrar;
      _pagosDivididos = [
        TransaccionPagoItemModel(metodo: 'Efectivo', monto: orden.montoACobrar),
      ];
    } else {
      _modalidad = 'LIQUIDACION';
      _montoDeclarado = 0;
      _pagosDivididos = [];
    }
    notifyListeners();
  }

  /// Cambia la modalidad de cobro ('LIQUIDACION' | 'ABONO').
  void setModalidad(String nuevaModalidad) {
    final modNorm = nuevaModalidad.toUpperCase();
    if (_modalidad == modNorm) return;
    _modalidad = modNorm;

    if (_ordenSeleccionada != null) {
      if (_modalidad == 'LIQUIDACION') {
        _montoDeclarado = _ordenSeleccionada!.montoACobrar;
      }
      _pagosDivididos = [
        TransaccionPagoItemModel(metodo: 'Efectivo', monto: _montoDeclarado),
      ];
    }
    notifyListeners();
  }

  /// Establece el monto total acordado a cobrar.
  void setMontoDeclarado(int nuevoMonto) {
    _montoDeclarado = nuevoMonto;
    if (_pagosDivididos.length == 1) {
      _pagosDivididos[0] = _pagosDivididos[0].copyWith(monto: nuevoMonto);
    }
    notifyListeners();
  }

  /// Agrega un nuevo canal de método de pago a la pasarela (Split payment).
  void agregarMetodoPago({String metodo = 'Debito', int monto = 0}) {
    _pagosDivididos.add(
      TransaccionPagoItemModel(metodo: metodo, monto: monto),
    );
    notifyListeners();
  }

  /// Remueve un canal de pago por su índice (mínimo debe haber 1).
  void removerMetodoPago(int index) {
    if (_pagosDivididos.length > 1 &&
        index >= 0 &&
        index < _pagosDivididos.length) {
      _pagosDivididos.removeAt(index);
      notifyListeners();
    }
  }

  /// Actualiza el monto numérico de un canal de pago.
  void actualizarMontoMetodo(int index, int monto) {
    if (index >= 0 && index < _pagosDivididos.length) {
      _pagosDivididos[index] = _pagosDivididos[index].copyWith(monto: monto);
      notifyListeners();
    }
  }

  /// Actualiza el tipo de método de pago (Efectivo, Débito, etc.) de un canal.
  void actualizarTipoMetodo(int index, String metodo) {
    if (index >= 0 && index < _pagosDivididos.length) {
      _pagosDivididos[index] = _pagosDivididos[index].copyWith(metodo: metodo);
      notifyListeners();
    }
  }

  /// Función "Auto-rellenar restante" (CA-04):
  /// Calcula la diferencia matemática restante y la asigna a la casilla activa.
  void autoRellenarRestante(int index) {
    if (index < 0 || index >= _pagosDivididos.length) return;

    int otrosMontos = 0;
    for (int i = 0; i < _pagosDivididos.length; i++) {
      if (i != index) {
        otrosMontos += _pagosDivididos[i].monto;
      }
    }

    final restante = _montoDeclarado - otrosMontos;
    if (restante >= 0) {
      _pagosDivididos[index] = _pagosDivididos[index].copyWith(monto: restante);
      notifyListeners();
    }
  }

  /// Reinicia la configuración de cobro al estado por defecto.
  void reiniciarCobro() {
    if (_ordenSeleccionada != null) {
      _modalidad = 'LIQUIDACION';
      _montoDeclarado = _ordenSeleccionada!.montoACobrar;
      _pagosDivididos = [
        TransaccionPagoItemModel(
          metodo: 'Efectivo',
          monto: _ordenSeleccionada!.montoACobrar,
        ),
      ];
      notifyListeners();
    }
  }

  /// Procesa el cobro enviando la petición atómica al Backend (FastAPI).
  Future<RegistrarCobroResponseModel?> procesarCobro() async {
    if (_ordenSeleccionada == null || !esCuadraturaValida) return null;

    _isProcesandoCobro = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = RegistrarCobroRequestModel(
        tipoOperacion: _ordenSeleccionada!.esVenta ? 'ORDEN' : 'BACKORDER',
        idDocumento: _ordenSeleccionada!.idReferencia,
        modalidad: _modalidad,
        montoDeclarado: _montoDeclarado,
        pagos: _pagosDivididos,
      );

      final resultado = await _cajaService.registrarCobro(request);
      _ultimoResultadoCobro = resultado;

      // Recargar lista de cobros pendientes tras éxito
      await cargarCobrosPendientes(refresh: true);

      return resultado;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isProcesandoCobro = false;
      notifyListeners();
    }
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

