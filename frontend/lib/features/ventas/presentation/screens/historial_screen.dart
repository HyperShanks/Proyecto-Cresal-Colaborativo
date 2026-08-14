import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/ordenes_service.dart';
import '../widgets/orden_card.dart';
import '../widgets/orden_detail_sheet.dart';

/// Pantalla principal para la visualización y monitoreo de órdenes de venta del vendedor (HU-3.5).
class HistorialScreen extends StatefulWidget {
  final VoidCallback? onOpenMenuDrawer;

  const HistorialScreen({
    super.key,
    this.onOpenMenuDrawer,
  });

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<OrdenHistorialModel> _ordenes = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filtros
  bool _verTodas = false;
  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
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
        onOrderUpdated: _cargarOrdenes,
      ),
    );
  }

  Widget _buildFiltrosBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: AppPalette.background,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Filtro Período: Hoy vs Todas
            ChoiceChip(
              label: const Text('Ventas de Hoy'),
              selected: !_verTodas,
              onSelected: (selected) {
                if (selected && _verTodas) {
                  setState(() => _verTodas = false);
                  _cargarOrdenes();
                }
              },
              selectedColor: AppPalette.primary,
              backgroundColor: AppPalette.surface,
              labelStyle: TextStyle(
                color: !_verTodas ? AppPalette.textPrimary : AppPalette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13.0,
              ),
              side: BorderSide(
                color: !_verTodas ? AppPalette.primary : Colors.white10,
              ),
            ),
            const SizedBox(width: 8.0),
            ChoiceChip(
              label: const Text('Historial Completo'),
              selected: _verTodas,
              onSelected: (selected) {
                if (selected && !_verTodas) {
                  setState(() => _verTodas = true);
                  _cargarOrdenes();
                }
              },
              selectedColor: AppPalette.primary,
              backgroundColor: AppPalette.surface,
              labelStyle: TextStyle(
                color: _verTodas ? AppPalette.textPrimary : AppPalette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13.0,
              ),
              side: BorderSide(
                color: _verTodas ? AppPalette.primary : Colors.white10,
              ),
            ),
            const SizedBox(width: 12.0),
            Container(height: 20.0, width: 1.0, color: Colors.white12),
            const SizedBox(width: 12.0),

            // Filtro por Estado: Todos
            FilterChip(
              label: const Text('Todas'),
              selected: _filtroEstado == null,
              onSelected: (_) {
                if (_filtroEstado != null) {
                  setState(() => _filtroEstado = null);
                  _cargarOrdenes();
                }
              },
              selectedColor: AppPalette.secondary.withValues(alpha: 0.2),
              backgroundColor: AppPalette.surface,
              labelStyle: TextStyle(
                color: _filtroEstado == null ? AppPalette.secondary : AppPalette.textSecondary,
                fontSize: 12.0,
                fontWeight: _filtroEstado == null ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: _filtroEstado == null ? AppPalette.secondary : Colors.white10,
              ),
            ),
            const SizedBox(width: 6.0),

            // Filtro: Reservadas
            FilterChip(
              label: const Text('Reservadas'),
              selected: _filtroEstado == 'Reservada',
              onSelected: (selected) {
                setState(() => _filtroEstado = selected ? 'Reservada' : null);
                _cargarOrdenes();
              },
              selectedColor: AppPalette.secondary.withValues(alpha: 0.2),
              backgroundColor: AppPalette.surface,
              labelStyle: TextStyle(
                color: _filtroEstado == 'Reservada' ? AppPalette.secondary : AppPalette.textSecondary,
                fontSize: 12.0,
                fontWeight: _filtroEstado == 'Reservada' ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: _filtroEstado == 'Reservada' ? AppPalette.secondary : Colors.white10,
              ),
            ),
            const SizedBox(width: 6.0),

            // Filtro: Pagadas
            FilterChip(
              label: const Text('Pagadas'),
              selected: _filtroEstado == 'Pagada',
              onSelected: (selected) {
                setState(() => _filtroEstado = selected ? 'Pagada' : null);
                _cargarOrdenes();
              },
              selectedColor: AppPalette.success.withValues(alpha: 0.2),
              backgroundColor: AppPalette.surface,
              labelStyle: TextStyle(
                color: _filtroEstado == 'Pagada' ? AppPalette.success : AppPalette.textSecondary,
                fontSize: 12.0,
                fontWeight: _filtroEstado == 'Pagada' ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: _filtroEstado == 'Pagada' ? AppPalette.success : Colors.white10,
              ),
            ),
            const SizedBox(width: 6.0),

            // Filtro: Anuladas
            FilterChip(
              label: const Text('Anuladas'),
              selected: _filtroEstado == 'Anulada',
              onSelected: (selected) {
                setState(() => _filtroEstado = selected ? 'Anulada' : null);
                _cargarOrdenes();
              },
              selectedColor: AppPalette.error.withValues(alpha: 0.2),
              backgroundColor: AppPalette.surface,
              labelStyle: TextStyle(
                color: _filtroEstado == 'Anulada' ? AppPalette.error : AppPalette.textSecondary,
                fontSize: 12.0,
                fontWeight: _filtroEstado == 'Anulada' ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: _filtroEstado == 'Anulada' ? AppPalette.error : Colors.white10,
              ),
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
              _verTodas
                  ? 'No tienes órdenes en tu historial'
                  : 'No has generado órdenes hoy',
              style: AppTypography.title.copyWith(fontSize: 18.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              _verTodas
                  ? 'Tus ventas derivadas a caja aparecerán aquí con su estado en tiempo real.'
                  : 'Las ventas creadas durante el día se listarán aquí para su seguimiento y gestión.',
              style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),
            if (!_verTodas)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.primary,
                  side: const BorderSide(color: AppPalette.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                icon: const Icon(Icons.history, size: 18.0),
                label: const Text('Ver Historial Completo'),
                onPressed: () {
                  setState(() => _verTodas = true);
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
            Text(
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
    return Scaffold(
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
              _verTodas ? 'Historial completo de ventas' : 'Ventas del día (Hoy)',
              style: AppTypography.small.copyWith(
                fontSize: 12.0,
                color: AppPalette.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppPalette.textPrimary),
            onPressed: _isLoading ? null : _cargarOrdenes,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltrosBar(),
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
                                  height: MediaQuery.of(context).size.height * 0.6,
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
          ),
        ],
      ),
    );
  }
}
