import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/checkout_wizard_models.dart';
import '../services/ventas_service.dart';

/// Controlador reactivo del estado para el Checkout Wizard por Pasos (SPEC-HU-05)
class CheckoutWizardController extends ChangeNotifier {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Paso 1: Ítems
  final List<Map<String, dynamic>> _itemsInventariados = [];
  final List<ItemManualModel> _itemsManuales = [];
  final List<ReservaBackorderModel> _reservas = [];

  // Paso 2: Cliente
  ClienteWizardModel? _clienteSeleccionado;

  // Paso 3: Logística y Despacho
  String _tipoEntrega = 'Retiro'; // 'Retiro', 'Despacho Domicilio', 'Traslado'
  int _idSucursalDestino = 1; // 1: Viña del Mar, 2: Limache
  String? _idVendedorAsignado; // Para vendedor online
  DespachoModel? _datosDespacho;

  // Paso 4: Abonos y Notas
  int _abonoAdicional = 0;
  String _notasGenerales = '';

  // Getters
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get itemsInventariados => List.unmodifiable(_itemsInventariados);
  List<ItemManualModel> get itemsManuales => List.unmodifiable(_itemsManuales);
  List<ReservaBackorderModel> get reservas => List.unmodifiable(_reservas);

  ClienteWizardModel? get clienteSeleccionado => _clienteSeleccionado;
  String get tipoEntrega => _tipoEntrega;
  int get idSucursalDestino => _idSucursalDestino;
  String? get idVendedorAsignado => _idVendedorAsignado;
  DespachoModel? get datosDespacho => _datosDespacho;
  int get abonoAdicional => _abonoAdicional;
  String get notasGenerales => _notasGenerales;

  // Cálculos financieros
  int get subtotalInventario => _itemsInventariados.fold<int>(0, (sum, i) => sum + (int.tryParse(i['precio']?.toString() ?? '0') ?? 0));
  int get subtotalManuales => _itemsManuales.fold<int>(0, (sum, m) => sum + m.precioFinal);
  int get subtotalReservas => _reservas.fold<int>(0, (sum, r) => sum + r.precioAcordado);

  int get totalVenta => subtotalInventario + subtotalManuales + subtotalReservas;

  int get abonoReservas => _reservas.fold<int>(0, (sum, r) => sum + r.montoAbonado);
  int get totalAbonos => abonoReservas + _abonoAdicional;

  int get montoPendiente {
    final saldo = totalVenta - totalAbonos;
    return saldo < 0 ? 0 : saldo;
  }

  int get totalItemsCount => _itemsInventariados.length + _itemsManuales.length + _reservas.length;

  // ── Gestión de Pasos ──────────────────────────────────────────────────────
  void setStep(int step) {
    if (step >= 0 && step <= 4) {
      _currentStep = step;
      _errorMessage = null;
      notifyListeners();
    }
  }

  bool nextStep() {
    _errorMessage = null;
    if (_currentStep == 0 && !validateStep1()) {
      _errorMessage = 'Debes agregar al menos un artículo o servicio para proceder.';
      notifyListeners();
      return false;
    }
    if (_currentStep == 1 && !validateStep2()) {
      _errorMessage = 'Falta identificar al cliente. Por favor, ingresa un RUT válido antes de proceder con la reserva de estos activos.';
      notifyListeners();
      return false;
    }
    if (_currentStep == 2 && !validateStep3()) {
      _errorMessage = 'Complete todos los campos obligatorios para el despacho a domicilio.';
      notifyListeners();
      return false;
    }
    if (_currentStep == 3 && !validateStep4()) {
      _errorMessage = 'El monto de abono no puede ser superior al total de la venta.';
      notifyListeners();
      return false;
    }

    if (_currentStep < 4) {
      _currentStep++;
      notifyListeners();
      return true;
    }
    return true;
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ── Validaciones ──────────────────────────────────────────────────────────
  bool validateStep1() => totalItemsCount > 0;
  bool validateStep2() => _clienteSeleccionado != null && _clienteSeleccionado!.rut.trim().isNotEmpty;
  bool validateStep3() {
    if (_tipoEntrega == 'Retiro' || _tipoEntrega == 'Traslado') return true;
    if (_datosDespacho == null) return false;
    return _datosDespacho!.direccionEnvio.trim().isNotEmpty &&
        _datosDespacho!.receptorNombres.trim().isNotEmpty &&
        _datosDespacho!.receptorRut.trim().isNotEmpty;
  }
  bool validateStep4() => totalAbonos <= totalVenta;

  // ── Modificadores de Estado ───────────────────────────────────────────────
  void clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  bool _limpiarErrorStep1SiAplica() {
    if (_errorMessage == 'Debes agregar al menos un artículo o servicio para proceder.' && totalItemsCount > 0) {
      _errorMessage = null;
      return true;
    }
    return false;
  }

  void addItemInventariado({
    required String idActivo,
    required String sku,
    required String descripcion,
    required int precio,
    String? pasillo,
    String? pallet,
  }) {
    if (!_itemsInventariados.any((i) => i['id_activo'] == idActivo)) {
      _itemsInventariados.add({
        'id_activo': idActivo,
        'sku': sku,
        'descripcion': descripcion,
        'precio': precio,
        'pasillo': pasillo,
        'pallet': pallet,
      });
      _limpiarErrorStep1SiAplica();
      notifyListeners();
    } else {
      if (_limpiarErrorStep1SiAplica()) {
        notifyListeners();
      }
    }
  }

  void removeItemInventariado(String idActivo) {
    _itemsInventariados.removeWhere((i) => i['id_activo'] == idActivo);
    notifyListeners();
  }

  void addItemManual(ItemManualModel item) {
    _itemsManuales.add(item);
    _limpiarErrorStep1SiAplica();
    notifyListeners();
  }

  void removeItemManual(int index) {
    if (index >= 0 && index < _itemsManuales.length) {
      _itemsManuales.removeAt(index);
      notifyListeners();
    }
  }

  void addReservaBackorder(ReservaBackorderModel reserva) {
    _reservas.add(reserva);
    _limpiarErrorStep1SiAplica();
    notifyListeners();
  }

  void removeReservaBackorder(int index) {
    if (index >= 0 && index < _reservas.length) {
      _reservas.removeAt(index);
      notifyListeners();
    }
  }

  void setCliente(ClienteWizardModel? cliente) {
    _clienteSeleccionado = cliente;
    _errorMessage = null;
    notifyListeners();
  }

  void setTipoEntrega(String tipo) {
    _tipoEntrega = tipo;
    if (_errorMessage == 'Complete todos los campos obligatorios para el despacho a domicilio.' && validateStep3()) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void setIdSucursalDestino(int sucursalId) {
    _idSucursalDestino = sucursalId;
    notifyListeners();
  }

  void setIdVendedorAsignado(String? vendedorId) {
    _idVendedorAsignado = vendedorId;
    notifyListeners();
  }

  void setDatosDespacho(DespachoModel? despacho) {
    _datosDespacho = despacho;
    if (_errorMessage == 'Complete todos los campos obligatorios para el despacho a domicilio.' && validateStep3()) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void setAbonoAdicional(int abono) {
    _abonoAdicional = abono < 0 ? 0 : abono;
    if (_errorMessage == 'El monto de abono no puede ser superior al total de la venta.' && validateStep4()) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void setNotasGenerales(String notas) {
    _notasGenerales = notas;
    notifyListeners();
  }

  void clearAll() {
    _currentStep = 0;
    _isLoading = false;
    _errorMessage = null;
    _itemsInventariados.clear();
    _itemsManuales.clear();
    _reservas.clear();
    _clienteSeleccionado = null;
    _tipoEntrega = 'Retiro';
    _idSucursalDestino = 1;
    _idVendedorAsignado = null;
    _datosDespacho = null;
    _abonoAdicional = 0;
    _notasGenerales = '';
    notifyListeners();
  }

  // ── Emisión Transaccional (ACID) ──────────────────────────────────────────
  Future<CheckoutWizardResponseModel?> submitOrder({http.Client? client}) async {
    if (!validateStep1() || !validateStep2() || !validateStep3() || !validateStep4()) {
      _errorMessage = 'Por favor complete todos los datos requeridos antes de emitir la orden.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = CheckoutWizardRequestModel(
        idCliente: _clienteSeleccionado!.idCliente,
        cliente: _clienteSeleccionado,
        tipoEntrega: _tipoEntrega,
        idSucursalDestino: _tipoEntrega == 'Traslado' ? _idSucursalDestino : null,
        idVendedorAsignado: _idVendedorAsignado,
        totalVenta: totalVenta,
        montoPendiente: montoPendiente,
        montoAbono: totalAbonos,
        instruccionesBodega: _notasGenerales,
        itemsInventariados: _itemsInventariados.map((i) => i['id_activo'].toString()).toList(),
        itemsManuales: _itemsManuales,
        reservas: _reservas,
        datosDespacho: _tipoEntrega == 'Despacho Domicilio' || _tipoEntrega == 'Despacho' || _tipoEntrega == 'Traslado'
            ? _datosDespacho
            : null,
      );

      final response = await VentasService.processCheckoutWizard(request, client: client);

      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      notifyListeners();
      return null;
    }
  }
}
