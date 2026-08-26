import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../../services/caja_service.dart';
import '../providers/historial_caja_provider.dart';
import '../widgets/historial_metricas_panel.dart';
import '../widgets/historial_tabla_view.dart';
import '../widgets/detalle_auditoria_dialog.dart';
import '../widgets/filtro_rango_fechas_dialog.dart';

/// Pantalla principal para el Historial de Órdenes y Auditoría de Caja con Filtros (SPEC-HU-4.5 / CRES-217).
class HistorialCajaScreen extends StatefulWidget {
  final HistorialCajaProvider? provider;
  final int? sucursalId;

  const HistorialCajaScreen({
    super.key,
    this.provider,
    this.sucursalId,
  });

  @override
  State<HistorialCajaScreen> createState() => _HistorialCajaScreenState();
}

class _HistorialCajaScreenState extends State<HistorialCajaScreen> {
  late final HistorialCajaProvider _provider;
  bool _providerInterno = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.provider != null) {
      _provider = widget.provider!;
      _providerInterno = false;
      _searchController.text = _provider.state.busqueda;
    } else {
      final sucId = widget.sucursalId ?? 1;
      _provider = HistorialCajaProvider(
        cajaService: CajaService(),
        sucursalId: sucId,
        autoCargar: false,
      );
      _providerInterno = true;
      _initAsync();
    }
  }

  Future<void> _initAsync() async {
    final sucursalId = await AuthService.getSucursalId();
    if (!mounted) return;
    if (sucursalId != null && sucursalId != _provider.sucursalId) {
      // Re-instanciar con la sucursal del token
    }
    _provider.cargarHistorial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_providerInterno) {
      _provider.dispose();
    }
    super.dispose();
  }

  Future<void> _abrirDialogoRangoFechas() async {
    final res = await FiltroRangoFechasDialog.show(
      context,
      fechaDesde: _provider.state.fechaDesde,
      fechaHasta: _provider.state.fechaHasta,
    );

    if (!mounted || res == null) return;
    _provider.aplicarRangoFechas(res['desde']!, res['hasta']!);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final state = _provider.state;

        return Container(
          color: AppPalette.backgroundLight,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. BARRA DE PERÍODOS Y FILTROS RÁPIDOS ──
              _buildBarraPeriodos(state),
              const SizedBox(height: 14),

              // ── 2. BARRA DE BÚSQUEDA Y FILTROS DESPLEGABLES ──
              _buildBarraBusquedaFiltros(state),
              const SizedBox(height: 16),

              // ── 3. PANEL DE MÉTRICAS DE ARQUEO / CUADRE ──
              if (state.data != null)
                HistorialMetricasPanel(resumen: state.data!.resumenCuadre),
              const SizedBox(height: 16),

              // ── 4. CONTENIDO PRINCIPAL (TABLA / LOADING / ERROR / ZERO STATE) ──
              Expanded(
                child: _buildCuerpoPrincipal(state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBarraPeriodos(HistorialCajaState state) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          _buildPeriodoButton(
            label: 'Hoy',
            isSelected: state.periodo == PeriodoHistorial.hoy,
            onTap: () => _provider.cambiarPeriodo(PeriodoHistorial.hoy),
          ),
          const SizedBox(width: 4),
          _buildPeriodoButton(
            label: 'Esta Semana',
            isSelected: state.periodo == PeriodoHistorial.estaSemana,
            onTap: () => _provider.cambiarPeriodo(PeriodoHistorial.estaSemana),
          ),
          const SizedBox(width: 4),
          _buildPeriodoButton(
            label: 'Este Mes',
            isSelected: state.periodo == PeriodoHistorial.esteMes,
            onTap: () => _provider.cambiarPeriodo(PeriodoHistorial.esteMes),
          ),
          const SizedBox(width: 4),
          _buildPeriodoButton(
            label: state.periodo == PeriodoHistorial.rango &&
                    state.fechaDesde != null &&
                    state.fechaHasta != null
                ? 'Rango: ${state.fechaDesde} a ${state.fechaHasta}'
                : 'Rango Personalizado...',
            isSelected: state.periodo == PeriodoHistorial.rango,
            icon: Icons.calendar_month_rounded,
            onTap: _abrirDialogoRangoFechas,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodoButton({
    required String label,
    required bool isSelected,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppPalette.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : AppPalette.textSecondaryLight,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.small.copyWith(
                    color: isSelected ? Colors.white : AppPalette.textSecondaryLight,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarraBusquedaFiltros(HistorialCajaState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          // Buscador con debounce
          Expanded(
            flex: 5,
            child: TextField(
              controller: _searchController,
              style: AppTypography.body.copyWith(fontSize: 13),
              onChanged: (val) => _provider.actualizarBusqueda(val),
              decoration: InputDecoration(
                hintText: 'Buscar por Folio (ORD-), RUT, Cliente, Vendedor...',
                hintStyle: AppTypography.small.copyWith(
                  color: AppPalette.textSecondaryLight,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppPalette.textSecondaryLight,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _provider.limpiarBusqueda();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppPalette.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppPalette.neutral.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppPalette.neutral.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppPalette.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Filtro de Estado
          Expanded(
            flex: 3,
            child: _buildDropdown(
              label: 'Estado:',
              value: state.estadoOrden,
              items: [
                _buildDropdownItem('TODOS', 'Todos los Estados'),
                _buildDropdownItem('Pagada', 'Pagada'),
                _buildDropdownItem('Despachada', 'Despachada'),
                _buildDropdownItem('Reservada', 'Reservada'),
                _buildDropdownItem('Anulada', 'Anulada'),
              ],
              onChanged: (val) {
                if (val != null) _provider.cambiarFiltroEstado(val);
              },
            ),
          ),
          const SizedBox(width: 12),

          // Filtro de Método de Pago
          Expanded(
            flex: 3,
            child: _buildDropdown(
              label: 'Método:',
              value: state.metodoPago,
              items: [
                _buildDropdownItem('TODOS', 'Todos los Métodos'),
                _buildDropdownItem('Efectivo', 'Efectivo'),
                _buildDropdownItem('Débito', 'Débito'),
                _buildDropdownItem('Crédito', 'Crédito'),
                _buildDropdownItem('Transferencia', 'Transferencia'),
                _buildDropdownItem('Cheque', 'Cheque'),
              ],
              onChanged: (val) {
                if (val != null) _provider.cambiarFiltroMetodo(val);
              },
            ),
          ),
          const SizedBox(width: 10),

          // Botón de Sincronización / Refresco
          Container(
            decoration: BoxDecoration(
              color: AppPalette.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppPalette.neutral.withValues(alpha: 0.25),
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: AppPalette.neutral,
              ),
              tooltip: 'Actualizar historial',
              onPressed: () => _provider.cargarHistorial(),
            ),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String value, String text) {
    return DropdownMenuItem<String>(
      value: value,
      child: Text(
        text,
        style: AppTypography.body.copyWith(
          color: AppPalette.textPrimaryLight,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.25),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppPalette.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppPalette.neutral,
            size: 20,
          ),
          style: AppTypography.body.copyWith(
            color: AppPalette.textPrimaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCuerpoPrincipal(HistorialCajaState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppPalette.primary,
        ),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: AppPalette.error,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: AppTypography.body.copyWith(color: AppPalette.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reintentar'),
                onPressed: () => _provider.cargarHistorial(),
              ),
            ],
          ),
        ),
      );
    }

    if (state.data == null || state.data!.items.isEmpty) {
      return _buildZeroState(state);
    }

    return HistorialTablaView(
      items: state.data!.items,
      paginaActual: state.paginaActual,
      totalPaginas: state.data!.totalPaginas,
      onCambiarPagina: (pag) => _provider.cargarHistorial(pagina: pag),
      onVerDetalle: (orden) => DetalleAuditoriaDialog.show(context, orden),
    );
  }

  Widget _buildZeroState(HistorialCajaState state) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppPalette.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppPalette.neutral.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 52,
              color: AppPalette.neutral.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'No se encontraron órdenes en este período o filtro',
              style: AppTypography.title.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppPalette.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pruebe seleccionando otro período contable o limpiando la búsqueda.',
              style: AppTypography.small.copyWith(
                color: AppPalette.textSecondaryLight,
              ),
            ),
            if (state.tieneFiltrosActivos) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.primary,
                  side: const BorderSide(color: AppPalette.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Restablecer Filtros a Hoy'),
                onPressed: () {
                  _searchController.clear();
                  _provider.limpiarFiltros();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
