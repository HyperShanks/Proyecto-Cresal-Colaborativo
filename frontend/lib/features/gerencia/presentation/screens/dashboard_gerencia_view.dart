// frontend/lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart
import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_error_snackbar.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/gerencia_models.dart';
import '../../services/gerencia_service.dart';
import '../widgets/kpi_card_widget.dart';
import '../widgets/metodos_pago_chart.dart';
import 'inventario_gerencia_view.dart';
import 'ordenes_gerencia_view.dart';
import 'backorders_gerencia_view.dart';

/// Enumeración de vistas principales del panel gerencial (HU-5.1 y HU-5.2).
enum VistaGerencia { dashboard, ordenes, inventario, backorders }

/// Vista principal del Dashboard Ejecutivo para Gerencia (HU-5.1).
/// Diseñé esta pantalla integrando la barra superior de filtros de sucursal,
/// la grilla superior de KPIs financieros y el trío de Bento cards para
/// métodos de pago, alertas operativas y flujo de despacho de bodega.
class DashboardGerenciaView extends StatefulWidget {
  final int? sucursalInicial;

  const DashboardGerenciaView({
    super.key,
    this.sucursalInicial,
  });

  @override
  State<DashboardGerenciaView> createState() => _DashboardGerenciaViewState();
}

class _DashboardGerenciaViewState extends State<DashboardGerenciaView>
    with SingleTickerProviderStateMixin {
  int? _sucursalSeleccionada;
  bool _cargando = false;
  String? _mensajeError;

  KpiFinancieroModel? _kpis;
  ResumenPagosModel? _pagos;
  FlujoOperativoModel? _flujo;
  String _nombreUsuario = 'Roberto Gerente';

  VistaGerencia _vistaActiva = VistaGerencia.dashboard;
  bool _sidebarOpen = true;
  bool _filtroSinTasar = false;

  late AnimationController _spinController;

  Future<void> _cerrarSesion() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _sucursalSeleccionada = widget.sucursalInicial;
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    // Libero explícitamente el controlador de animación según RULES.md
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    final nombre = await AuthService.getNombreUsuario();
    if (mounted && nombre != null && nombre.trim().isNotEmpty) {
      setState(() => _nombreUsuario = nombre);
    }
    await _cargarDashboard();
  }

  /// Cargo simultáneamente los 3 endpoints analíticos aplicando guardas de montaje.
  Future<void> _cargarDashboard({bool mostrarToast = false}) async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
      _mensajeError = null;
    });
    _spinController.repeat();

    try {
      final futures = await Future.wait([
        GerenciaService.obtenerKpis(idSucursal: _sucursalSeleccionada),
        GerenciaService.obtenerResumenPagos(idSucursal: _sucursalSeleccionada),
        GerenciaService.obtenerFlujoOperativo(idSucursal: _sucursalSeleccionada),
      ]);

      if (!mounted) return;

      setState(() {
        _kpis = futures[0] as KpiFinancieroModel;
        _pagos = futures[1] as ResumenPagosModel;
        _flujo = futures[2] as FlujoOperativoModel;
        _cargando = false;
      });
      _spinController.stop();
      _spinController.reset();

      if (mostrarToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Dashboard gerencial sincronizado exitosamente.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppPalette.success,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final errorStr = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _cargando = false;
        _mensajeError = errorStr;
      });
      _spinController.stop();
      _spinController.reset();

      CustomErrorSnackbar.mostrar(
        context,
        mensaje: errorStr,
        codigoError: 'GERENCIA_NETWORK_ERROR',
        onReintentar: () => _cargarDashboard(),
      );
    }
  }

  String _obtenerNombreSucursal(int? id) {
    if (id == null) return 'Todas las Sucursales (Consolidado)';
    if (id == 1 || id == 101) return 'Casa Matriz (Viña del Mar)';
    if (id == 2 || id == 102) return 'Patio Desarme (Limache)';
    return 'Sucursal $id';
  }

  String _formatearFechaHoy() {
    final ahora = DateTime.now();
    final dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];

    final diaNombre = dias[ahora.weekday - 1];
    final mesNombre = meses[ahora.month - 1];
    return '$diaNombre ${ahora.day} de $mesNombre de ${ahora.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.backgroundLight,
      body: Row(
        children: [
          // Sidebar Corporativo Deep Blue (#004c89 / AppPalette.tertiary)
          _buildSidebar(),

          // Área Principal (Topbar + Contenido Dinámico)
          Expanded(
            child: Column(
              children: [
                _buildTopbar(),
                Expanded(
                  child: _vistaActiva == VistaGerencia.dashboard
                      ? _buildDashboardContent()
                      : _vistaActiva == VistaGerencia.ordenes
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: OrdenesGerenciaView(
                                idSucursalInicial: _sucursalSeleccionada,
                              ),
                            )
                          : _vistaActiva == VistaGerencia.inventario
                              ? InventarioGerenciaView(
                                  idSucursalInicial: _sucursalSeleccionada,
                                  filtroSinTasarInicial: _filtroSinTasar,
                                  onStockMutado: () => _cargarDashboard(),
                                )
                              : _vistaActiva == VistaGerencia.backorders
                                  ? BackordersGerenciaView(
                                      idSucursalInicial: _sucursalSeleccionada,
                                    )
                                  : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return _cargando && _kpis == null
        ? const Center(
            child: CircularProgressIndicator(
              color: AppPalette.primary,
            ),
          )
        : _mensajeError != null && _kpis == null
            ? _buildErrorState()
            : RefreshIndicator(
                onRefresh: () => _cargarDashboard(mostrarToast: true),
                color: AppPalette.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner de Bienvenida y Fecha
                      _buildWelcomeBanner(),
                      const SizedBox(height: 20),

                      // Grid Superior de 4 KPIs
                      _buildKpiGrid(),
                      const SizedBox(height: 24),

                      // Bento Trío de Visualizaciones
                      _buildBentoSection(),
                    ],
                  ),
                ),
              );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarOpen ? 240 : 68,
      decoration: const BoxDecoration(
        color: AppPalette.tertiary,
        border: Border(
          right: BorderSide(
            color: Colors.white12,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header del Sidebar con Llave Mecánica Oficial
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.build_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (_sidebarOpen) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'PANEL EJECUTIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Control Ejecutivo V1',
                          style: TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Navegación de las 4 Vistas Principales (HU 5.1 a 5.4)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              children: [
                if (_sidebarOpen)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'SUPERVISIÓN Y CONTROL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                // 1. Dashboard Ejecutivo
                _buildSidebarNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard Ejecutivo',
                  isSelected: _vistaActiva == VistaGerencia.dashboard,
                  onTap: () {
                    if (_vistaActiva != VistaGerencia.dashboard) {
                      setState(() => _vistaActiva = VistaGerencia.dashboard);
                    }
                  },
                ),

                const SizedBox(height: 6),

                // 2. Historial de Órdenes
                _buildSidebarNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Historial de Órdenes',
                  isSelected: _vistaActiva == VistaGerencia.ordenes,
                  onTap: () {
                    if (_vistaActiva != VistaGerencia.ordenes) {
                      setState(() => _vistaActiva = VistaGerencia.ordenes);
                    }
                  },
                ),

                const SizedBox(height: 6),

                // 3. Maestro de Inventario y Tasación
                _buildSidebarNavItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Inventario y Tasación',
                  isSelected: _vistaActiva == VistaGerencia.inventario,
                  badgeText: (_flujo?.cuellosBotellaPaletizados ?? 0) > 0
                      ? '${_flujo!.cuellosBotellaPaletizados}'
                      : null,
                  onTap: () {
                    if (_vistaActiva != VistaGerencia.inventario) {
                      setState(() {
                        _vistaActiva = VistaGerencia.inventario;
                        _filtroSinTasar = false;
                      });
                    }
                  },
                ),

                const SizedBox(height: 6),

                // 4. Visor Centralizado de Backorders
                _buildSidebarNavItem(
                  icon: Icons.bookmark_added_rounded,
                  label: 'Visor de Backorders',
                  isSelected: _vistaActiva == VistaGerencia.backorders,
                  badgeText: null,
                  onTap: () {
                    if (_vistaActiva != VistaGerencia.backorders) {
                      setState(() {
                        _vistaActiva = VistaGerencia.backorders;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // Footer del Sidebar: Perfil Gerencial y Cerrar Sesión
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
              color: Colors.black12,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Text(
                    _nombreUsuario.isNotEmpty
                        ? _nombreUsuario[0].toUpperCase()
                        : 'G',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_sidebarOpen) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nombreUsuario,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'gerente@cresal.cl',
                          style: TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFFCA5A5),
                      size: 18,
                    ),
                    tooltip: 'Cerrar sesión',
                    onPressed: _cerrarSesion,
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFFCA5A5),
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Cerrar sesión',
                    onPressed: _cerrarSesion,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF7DD3FC) : Colors.white70,
            ),
            if (_sidebarOpen) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Color(0xFFBAE6FD),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopbar() {
    final cuellosBotella = _flujo?.cuellosBotellaPaletizados ?? 0;
    final saldoPendiente = _flujo?.alertasSaldoPendiente ?? 0;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppPalette.borderLight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lado Izquierdo: Botón Colapsar Menú + Identidad Ejecutiva
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _sidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                    color: const Color(0xFF0F172A),
                    size: 22,
                  ),
                  tooltip: _sidebarOpen ? 'Colapsar menú lateral' : 'Expandir menú lateral',
                  onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppPalette.tertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _vistaActiva == VistaGerencia.dashboard
                        ? Icons.dashboard_customize
                        : _vistaActiva == VistaGerencia.ordenes
                            ? Icons.receipt_long
                            : _vistaActiva == VistaGerencia.inventario
                                ? Icons.inventory_2
                                : Icons.bookmark_added_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _vistaActiva == VistaGerencia.dashboard
                            ? 'CRESAL GERENCIA'
                            : _vistaActiva == VistaGerencia.ordenes
                                ? 'HISTORIAL DE ÓRDENES'
                                : _vistaActiva == VistaGerencia.inventario
                                    ? 'MAESTRO DE INVENTARIO Y TASACIÓN'
                                    : 'VISOR CENTRALIZADO DE RESERVAS Y BACKORDERS',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _vistaActiva == VistaGerencia.dashboard
                            ? 'Dashboard Ejecutivo y Pulso Operativo'
                            : _vistaActiva == VistaGerencia.ordenes
                                ? 'Historial y Auditoría de Órdenes'
                                : _vistaActiva == VistaGerencia.inventario
                                    ? 'Control de stock físico, ubicaciones en rack y fijación de precios comerciales'
                                    : 'Monitoreo de compras en verde y asignación automática de vehículos donantes',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Lado Derecho: Selector de Sucursal, Botón Refrescar y Campana
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector Dropdown de Sucursal (Tarjeta Ejecutiva Foto 4)
              _buildSelectorSucursales(),
              const SizedBox(width: 10),

              // Botón Refrescar con Spin
              OutlinedButton.icon(
                onPressed: _cargando
                    ? null
                    : () => _cargarDashboard(mostrarToast: true),
                icon: RotationTransition(
                  turns: _spinController,
                  child: const Icon(Icons.sync, size: 16),
                ),
                label: Text(
                  _cargando ? 'Actualizando...' : 'Actualizar',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: AppPalette.borderLight),
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Campana de Notificaciones Ejecutivas con Badge
              PopupMenuButton<String>(
                tooltip: 'Alertas y Notificaciones Ejecutivas',
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppPalette.borderLight),
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppPalette.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppPalette.borderLight),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF0F172A),
                        size: 20,
                      ),
                    ),
                    if (cuellosBotella > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$cuellosBotella',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'tasacion',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFB923C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.hourglass_top,
                            color: Color(0xFFEA580C),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$cuellosBotella repuestos sin tasar',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'En espera de fijación de precio en bodega',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'ordenes',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.pending_actions,
                            color: Color(0xFFB45309),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$saldoPendiente órdenes con saldo retenido',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'Retiro condicionado a liquidación total',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'tasacion') {
                    setState(() {
                      _vistaActiva = VistaGerencia.inventario;
                      _filtroSinTasar = true;
                    });
                  } else if (val == 'ordenes') {
                    setState(() {
                      _vistaActiva = VistaGerencia.ordenes;
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorSucursales() {
    final Map<int?, ({String titulo, String subtitulo, IconData icon})> sucursales = {
      null: (
        titulo: 'Todas las Sucursales (Consolidado)',
        subtitulo: 'Consolidado general',
        icon: Icons.domain_rounded,
      ),
      1: (
        titulo: 'Sucursal 1: Casa Matriz (Viña)',
        subtitulo: 'Viña del Mar (Mesón & Ventas)',
        icon: Icons.storefront_rounded,
      ),
      2: (
        titulo: 'Sucursal 2: Patio Desarme (Limache)',
        subtitulo: 'Limache (Desarme & Bodega)',
        icon: Icons.warehouse_rounded,
      ),
    };

    final actual = sucursales[_sucursalSeleccionada] ?? sucursales[null]!;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<int?>(
        tooltip: 'Seleccionar sucursal de auditoría',
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        offset: const Offset(0, 42),
        initialValue: _sucursalSeleccionada,
        onSelected: (nuevoId) {
          setState(() => _sucursalSeleccionada = nuevoId);
          if (_vistaActiva == VistaGerencia.dashboard) {
            _cargarDashboard();
          }
        },
        itemBuilder: (context) {
          return sucursales.entries.map((entry) {
            final id = entry.key;
            final data = entry.value;
            final isSelected = id == _sucursalSeleccionada;

            return PopupMenuItem<int?>(
              value: id,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0F9FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      data.icon,
                      size: 20,
                      color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.titulo,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.subtitulo,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Color(0xFF0284C7),
                      )
                    else
                      const SizedBox(width: 18),
                  ],
                ),
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 16,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Sucursal: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                actual.titulo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buenos días, $_nombreUsuario',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Resumen operativo de hoy • ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _formatearFechaHoy(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const Text(
                          ' • Filtro: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _obtenerNombreSucursal(_sucursalSeleccionada),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppPalette.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppPalette.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle,
                          size: 14, color: AppPalette.success),
                      SizedBox(width: 6),
                      Text(
                        'Cajas en Línea',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiGrid() {
    final kpis = _kpis ??
        const KpiFinancieroModel(
          ventasDelDia: 0,
          transaccionesHoy: 0,
          acumuladoMensualMtd: 0,
          ticketPromedio: 0,
        );

    final facturacionFmt = CurrencyFormatter.formatCLP(kpis.ventasDelDia);
    final mtdFmt = CurrencyFormatter.formatCLP(kpis.acumuladoMensualMtd);
    final ticketFmt = CurrencyFormatter.formatCLP(kpis.ticketPromedio.toInt());
    final margenFmt =
        '${(kpis.margenBruto ?? 64.8).toStringAsFixed(1)}%';

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 700) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1100) {
          crossAxisCount = 2;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.7,
          children: [
            // KPI 1: Facturación Hoy
            KpiCardWidget(
              titulo: 'Facturación Hoy',
              valor: facturacionFmt,
              badgeTexto: '+14.2%',
              badgeColor: AppPalette.success,
              subtitulo: 'Meta Diaria: \$5.0M',
              icono: Icons.payments,
            ),

            // KPI 2: Acumulado Mes (MTD)
            KpiCardWidget(
              titulo: 'Acumulado Mes (MTD)',
              valor: mtdFmt,
              badgeTexto: '+8.5%',
              badgeColor: AppPalette.success,
              subtitulo:
                  'Avance: ${kpis.transaccionesHoy} órdenes liquidadas',
              icono: Icons.calendar_month,
              valorColor: AppPalette.tertiary,
            ),

            // KPI 3: Ticket Promedio
            KpiCardWidget(
              titulo: 'Ticket Promedio',
              valor: ticketFmt,
              badgeTexto: '+5.1%',
              badgeColor: AppPalette.primary,
              subtitulo: 'Promedio por orden de mesón',
              icono: Icons.receipt_long,
            ),

            // KPI 4: Margen Bruto Desarme
            KpiCardWidget(
              titulo: 'Margen Bruto Desarme',
              valor: margenFmt,
              badgeTexto: 'Óptimo',
              badgeColor: AppPalette.success,
              subtitulo: 'Costo adquisición amortizado',
              icono: Icons.trending_up,
              valorColor: AppPalette.success,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBentoSection() {
    final pagos = _pagos ??
        const ResumenPagosModel(
          efectivoFisico: 0,
          canalesElectronicos: 0,
          desglose: [],
        );
    final flujo = _flujo ??
        const FlujoOperativoModel(
          enPreparacion: 0,
          listosMostrador: 0,
          enviadosCourier: 0,
          alertasSaldoPendiente: 0,
          cuellosBotellaPaletizados: 0,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1050;

        if (!isDesktop) {
          return Column(
            children: [
              SizedBox(
                height: 380,
                child: MetodosPagoChart(resumen: pagos),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 380,
                child: _buildBentoAlertas(flujo),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 380,
                child: _buildBentoFlujoDespacho(flujo),
              ),
            ],
          );
        }

        return SizedBox(
          height: 390,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bento 1: Medios de Pago
              Expanded(
                flex: 4,
                child: MetodosPagoChart(resumen: pagos),
              ),
              const SizedBox(width: 16),

              // Bento 2: Control de Riesgo & Alertas
              Expanded(
                flex: 3,
                child: _buildBentoAlertas(flujo),
              ),
              const SizedBox(width: 16),

              // Bento 3: Flujo de Despacho en Bodega
              Expanded(
                flex: 3,
                child: _buildBentoFlujoDespacho(flujo),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBentoAlertas(FlujoOperativoModel flujo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CONTROL DE RIESGO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Alertas Operativas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7), // Amber 100
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${flujo.alertasSaldoPendiente + flujo.cuellosBotellaPaletizados} Activas',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Órdenes con saldo retenido y piezas sin tasar',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),

              // Alerta 1: Saldos por Cobrar (Clic para auditar órdenes)
              InkWell(
                onTap: () {
                  setState(() => _vistaActiva = VistaGerencia.ordenes);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.pending_actions,
                          color: Color(0xFFB45309),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Saldos por Cobrar',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF78350F),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${flujo.alertasSaldoPendiente} órdenes',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Retiro en mesón condicionado al pago total.',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Alerta 2: Cuellos de Botella de Tasación (Clic para tasar stock)
              InkWell(
                onTap: () {
                  setState(() {
                    _vistaActiva = VistaGerencia.inventario;
                    _filtroSinTasar = true;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB923C).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.hourglass_top,
                          color: Color(0xFFC2410C),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Cuello de Botella Tasación',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF7C2D12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${flujo.cuellosBotellaPaletizados} piezas',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFC2410C),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Paletizados sin precio fijado por Jefe de Ventas.',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9A3412),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Footer Bento 2
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Nivel de Riesgo Operativo:',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Controlado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoFlujoDespacho(FlujoOperativoModel flujo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'BODEGA & SALIDAS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Flujo de Despacho',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppPalette.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.circle, size: 8, color: AppPalette.success),
                          SizedBox(width: 4),
                          Text(
                            'Flujo Normal',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Seguimiento en vivo de preparación, retiro y courier',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),

                // 3 Etapas Logísticas
                _buildEtapaFila(
                  numero: '1',
                  titulo: 'En Preparación (Rack)',
                  descripcion: 'Piezas bajando para embalaje',
                  conteo: flujo.enPreparacion,
                  badgeBg: const Color(0xFFFEF3C7),
                  badgeTextColor: const Color(0xFF92400E),
                ),
                const SizedBox(height: 10),

                _buildEtapaFila(
                  numero: '2',
                  titulo: 'Listo Mostrador',
                  descripcion: 'Esperando retiro cliente',
                  conteo: flujo.listosMostrador,
                  badgeBg: const Color(0xFFDCFCE7),
                  badgeTextColor: const Color(0xFF166534),
                ),
                const SizedBox(height: 10),

                _buildEtapaFila(
                  numero: '3',
                  titulo: 'Despacho Courier',
                  descripcion: 'Starken & Chilexpress en ruta',
                  conteo: flujo.enviadosCourier,
                  badgeBg: const Color(0xFFE0F2FE),
                  badgeTextColor: const Color(0xFF075985),
                ),
              ],
            ),

            // Footer Bento 3
            const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(
                  child: Text(
                    'Tiempo prom. preparación:',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '24 minutos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtapaFila({
    required String numero,
    required String titulo,
    required String descripcion,
    required int conteo,
    required Color badgeBg,
    required Color badgeTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    numero,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: badgeTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        descripcion,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              conteo.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 56,
              color: AppPalette.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'No fue posible cargar el Dashboard Ejecutivo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _mensajeError ?? 'Ocurrió un error al consultar el servidor.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _cargarDashboard(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
