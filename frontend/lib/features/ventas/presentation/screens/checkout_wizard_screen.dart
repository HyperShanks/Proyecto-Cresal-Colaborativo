import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/utils/rut_formatter.dart';
import '../../../../core/utils/rut_validator.dart';
import '../../../auth/services/auth_service.dart';
import '../../controllers/cart_controller.dart';
import '../../models/cart_item_model.dart';
import '../../models/checkout_wizard_models.dart';
import '../../controllers/checkout_wizard_controller.dart';
import '../../services/ordenes_service.dart';
import '../../services/ordenes_sync_notifier.dart';
import '../widgets/modal_backorder_form.dart';

/// Pantalla Principal del Checkout Wizard por 5 Pasos Secuenciales (SPEC-HU-05)
/// Integra Carrito Híbrido, Micro-CRM con Consumidor Final, Logística (Retiro/Despacho/Traslado) y Abonos.
class CheckoutWizardScreen extends StatefulWidget {
  final VoidCallback? onOpenMenuDrawer;
  final VoidCallback? onNavigateToCatalogo;
  final List<Map<String, dynamic>>? initialInventario;
  final List<ItemManualModel>? initialManuales;

  const CheckoutWizardScreen({
    super.key,
    this.onOpenMenuDrawer,
    this.onNavigateToCatalogo,
    this.initialInventario,
    this.initialManuales,
  });

  @override
  State<CheckoutWizardScreen> createState() => _CheckoutWizardScreenState();
}

class _CheckoutWizardScreenState extends State<CheckoutWizardScreen> {
  final CheckoutWizardController _controller = CheckoutWizardController();

  // Controladores Paso 2 (Micro-CRM)
  final _rutController = TextEditingController();
  final _clienteNombresController = TextEditingController();
  final _clienteApellidosController = TextEditingController();
  final _clienteTelefonoController = TextEditingController();
  final _clienteEmailController = TextEditingController();
  final FocusNode _rutFocusNode = FocusNode();
  bool _isSearchingCliente = false;
  bool _esClienteAnonimo = false;
  String _comunaCliente = 'Viña del Mar';

  // Controladores Paso 3 (Logística & Despacho / Traslado)
  final _direccionController = TextEditingController();
  final _receptorNombresController = TextEditingController();
  final _receptorRutController = TextEditingController();
  final _receptorTelefonoController = TextEditingController();
  final _empresaTransporteController = TextEditingController(text: 'Chilexpress');
  String _comunaDespacho = 'Viña del Mar';
  int _idSucursalDestino = 1; // 1: Viña del Mar, 2: Limache
  int? _userRolId;
  bool get _esVendedorOnline => _userRolId == 7;
  List<VendedorModel> _vendedoresDisponibles = [];
  String? _idVendedorAsignado;

  // Controladores Paso 4 (Comercial / Abonos)
  final _montoAbonoController = TextEditingController();
  final _notasGeneralesController = TextEditingController();

  static const List<String> _comunasDisponibles = [
    'Viña del Mar',
    'Valparaíso',
    'Limache',
    'Quilpué',
    'Villa Alemana',
    'Concón',
    'Quillota',
    'San Antonio',
    'Santiago',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    CartController.instance.addListener(_sincronizarDesdeCartController);
    _rutFocusNode.addListener(_onRutFocusChange);

    _sincronizarDesdeCartController();
    _cargarRolYVendedores();

    // Cargar ítems iniciales directos si se pasan por parámetro
    if (widget.initialInventario != null) {
      for (final item in widget.initialInventario!) {
        _controller.addItemInventariado(
          idActivo: item['id_activo']?.toString() ?? '',
          sku: item['sku']?.toString() ?? item['sku_qr_fisico']?.toString() ?? 'SKU-00',
          descripcion: item['descripcion']?.toString() ?? 'Repuesto',
          precio: int.tryParse(item['precio']?.toString() ?? '0') ?? 0,
          pasillo: item['pasillo']?.toString(),
          pallet: item['pallet']?.toString(),
        );
      }
    }

    if (widget.initialManuales != null) {
      for (final m in widget.initialManuales!) {
        _controller.addItemManual(m);
      }
    }
  }

  Future<void> _cargarRolYVendedores() async {
    try {
      final rolId = await AuthService.getIdRol();
      if (mounted) {
        setState(() => _userRolId = rolId);
      }
      if (rolId == 7) {
        final vends = await OrdenesService.obtenerVendedores();
        if (mounted) {
          setState(() => _vendedoresDisponibles = vends);
        }
      }
    } catch (_) {}
  }

  void _sincronizarDesdeCartController() {
    final cartItems = CartController.instance.items;
    for (final item in cartItems) {
      if (item is InventariadoCartItem) {
        _controller.addItemInventariado(
          idActivo: item.id,
          sku: item.sku,
          descripcion: item.titulo,
          precio: item.precioFinal,
        );
      } else if (item is VentaLibreCartItem) {
        if (!_controller.itemsManuales.any((m) => m.descripcion == item.descripcion && m.precioUnitario == item.monto)) {
          _controller.addItemManual(
            ItemManualModel(
              descripcion: item.descripcion,
              cantidad: item.cantidad,
              precioUnitario: item.monto,
              precioFinal: item.subtotal,
              notasPreparacion: item.observacion,
            ),
          );
        }
      } else if (item is ReservaBackorderCartItem) {
        if (!_controller.reservas.any((r) => r.marcaRequerida == item.marca && r.modeloRequerido == item.modelo && r.idCategoriaRequerida == item.idCategoria)) {
          _controller.addReservaBackorder(
            ReservaBackorderModel(
              idCategoriaRequerida: item.idCategoria,
              categoriaNombre: item.categoriaNombre,
              marcaRequerida: item.marca,
              modeloRequerido: item.modelo,
              anioRequerido: item.anio,
              precioAcordado: item.precioAcordado,
              montoAbonado: item.montoAbonado,
              notasPreparacion: item.notas,
            ),
          );
        }
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CartController.instance.removeListener(_sincronizarDesdeCartController);
    _rutFocusNode.removeListener(_onRutFocusChange);
    _rutFocusNode.dispose();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _rutController.dispose();
    _clienteNombresController.dispose();
    _clienteApellidosController.dispose();
    _clienteTelefonoController.dispose();
    _clienteEmailController.dispose();
    _direccionController.dispose();
    _receptorNombresController.dispose();
    _receptorRutController.dispose();
    _receptorTelefonoController.dispose();
    _empresaTransporteController.dispose();
    _montoAbonoController.dispose();
    _notasGeneralesController.dispose();
    super.dispose();
  }

  // ── Búsqueda y Autocompletado Reactivo por RUT ────────────────────────────
  void _onRutFocusChange() {
    if (!_rutFocusNode.hasFocus && !_esClienteAnonimo) {
      _buscarClientePorRut();
    }
  }

  Future<void> _buscarClientePorRut() async {
    final rut = _rutController.text.trim();
    if (rut.length < 7 || _esClienteAnonimo) return;

    setState(() => _isSearchingCliente = true);
    try {
      final res = await OrdenesService.buscarClientePorRut(rut);
      if (!mounted) return;

      setState(() {
        _isSearchingCliente = false;
        if (res != null) {
          _clienteNombresController.text = res['nombres']?.toString() ?? '';
          _clienteApellidosController.text = res['apellidos']?.toString() ?? '';
          if (res['telefono'] != null) {
            _clienteTelefonoController.text = res['telefono'].toString();
          }
          if (res['correo'] != null) {
            _clienteEmailController.text = res['correo'].toString();
          }
          final com = res['comuna']?.toString();
          if (com != null && _comunasDisponibles.contains(com)) {
            _comunaCliente = com;
          }

          final cliente = ClienteWizardModel(
            idCliente: res['id_cliente']?.toString() ?? 'cli-${DateTime.now().millisecondsSinceEpoch}',
            rut: rut,
            nombres: _clienteNombresController.text,
            apellidos: _clienteApellidosController.text,
            telefono: _clienteTelefonoController.text,
            correo: _clienteEmailController.text,
            comuna: _comunaCliente,
            consentimientoLegal: true,
            estado: 'Activo',
          );
          _controller.setCliente(cliente);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppPalette.surface,
              duration: const Duration(seconds: 2),
              content: Text(
                'Cliente frecuente encontrado: ${cliente.nombreCompleto}',
                style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold),
              ),
            ),
          );
        } else {
          _actualizarClienteLocal();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearchingCliente = false);
      _actualizarClienteLocal();
    }
  }

  void _actualizarClienteLocal() {
    final rut = _rutController.text.trim();
    final nom = _clienteNombresController.text.trim();
    final ape = _clienteApellidosController.text.trim();

    if (rut.isNotEmpty && nom.isNotEmpty) {
      final cliente = ClienteWizardModel(
        idCliente: _controller.clienteSeleccionado?.idCliente ?? 'cli-${DateTime.now().millisecondsSinceEpoch}',
        rut: rut,
        nombres: nom,
        apellidos: ape.isNotEmpty ? ape : 'S/A',
        telefono: _clienteTelefonoController.text.trim(),
        correo: _clienteEmailController.text.trim(),
        comuna: _comunaCliente,
        consentimientoLegal: true,
        estado: 'Activo',
      );
      _controller.setCliente(cliente);
    }
  }

  void _toggleClienteAnonimo(bool valor) {
    setState(() {
      _esClienteAnonimo = valor;
      if (valor) {
        _rutController.text = '6.666.666-6';
        _clienteNombresController.text = 'Consumidor';
        _clienteApellidosController.text = 'Final';
        _clienteTelefonoController.clear();
        _clienteEmailController.clear();
        _comunaCliente = 'Viña del Mar';

        _controller.setCliente(
          const ClienteWizardModel(
            idCliente: 'cli-cf',
            rut: '6.666.666-6',
            nombres: 'Consumidor',
            apellidos: 'Final',
            comuna: 'Viña del Mar',
            consentimientoLegal: true,
            estado: 'Activo',
          ),
        );
      } else {
        _rutController.clear();
        _clienteNombresController.clear();
        _clienteApellidosController.clear();
        _clienteTelefonoController.clear();
        _clienteEmailController.clear();
        _controller.setCliente(null);
      }
    });
  }

  // ── Emisión Final Transaccional (ACID) ─────────────────────────────────────
  Future<void> _confirmarYEnviarOrden() async {
    if (_controller.tipoEntrega == 'Despacho Domicilio' || _controller.tipoEntrega == 'Despacho') {
      final d = DespachoModel(
        direccionEnvio: _direccionController.text.trim(),
        receptorNombres: _receptorNombresController.text.trim(),
        receptorRut: _receptorRutController.text.trim(),
        receptorTelefono: _receptorTelefonoController.text.trim(),
        idComunaDestino: _comunasDisponibles.indexOf(_comunaDespacho) + 1,
        comunaNombre: _comunaDespacho,
        empresaTransporte: _empresaTransporteController.text.trim().isNotEmpty
            ? _empresaTransporteController.text.trim()
            : 'Chilexpress',
        tipoEntrega: 'Despacho',
      );
      _controller.setDatosDespacho(d);
    } else if (_controller.tipoEntrega == 'Traslado') {
      final nomDest = _idSucursalDestino == 1 ? 'Viña del Mar' : 'Limache';
      final d = DespachoModel(
        direccionEnvio: 'Traslado a Sucursal $nomDest',
        receptorNombres: _receptorNombresController.text.trim().isNotEmpty
            ? _receptorNombresController.text.trim()
            : (_controller.clienteSeleccionado?.nombreCompleto ?? 'Cliente'),
        receptorRut: _receptorRutController.text.trim().isNotEmpty
            ? _receptorRutController.text.trim()
            : (_controller.clienteSeleccionado?.rut ?? 'S/R'),
        receptorTelefono: _receptorTelefonoController.text.trim().isNotEmpty
            ? _receptorTelefonoController.text.trim()
            : '+56900000000',
        idComunaDestino: _idSucursalDestino,
        comunaNombre: nomDest,
        empresaTransporte: 'Interno',
        tipoEntrega: 'Traslado',
        idSucursalDestino: _idSucursalDestino,
      );
      _controller.setDatosDespacho(d);
      _controller.setIdSucursalDestino(_idSucursalDestino);
    }

    if (_esVendedorOnline && _idVendedorAsignado != null) {
      _controller.setIdVendedorAsignado(_idVendedorAsignado);
    }

    final res = await _controller.submitOrder();
    if (!mounted) return;

    if (res != null) {
      OrdenesSyncNotifier.instance.notificarCambio();
      CartController.instance.vaciarCarrito();
      _controller.clearAll();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppPalette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppPalette.success)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppPalette.success, size: 28),
              const SizedBox(width: 10),
              Text('¡Orden Generada!', style: AppTypography.title.copyWith(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Folio: ${res.folioDisplay}', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Total Venta: \$${res.totalVenta}', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
              Text('Monto Pendiente en Caja: \$${res.montoPendiente}', style: AppTypography.body.copyWith(color: AppPalette.secondary)),
              if (res.reservasGeneradas > 0) ...[
                const SizedBox(height: 6),
                Text('• ${res.reservasGeneradas} venta(s) en verde generadas por encargo.', style: AppTypography.small.copyWith(color: AppPalette.success)),
              ],
              if (res.despachoGenerado) ...[
                const SizedBox(height: 4),
                Text('• Solicitud de despacho / traslado registrada.', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary),
              onPressed: () {
                Navigator.of(ctx).pop();
                if (widget.onNavigateToCatalogo != null) {
                  widget.onNavigateToCatalogo!();
                } else if (Navigator.canPop(context)) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('FINALIZAR Y VOLVER'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        leading: widget.onOpenMenuDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenuDrawer,
                tooltip: 'Abrir Menú',
              )
            : (Navigator.canPop(context) ? const BackButton() : null),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checkout Transaccional', style: AppTypography.title.copyWith(fontSize: 18)),
            Text('Flujo Secuencial de 5 Pasos • Ventas y Ventas en Verde', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontSize: 12)),
          ],
        ),
        actions: [
          if (_controller.totalItemsCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppPalette.error),
              tooltip: 'Vaciar Carrito',
              onPressed: () {
                CartController.instance.vaciarCarrito();
                _controller.clearAll();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Barra superior de progreso de pasos
          _buildStepProgressBar(),

          if (_controller.errorMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppPalette.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppPalette.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_controller.errorMessage!, style: const TextStyle(color: AppPalette.error, fontSize: 12))),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStepContent(),
            ),
          ),

          _buildBottomNavigationButtons(),
        ],
      ),
    );
  }

  // ── Stepper Bar ───────────────────────────────────────────────────────────
  Widget _buildStepProgressBar() {
    final stepLabels = ['Ítems & Reservas', 'Cliente CRM', 'Logística', 'Abonos / Notas', 'Confirmación'];

    return Container(
      color: AppPalette.surface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(5, (index) {
          final isCompleted = index < _controller.currentStep;
          final isCurrent = index == _controller.currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? AppPalette.primary
                              : isCompleted
                                  ? AppPalette.success
                                  : AppPalette.background,
                          border: Border.all(
                            color: isCurrent
                                ? AppPalette.primary
                                : isCompleted
                                    ? AppPalette.success
                                    : Colors.white24,
                          ),
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCurrent ? AppPalette.textPrimary : AppPalette.textSecondary)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stepLabels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? AppPalette.primary : AppPalette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (index < 4)
                  Container(
                    width: 12,
                    height: 2,
                    color: index < _controller.currentStep ? AppPalette.success : Colors.white12,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_controller.currentStep) {
      case 0:
        return _buildStep1Items();
      case 1:
        return _buildStep2Cliente();
      case 2:
        return _buildStep3Logistica();
      case 3:
        return _buildStep4Condiciones();
      case 4:
      default:
        return _buildStep5Confirmacion();
    }
  }

  // ── PASO 1: ÍTEMS & RESERVAS ──────────────────────────────────────────────
  Widget _buildStep1Items() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '1. Selección de Repuestos y Encargos',
                style: AppTypography.title.copyWith(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('${_controller.totalItemsCount} artículos (\$${_controller.totalVenta})', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.secondary,
                  foregroundColor: AppPalette.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.bookmark_add, size: 20),
                label: const Text(
                  'Venta en Verde',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () async {
                  final reserva = await ModalBackorderForm.mostrar(context);
                  if (reserva != null) {
                    _controller.addReservaBackorder(reserva);
                    CartController.instance.agregarReservaBackorder(
                      idCategoria: reserva.idCategoriaRequerida,
                      categoriaNombre: reserva.categoriaNombre,
                      marca: reserva.marcaRequerida,
                      modelo: reserva.modeloRequerido,
                      anio: reserva.anioRequerido,
                      precioAcordado: reserva.precioAcordado,
                      montoAbonado: reserva.montoAbonado,
                      notas: reserva.notasPreparacion,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.primary,
                  side: const BorderSide(color: AppPalette.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.edit_note, size: 20),
                label: const Text(
                  '+ Ítem Manual',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _abrirDialogoItemManual,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_controller.totalItemsCount == 0)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: AppPalette.textSecondary, size: 48),
                const SizedBox(height: 10),
                Text('El carrito está actualmente vacío', style: AppTypography.title.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text('Añada productos desde el Catálogo, cargue ítems manuales o cree una Reserva por Encargo (Compra en Verde).', style: AppTypography.small.copyWith(color: AppPalette.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (widget.onNavigateToCatalogo != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    icon: const Icon(Icons.storefront, size: 18),
                    label: const Text('IR AL CATÁLOGO DE REPUESTOS'),
                    onPressed: widget.onNavigateToCatalogo,
                  ),
              ],
            ),
          )
        else ...[
          if (_controller.itemsInventariados.isNotEmpty) ...[
            Text('REPUESTOS EN INVENTARIO (${_controller.itemsInventariados.length})', style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ..._controller.itemsInventariados.map((item) {
              return Card(
                color: AppPalette.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined, color: AppPalette.primary),
                  title: Text(item['descripcion'] ?? 'Repuesto', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('SKU: ${item['sku']} • Pasillo: ${item['pasillo'] ?? 'S/P'}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${item['precio']}', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, color: AppPalette.primary)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppPalette.error, size: 20),
                        onPressed: () {
                          _controller.removeItemInventariado(item['id_activo']);
                          CartController.instance.eliminarItem(item['id_activo']);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          if (_controller.reservas.isNotEmpty) ...[
            Text('VENTAS EN VERDE (${_controller.reservas.length})', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ..._controller.reservas.asMap().entries.map((entry) {
              final idx = entry.key;
              final r = entry.value;
              return Card(
                color: AppPalette.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppPalette.secondary, width: 1)),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.bookmark_added_rounded, color: AppPalette.secondary),
                  title: Text('${r.categoriaNombre} - ${r.marcaRequerida} ${r.modeloRequerido}', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Precio: \$${r.precioAcordado} • Abono: \$${r.montoAbonado}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppPalette.error, size: 20),
                    onPressed: () => _controller.removeReservaBackorder(idx),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          if (_controller.itemsManuales.isNotEmpty) ...[
            Text('ÍTEMS MANUALES (${_controller.itemsManuales.length})', style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ..._controller.itemsManuales.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value;
              return Card(
                color: AppPalette.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.edit_note, color: Colors.white70),
                  title: Text(m.descripcion, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Cantidad: ${m.cantidad} • Unit: \$${m.precioUnitario}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('\$${m.precioFinal}', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppPalette.error, size: 20),
                        onPressed: () => _controller.removeItemManual(idx),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  // ── PASO 2: CLIENTE CRM UNIFICADO CON CONSUMIDOR FINAL ────────────────────
  // ── PASO 2: CLIENTE CRM UNIFICADO CON CONSUMIDOR FINAL ────────────────────
  Widget _buildStep2Cliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2. Datos del Cliente (Micro-CRM)', style: AppTypography.title.copyWith(fontSize: 16)),
        const SizedBox(height: 12),

        // Botón Interactivo Consumidor Final (Sin RUT) - Clickable en toda el área
        Material(
          color: _esClienteAnonimo ? AppPalette.secondary.withValues(alpha: 0.15) : AppPalette.surface,
          borderRadius: BorderRadius.circular(10.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(10.0),
            onTap: () => _toggleClienteAnonimo(!_esClienteAnonimo),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: _esClienteAnonimo ? AppPalette.secondary : Colors.white12,
                  width: _esClienteAnonimo ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.no_accounts_outlined,
                          size: 22,
                          color: _esClienteAnonimo ? AppPalette.secondary : AppPalette.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Consumidor Final (Sin RUT)',
                                style: AppTypography.body.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _esClienteAnonimo ? AppPalette.secondary : AppPalette.textPrimary,
                                ),
                              ),
                              Text(
                                'Toca aquí para venta rápida sin registrar datos',
                                style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    key: const Key('switch_cliente_anonimo'),
                    value: _esClienteAnonimo,
                    activeThumbColor: AppPalette.secondary,
                    onChanged: (val) => _toggleClienteAnonimo(val),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_esClienteAnonimo) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: AppPalette.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppPalette.secondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aviso: La orden se asignará al cliente Consumidor Final (RUT 6.666.666-6). El cliente solo podrá pagar y retirar en caja presentando su Número de Orden.',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Formulario Unificado de Cliente
          Builder(
            builder: (context) {
              final rutText = _rutController.text.trim();
              final bool rutInvalido = !_esClienteAnonimo &&
                  rutText.isNotEmpty &&
                  !RutValidator.isValid(rutText);
              final String? rutError = rutInvalido
                  ? 'RUT inválido. Verifique el número ingresado.'
                  : null;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('input_rut_cliente'),
                            controller: _rutController,
                            focusNode: _rutFocusNode,
                            style: AppTypography.body,
                            inputFormatters: [RutFormatter()],
                            decoration: _inputDeco(
                              'RUT Cliente (ej: 12.345.678-9) *',
                              Icons.badge_outlined,
                              errorText: rutError,
                              suffix: _isSearchingCliente
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppPalette.primary))
                                  : IconButton(
                                      icon: const Icon(Icons.search,
                                          color: AppPalette.primary, size: 20),
                                      tooltip: 'Buscar por RUT',
                                      onPressed: _buscarClientePorRut,
                                    ),
                            ),
                            onChanged: (val) {
                              setState(() {});
                              _actualizarClienteLocal();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('input_cliente_nombres'),
                            controller: _clienteNombresController,
                            style: AppTypography.body,
                            decoration: _inputDeco('Nombres *', Icons.person),
                            onChanged: (val) {
                              setState(() {});
                              _actualizarClienteLocal();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: const Key('input_cliente_apellidos'),
                            controller: _clienteApellidosController,
                            style: AppTypography.body,
                            decoration: _inputDeco('Apellidos *', Icons.person_outline),
                            onChanged: (val) => _actualizarClienteLocal(),
                          ),
                        ),
                      ],
                    ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _clienteTelefonoController,
                        style: AppTypography.body,
                        keyboardType: TextInputType.phone,
                        decoration: _inputDeco('Teléfono (+569...)', Icons.phone),
                        onChanged: (val) => _actualizarClienteLocal(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _comunaCliente,
                        dropdownColor: AppPalette.surface,
                        style: AppTypography.body,
                        decoration: _inputDeco('Comuna', Icons.location_city),
                        items: _comunasDisponibles.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _comunaCliente = val);
                            _actualizarClienteLocal();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _clienteEmailController,
                  style: AppTypography.body,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDeco('Correo Electrónico (Opcional)', Icons.email_outlined),
                  onChanged: (val) => _actualizarClienteLocal(),
                ),
              ],
            ),
          );
        },
      ),
        ],
      ],
    );
  }

  // ── PASO 3: LOGÍSTICA (RETIRO / DESPACHO / TRASLADO) ──────────────────────
  Widget _buildStep3Logistica() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('3. Modalidad de Entrega y Despacho', style: AppTypography.title.copyWith(fontSize: 16)),
        const SizedBox(height: 14),

        // Selector de 3 Opciones: Retiro, Despacho, Traslado
        Row(
          children: [
            _buildDeliveryChoice('Retiro en Tienda', 'Retiro', Icons.storefront_outlined),
            const SizedBox(width: 8),
            _buildDeliveryChoice('Despacho Domicilio', 'Despacho Domicilio', Icons.local_shipping_outlined),
            const SizedBox(width: 8),
            _buildDeliveryChoice('Traslado Sucursal', 'Traslado', Icons.sync_alt_outlined),
          ],
        ),
        const SizedBox(height: 16),

        if (_controller.tipoEntrega == 'Retiro') ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppPalette.success, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Retiro en Mesón de Sucursal', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                      Text('El cliente retira los repuestos físicos directamente en el mesón tras completar el pago o abono.', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (_controller.tipoEntrega == 'Despacho Domicilio' || _controller.tipoEntrega == 'Despacho') ...[
          Builder(
            builder: (context) {
              final receptorRutText = _receptorRutController.text.trim();
              final bool receptorRutInvalido = receptorRutText.isNotEmpty &&
                  !RutValidator.isValid(receptorRutText);
              final String? receptorRutError = receptorRutInvalido
                  ? 'RUT inválido. Verifique el número ingresado.'
                  : null;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos del Receptor y Dirección de Envío:', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _direccionController,
                      style: AppTypography.body,
                      decoration: _inputDeco('Dirección de entrega (Calle, Número, Depto) *', Icons.home_outlined),
                      onChanged: (val) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _comunaDespacho,
                      dropdownColor: AppPalette.surface,
                      style: AppTypography.body,
                      decoration: _inputDeco('Comuna Destino *', Icons.map),
                      items: _comunasDisponibles.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (val) => setState(() => _comunaDespacho = val ?? 'Viña del Mar'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _empresaTransporteController,
                      style: AppTypography.body,
                      decoration: _inputDeco('Empresa de Transporte *', Icons.local_shipping),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('input_receptor_rut'),
                      controller: _receptorRutController,
                      style: AppTypography.body,
                      inputFormatters: [RutFormatter()],
                      decoration: _inputDeco(
                        'RUT Receptor *',
                        Icons.badge,
                        errorText: receptorRutError,
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _receptorNombresController,
                      style: AppTypography.body,
                      decoration: _inputDeco('Nombre Receptor *', Icons.person),
                      onChanged: (val) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _receptorTelefonoController,
                      keyboardType: TextInputType.phone,
                      style: AppTypography.body,
                      decoration: _inputDeco('Teléfono Receptor *', Icons.phone),
                    ),
                  ],
                ),
              );
            },
          ),
        ] else if (_controller.tipoEntrega == 'Traslado') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configuración de Traslado Inter-Sucursal:', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _idSucursalDestino,
                  dropdownColor: AppPalette.surface,
                  style: AppTypography.body,
                  decoration: _inputDeco('Sucursal de Destino *', Icons.swap_horiz),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Sucursal Viña del Mar', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 2, child: Text('Sucursal Limache', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setState(() => _idSucursalDestino = val ?? 1),
                ),
                const SizedBox(height: 10),
                Text(
                  'ℹ️ Se generará automáticamente la orden de traslado logístico para que Bodega envíe la pieza a ${_idSucursalDestino == 1 ? "Viña del Mar" : "Limache"}.',
                  style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(controller: _receptorRutController, style: AppTypography.body, decoration: _inputDeco('RUT quien retira en destino (Opcional)', Icons.badge)),
                const SizedBox(height: 10),
                TextField(controller: _receptorNombresController, style: AppTypography.body, decoration: _inputDeco('Nombre quien retira (Opcional)', Icons.person)),
              ],
            ),
          ),
        ],

        if (_esVendedorOnline) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Responsable de Entrega en Sucursal (Venta Online)', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.secondary)),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _idVendedorAsignado,
                    dropdownColor: AppPalette.surface,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: AppPalette.primary),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Mesón General (Cualquier vendedor)'),
                      ),
                      ..._vendedoresDisponibles.map(
                        (v) => DropdownMenuItem<String?>(
                          value: v.idUsuario,
                          child: Text('Vendedor: ${v.nombreCompleto} (${v.rut})'),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _idVendedorAsignado = val),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeliveryChoice(String label, String value, IconData icon) {
    final isSelected = _controller.tipoEntrega == value;
    return Expanded(
      child: Material(
        color: isSelected ? AppPalette.primary.withValues(alpha: 0.18) : AppPalette.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _controller.setTipoEntrega(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? AppPalette.primary : Colors.white12, width: isSelected ? 1.5 : 1),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: isSelected ? AppPalette.primary : AppPalette.textSecondary),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppPalette.textPrimary : AppPalette.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── PASO 4: CONDICIONES COMERCIALES & ABONOS ──────────────────────────────
  Widget _buildStep4Condiciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('4. Condiciones Comerciales y Abonos', style: AppTypography.title.copyWith(fontSize: 16)),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              _buildResumenRow('Subtotal Repuestos Inventario:', '\$${_controller.subtotalInventario}'),
              _buildResumenRow('Subtotal Ítems Manuales:', '\$${_controller.subtotalManuales}'),
              _buildResumenRow('Subtotal Ventas en Verde:', '\$${_controller.subtotalReservas}'),
              const Divider(color: Colors.white24, height: 20),
              _buildResumenRow('TOTAL DE LA VENTA:', '\$${_controller.totalVenta}', isBold: true, color: AppPalette.primary),
              const SizedBox(height: 8),
              _buildResumenRow('Total Abonos Acordados:', '\$${_controller.totalAbonos}', color: AppPalette.success),
              _buildResumenRow('Saldo Pendiente a Cobrar en Caja:', '\$${_controller.montoPendiente}', isBold: true, color: AppPalette.secondary),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Campo de Abono / Anticipo Editable
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Monto de Abono / Anticipo Inicial (\$):', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _montoAbonoController,
                keyboardType: TextInputType.number,
                style: AppTypography.body,
                decoration: _inputDeco('Ej: 50000 (Dejar vacío o 0 para pagar total en caja)', Icons.payments_outlined),
                onChanged: (val) {
                  final ab = int.tryParse(val.trim()) ?? 0;
                  _controller.setAbonoAdicional(ab);
                },
              ),
              const SizedBox(height: 6),
              Text(
                _controller.totalAbonos == 0
                    ? 'ℹ️ El cliente liquidará el 100% de la orden en Caja.'
                    : 'ℹ️ El cliente abonará \$${_controller.totalAbonos} y quedará un saldo de \$${_controller.montoPendiente} en Caja.',
                style: AppTypography.small.copyWith(color: AppPalette.secondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('Instrucciones Generales de Preparación / Bodega:', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _notasGeneralesController,
          maxLines: 2,
          style: AppTypography.body,
          decoration: _inputDeco('Ej: Revisar empaque, coordinar con chofer de ruta...', Icons.notes),
          onChanged: (val) => _controller.setNotasGenerales(val),
        ),
      ],
    );
  }

  // ── PASO 5: CONFIRMACIÓN Y EMISIÓN ────────────────────────────────────────
  Widget _buildStep5Confirmacion() {
    final cli = _controller.clienteSeleccionado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('5. Revisión Final y Emisión de Orden', style: AppTypography.title.copyWith(fontSize: 16)),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RESUMEN DE CLIENTE & ENTREGA', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Cliente: ${cli?.nombreCompleto ?? "Consumidor Final"} (${cli?.rut ?? "6.666.666-6"})', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
              Text('Modalidad: ${_controller.tipoEntrega}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
              if (_controller.tipoEntrega == 'Despacho Domicilio' && _controller.datosDespacho != null)
                Text('Destino: ${_controller.datosDespacho!.direccionEnvio} • Receptor: ${_controller.datosDespacho!.receptorNombres}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
              if (_controller.tipoEntrega == 'Traslado')
                Text('Traslado a: ${_idSucursalDestino == 1 ? "Viña del Mar" : "Limache"}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
              const Divider(color: Colors.white24, height: 20),

              Text('DETALLE COMERCIAL', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('• Total Artículos: ${_controller.totalItemsCount}', style: AppTypography.body),
              Text('• Total Venta: \$${_controller.totalVenta}', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, color: AppPalette.primary)),
              Text('• Abono Acordado: \$${_controller.totalAbonos}', style: AppTypography.body.copyWith(color: AppPalette.success)),
              Text('• Saldo a Pagar en Caja: \$${_controller.montoPendiente}', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, color: AppPalette.secondary)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: _controller.isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 22),
            label: Text(_controller.isLoading ? 'Emitiendo Orden...' : 'CONFIRMAR Y EMITIR ORDEN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            onPressed: _controller.isLoading ? null : _confirmarYEnviarOrden,
          ),
        ),
      ],
    );
  }

  Widget _buildResumenRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppPalette.textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color ?? AppPalette.textPrimary, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: isBold ? 15 : 13)),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationButtons() {
    final bool puedeAvanzar;
    if (_controller.currentStep == 1) {
      if (_esClienteAnonimo) {
        puedeAvanzar = true;
      } else {
        final rut = _rutController.text.trim();
        final nom = _clienteNombresController.text.trim();
        puedeAvanzar =
            rut.isNotEmpty && nom.isNotEmpty && RutValidator.isValid(rut);
      }
    } else if (_controller.currentStep == 2) {
      if (_controller.tipoEntrega == 'Despacho Domicilio' ||
          _controller.tipoEntrega == 'Despacho') {
        final rRut = _receptorRutController.text.trim();
        final dir = _direccionController.text.trim();
        final rNom = _receptorNombresController.text.trim();
        puedeAvanzar = dir.isNotEmpty &&
            rNom.isNotEmpty &&
            rRut.isNotEmpty &&
            RutValidator.isValid(rRut);
      } else {
        puedeAvanzar = true;
      }
    } else {
      puedeAvanzar = true;
    }

    return Container(
      color: AppPalette.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_controller.currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.textSecondary,
                    side: const BorderSide(color: Colors.white24)),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Anterior', overflow: TextOverflow.ellipsis),
                onPressed: _controller.isLoading ? null : _controller.previousStep,
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: 12),

          if (_controller.currentStep < 4)
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('btn_siguiente_wizard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: AppPalette.textPrimary,
                  disabledBackgroundColor: AppPalette.surface,
                  disabledForegroundColor: AppPalette.textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Siguiente', overflow: TextOverflow.ellipsis),
              onPressed: puedeAvanzar
                  ? () {
                      if (_controller.currentStep == 1) {
                        if (_esClienteAnonimo) {
                          _controller.setCliente(
                            const ClienteWizardModel(
                              idCliente: 'cli-cf',
                              rut: '6.666.666-6',
                              nombres: 'Consumidor',
                              apellidos: 'Final',
                              comuna: 'Viña del Mar',
                              consentimientoLegal: true,
                              estado: 'Activo',
                            ),
                          );
                        } else {
                          _actualizarClienteLocal();
                        }
                      }
                      _controller.nextStep();
                    }
                  : null,
              ),
            ),
        ],
      ),
    );
  }

  void _abrirDialogoItemManual() {
    final descCtrl = TextEditingController();
    final cantCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        title: Text('Añadir Ítem Manual', style: AppTypography.title.copyWith(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descCtrl, style: AppTypography.body, decoration: _inputDeco('Descripción del ítem', Icons.edit)),
            const SizedBox(height: 10),
            TextField(controller: cantCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: AppTypography.body, decoration: _inputDeco('Cantidad', Icons.numbers)),
            const SizedBox(height: 10),
            TextField(controller: precioCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], style: AppTypography.body, decoration: _inputDeco('Precio Unitario (\$)', Icons.attach_money)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.secondary, foregroundColor: AppPalette.background),
            onPressed: () {
              final desc = descCtrl.text.trim();
              final cantParsed = int.tryParse(cantCtrl.text.trim());
              final cant = (cantParsed != null && cantParsed > 0) ? cantParsed : 1;
              final precio = int.tryParse(precioCtrl.text.trim()) ?? 0;
              if (desc.isNotEmpty && precio > 0) {
                _controller.addItemManual(ItemManualModel(descripcion: desc, cantidad: cant, precioUnitario: precio, precioFinal: precio * cant));
                CartController.instance.agregarVentaLibre(descripcion: desc, monto: precio, cantidad: cant);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon, {Widget? suffix, String? errorText}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppPalette.primary, size: 18),
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      suffixIcon: suffix,
      errorText: errorText,
      errorStyle: const TextStyle(color: AppPalette.error, fontSize: 11, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: AppPalette.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppPalette.error, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppPalette.error, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppPalette.primary, width: 1.5)),
    );
  }
}
