import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/ordenes_service.dart';
import '../widgets/orden_card.dart';
import '../widgets/orden_detail_sheet.dart';
import '../widgets/historial_filtros_drawer.dart';

/// Pantalla principal para la visualización y monitoreo de órdenes de venta del vendedor (HU-3.5).
class HistorialScreen extends StatefulWidget {
  final VoidCallback? onOpenMenuDrawer;
  final VoidCallback? onRefreshCatalogo;

  const HistorialScreen({
    super.key,
    this.onOpenMenuDrawer,
    this.onRefreshCatalogo,
  });

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<OrdenHistorialModel> _ordenes = [];
  bool _isLoading = true;
  String? _errorMessage;

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
    _cargarOrdenes();
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
      );

      if (!mounted) return;

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
                    // Sincronizar valores temporales antes de abrir drawer
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
      body: _isLoading
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
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: _buildEmptyState(),
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
                          vertical: 12.0,
                        ),
                        itemCount: _ordenes.length,
                        itemBuilder: (context, index) {
                          final orden = _ordenes[index];
                          return OrdenCard(
                            orden: orden,
                            onTap: () => _abrirDetalleOrden(orden),
                          );
                        },
                      ),
                    ),
    );
  }
}
