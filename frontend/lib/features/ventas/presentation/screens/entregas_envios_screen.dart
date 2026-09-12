import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../auth/services/auth_service.dart';
import '../widgets/qr_ticket_dialog.dart';
import '../../services/ordenes_service.dart';
import '../../services/ordenes_sync_notifier.dart';

/// Pantalla colaborativa para el Módulo 'Entregas y Envíos'
/// Permite gestionar retiros en sucursal y despachos externos con filtros avanzados,
/// trazabilidad de vendedores, tarjetas limpias y modal de detalle exhaustivo.
class EntregasEnviosScreen extends StatefulWidget {
  const EntregasEnviosScreen({super.key});

  @override
  State<EntregasEnviosScreen> createState() => _EntregasEnviosScreenState();
}

class _EntregasEnviosScreenState extends State<EntregasEnviosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controladores y Estados de Filtros
  final TextEditingController _clienteFilterController = TextEditingController();
  final TextEditingController _vendedorFilterController = TextEditingController();
  String _estadoPagoFilter = 'todos'; // 'todos', 'pagados', 'pendientes'

  List<EntregaEnvioModel> _todasEntregas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    OrdenesSyncNotifier.instance.addListener(_onSyncNotification);
    _verificarPermisosYCargar();
  }

  void _onSyncNotification() {
    if (mounted) {
      _cargarDatos();
    }
  }

  Future<void> _verificarPermisosYCargar() async {
    final idRol = await AuthService.getIdRol();
    final rol = await AuthService.getRol();
    final esVendedorOnline = idRol == 7 ||
        rol?.toLowerCase() == 'vendedoronline' ||
        rol?.toLowerCase() == 'vendedor online';

    if (esVendedorOnline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppPalette.surface,
          content: Text(
            'Acceso restringido: Las entregas presenciales son gestionadas por el equipo de sucursal.',
            style: TextStyle(color: AppPalette.error),
          ),
        ),
      );
      Navigator.of(context).pop();
      return;
    }
    _cargarDatos();
  }

  @override
  void dispose() {
    OrdenesSyncNotifier.instance.removeListener(_onSyncNotification);
    _tabController.dispose();
    _clienteFilterController.dispose();
    _vendedorFilterController.dispose();
    super.dispose();
  }

  bool get _tieneFiltrosActivos =>
      _clienteFilterController.text.trim().isNotEmpty ||
      _vendedorFilterController.text.trim().isNotEmpty ||
      _estadoPagoFilter != 'todos';

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await OrdenesService.obtenerEntregasEnvios(
        busquedaCliente: _clienteFilterController.text.trim().isNotEmpty
            ? _clienteFilterController.text.trim()
            : null,
        busquedaVendedor: _vendedorFilterController.text.trim().isNotEmpty
            ? _vendedorFilterController.text.trim()
            : null,
        estadoPago: _estadoPagoFilter != 'todos' ? _estadoPagoFilter : null,
      );
      if (!mounted) return;
      setState(() {
        _todasEntregas = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<EntregaEnvioModel> get _retiros =>
      _todasEntregas.where((e) => e.tipoEntrega.toLowerCase() == 'retiro').toList();

  List<EntregaEnvioModel> get _despachos =>
      _todasEntregas.where((e) => e.tipoEntrega.toLowerCase() == 'despacho').toList();

  void _limpiarFiltros() {
    _clienteFilterController.clear();
    _vendedorFilterController.clear();
    _estadoPagoFilter = 'todos';
    Navigator.of(context).pop();
    _cargarDatos();
  }

  void _aplicarFiltros() {
    Navigator.of(context).pop();
    _cargarDatos();
  }

  void _abrirModalFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabecera del Modal de Filtros
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, color: AppPalette.primary, size: 22),
                            const SizedBox(width: 8),
                            Text('Filtros de Búsqueda', style: AppTypography.title),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppPalette.textSecondary),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),

                    // Buscador 1: Cliente (Nombre, RUT, Teléfono)
                    Text(
                      'Búsqueda por Cliente',
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _clienteFilterController,
                      style: AppTypography.body.copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Nombre, RUT o Teléfono del cliente / receptor...',
                        hintStyle: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                        prefixIcon: const Icon(Icons.person_search_outlined, size: 20, color: AppPalette.textSecondary),
                        filled: true,
                        fillColor: AppPalette.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Buscador 2: Vendedor (Creador o Asignado)
                    Text(
                      'Búsqueda por Vendedor',
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _vendedorFilterController,
                      style: AppTypography.body.copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Nombre del vendedor creador o asignado...',
                        hintStyle: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppPalette.textSecondary),
                        filled: true,
                        fillColor: AppPalette.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filtro 3: Estado de Pago
                    Text(
                      'Estado de Pago / Liquidación',
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: _estadoPagoFilter == 'todos',
                          onSelected: (selected) {
                            if (selected) setModalState(() => _estadoPagoFilter = 'todos');
                          },
                          selectedColor: AppPalette.primary.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: _estadoPagoFilter == 'todos' ? AppPalette.primary : AppPalette.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Pagados'),
                          selected: _estadoPagoFilter == 'pagados',
                          onSelected: (selected) {
                            if (selected) setModalState(() => _estadoPagoFilter = 'pagados');
                          },
                          selectedColor: AppPalette.success.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: _estadoPagoFilter == 'pagados' ? AppPalette.success : AppPalette.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Con Saldo Pendiente'),
                          selected: _estadoPagoFilter == 'pendientes',
                          onSelected: (selected) {
                            if (selected) setModalState(() => _estadoPagoFilter = 'pendientes');
                          },
                          selectedColor: AppPalette.warning.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: _estadoPagoFilter == 'pendientes' ? AppPalette.warning : AppPalette.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botonera de Acción del Modal
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppPalette.textSecondary,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _limpiarFiltros,
                            child: const Text('LIMPIAR'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _aplicarFiltros,
                            child: const Text('APLICAR FILTROS', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirQrModal(EntregaEnvioModel orden) {
    QrTicketDialog.mostrar(context, orden.toHistorialModel());
  }



  Future<void> _marcarDespachoEnviado(EntregaEnvioModel orden) async {
    final idDespacho = orden.despacho?.idDespacho;
    if (idDespacho == null || idDespacho.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: AppPalette.secondary, size: 28),
            const SizedBox(width: 10),
            Text('Marcar como Enviado', style: AppTypography.title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Confirmas la entrega de la encomienda ${orden.folioDisplay} a la empresa de transporte (${orden.despacho?.empresaTransporte ?? "Courier"})?',
              style: AppTypography.body,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receptor: ${orden.despacho?.receptorNombres ?? "S/R"}',
                    style: AppTypography.small.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Destino: ${orden.despacho?.direccionEnvio ?? ""}, ${orden.despacho?.comunaDestino ?? ""}',
                    style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                  ),
                  Text(
                    'Transporte: ${orden.despacho?.empresaTransporte ?? "Chilexpress"}',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Responsable: ${orden.vendedorAsignadoNombre ?? orden.vendedorNombre ?? "Mesón General"}',
                    style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR', style: TextStyle(color: AppPalette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.secondary,
              foregroundColor: Colors.black, // Fix de contraste AAA
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('MARCAR COMO ENVIADO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await OrdenesService.marcarDespachoEnviado(idDespacho);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.surface,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppPalette.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Despacho ${orden.folioDisplay} marcado como Enviado!',
                    style: const TextStyle(color: AppPalette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
        _cargarDatos();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.surface,
            content: Text(
              'Error al marcar despacho enviado: ${e.toString().replaceAll("Exception: ", "")}',
              style: const TextStyle(color: AppPalette.error),
            ),
          ),
        );
      }
    }
  }

  /// Modal de Detalle Completo de la Orden al tocar la tarjeta (onTap)
  void _abrirDetalleCompleto(EntregaEnvioModel orden) {
    final bool saldoPendiente = orden.tieneSaldoPendiente;
    final desp = orden.despacho;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cabecera: Folio + Fecha + Estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(orden.folioDisplay, style: AppTypography.title.copyWith(fontSize: 20)),
                          Text(orden.fechaFormateada, style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (orden.tipoEntrega.toLowerCase() == 'despacho'
                                  ? AppPalette.secondary
                                  : AppPalette.primary)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (orden.tipoEntrega.toLowerCase() == 'despacho'
                                    ? AppPalette.secondary
                                    : AppPalette.primary)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          orden.tipoEntrega.toUpperCase(),
                          style: TextStyle(
                            color: orden.tipoEntrega.toLowerCase() == 'despacho'
                                ? AppPalette.secondary
                                : AppPalette.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),

                  // Ficha de Contacto Completa
                  Text('DATOS DE CLIENTE Y ENTREGA', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              orden.esConsumidorFinal ? Icons.receipt_long_outlined : Icons.person,
                              size: 16,
                              color: AppPalette.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                orden.esConsumidorFinal
                                    ? 'Orden: #${orden.folioDisplay} (Consumidor Final)'
                                    : 'Cliente: ${orden.cliente?.nombres ?? ""} ${orden.cliente?.apellidos ?? ""}'.trim(),
                                style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          orden.esConsumidorFinal
                              ? 'Venta mostrador sin RUT personal registrado'
                              : 'RUT: ${orden.cliente?.rutCliente ?? "S/R"}  •  Tel: ${orden.cliente?.telefono ?? "S/T"}',
                          style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                        ),
                        if (orden.cliente?.correo != null)
                          Text('Correo: ${orden.cliente!.correo}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                        if (desp != null) ...[
                          const Divider(color: Colors.white10, height: 16),
                          Row(
                            children: [
                              const Icon(Icons.local_shipping, size: 16, color: AppPalette.secondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Receptor: ${desp.receptorNombres} (RUT: ${desp.receptorRut})',
                                  style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Dirección: ${desp.direccionEnvio}, ${desp.comunaDestino ?? ""}', style: AppTypography.small.copyWith(color: AppPalette.textPrimary)),
                          Text('Transporte: ${desp.empresaTransporte ?? "Chilexpress"}  •  Tel: ${desp.receptorTelefono}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trazabilidad de Vendedores
                  Text('TRAZABILIDAD DE VENDEDORES', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_outlined, size: 16, color: AppPalette.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Vendedor Creador: ${orden.vendedorNombre ?? "Vendedor Central"}', style: AppTypography.small),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.assignment_ind_outlined, size: 16, color: AppPalette.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Responsable Asignado: ${orden.vendedorAsignadoNombre ?? "Mesón General (Todos)"}', style: AppTypography.small.copyWith(color: AppPalette.primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Desglose de Repuestos Exhaustivo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DESGLOSE DE REPUESTOS (${orden.totalItems})', style: AppTypography.small.copyWith(fontWeight: FontWeight.bold, color: AppPalette.textSecondary)),
                      _buildPreparacionBadge(orden.preparacionLista),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...orden.detalles.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppPalette.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  item.esInventariado ? Icons.inventory_2_outlined : Icons.edit_note_outlined,
                                  size: 16,
                                  color: item.esInventariado ? AppPalette.primary : AppPalette.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.tituloDisplay,
                                    style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Text(item.subtotalFormateado, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: AppPalette.primary)),
                              ],
                            ),
                            if (item.skuQrFisico != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('SKU QR: ${item.skuQrFisico}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontSize: 11)),
                              ),
                            if (item.notasPreparacion != null && item.notasPreparacion!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('Nota: ${item.notasPreparacion}', style: AppTypography.small.copyWith(color: AppPalette.warning, fontSize: 11)),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Cantidad: ${item.cantidad}x  •  Unitario: ${item.precioFinalFormateado}', style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontSize: 11)),
                                Text('Estado: ${item.estadoPreparacion ?? "Pendiente"}', style: TextStyle(color: item.preparacionLista ? AppPalette.success : AppPalette.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Resumen Financiero
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: saldoPendiente ? AppPalette.warning.withValues(alpha: 0.5) : AppPalette.success.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL VENTA', style: TextStyle(color: AppPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(orden.totalVentaFormateado, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              saldoPendiente ? 'SALDO PENDIENTE' : 'ESTADO DE PAGO',
                              style: TextStyle(
                                color: saldoPendiente ? AppPalette.warning : AppPalette.success,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              saldoPendiente ? orden.montoPendienteFormateado : 'PAGADO COMPLETO',
                              style: TextStyle(
                                color: saldoPendiente ? AppPalette.warning : AppPalette.success,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botonera de Acción en Detalle
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: orden.tieneQrDisponible
                                ? AppPalette.primary
                                : AppPalette.textSecondary,
                            side: BorderSide(
                              color: orden.tieneQrDisponible
                                  ? AppPalette.primary
                                  : Colors.white24,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            if (!orden.tieneQrDisponible) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppPalette.surface,
                                  behavior: SnackBarBehavior.floating,
                                  content: Row(
                                    children: [
                                      const Icon(Icons.lock_clock_rounded,
                                          color: AppPalette.warning, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          saldoPendiente
                                              ? 'QR bloqueado: Orden con saldo pendiente de ${orden.montoPendienteFormateado}. Requiere confirmación de pago en Caja.'
                                              : 'Esta orden no requiere código QR para retiro en bodega.',
                                          style: const TextStyle(color: AppPalette.warning),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.of(ctx).pop();
                            _abrirQrModal(orden);
                          },
                          icon: Icon(
                            orden.tieneQrDisponible ? Icons.qr_code_2 : Icons.lock_outline,
                            size: 18,
                          ),
                          label: Text(
                            orden.tieneQrDisponible ? 'VER TICKET QR' : 'QR BLOQUEADO',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (orden.tipoEntrega.toLowerCase() != 'retiro') ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.secondary,
                              foregroundColor: Colors.black, // Fix de contraste AAA
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _marcarDespachoEnviado(orden);
                            },
                            icon: const Icon(Icons.local_shipping, size: 18, color: Colors.black),
                            label: const Text('MARCAR ENVIADO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_outlined, color: AppPalette.primary, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Entregas y Envíos',
                style: AppTypography.title.copyWith(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Botón de Filtros con indicador de estado
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: Stack(
              children: [
                Icon(
                  Icons.tune_outlined,
                  size: 22,
                  color: _tieneFiltrosActivos ? AppPalette.primary : AppPalette.textPrimary,
                ),
                if (_tieneFiltrosActivos)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppPalette.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filtros de Búsqueda',
            onPressed: _abrirModalFiltros,
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.refresh_rounded, color: AppPalette.textPrimary, size: 22),
            tooltip: 'Actualizar lista',
            onPressed: _cargarDatos,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppPalette.primary,
          indicatorWeight: 3,
          labelColor: AppPalette.primary,
          unselectedLabelColor: AppPalette.textSecondary,
          labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: MarqueeText(
                      text: 'Retiros en Tienda',
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (!_isLoading) ...[
                    const SizedBox(width: 6),
                    _buildBadgeCount(_retiros.length, AppPalette.primary),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: MarqueeText(
                      text: 'Despachos (Courier)',
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (!_isLoading) ...[
                    const SizedBox(width: 6),
                    _buildBadgeCount(_despachos.length, AppPalette.secondary),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppPalette.primary))
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRetirosTab(),
                    _buildDespachosTab(),
                  ],
                ),
    );
  }

  Widget _buildBadgeCount(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppPalette.error, size: 54),
            const SizedBox(height: 16),
            Text('Error al cargar entregas y envíos', style: AppTypography.title),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Ocurrió un error inesperado.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetirosTab() {
    if (_retiros.isEmpty) {
      return _buildEmptyView(
        icon: Icons.storefront_outlined,
        title: 'Sin Retiros Pendientes',
        subtitle: _tieneFiltrosActivos
            ? 'No se encontraron retiros con los filtros seleccionados.'
            : 'No hay pedidos en espera de retiro en esta sucursal.',
      );
    }

    return RefreshIndicator(
      color: AppPalette.primary,
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _retiros.length,
        itemBuilder: (context, index) {
          return _buildRetiroCard(_retiros[index]);
        },
      ),
    );
  }

  Widget _buildDespachosTab() {
    if (_despachos.isEmpty) {
      return _buildEmptyView(
        icon: Icons.local_shipping_outlined,
        title: 'Sin Despachos Pendientes',
        subtitle: _tieneFiltrosActivos
            ? 'No se encontraron despachos con los filtros seleccionados.'
            : 'No hay pedidos por enviar a regiones o domicilio.',
      );
    }

    return RefreshIndicator(
      color: AppPalette.primary,
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _despachos.length,
        itemBuilder: (context, index) {
          return _buildDespachoCard(_despachos[index]);
        },
      ),
    );
  }

  Widget _buildEmptyView({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppPalette.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: AppTypography.title.copyWith(color: AppPalette.textPrimary)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppPalette.textSecondary),
            ),
            if (_tieneFiltrosActivos) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  _clienteFilterController.clear();
                  _vendedorFilterController.clear();
                  _estadoPagoFilter = 'todos';
                  _cargarDatos();
                },
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Limpiar Filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tarjeta Resumida y Compacta de Retiro en Tienda
  Widget _buildRetiroCard(EntregaEnvioModel orden) {
    final bool saldoPendiente = orden.tieneSaldoPendiente;

    // Resumen simple de ítems
    final itemsResumen = orden.detalles.length == 1
        ? '${orden.detalles.first.cantidad}x ${orden.detalles.first.tituloDisplay}'
        : '${orden.totalItems} piezas (${orden.detalles.map((d) => d.tituloDisplay).take(2).join(", ")}${orden.detalles.length > 2 ? "..." : ""})';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: saldoPendiente
              ? AppPalette.warning.withValues(alpha: 0.35)
              : AppPalette.success.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDetalleCompleto(orden),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Folio + Fecha + Chip de Modalidad
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              orden.folioDisplay,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppPalette.primary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          orden.fechaFormateada,
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront, size: 12, color: AppPalette.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Retiro',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fila 2: Nombre del Cliente / Receptor + Vendedor
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    orden.esConsumidorFinal ? Icons.receipt_long_outlined : Icons.person_outline,
                    size: 18,
                    color: orden.esConsumidorFinal ? AppPalette.primary : AppPalette.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orden.clienteDisplay,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: orden.esConsumidorFinal ? AppPalette.primary : AppPalette.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Vendedor: ${orden.vendedorNombre ?? "Vendedor Central"} • Resp: ${orden.vendedorAsignadoNombre ?? "Mesón General"}',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Fila 3: Resumen simple de ítems y Badge de saldo
              Row(
                children: [
                  Expanded(
                    child: Text(
                      itemsResumen,
                      style: AppTypography.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  saldoPendiente
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppPalette.warning),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'SALDO: ${orden.montoPendienteFormateado}',
                              style: const TextStyle(
                                color: AppPalette.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppPalette.success),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'PAGADO - LISTO',
                              style: TextStyle(
                                color: AppPalette.success,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 12),

              // Fila 4: Botonera de Acción Rápida y Acceso a Detalle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () {
                      if (!orden.tieneQrDisponible) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppPalette.surface,
                            behavior: SnackBarBehavior.floating,
                            content: Row(
                              children: [
                                const Icon(Icons.lock_clock_rounded,
                                    color: AppPalette.warning, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    saldoPendiente
                                        ? 'QR bloqueado: Orden con saldo pendiente de ${orden.montoPendienteFormateado}. Requiere confirmación de pago en Caja.'
                                        : 'Esta orden no requiere código QR para retiro en bodega.',
                                    style: const TextStyle(color: AppPalette.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        return;
                      }
                      _abrirQrModal(orden);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            orden.tieneQrDisponible ? Icons.qr_code_2 : Icons.lock_outline,
                            color: orden.tieneQrDisponible ? AppPalette.primary : AppPalette.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            orden.tieneQrDisponible ? 'Ticket QR' : 'QR Bloqueado',
                            style: AppTypography.body.copyWith(
                              color: orden.tieneQrDisponible ? AppPalette.primary : AppPalette.warning,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner,
                          size: 15,
                          color: AppPalette.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Salida en Barrera Bodega',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta Resumida y Compacta de Despacho
  Widget _buildDespachoCard(EntregaEnvioModel orden) {
    final desp = orden.despacho;
    final itemsResumen = orden.detalles.length == 1
        ? '${orden.detalles.first.cantidad}x ${orden.detalles.first.tituloDisplay}'
        : '${orden.totalItems} piezas (${orden.detalles.map((d) => d.tituloDisplay).take(2).join(", ")}${orden.detalles.length > 2 ? "..." : ""})';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.secondary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDetalleCompleto(orden),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Folio + Fecha + Chip de Transporte
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppPalette.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              orden.folioDisplay,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppPalette.secondary,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          orden.fechaFormateada,
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppPalette.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_shipping, size: 12, color: AppPalette.secondary),
                        const SizedBox(width: 4),
                        Text(
                          desp?.empresaTransporte ?? 'Courier',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fila 2: Receptor y Destino + Vendedor
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: AppPalette.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (desp != null && desp.receptorNombres.isNotEmpty && desp.receptorNombres != "S/R")
                              ? '${desp.receptorNombres} (${desp.comunaDestino ?? ""})'
                              : orden.clienteDisplay,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppPalette.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Vendedor: ${orden.vendedorNombre ?? "Vendedor Central"} • Resp: ${orden.vendedorAsignadoNombre ?? "Mesón General"}',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Fila 3: Resumen simple de ítems y Badge de estado
              Row(
                children: [
                  Expanded(
                    child: Text(
                      itemsResumen,
                      style: AppTypography.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppPalette.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppPalette.secondary),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        desp?.estadoDespacho.toUpperCase() ?? 'POR ENVIAR',
                        style: const TextStyle(
                          color: AppPalette.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fila 4: Botonera de Acción Rápida (con contraste AAA)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _abrirDetalleCompleto(orden),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2, color: AppPalette.secondary, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            'Ver Detalle',
                            style: AppTypography.body.copyWith(
                              color: AppPalette.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.secondary,
                          foregroundColor: Colors.black87, // Fix de contraste AAA
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: () => _marcarDespachoEnviado(orden),
                        icon: const Icon(Icons.local_shipping, size: 20, color: Colors.black87),
                        label: const Text(
                          'Marcar como Enviado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreparacionBadge(bool lista) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: lista
            ? AppPalette.success.withValues(alpha: 0.15)
            : AppPalette.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        lista ? 'PREPARACIÓN LISTA' : 'EN PREPARACIÓN',
        style: TextStyle(
          color: lista ? AppPalette.success : AppPalette.warning,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
