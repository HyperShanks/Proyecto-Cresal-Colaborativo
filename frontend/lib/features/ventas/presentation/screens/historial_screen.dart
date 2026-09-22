import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/routes/route_observer.dart';
import '../../services/ordenes_service.dart';
import '../../services/ordenes_sync_notifier.dart';
import '../widgets/orden_card.dart';
import '../widgets/orden_detail_sheet.dart';
import '../widgets/historial_filtros_drawer.dart';
import '../widgets/asignar_activo_vendedor_dialog.dart';
import '../../../../core/services/silent_polling_manager.dart';

/// Pantalla principal para la visualización y monitoreo de órdenes de venta del vendedor (HU-3.5).
class HistorialScreen extends StatefulWidget {
  final VoidCallback? onOpenMenuDrawer;
  final VoidCallback? onRefreshCatalogo;
  final List<OrdenHistorialModel>? initialOrdenes;
  final http.Client? client;

  const HistorialScreen({
    super.key,
    this.onOpenMenuDrawer,
    this.onRefreshCatalogo,
    this.initialOrdenes,
    this.client,
  });

  @override
  State<HistorialScreen> createState() => HistorialScreenState();
}

class HistorialScreenState extends State<HistorialScreen> with RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  List<OrdenHistorialModel> _ordenesHistorial = [];
  List<OrdenHistorialModel> _ordenesPorAsignar = [];
  int _activeRequestId = 0;

  List<OrdenHistorialModel> get _ordenes =>
      _seccionActual == 'por_asignar' ? _ordenesPorAsignar : _ordenesHistorial;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  // Filtros aplicados
  bool _verTodas = false;
  String? _filtroEstado;

  // Filtros temporales mientras el drawer está abierto
  bool _tempVerTodas = false;
  String? _tempFiltroEstado;

  // Sección actual: 'normal' (Historial de Órdenes) o 'por_asignar' (Ventas en Verde Pagadas sin activo asignado)
  String _seccionActual = 'normal';
  int _conteoPorAsignar = 0;
  SilentPollingManager? _pollingManager;
  bool _isModalAbierto = false;

  @override
  void initState() {
    super.initState();
    _tempVerTodas = _verTodas;
    _tempFiltroEstado = _filtroEstado;

    OrdenesSyncNotifier.instance.addListener(_onSyncNotification);
    _iniciarAutoRefresh();

    if (widget.initialOrdenes != null) {
      _ordenesHistorial = List.from(widget.initialOrdenes!);
      _ordenarOrdenes(_ordenesHistorial);
      _isLoading = false;
    } else {
      _cargarOrdenes();
    }
  }

  void _iniciarAutoRefresh() {
    _pollingManager?.dispose();
    _pollingManager = SilentPollingManager(
      interval: const Duration(seconds: 15),
      debugLabel: 'HistorialPolling',
      shouldPause: () => _isModalAbierto || _isLoading,
      onPoll: () async {
        if (mounted) {
          await _cargarOrdenesSilencioso();
        }
      },
    )..start();
  }

  /// Prioridad de ordenamiento: 0 = Activas/Pendientes, 1 = Completadas, 2 = Anuladas (al final absoluto)
  static int _prioridadEstado(String estado) {
    final est = estado.trim().toLowerCase();
    if (est == 'anulada') return 2;
    if (est == 'completada' || est == 'entregada') return 1;
    return 0;
  }

  void _ordenarOrdenes(List<OrdenHistorialModel> lista) {
    lista.sort((a, b) {
      final aPrio = _prioridadEstado(a.estadoOrden);
      final bPrio = _prioridadEstado(b.estadoOrden);
      if (aPrio != bPrio) {
        return aPrio.compareTo(bPrio);
      }
      return (b.fechaCreacion ?? '').compareTo(a.fechaCreacion ?? '');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _cargarOrdenesSilencioso();
  }

  void _onSyncNotification() {
    if (mounted) {
      _cargarOrdenesSilencioso();
    }
  }

  @override
  void dispose() {
    _pollingManager?.dispose();
    routeObserver.unsubscribe(this);
    OrdenesSyncNotifier.instance.removeListener(_onSyncNotification);
    _searchController.dispose();
    super.dispose();
  }

  /// Método público para forzar recarga de órdenes (Auto-Refresh SPEC-HU-TAREA-20)
  Future<void> refrescar() async {
    await _cargarOrdenes();
  }

  /// Recarga silenciosa sin loaders si ya hay datos en memoria
  Future<void> refrescarSilencioso() async {
    if (_ordenesHistorial.isEmpty && _ordenesPorAsignar.isEmpty) {
      await _cargarOrdenes();
    } else {
      await _cargarOrdenesSilencioso();
    }
  }

  Future<void> _cargarOrdenes() async {
    final int requestId = ++_activeRequestId;
    final String seccionSolicitada = _seccionActual;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ordenes = await OrdenesService.obtenerMisVentas(
        todas: seccionSolicitada == 'por_asignar' ? true : _verTodas,
        estado: seccionSolicitada == 'por_asignar' ? null : _filtroEstado,
        seccion: seccionSolicitada,
        client: widget.client,
      );

      if (!mounted || requestId != _activeRequestId || _seccionActual != seccionSolicitada) {
        return;
      }

      // Ordenar: Activas al principio, completadas al final y anuladas al final absoluto
      _ordenarOrdenes(ordenes);

      int conteo = _conteoPorAsignar;
      if (seccionSolicitada == 'por_asignar') {
        conteo = ordenes.length;
      } else {
        try {
          final porAsignar = await OrdenesService.obtenerMisVentas(
            seccion: 'por_asignar',
            todas: true,
            client: widget.client,
          );
          if (!mounted || requestId != _activeRequestId) return;
          conteo = porAsignar.length;
        } catch (_) {}
      }

      if (!mounted || requestId != _activeRequestId || _seccionActual != seccionSolicitada) {
        return;
      }

      setState(() {
        if (seccionSolicitada == 'por_asignar') {
          _ordenesPorAsignar = ordenes;
        } else {
          _ordenesHistorial = ordenes;
        }
        _conteoPorAsignar = conteo;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _activeRequestId || _seccionActual != seccionSolicitada) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Recarga en segundo plano sin interrumpir la interacción del usuario
  Future<void> _cargarOrdenesSilencioso() async {
    if (!mounted || _isLoading) return;
    final int requestId = ++_activeRequestId;
    final String seccionSolicitada = _seccionActual;

    try {
      final ordenes = await OrdenesService.obtenerMisVentas(
        todas: seccionSolicitada == 'por_asignar' ? true : _verTodas,
        estado: seccionSolicitada == 'por_asignar' ? null : _filtroEstado,
        seccion: seccionSolicitada,
        client: widget.client,
      );

      if (!mounted || requestId != _activeRequestId || _seccionActual != seccionSolicitada) return;
      _ordenarOrdenes(ordenes);

      int conteo = _conteoPorAsignar;
      if (seccionSolicitada == 'por_asignar') {
        conteo = ordenes.length;
      } else {
        try {
          final porAsignar = await OrdenesService.obtenerMisVentas(
            seccion: 'por_asignar',
            todas: true,
            client: widget.client,
          );
          if (!mounted || requestId != _activeRequestId) return;
          conteo = porAsignar.length;
        } catch (_) {}
      }

      if (!mounted || requestId != _activeRequestId || _seccionActual != seccionSolicitada) return;

      setState(() {
        if (seccionSolicitada == 'por_asignar') {
          _ordenesPorAsignar = ordenes;
        } else {
          _ordenesHistorial = ordenes;
        }
        _conteoPorAsignar = conteo;
      });
    } catch (_) {
      // Ignorar errores en ciclo silencioso
    }
  }

  /// Lista filtrada reactivamente según el término de búsqueda ingresado
  List<OrdenHistorialModel> get _ordenesFiltradas {
    if (_searchQuery.trim().isEmpty) {
      return _ordenes;
    }

    final query = _searchQuery.trim().toLowerCase();
    final cleanQuery = query.replaceAll('#', '').trim();

    return _ordenes.where((orden) {
      // 1. Folio / ID de Orden / Token QR
      final idMatch = orden.idOrden.toLowerCase().contains(cleanQuery);
      final folioMatch = orden.folioDisplay.toLowerCase().contains(cleanQuery) ||
          orden.folioDisplay.toLowerCase().contains(query);
      final qrMatch = orden.qrTransaccionalSalida != null &&
          orden.qrTransaccionalSalida!.toLowerCase().contains(cleanQuery);

      // 2. Cliente: Nombre Completo y RUT
      final cliente = orden.cliente;
      final clienteNombreMatch = cliente != null &&
          cliente.nombreCompleto.toLowerCase().contains(cleanQuery);
      final clienteRutMatch = cliente != null &&
          (cliente.rutCliente.toLowerCase().contains(cleanQuery) ||
              cliente.rutCliente.replaceAll('.', '').replaceAll('-', '').toLowerCase().contains(cleanQuery.replaceAll('.', '').replaceAll('-', '')));

      // 3. Despacho: Receptor y RUT
      final despacho = orden.despacho;
      final receptorNombreMatch = despacho != null &&
          despacho.receptorNombres.toLowerCase().contains(cleanQuery);
      final receptorRutMatch = despacho != null &&
          despacho.receptorRut.toLowerCase().contains(cleanQuery);

      // 4. Marca / Modelo / Título o SKU del Repuesto en líneas de detalle
      final repuestosMatch = orden.detalles.any((detalle) {
        final titulo = detalle.titulo.toLowerCase();
        final desc = (detalle.descripcionManual ?? '').toLowerCase();
        final sku = (detalle.skuQrFisico ?? '').toLowerCase();
        return titulo.contains(cleanQuery) ||
            desc.contains(cleanQuery) ||
            sku.contains(cleanQuery);
      });

      return idMatch ||
          folioMatch ||
          qrMatch ||
          clienteNombreMatch ||
          clienteRutMatch ||
          receptorNombreMatch ||
          receptorRutMatch ||
          repuestosMatch;
    }).toList();
  }

  Future<void> _abrirDetalleOrden(OrdenHistorialModel orden) async {
    _isModalAbierto = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        builder: (ctx) => OrdenDetailSheet(
          orden: orden,
          onOrderUpdated: () {
            _cargarOrdenesSilencioso();
            widget.onRefreshCatalogo?.call();
          },
        ),
      );
    } finally {
      _isModalAbierto = false;
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 6.0),
      child: TextField(
        key: const Key('buscador_ordenes_textfield'),
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        style: AppTypography.body.copyWith(color: AppPalette.textPrimary, fontSize: 14),
        cursorColor: AppPalette.primary,
        decoration: InputDecoration(
          hintText: 'Buscar por Folio, Cliente, RUT o Repuesto...',
          hintStyle: AppTypography.body.copyWith(
            color: AppPalette.textSecondary.withValues(alpha: 0.65),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppPalette.textSecondary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  key: const Key('btn_limpiar_busqueda_ordenes'),
                  icon: const Icon(
                    Icons.clear,
                    color: AppPalette.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  tooltip: 'Limpiar búsqueda',
                )
              : null,
          filled: true,
          fillColor: AppPalette.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14.0,
            vertical: 10.0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(
              color: AppPalette.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                titulo: 'Historial de Órdenes',
                seccion: 'normal',
                icon: Icons.history,
              ),
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: _buildTabButton(
                titulo: 'Por Asignar',
                seccion: 'por_asignar',
                icon: Icons.pending_actions,
                badgeCount: _conteoPorAsignar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String titulo,
    required String seccion,
    required IconData icon,
    int badgeCount = 0,
  }) {
    final isSelected = _seccionActual == seccion;
    return InkWell(
      key: Key('tab_seccion_$seccion'),
      onTap: () {
        if (_seccionActual != seccion) {
          setState(() {
            _seccionActual = seccion;
          });
          _cargarOrdenes();
        }
      },
      borderRadius: BorderRadius.circular(8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
          border: isSelected
              ? Border.all(color: AppPalette.primary.withValues(alpha: 0.6), width: 1.0)
              : Border.all(color: Colors.transparent, width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.0,
              color: isSelected ? AppPalette.primary : AppPalette.textSecondary,
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  titulo,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppPalette.textPrimary : AppPalette.textSecondary,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? AppPalette.secondary : AppPalette.warning,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdenPorAsignarCard(OrdenHistorialModel orden) {
    // Guardia de seguridad: Asegurar que la orden sea venta en verde con ítem pendiente
    final tieneBackorderPendiente = orden.detalles.any((d) => !d.esInventariado);
    if (!tieneBackorderPendiente) {
      return const SizedBox.shrink();
    }

    return Container(
      key: Key('orden_por_asignar_${orden.idOrden}'),
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: AppPalette.warning.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: () => _abrirDetalleOrden(orden),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Folio y Badge de Advertencia
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: AppPalette.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Icon(
                              Icons.hourglass_top,
                              size: 18.0,
                              color: AppPalette.warning,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              orden.folioDisplay,
                              style: AppTypography.title.copyWith(
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: AppPalette.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: AppPalette.warning.withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pending_actions, size: 13.0, color: AppPalette.warning),
                          const SizedBox(width: 4.0),
                          Text(
                            'Por Asignar Activo',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.warning,
                              fontFamily: AppTypography.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12.0),
                const Divider(color: Colors.white10, height: 1.0),
                const SizedBox(height: 12.0),

                // Cliente
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16.0,
                      color: AppPalette.textSecondary,
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Text(
                        orden.cliente != null && orden.cliente!.nombres.isNotEmpty
                            ? '${orden.cliente!.nombreCompleto} (${orden.cliente!.rutCliente})'
                            : 'Cliente General',
                        style: AppTypography.body.copyWith(
                          fontSize: 14.0,
                          color: AppPalette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),

                // Fecha y estado de pago
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14.0,
                      color: AppPalette.textSecondary,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      orden.fechaFormateada,
                      style: AppTypography.small.copyWith(
                        fontSize: 12.5,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: AppPalette.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(color: AppPalette.success.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Pagada al 100% (${orden.totalVentaFormateado})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.success,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Detalle del ítem en verde
                if (orden.detalles.isNotEmpty) ...[
                  const SizedBox(height: 10.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repuesto en Verde Solicitado:',
                          style: AppTypography.small.copyWith(
                            fontSize: 11.0,
                            color: AppPalette.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          orden.detalles.first.titulo,
                          style: AppTypography.body.copyWith(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12.0),
                // Botón de asignación física
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: AppPalette.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 20.0),
                    label: const Text(
                      'Asignar Activo Físico',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      AsignarActivoVendedorDialog.mostrar(
                        context,
                        orden: orden,
                        onAsignadoExitoso: _cargarOrdenes,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResultsState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.search_off,
                size: 50.0,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 20.0),
            Text(
              'No se encontraron órdenes que coincidan con la búsqueda',
              style: AppTypography.title.copyWith(fontSize: 16.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              'No hay resultados para "$_searchQuery". Verifica el folio (#...), cliente, RUT o nombre del repuesto.',
              style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20.0),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.primary,
                side: const BorderSide(color: AppPalette.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              icon: const Icon(Icons.clear, size: 18.0),
              label: const Text('Limpiar Búsqueda'),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool esPorAsignar = _seccionActual == 'por_asignar';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(
                esPorAsignar
                    ? Icons.assignment_turned_in_outlined
                    : Icons.receipt_long_outlined,
                size: 54.0,
                color: esPorAsignar ? AppPalette.success : AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 20.0),
            Text(
              esPorAsignar
                  ? 'Sin ventas en verde por asignar'
                  : _filtroEstado != null
                      ? 'No hay órdenes en estado "$_filtroEstado"'
                      : _verTodas
                          ? 'No tienes órdenes en tu historial'
                          : 'No has generado órdenes hoy',
              style: AppTypography.title.copyWith(fontSize: 18.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              esPorAsignar
                  ? 'Todas tus ventas en verde pagadas ya cuentan con su activo físico asignado o están en proceso.'
                  : _filtroEstado != null
                      ? 'Prueba cambiando o limpiando los filtros para ver otras ventas.'
                      : _verTodas
                          ? 'Tus ventas derivadas a caja aparecerán aquí con su estado en tiempo real.'
                          : 'Las ventas creadas durante el día se listarán aquí para su seguimiento y gestión.',
              style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),
            if (!esPorAsignar && (_filtroEstado != null || !_verTodas))
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.primary,
                  side: const BorderSide(color: AppPalette.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                icon: Icon(_filtroEstado != null ? Icons.filter_alt_off : Icons.history, size: 18.0),
                label: Text(_filtroEstado != null ? 'Limpiar Filtros' : 'Ver Historial Completo'),
                onPressed: () {
                  setState(() {
                    _filtroEstado = null;
                    _tempFiltroEstado = null;
                    if (_filtroEstado == null && !_verTodas) {
                      _verTodas = true;
                      _tempVerTodas = true;
                    }
                  });
                  _cargarOrdenes();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48.0, color: AppPalette.error),
            const SizedBox(height: 16.0),
            const Text(
              'Error al cargar órdenes',
              style: AppTypography.title,
            ),
            const SizedBox(height: 8.0),
            Text(
              _errorMessage ?? 'Ocurrió un error inesperado al conectar con el servidor.',
              style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20.0),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: AppPalette.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              icon: const Icon(Icons.refresh, size: 18.0),
              label: const Text('Reintentar'),
              onPressed: _cargarOrdenes,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayFiltrosActivos = _verTodas || _filtroEstado != null;
    final ordenesMostradas = _ordenesFiltradas;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        elevation: 0,
        leading: widget.onOpenMenuDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu, color: AppPalette.textPrimary),
                onPressed: widget.onOpenMenuDrawer,
                tooltip: 'Menú principal',
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis Órdenes de Venta',
              style: AppTypography.title,
            ),
            Text(
              _seccionActual == 'por_asignar'
                  ? 'Ventas en verde pagadas pendientes de activo'
                  : _filtroEstado != null
                      ? 'Filtro: $_filtroEstado (${_verTodas ? "Historial" : "Hoy"})'
                      : _verTodas
                          ? 'Historial completo de ventas'
                          : 'Ventas del día (Hoy)',
              style: AppTypography.small.copyWith(
                fontSize: 12.0,
                color: (_seccionActual == 'por_asignar' || hayFiltrosActivos)
                    ? AppPalette.secondary
                    : AppPalette.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // Botón de Filtros (Abre el EndDrawer)
          Builder(
            builder: (ctx) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.tune,
                    color: hayFiltrosActivos ? AppPalette.secondary : AppPalette.textPrimary,
                  ),
                  onPressed: () {
                    setState(() {
                      _tempVerTodas = _verTodas;
                      _tempFiltroEstado = _filtroEstado;
                    });
                    Scaffold.of(ctx).openEndDrawer();
                  },
                  tooltip: 'Filtrar órdenes',
                ),
                if (hayFiltrosActivos)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppPalette.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppPalette.textPrimary),
            onPressed: _isLoading ? null : _cargarOrdenes,
            tooltip: 'Actualizar lista',
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: HistorialFiltrosDrawer(
        verTodas: _tempVerTodas,
        filtroEstado: _tempFiltroEstado,
        onPeriodoChanged: (val) {
          setState(() => _tempVerTodas = val);
        },
        onEstadoChanged: (val) {
          setState(() => _tempFiltroEstado = val);
        },
        onAplicar: () {
          setState(() {
            _verTodas = _tempVerTodas;
            _filtroEstado = _tempFiltroEstado;
          });
          _cargarOrdenes();
        },
        onLimpiar: () {
          setState(() {
            _verTodas = false;
            _filtroEstado = null;
            _tempVerTodas = false;
            _tempFiltroEstado = null;
          });
          _cargarOrdenes();
        },
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSeccionTabs(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppPalette.primary),
                  )
                : _errorMessage != null
                    ? _buildErrorState()
                    : _ordenes.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _cargarOrdenes,
                            color: AppPalette.primary,
                            backgroundColor: AppPalette.surface,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.65,
                                  child: _buildEmptyState(),
                                ),
                              ],
                            ),
                          )
                        : ordenesMostradas.isEmpty
                            ? RefreshIndicator(
                                onRefresh: _cargarOrdenes,
                                color: AppPalette.primary,
                                backgroundColor: AppPalette.surface,
                                child: ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.65,
                                      child: _buildNoSearchResultsState(),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _cargarOrdenes,
                                color: AppPalette.primary,
                                backgroundColor: AppPalette.surface,
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  itemCount: ordenesMostradas.length,
                                  itemBuilder: (context, index) {
                                    final orden = ordenesMostradas[index];
                                    if (_seccionActual == 'por_asignar') {
                                      return _buildOrdenPorAsignarCard(orden);
                                    }
                                    return OrdenCard(
                                      orden: orden,
                                      onTap: () => _abrirDetalleOrden(orden),
                                      onEstadoDespachoCambiado: _cargarOrdenes,
                                    );
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
