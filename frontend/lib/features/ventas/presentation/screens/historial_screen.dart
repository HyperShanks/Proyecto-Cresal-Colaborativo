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

  List<OrdenHistorialModel> _ordenes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  // Filtros aplicados
  bool _verTodas = false;
  String? _filtroEstado;

  // Filtros temporales mientras el drawer está abierto
  bool _tempVerTodas = false;
  String? _tempFiltroEstado;

  @override
  void initState() {
    super.initState();
    _tempVerTodas = _verTodas;
    _tempFiltroEstado = _filtroEstado;

    OrdenesSyncNotifier.instance.addListener(_onSyncNotification);

    if (widget.initialOrdenes != null) {
      _ordenes = List.from(widget.initialOrdenes!);
      _ordenes.sort((a, b) {
        final aComp = a.estadoOrden.toLowerCase() == 'completada' ? 1 : 0;
        final bComp = b.estadoOrden.toLowerCase() == 'completada' ? 1 : 0;
        if (aComp != bComp) {
          return aComp.compareTo(bComp);
        }
        return (b.fechaCreacion ?? '').compareTo(a.fechaCreacion ?? '');
      });
      _isLoading = false;
    } else {
      _cargarOrdenes();
    }
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
    refrescar();
  }

  void _onSyncNotification() {
    if (mounted) {
      _cargarOrdenes();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    OrdenesSyncNotifier.instance.removeListener(_onSyncNotification);
    _searchController.dispose();
    super.dispose();
  }

  /// Método público para forzar recarga de órdenes (Auto-Refresh SPEC-HU-TAREA-20)
  Future<void> refrescar() async {
    await _cargarOrdenes();
  }

  Future<void> _cargarOrdenes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ordenes = await OrdenesService.obtenerMisVentas(
        todas: _verTodas,
        estado: _filtroEstado,
        client: widget.client,
      );

      if (!mounted) return;

      // Ordenar: Completadas al final, las demás al principio (más recientes primero)
      ordenes.sort((a, b) {
        final aComp = a.estadoOrden.toLowerCase() == 'completada' ? 1 : 0;
        final bComp = b.estadoOrden.toLowerCase() == 'completada' ? 1 : 0;
        if (aComp != bComp) {
          return aComp.compareTo(bComp);
        }
        return (b.fechaCreacion ?? '').compareTo(a.fechaCreacion ?? '');
      });

      setState(() {
        _ordenes = ordenes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
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

  void _abrirDetalleOrden(OrdenHistorialModel orden) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => OrdenDetailSheet(
        orden: orden,
        onOrderUpdated: () {
          _cargarOrdenes();
          widget.onRefreshCatalogo?.call();
        },
      ),
    );
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
                Icons.receipt_long_outlined,
                size: 54.0,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 20.0),
            Text(
              _filtroEstado != null
                  ? 'No hay órdenes en estado "$_filtroEstado"'
                  : _verTodas
                      ? 'No tienes órdenes en tu historial'
                      : 'No has generado órdenes hoy',
              style: AppTypography.title.copyWith(fontSize: 18.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              _filtroEstado != null
                  ? 'Prueba cambiando o limpiando los filtros para ver otras ventas.'
                  : _verTodas
                      ? 'Tus ventas derivadas a caja aparecerán aquí con su estado en tiempo real.'
                      : 'Las ventas creadas durante el día se listarán aquí para su seguimiento y gestión.',
              style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),
            if (_filtroEstado != null || !_verTodas)
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
              _filtroEstado != null
                  ? 'Filtro: $_filtroEstado (${_verTodas ? "Historial" : "Hoy"})'
                  : _verTodas
                      ? 'Historial completo de ventas'
                      : 'Ventas del día (Hoy)',
              style: AppTypography.small.copyWith(
                fontSize: 12.0,
                color: hayFiltrosActivos ? AppPalette.secondary : AppPalette.textSecondary,
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
                                    return OrdenCard(
                                      orden: orden,
                                      onTap: () => _abrirDetalleOrden(orden),
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
