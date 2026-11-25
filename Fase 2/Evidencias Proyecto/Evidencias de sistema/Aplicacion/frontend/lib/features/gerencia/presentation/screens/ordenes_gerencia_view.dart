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
  final String? estadoInicial;
  final String? tipoActivoInicial;
  final String? periodoInicial;

  const OrdenesGerenciaView({
    super.key,
    this.idSucursalInicial,
    this.estadoInicial,
    this.tipoActivoInicial,
    this.periodoInicial,
  });

  @override
  State<OrdenesGerenciaView> createState() => OrdenesGerenciaViewState();
}

class OrdenesGerenciaViewState extends State<OrdenesGerenciaView> {
  late final TextEditingController _busquedaController;
  Timer? _debounceTimer;

  int? _idSucursal;
  String _periodo = 'hoy';
  String _estado = 'todos';
  String _metodoPago = 'todos';
  String _tipoActivo = 'todos';
  int _paginaActual = 1;

  bool _isLoading = false;
  String? _errorMessage;
  String? _codigoError;
  String? _detalleTecnicoError;
  bool _mostrarDetalleTecnico = false;
  HistorialCajaResponseModel? _data;

  /// Permite a vistas contenedoras (como [DashboardGerenciaView]) solicitar una recarga explícita.
  Future<void> refrescar({
    int? idSucursal,
    bool actualizarSucursal = false,
    bool silent = false,
  }) async {
    if (actualizarSucursal) {
      _idSucursal = idSucursal;
    }
    if (silent) {
      await refrescarSilencioso();
      return;
    }
    setState(() => _paginaActual = 1);
    await _cargarOrdenes(pagina: 1);
  }

  /// Permite refrescar las órdenes de manera silenciosa manteniendo la página actual.
  Future<void> refrescarSilencioso({
    int? pagina,
    int? idSucursal,
    bool actualizarSucursal = false,
  }) async {
    if (!mounted) return;
    if (actualizarSucursal) {
      _idSucursal = idSucursal;
    }
    final targetPage = pagina ?? _paginaActual;
    try {
      final res = await GerenciaService.obtenerHistorialOrdenes(
        idSucursal: _idSucursal,
        estado: _estado,
        periodo: _periodo,
        metodoPago: _metodoPago,
        tipoActivo: _tipoActivo,
        busqueda: _busquedaController.text.trim(),
        pagina: targetPage,
        limite: 20,
      );
      if (!mounted) return;
      setState(() {
        _data = res;
        _paginaActual = targetPage;
      });
      debugPrint('📦 [GERENCIA-ORDENES] ✅ Sincronización silenciosa completada (Pág $targetPage)');
    } catch (e) {
      debugPrint('📦 [GERENCIA-ORDENES] ⚠️ Error en refresco silencioso (ignorado): $e');
    }
  }

  /// Aplica un filtro de estado específico y recarga inmediatamente
  Future<void> aplicarFiltroEstado(String estado) async {
    setState(() {
      _estado = estado;
      _periodo = 'todos';
      _paginaActual = 1;
    });
    await _cargarOrdenes(pagina: 1);
  }

  /// Aplica el filtro de tipo de activo (ej: 'MOTORES_CAJAS') y periodo, recargando inmediatamente
  Future<void> aplicarFiltroTipoActivo(String tipoActivo, {String periodo = 'hoy'}) async {
    setState(() {
      _tipoActivo = tipoActivo;
      _periodo = periodo;
      _estado = 'todos';
      _metodoPago = 'todos';
      _busquedaController.clear();
      _paginaActual = 1;
    });
    await _cargarOrdenes(pagina: 1);
  }

  @override
  void initState() {
    super.initState();
    _idSucursal = widget.idSucursalInicial;
    if (widget.estadoInicial != null && widget.estadoInicial!.isNotEmpty) {
      _estado = widget.estadoInicial!;
      _periodo = 'todos';
    }
    if (widget.tipoActivoInicial != null && widget.tipoActivoInicial!.isNotEmpty) {
      _tipoActivo = widget.tipoActivoInicial!;
    }
    if (widget.periodoInicial != null && widget.periodoInicial!.isNotEmpty) {
      _periodo = widget.periodoInicial!;
    }
    _busquedaController = TextEditingController();
    _cargarOrdenes();
  }

  @override
  void didUpdateWidget(covariant OrdenesGerenciaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldReload = false;
    if (oldWidget.idSucursalInicial != widget.idSucursalInicial) {
      _idSucursal = widget.idSucursalInicial;
      shouldReload = true;
    }
    if (oldWidget.estadoInicial != widget.estadoInicial && widget.estadoInicial != null) {
      _estado = widget.estadoInicial!;
      _periodo = 'todos';
      shouldReload = true;
    }
    if (oldWidget.tipoActivoInicial != widget.tipoActivoInicial && widget.tipoActivoInicial != null) {
      _tipoActivo = widget.tipoActivoInicial!;
      shouldReload = true;
    }
    if (oldWidget.periodoInicial != widget.periodoInicial && widget.periodoInicial != null) {
      _periodo = widget.periodoInicial!;
      shouldReload = true;
    }
    if (shouldReload) {
      setState(() => _paginaActual = 1);
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
    debugPrint('📦 [GERENCIA-ORDENES] 🔄 Solicitando historial de órdenes (Sucursal: ${_idSucursal ?? "Todas"}, Periodo: $_periodo, Estado: $_estado, Método Pago: $_metodoPago, Tipo Activo: $_tipoActivo, Pág: $pagina)...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _codigoError = null;
      _detalleTecnicoError = null;
      _mostrarDetalleTecnico = false;
      _paginaActual = pagina;
    });

    try {
      final res = await GerenciaService.obtenerHistorialOrdenes(
        idSucursal: _idSucursal,
        estado: _estado,
        periodo: _periodo,
        metodoPago: _metodoPago,
        tipoActivo: _tipoActivo,
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
      debugPrint('📦 [GERENCIA-ORDENES] ❌ Error API al cargar órdenes: ${e.messageUser} (Código: ${e.diagnosticCode})');
      setState(() {
        _errorMessage = e.messageUser;
        _codigoError = e.diagnosticCode;
        _detalleTecnicoError = e.messageDev;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('📦 [GERENCIA-ORDENES] ❌ Error inesperado al cargar órdenes: $e');
      setState(() {
        _errorMessage = ApiService.limpiarMensajeExcepcion(e);
        _codigoError = 'GERENCIA_ORDENES_ERROR';
        _detalleTecnicoError = e.toString();
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

  void _onTipoActivoChanged(String nuevoTipo) {
    setState(() {
      _tipoActivo = nuevoTipo;
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
      _tipoActivo = 'todos';
      _paginaActual = 1;
    });
    _cargarOrdenes();
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?.items ?? [];
    // Total Consolidado en Vista: calcula con precisión el monto efectivamente recaudado/abonado
    // de las órdenes presentes en la vista (total_venta - monto_pendiente), excluyendo anuladas.
    final totalConsolidado = items.isNotEmpty
        ? items.fold<int>(0, (acc, it) {
            if (it.esAnulada) return acc;
            final recaudado = it.totalLiquidado > 0
                ? it.totalLiquidado
                : (it.totalVenta - it.montoPendiente);
            return acc + (recaudado > 0 ? recaudado : 0);
          })
        : (_data?.totalMontoConsolidado ?? 0);
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
          tipoActivoSeleccionado: _tipoActivo,
          onTipoActivoChanged: _onTipoActivoChanged,
          onLimpiar: _onLimpiarFiltros,
        ),

        const SizedBox(height: 14),

        if (_tipoActivo.toUpperCase() == 'MOTORES_CAJAS')
          _buildBannerFiltroMotoresCajas(),

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

  Widget _buildBannerFiltroMotoresCajas() {
    final periodoLabel = _periodo == 'hoy'
        ? 'Hoy'
        : (_periodo == 'mes'
            ? 'Este Mes'
            : (_periodo == 'semana' ? 'Esta Semana' : 'Histórico Completo'));

    return Container(
      key: const Key('banner_filtro_motores_cajas'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF), // Indigo 50
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)), // Indigo 200
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.precision_manufacturing_rounded,
              size: 18,
              color: Color(0xFF4338CA),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text.rich(
                  TextSpan(
                    text: 'Filtro Activo: Salidas de Motores y Cajas Inventariadas ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF312E81), // Indigo 900
                    ),
                    children: [
                      TextSpan(
                        text: '(MOT-XXXX y CAJ-XXXX)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Mostrando exclusivamente órdenes que contienen motores o transmisiones inventariadas • Periodo: $periodoLabel',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF4F46E5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const Key('btn_limpiar_filtro_banner'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4338CA),
              side: const BorderSide(color: Color(0xFFA5B4FC)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text(
              'Restablecer historial general',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: _onLimpiarFiltros,
          ),
        ],
      ),
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
          constraints: const BoxConstraints(maxWidth: 480),
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
              if (_codigoError != null && _codigoError!.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppPalette.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Código: ${_codigoError!}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                _errorMessage!,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              if (_detalleTecnicoError != null &&
                  _detalleTecnicoError!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _mostrarDetalleTecnico = !_mostrarDetalleTecnico;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      _mostrarDetalleTecnico
                          ? 'Ocultar detalle técnico ▲'
                          : 'Ver detalle técnico ▼',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                if (_mostrarDetalleTecnico) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: SelectableText(
                      _detalleTecnicoError!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Color(0xFF334155),
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ],
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
