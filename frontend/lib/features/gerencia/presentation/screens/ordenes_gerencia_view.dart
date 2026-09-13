// frontend/lib/features/gerencia/presentation/screens/ordenes_gerencia_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../caja/models/historial_caja_model.dart';
import '../../services/gerencia_service.dart';
import '../widgets/auditoria_detalle_dialog.dart';
import '../widgets/auditoria_tabla_view.dart';
import '../widgets/panel_filtros_avanzados.dart';

/// Vista de Auditoría y Visor Centralizado de Órdenes de Venta (HU-5.2).
/// Diseñé esta vista como un espejo de auditoría de solo lectura para Gerencia,
/// inspirada fielmente en la Pantalla 2 de `prototipo_gerencia_v1.html`.
/// Integra filtros multidimensionales en 1 fila, resumen de consolidado global,
/// tabla densa de órdenes y modal 360° de trazabilidad forense.
class OrdenesGerenciaView extends StatefulWidget {
  final int? idSucursalInicial;

  const OrdenesGerenciaView({
    super.key,
    this.idSucursalInicial,
  });

  @override
  State<OrdenesGerenciaView> createState() => _OrdenesGerenciaViewState();
}

class _OrdenesGerenciaViewState extends State<OrdenesGerenciaView> {
  late final TextEditingController _busquedaController;
  Timer? _debounceTimer;

  int? _idSucursal;
  String _periodo = 'hoy';
  String _estado = 'todos';
  String _metodoPago = 'todos';
  int _paginaActual = 1;

  bool _isLoading = false;
  String? _errorMessage;
  HistorialCajaResponseModel? _data;

  @override
  void initState() {
    super.initState();
    _idSucursal = widget.idSucursalInicial;
    _busquedaController = TextEditingController();
    _cargarOrdenes();
  }

  @override
  void didUpdateWidget(covariant OrdenesGerenciaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idSucursalInicial != widget.idSucursalInicial) {
      setState(() {
        _idSucursal = widget.idSucursalInicial;
        _paginaActual = 1;
      });
      _cargarOrdenes();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  /// Consulto las órdenes aplicando los criterios multidimensionales actuales.
  Future<void> _cargarOrdenes({int pagina = 1}) async {
    debugPrint('📦 [GERENCIA-ORDENES] 🔄 Solicitando historial de órdenes (Sucursal: ${_idSucursal ?? "Todas"}, Periodo: $_periodo, Estado: $_estado, Método Pago: $_metodoPago, Pág: $pagina)...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _paginaActual = pagina;
    });

    try {
      final res = await GerenciaService.obtenerHistorialOrdenes(
        idSucursal: _idSucursal,
        estado: _estado,
        periodo: _periodo,
        metodoPago: _metodoPago,
        busqueda: _busquedaController.text.trim(),
        pagina: _paginaActual,
        limite: 20,
      );

      if (!mounted) return;

      final totalReg = res.totalRegistros;
      final totalPags = res.totalPaginas;
      final totalVentas = res.resumenCuadre.totalRecaudado;
      final totalTrans = res.resumenCuadre.totalOrdenesPagadas;
      debugPrint('📦 [GERENCIA-ORDENES] ✅ OK 200 - Órdenes cargadas exitosamente:');
      debugPrint('   • Mostrando ${res.items.length} órdenes en página $_paginaActual de $totalPags (Total global: $totalReg)');
      debugPrint('   • Consolidado financiero periodo: \$$totalVentas ($totalTrans órdenes pagadas)');

      setState(() {
        _data = res;
        _isLoading = false;
      });
    } on CustomApiException catch (e) {
      if (!mounted) return;
      debugPrint('📦 [GERENCIA-ORDENES] ❌ Error API al cargar órdenes: ${e.messageUser} (Código: ${e.errorCode})');
      setState(() {
        _errorMessage = e.messageUser;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('📦 [GERENCIA-ORDENES] ❌ Error inesperado al cargar órdenes: $e');
      setState(() {
        _errorMessage =
            'Ocurrió un error inesperado al cargar las órdenes. Intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  void _onBusquedaChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _cargarOrdenes(pagina: 1);
    });
  }

  void _onPeriodoChanged(String nuevoPeriodo) {
    setState(() {
      _periodo = nuevoPeriodo;
      _paginaActual = 1;
    });
    _cargarOrdenes();
  }

  void _onEstadoChanged(String nuevoEstado) {
    setState(() {
      _estado = nuevoEstado;
      _paginaActual = 1;
    });
    _cargarOrdenes();
  }

  void _onMetodoPagoChanged(String nuevoMetodo) {
    setState(() {
      _metodoPago = nuevoMetodo;
      _paginaActual = 1;
    });
    _cargarOrdenes();
  }

  void _onLimpiarFiltros() {
    _debounceTimer?.cancel();
    _busquedaController.clear();
    setState(() {
      _periodo = 'hoy';
      _estado = 'todos';
      _metodoPago = 'todos';
      _paginaActual = 1;
    });
    _cargarOrdenes();
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?.items ?? [];
    final totalConsolidado = _data?.totalMontoConsolidado ?? 0;
    final totalRegistros = _data?.totalRegistros ?? items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. BARRA DE FILTROS MULTIDIMENSIONALES (HU-5.2) ──
        PanelFiltrosAvanzados(
          busquedaController: _busquedaController,
          onBusquedaChanged: _onBusquedaChanged,
          periodoSeleccionado: _periodo,
          onPeriodoChanged: _onPeriodoChanged,
          estadoSeleccionado: _estado,
          onEstadoChanged: _onEstadoChanged,
          metodoPagoSeleccionado: _metodoPago,
          onMetodoPagoChanged: _onMetodoPagoChanged,
          onLimpiar: _onLimpiarFiltros,
        ),

        const SizedBox(height: 14),

        // ── 2. TABLA FORENSE DE AUDITORÍA CON 10 COLUMNAS E ÍCONOS DEL MOCKUP ──
        Expanded(
          child: _buildContenidoPrincipal(
            items,
            totalRegistros: totalRegistros,
            totalConsolidado: totalConsolidado,
          ),
        ),
      ],
    );
  }

  Widget _buildContenidoPrincipal(
    List<HistorialOrdenItemModel> items, {
    required int totalRegistros,
    required int totalConsolidado,
  }) {
    if (_isLoading && _data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppPalette.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppPalette.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPalette.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppPalette.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _cargarOrdenes(pagina: _paginaActual),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return AuditoriaTablaView(
      items: items,
      paginaActual: _paginaActual,
      totalPaginas: _data?.totalPaginas ?? 1,
      totalRegistros: totalRegistros,
      totalConsolidado: totalConsolidado,
      onCambiarPagina: (nuevaPagina) => _cargarOrdenes(pagina: nuevaPagina),
      onVerDetalle: (orden) => AuditoriaDetalleDialog.show(context, orden),
    );
  }
}
