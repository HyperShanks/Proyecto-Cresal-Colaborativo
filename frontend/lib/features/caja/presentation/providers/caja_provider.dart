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

  List<CobroPendienteModel> _todosLosCobros = [];
  List<CobroPendienteModel> _cobrosFiltrados = [];
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
  String _modalidadPago = 'UNICO'; // 'UNICO' | 'SPLIT'
  int _montoDeclarado = 0;
  List<TransaccionPagoItemModel> _pagosDivididos = [];
  bool _isProcesandoCobro = false;
  RegistrarCobroResponseModel? _ultimoResultadoCobro;

  // ── ESTADO REACTIVO DE ATRIBUCIÓN BACKORDER ──
  String? _skuActivoAtribuido;
  bool _forzarAtribucion = false;
  ValidarActivoBackorderResponseModel? _validacionActivo;
  bool _isRevisandoActivo = false;

  CajaProvider({
    ICajaService? cajaService,
  }) : _cajaService = cajaService ?? CajaService();

  List<CobroPendienteModel> get cobros => _cobrosFiltrados;
  CobroPendienteModel? get ordenSeleccionada => _ordenSeleccionada;
  String get filtroTipo => _filtroTipo;
  String get terminoBusqueda => _terminoBusqueda;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  int get totalCobros => _todosLosCobros.length;

  int get totalVentasCount => _todosLosCobros.where((c) => c.esVenta).length;
  int get totalBackordersCount => _todosLosCobros.where((c) => c.esBackorder).length;

  int get montoTotalPendiente =>
      _todosLosCobros.fold(0, (sum, item) => sum + item.montoACobrar);

  // ── GETTERS DE COBRO & CUADRATURA (SPEC-HU-03) ──
  String get modalidad => _modalidad;
  String get modalidadPago => _modalidadPago;
  int get montoDeclarado => _montoDeclarado;
  List<TransaccionPagoItemModel> get pagosDivididos =>
      List.unmodifiable(_pagosDivididos);
  bool get isProcesandoCobro => _isProcesandoCobro;
  RegistrarCobroResponseModel? get ultimoResultadoCobro =>
      _ultimoResultadoCobro;

  String? get skuActivoAtribuido => _skuActivoAtribuido;
  bool get forzarAtribucion => _forzarAtribucion;
  ValidarActivoBackorderResponseModel? get validacionActivo => _validacionActivo;
  bool get isRevisandoActivo => _isRevisandoActivo;

  int get totalPagosIngresados =>
      _pagosDivididos.fold(0, (sum, p) => sum + p.monto);

  int get diferenciaCuadratura => _montoDeclarado - totalPagosIngresados;

  /// Valida que el monto declarado esté dentro del rango permitido (1 <= monto <= saldo pendiente).
  bool get esMontoValido {
    if (_ordenSeleccionada == null) return false;
    final maxPermitido = _ordenSeleccionada!.montoACobrar;
    return _montoDeclarado > 0 && _montoDeclarado <= maxPermitido;
  }

  /// Indica si el monto declarado excede el saldo pendiente de la orden.
  bool get esMontoExcedido {
    if (_ordenSeleccionada == null) return false;
    return _montoDeclarado > _ordenSeleccionada!.montoACobrar;
  }

  bool get esCuadraturaValida =>
      diferenciaCuadratura == 0 &&
      esMontoValido &&
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
        busqueda: null,
        tipoOperacion: 'TODOS',
      );

      _todosLosCobros = items;
      _aplicarFiltrosLocales();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Aplica los filtros de píldoras y búsqueda sobre la colección en memoria.
  void _aplicarFiltrosLocales() {
    var resultado = List<CobroPendienteModel>.from(_todosLosCobros);

    // Filtro por píldora de tipo
    if (_filtroTipo == 'VENTA') {
      resultado = resultado.where((c) => c.esVenta).toList();
    } else if (_filtroTipo == 'BACKORDER') {
      resultado = resultado.where((c) => c.esBackorder).toList();
    }

    // Filtro por término de búsqueda (multicriterio)
    if (_terminoBusqueda.trim().isNotEmpty) {
      final query = _terminoBusqueda.trim().toLowerCase();
      resultado = resultado.where((c) {
        final folio = c.folioDocumento.toLowerCase();
        final cliente = c.clienteNombre.toLowerCase();
        final rut = c.clienteRut.toLowerCase();
        final vendedor = c.vendedorNombre.toLowerCase();
        return folio.contains(query) ||
            cliente.contains(query) ||
            rut.contains(query) ||
            vendedor.contains(query);
      }).toList();
    }

    _cobrosFiltrados = resultado;

    // Mantener seleccionada la orden actual si aún existe en la lista filtrada, o resetear
    if (_ordenSeleccionada != null) {
      final encontrada = _cobrosFiltrados
          .where((o) => o.idReferencia == _ordenSeleccionada!.idReferencia);
      if (encontrada.isNotEmpty) {
        _ordenSeleccionada = encontrada.first;
      } else {
        _ordenSeleccionada = null;
        _montoDeclarado = 0;
        _pagosDivididos = [];
      }
    }
  }

  /// Selecciona una orden para desplegar en el panel de detalle derecho (Master-Detail).
  /// Inicializa automáticamente la pasarela en Liquidación total con Efectivo (Pago Único).
  void seleccionarOrden(CobroPendienteModel? orden) {
    if (_ordenSeleccionada?.idReferencia == orden?.idReferencia &&
        orden != null) {
      return;
    }
    _ordenSeleccionada = orden;
    _ultimoResultadoCobro = null;
    if (orden != null) {
      final esBackorderInicial = orden.esBackorder && (orden.abonoPrevio == 0);
      _modalidad = esBackorderInicial ? 'ABONO' : 'LIQUIDACION';
      _modalidadPago = 'UNICO';
      _montoDeclarado = orden.montoACobrar;
      _pagosDivididos = [
        TransaccionPagoItemModel(metodo: 'Efectivo', monto: orden.montoACobrar),
      ];
    } else {
      _modalidad = 'LIQUIDACION';
      _modalidadPago = 'UNICO';
      _montoDeclarado = 0;
      _pagosDivididos = [];
    }
    _skuActivoAtribuido = null;
    _forzarAtribucion = false;
    _validacionActivo = null;
    notifyListeners();
  }

  /// Cambia la modalidad de cobro ('LIQUIDACION' | 'ABONO').
  void setModalidad(String nuevaModalidad) {
    final modNorm = nuevaModalidad.toUpperCase();
    if (_modalidad == modNorm) return;

    // Si es un backorder en etapa de abono inicial (sin abono previo), no permitir cambiar a Liquidación
    // ya que el activo físico aún no existe ni ha ingresado a inventario.
    if (_ordenSeleccionada?.esBackorder == true &&
        _ordenSeleccionada?.abonoPrevio == 0 &&
        modNorm == 'LIQUIDACION') {
      return;
    }

    _modalidad = modNorm;

    if (_ordenSeleccionada != null) {
      if (_modalidad == 'LIQUIDACION') {
        _montoDeclarado = _ordenSeleccionada!.montoACobrar;
      } else if (_modalidad == 'ABONO') {
        // En abono, si el monto declarado supera el saldo pendiente o es <= 0, sugerir monto a cobrar o 50%
        if (_montoDeclarado >= _ordenSeleccionada!.montoACobrar || _montoDeclarado <= 0) {
          if (_ordenSeleccionada!.esBackorder && _ordenSeleccionada!.abonoPrevio == 0) {
            _montoDeclarado = _ordenSeleccionada!.montoACobrar;
          } else {
            _montoDeclarado = (_ordenSeleccionada!.montoACobrar * 0.5).round();
            if (_montoDeclarado <= 0) {
              _montoDeclarado = _ordenSeleccionada!.montoACobrar;
            }
          }
        }
      }
      if (_modalidadPago == 'UNICO' || _pagosDivididos.length <= 1) {
        final metodoActual = _pagosDivididos.isNotEmpty ? _pagosDivididos.first.metodo : 'Efectivo';
        _pagosDivididos = [
          TransaccionPagoItemModel(metodo: metodoActual, monto: _montoDeclarado),
        ];
      }
    }
    notifyListeners();
  }

  /// Cambia la modalidad de la pasarela ('UNICO' | 'SPLIT').
  void setModalidadPago(String nuevaModalidad) {
    final modNorm = nuevaModalidad.toUpperCase();
    if (_modalidadPago == modNorm) return;
    _modalidadPago = modNorm;

    if (_modalidadPago == 'UNICO') {
      final primerMetodo = _pagosDivididos.isNotEmpty ? _pagosDivididos.first.metodo : 'Efectivo';
      _pagosDivididos = [
        TransaccionPagoItemModel(metodo: primerMetodo, monto: _montoDeclarado),
      ];
    }
    notifyListeners();
  }

  /// Establece el monto total acordado a cobrar.
  void setMontoDeclarado(int nuevoMonto) {
    _montoDeclarado = nuevoMonto;
    if (_modalidadPago == 'UNICO' || _pagosDivididos.length == 1) {
      if (_pagosDivididos.isNotEmpty) {
        _pagosDivididos[0] = _pagosDivididos[0].copyWith(monto: nuevoMonto);
      }
    }
    notifyListeners();
  }

  /// Comprueba si un canal de pago se encuentra activo en la pasarela.
  bool esMetodoActivo(String metodo) {
    final mNorm = metodo.toLowerCase().replaceAll('é', 'e');
    return _pagosDivididos.any(
      (p) => p.metodo.toLowerCase().replaceAll('é', 'e') == mNorm,
    );
  }

  /// Alterna o selecciona un método de pago desde el grid de 5 botones.
  void toggleMetodoPago(String metodo) {
    final mNorm = metodo.toLowerCase().replaceAll('é', 'e');

    if (_modalidadPago == 'UNICO') {
      // En modo único, el método seleccionado cubre el 100% de inmediato
      _pagosDivididos = [
        TransaccionPagoItemModel(metodo: metodo, monto: _montoDeclarado),
      ];
      notifyListeners();
      return;
    }

    // En modo dividido (SPLIT)
    final index = _pagosDivididos.indexWhere(
      (p) => p.metodo.toLowerCase().replaceAll('é', 'e') == mNorm,
    );

    if (index >= 0) {
      if (_pagosDivididos.length > 1) {
        _pagosDivididos.removeAt(index);
      }
    } else {
      final restante = diferenciaCuadratura > 0 ? diferenciaCuadratura : 0;
      _pagosDivididos.add(
        TransaccionPagoItemModel(metodo: metodo, monto: restante),
      );
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
      _modalidadPago = 'UNICO';
      _montoDeclarado = _ordenSeleccionada!.montoACobrar;
      _pagosDivididos = [
        TransaccionPagoItemModel(
          metodo: 'Efectivo',
          monto: _ordenSeleccionada!.montoACobrar,
        ),
      ];
      _skuActivoAtribuido = null;
      _forzarAtribucion = false;
      _validacionActivo = null;
      notifyListeners();
    }
  }

  /// Valida el SKU de un activo ingresado contra la reserva backorder activa.
  Future<void> validarActivoBackorder(String sku) async {
    if (_ordenSeleccionada == null || !_ordenSeleccionada!.esBackorder) return;
    
    _isRevisandoActivo = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final req = ValidarActivoBackorderRequestModel(
        idDocumento: _ordenSeleccionada!.idReferencia,
        skuActivo: sku,
      );
      _validacionActivo = await _cajaService.validarActivoBackorder(req);
      _skuActivoAtribuido = sku;
      _forzarAtribucion = false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _validacionActivo = null;
      _skuActivoAtribuido = null;
      _forzarAtribucion = false;
    } finally {
      _isRevisandoActivo = false;
      notifyListeners();
    }
  }

  void setForzarAtribucion(bool val) {
    _forzarAtribucion = val;
    notifyListeners();
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
        skuActivoAtribuido: _skuActivoAtribuido,
        forzarAtribucion: _forzarAtribucion,
      );

      final resultado = await _cajaService.registrarCobro(request);
      _ultimoResultadoCobro = resultado;

      return resultado;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isProcesandoCobro = false;
      notifyListeners();
    }
  }

  /// Remueve la orden procesada de la lista en memoria y limpia el panel lateral (SPEC-HU-04 / CA-06).
  void removerOrdenProcesada(String idDocumento) {
    _todosLosCobros.removeWhere((c) => c.idReferencia == idDocumento);
    _aplicarFiltrosLocales();
    _ordenSeleccionada = null;
    _montoDeclarado = 0;
    _pagosDivididos = [];
    _modalidad = 'LIQUIDACION';
    notifyListeners();
  }

  /// Cambia el filtro de píldoras ('TODOS', 'VENTA', 'BACKORDER') de forma instantánea sin resetear contadores.
  void setFiltroTipo(String nuevoTipo) {
    final tipoNorm = nuevoTipo.toUpperCase();
    if (_filtroTipo == tipoNorm) return;
    _filtroTipo = tipoNorm;
    _aplicarFiltrosLocales();
    notifyListeners();
  }

  /// Ejecuta búsqueda con debounce de 150 ms sobre la colección en memoria.
  void buscar(String query) {
    _debounceTimer?.cancel();
    _terminoBusqueda = query;

    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _aplicarFiltrosLocales();
      notifyListeners();
    });
  }

  /// Limpia el campo de búsqueda inmediatamente.
  void limpiarBusqueda() {
    _debounceTimer?.cancel();
    if (_terminoBusqueda.isEmpty) return;
    _terminoBusqueda = '';
    _aplicarFiltrosLocales();
    notifyListeners();
  }
}

