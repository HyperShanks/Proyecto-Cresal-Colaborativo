import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/checkout_wizard_models.dart';
import '../../controllers/checkout_wizard_controller.dart';
import '../../services/ordenes_service.dart';
import '../widgets/modal_backorder_form.dart';

/// Pantalla Principal del Checkout Wizard por 5 Pasos Secuenciales (SPEC-HU-05)
class CheckoutWizardScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialInventario;
  final List<ItemManualModel>? initialManuales;

  const CheckoutWizardScreen({
    super.key,
    this.initialInventario,
    this.initialManuales,
  });

  @override
  State<CheckoutWizardScreen> createState() => _CheckoutWizardScreenState();
}

class _CheckoutWizardScreenState extends State<CheckoutWizardScreen> {
  final CheckoutWizardController _controller = CheckoutWizardController();

  // Controladores Paso 2 (Cliente)
  final _rutSearchController = TextEditingController();
  final _clienteNombresController = TextEditingController();
  final _clienteApellidosController = TextEditingController();
  final _clienteTelefonoController = TextEditingController();
  final _clienteEmailController = TextEditingController();
  bool _isSearchingCliente = false;
  bool _isNuevoClienteForm = false;

  // Controladores Paso 3 (Despacho)
  final _direccionController = TextEditingController();
  final _receptorNombresController = TextEditingController();
  final _receptorRutController = TextEditingController();
  final _receptorTelefonoController = TextEditingController();
  int _comunaId = 1;

  // Controladores Paso 4 (Comercial / Abono)
  final _abonoAdicionalController = TextEditingController();
  final _notasGeneralesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);

    // Cargar ítems iniciales si se pasan desde el carrito
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

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _rutSearchController.dispose();
    _clienteNombresController.dispose();
    _clienteApellidosController.dispose();
    _clienteTelefonoController.dispose();
    _clienteEmailController.dispose();
    _direccionController.dispose();
    _receptorNombresController.dispose();
    _receptorRutController.dispose();
    _receptorTelefonoController.dispose();
    _abonoAdicionalController.dispose();
    _notasGeneralesController.dispose();
    super.dispose();
  }

  // ── Helper Buscar Cliente ──────────────────────────────────────────────────
  Future<void> _buscarClientePorRut() async {
    final rut = _rutSearchController.text.trim();
    if (rut.isEmpty) return;

    setState(() => _isSearchingCliente = true);
    try {
      final res = await OrdenesService.buscarClientePorRut(rut);
      if (!mounted) return;

      setState(() {
        _isSearchingCliente = false;
        if (res != null) {
          final cliente = ClienteWizardModel.fromJson(res);
          _controller.setCliente(cliente);
          _isNuevoClienteForm = false;
        } else {
          _isNuevoClienteForm = true;
          _clienteNombresController.clear();
          _clienteApellidosController.clear();
          _clienteTelefonoController.clear();
          _clienteEmailController.clear();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearchingCliente = false;
        _isNuevoClienteForm = true;
      });
    }
  }

  void _guardarNuevoClienteLocal() {
    final rut = _rutSearchController.text.trim();
    final nom = _clienteNombresController.text.trim();
    final ape = _clienteApellidosController.text.trim();
    final tel = _clienteTelefonoController.text.trim();
    final mail = _clienteEmailController.text.trim();

    if (rut.isEmpty || nom.isEmpty || ape.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RUT, Nombres y Apellidos son obligatorios.')),
      );
      return;
    }

    final cliente = ClienteWizardModel(
      idCliente: 'cli-${DateTime.now().millisecondsSinceEpoch}',
      rut: rut,
      nombres: nom,
      apellidos: ape,
      telefono: tel,
      correo: mail,
      consentimientoLegal: true,
      estado: 'Activo',
    );

    _controller.setCliente(cliente);
    setState(() => _isNuevoClienteForm = false);
  }

  // ── Emisión Final ──────────────────────────────────────────────────────────
  Future<void> _confirmarYEnviarOrden() async {
    // Sincronizar datos finales de despacho si aplica
    if (_controller.tipoEntrega == 'Despacho Domicilio') {
      final d = DespachoModel(
        direccionEnvio: _direccionController.text.trim(),
        receptorNombres: _receptorNombresController.text.trim(),
        receptorRut: _receptorRutController.text.trim(),
        receptorTelefono: _receptorTelefonoController.text.trim(),
        idComunaDestino: _comunaId,
        empresaTransporte: 'Por Asignar',
      );
      _controller.setDatosDespacho(d);
    }

    final res = await _controller.submitOrder();
    if (!mounted) return;

    if (res != null) {
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
              Text('ID Orden: ${res.idOrden}', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Total Venta: \$${res.totalVenta}', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
              Text('Monto Pendiente en Caja: \$${res.montoPendiente}', style: AppTypography.body.copyWith(color: AppPalette.secondary)),
              if (res.reservasGeneradas > 0) ...[
                const SizedBox(height: 6),
                Text('• ${res.reservasGeneradas} reserva(s) por encargo generadas en backorder.', style: AppTypography.small.copyWith(color: AppPalette.success)),
              ],
              if (res.despachoGenerado) ...[
                const SizedBox(height: 4),
                Text('• Solicitud de despacho a domicilio registrada.', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checkout Transaccional', style: AppTypography.title.copyWith(fontSize: 18)),
            Text('Wizard de 5 Pasos • Ventas y Backorders', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra superior de progreso de pasos
          _buildStepProgressBar(),

          // Mensaje de error general si ocurre
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

          // Contenido modular del paso actual
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStepContent(),
            ),
          ),

          // Barra inferior de navegación
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

  // ── Contenido según Paso ──────────────────────────────────────────────────
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
            Text('1. Selección de Repuestos y Encargos', style: AppTypography.title.copyWith(fontSize: 16)),
            Text('${_controller.totalItemsCount} artículos', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),

        // Botones para añadir Ítems Manuales o Reservas por Encargo
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppPalette.primary, side: const BorderSide(color: AppPalette.primary)),
                icon: const Icon(Icons.bookmark_add, size: 18),
                label: const Text('Reserva Backorder', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final reserva = await ModalBackorderForm.mostrar(context);
                  if (reserva != null) {
                    _controller.addReservaBackorder(reserva);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppPalette.secondary, side: const BorderSide(color: AppPalette.secondary)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ítem Manual', style: TextStyle(fontWeight: FontWeight.bold)),
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
                Text('El carrito está vacío', style: AppTypography.title.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text('Añada productos de inventario, ítems manuales o reservas por encargo.', style: AppTypography.small.copyWith(color: AppPalette.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          )
        else ...[
          // Repuestos de Inventario
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
                        onPressed: () => _controller.removeItemInventariado(item['id_activo']),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Reservas Backorder
          if (_controller.reservas.isNotEmpty) ...[
            Text('RESERVAS POR ENCARGO / BACKORDER (${_controller.reservas.length})', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold)),
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

          // Ítems Manuales
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

  // ── PASO 2: CLIENTE CRM ───────────────────────────────────────────────────
  Widget _buildStep2Cliente() {
    final cli = _controller.clienteSeleccionado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2. Selección y Validación de Cliente CRM', style: AppTypography.title.copyWith(fontSize: 16)),
        const SizedBox(height: 12),

        // Buscador por RUT
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rutSearchController,
                style: AppTypography.body,
                decoration: _inputDeco('Ingrese RUT del Cliente (ej: 19.999.888-7)', Icons.badge_outlined),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              icon: _isSearchingCliente
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, size: 18),
              label: const Text('Buscar'),
              onPressed: _isSearchingCliente ? null : _buscarClientePorRut,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tarjeta de Cliente Seleccionado
        if (cli != null && !_isNuevoClienteForm) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.success, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CLIENTE ASIGNADO', style: AppTypography.small.copyWith(color: AppPalette.success, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: AppPalette.primary),
                      onPressed: () => setState(() => _isNuevoClienteForm = true),
                    ),
                  ],
                ),
                Text(cli.nombreCompleto, style: AppTypography.title.copyWith(fontSize: 16)),
                Text('RUT: ${cli.rut} • Tel: ${cli.telefono ?? 'Sin teléfono'}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                Text('Email: ${cli.correo ?? 'Sin correo'}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
              ],
            ),
          ),
        ],

        // Formulario de nuevo cliente si no existe
        if (_isNuevoClienteForm || cli == null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registrar Datos de Cliente:', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(controller: _clienteNombresController, style: AppTypography.body, decoration: _inputDeco('Nombres *', Icons.person)),
                const SizedBox(height: 10),
                TextField(controller: _clienteApellidosController, style: AppTypography.body, decoration: _inputDeco('Apellidos *', Icons.person_outline)),
                const SizedBox(height: 10),
                TextField(controller: _clienteTelefonoController, style: AppTypography.body, decoration: _inputDeco('Teléfono (+569...)', Icons.phone)),
                const SizedBox(height: 10),
                TextField(controller: _clienteEmailController, style: AppTypography.body, decoration: _inputDeco('Correo Electrónico', Icons.email_outlined)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppPalette.success),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Asignar Cliente a la Orden'),
                  onPressed: _guardarNuevoClienteLocal,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── PASO 3: LOGÍSTICA & DESPACHO ──────────────────────────────────────────
  Widget _buildStep3Logistica() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('3. Modalidad de Entrega y Despacho', style: AppTypography.title.copyWith(fontSize: 16)),
        const SizedBox(height: 14),

        // Selector de tipo de entrega
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Retiro en Tienda', style: TextStyle(fontWeight: FontWeight.bold))),
                selected: _controller.tipoEntrega == 'Retiro',
                selectedColor: AppPalette.primary,
                backgroundColor: AppPalette.surface,
                onSelected: (val) {
                  if (val) _controller.setTipoEntrega('Retiro');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Despacho a Domicilio', style: TextStyle(fontWeight: FontWeight.bold))),
                selected: _controller.tipoEntrega == 'Despacho Domicilio',
                selectedColor: AppPalette.secondary,
                backgroundColor: AppPalette.surface,
                onSelected: (val) {
                  if (val) _controller.setTipoEntrega('Despacho Domicilio');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_controller.tipoEntrega == 'Despacho Domicilio') ...[
          Container(
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
                TextField(controller: _direccionController, style: AppTypography.body, decoration: _inputDeco('Dirección de entrega (Calle, Número, Depto) *', Icons.home_outlined)),
                const SizedBox(height: 10),
                TextField(controller: _receptorNombresController, style: AppTypography.body, decoration: _inputDeco('Nombre de quien recibe *', Icons.person)),
                const SizedBox(height: 10),
                TextField(controller: _receptorRutController, style: AppTypography.body, decoration: _inputDeco('RUT del Receptor *', Icons.badge)),
                const SizedBox(height: 10),
                TextField(controller: _receptorTelefonoController, style: AppTypography.body, decoration: _inputDeco('Teléfono de contacto *', Icons.phone)),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _comunaId,
                  dropdownColor: AppPalette.surface,
                  style: AppTypography.body,
                  decoration: _inputDeco('Comuna de Destino', Icons.map),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Viña del Mar')),
                    DropdownMenuItem(value: 2, child: Text('Valparaíso')),
                    DropdownMenuItem(value: 3, child: Text('Concón')),
                    DropdownMenuItem(value: 4, child: Text('Quilpué')),
                    DropdownMenuItem(value: 5, child: Text('Villa Alemana')),
                    DropdownMenuItem(value: 6, child: Text('Santiago')),
                  ],
                  onChanged: (val) => setState(() => _comunaId = val ?? 1),
                ),
              ],
            ),
          ),
        ] else ...[
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
                      Text('El cliente retira los repuestos físicos directamente en caja/mostrador.', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── PASO 4: CONDICIONES COMERCIALES & ABONOS ──────────────────────────────
  Widget _buildStep4Condiciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('4. Condiciones Comerciales y Abonos', style: AppTypography.title.copyWith(fontSize: 16)),
        const SizedBox(height: 14),

        // Resumen Financiero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              _buildResumenRow('Subtotal Repuestos Inventario:', '\$${_controller.subtotalInventario}'),
              _buildResumenRow('Subtotal Ítems Manuales:', '\$${_controller.subtotalManuales}'),
              _buildResumenRow('Subtotal Reservas Backorder:', '\$${_controller.subtotalReservas}'),
              const Divider(color: Colors.white24, height: 20),
              _buildResumenRow('TOTAL DE LA VENTA:', '\$${_controller.totalVenta}', isBold: true, color: AppPalette.primary),
              const SizedBox(height: 8),
              _buildResumenRow('Abonos Compra en Verde (Backorder):', '\$${_controller.abonoReservas}', color: AppPalette.success),
              _buildResumenRow('Saldo Pendiente a Cobrar en Caja:', '\$${_controller.montoPendiente}', isBold: true, color: AppPalette.secondary),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Notas Técnicas Generales para Bodega
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
              Text('Cliente: ${cli?.nombreCompleto ?? "No seleccionado"} (${cli?.rut ?? ""})', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
              Text('Modalidad: ${_controller.tipoEntrega}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
              if (_controller.tipoEntrega == 'Despacho Domicilio' && _controller.datosDespacho != null)
                Text('Destino: ${_controller.datosDespacho!.direccionEnvio} • Receptor: ${_controller.datosDespacho!.receptorNombres}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
              const Divider(color: Colors.white24, height: 20),

              Text('DETALLE COMERCIAL', style: AppTypography.small.copyWith(color: AppPalette.secondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('• Total Artículos: ${_controller.totalItemsCount}', style: AppTypography.body),
              Text('• Total Venta: \$${_controller.totalVenta}', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, color: AppPalette.primary)),
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

  // ── Botones de Navegación ─────────────────────────────────────────────────
  Widget _buildBottomNavigationButtons() {
    return Container(
      color: AppPalette.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_controller.currentStep > 0)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppPalette.textSecondary, side: const BorderSide(color: Colors.white24)),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Anterior'),
              onPressed: _controller.isLoading ? null : _controller.previousStep,
            )
          else
            const SizedBox(width: 100),

          if (_controller.currentStep < 4)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary, foregroundColor: AppPalette.textPrimary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Siguiente'),
              onPressed: _controller.nextStep,
            ),
        ],
      ),
    );
  }

  void _abrirDialogoItemManual() {
    final descCtrl = TextEditingController();
    final cantCtrl = TextEditingController(text: '1');
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
            TextField(controller: cantCtrl, keyboardType: TextInputType.number, style: AppTypography.body, decoration: _inputDeco('Cantidad', Icons.numbers)),
            const SizedBox(height: 10),
            TextField(controller: precioCtrl, keyboardType: TextInputType.number, style: AppTypography.body, decoration: _inputDeco('Precio Unitario (\$)', Icons.attach_money)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.secondary, foregroundColor: AppPalette.background),
            onPressed: () {
              final desc = descCtrl.text.trim();
              final cant = int.tryParse(cantCtrl.text) ?? 1;
              final precio = int.tryParse(precioCtrl.text) ?? 0;
              if (desc.isNotEmpty && precio > 0) {
                _controller.addItemManual(ItemManualModel(descripcion: desc, cantidad: cant, precioUnitario: precio, precioFinal: precio * cant));
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.small.copyWith(color: AppPalette.textSecondary),
      prefixIcon: Icon(icon, color: AppPalette.primary, size: 20),
      filled: true,
      fillColor: AppPalette.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppPalette.primary, width: 1.5)),
    );
  }
}
