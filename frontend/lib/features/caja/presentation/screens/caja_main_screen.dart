import 'package:flutter/material.dart';
import '../../../../core/routes/route_observer.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/widgets/cresal_logo.dart';
import '../../../auth/services/auth_service.dart';
import '../../../tickets/presentation/widgets/soporte_desktop_view.dart';
import '../providers/caja_provider.dart';
import '../widgets/caja_drawer.dart';
import '../widgets/bandeja_cobros_panel.dart';
import '../widgets/panel_detalle_cobro.dart';
import 'historial_caja_screen.dart';
import '../../../../core/services/silent_polling_manager.dart';

/// Contenedor principal de escritorio para el Módulo de Caja (CRES-213 / CRES-214).
/// Implementa Sidebar Dinámico Colapsable (256px / 80px) y Grid 4/12 + 8/12 Master-Detail.
class CajaMainScreen extends StatefulWidget {
  final CajaProvider? provider;

  const CajaMainScreen({
    super.key,
    this.provider,
  });

  @override
  State<CajaMainScreen> createState() => _CajaMainScreenState();
}

class _CajaMainScreenState extends State<CajaMainScreen> with RouteAware {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HistorialCajaScreenState> _historialKey =
      GlobalKey<HistorialCajaScreenState>();
  late final CajaProvider _cajaProvider;
  bool _providerInterno = false;

  bool _sidebarOpen = true;
  int _selectedNavIndex = 0; // 0: Caja, 1: Historial
  String _cajeraNombre = AuthService.cachedUser != null && AuthService.cachedUser!.nombres.isNotEmpty
      ? '${AuthService.cachedUser!.nombres} ${AuthService.cachedUser!.apellidos}'.trim()
      : 'Operario de Caja';
  String _sucursalNombre = 'Sucursal Activa';
  int _idSucursal = AuthService.cachedUser?.idSucursal ?? 1;
  SilentPollingManager? _cajaPollingManager;

  @override
  void initState() {
    super.initState();

    if (widget.provider != null) {
      _cajaProvider = widget.provider!;
      _providerInterno = false;
    } else {
      _cajaProvider = CajaProvider();
      _providerInterno = true;
    }

    _cargarDatosCajera();

    _cajaPollingManager = SilentPollingManager(
      interval: const Duration(seconds: 12),
      debugLabel: 'CajaPolling',
      shouldPause: () =>
          _selectedNavIndex != 0 ||
          _cajaProvider.isProcesandoCobro ||
          _cajaProvider.pagosDivididos.isNotEmpty,
      onPoll: () async {
        if (mounted && _selectedNavIndex == 0) {
          await _cajaProvider.cargarCobrosPendientesSilencioso(
            sucursalId: _idSucursal,
          );
        }
      },
    )..start();
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
    if (_selectedNavIndex == 0) {
      _cajaProvider.cargarCobrosPendientesSilencioso(sucursalId: _idSucursal);
    } else if (_selectedNavIndex == 1) {
      _historialKey.currentState?.refrescar();
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _cajaPollingManager?.dispose();
    if (_providerInterno) {
      _cajaProvider.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatosCajera() async {
    final nombre = await AuthService.getNombreUsuario();
    final sucursal = await AuthService.getNombreSucursal();
    final sucursalId = await AuthService.getSucursalId();

    if (!mounted) return;

    setState(() {
      if (nombre != null && nombre.isNotEmpty) {
        _cajeraNombre = nombre;
      }
      if (sucursal != null && sucursal.isNotEmpty) {
        _sucursalNombre = sucursal;
      }
      if (sucursalId != null) {
        _idSucursal = sucursalId;
      }
    });

    _cajaProvider.cargarCobrosPendientes(sucursalId: _idSucursal);
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppPalette.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppPalette.neutral.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppPalette.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppPalette.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Cerrar Sesión',
                style: AppTypography.title.copyWith(
                  color: AppPalette.textPrimaryLight,
                ),
              ),
            ],
          ),
          content: Text(
            '¿Está seguro de que desea cerrar la sesión del turno de caja actual?',
            style: AppTypography.body.copyWith(
              color: AppPalette.textPrimaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'CANCELAR',
                style: AppTypography.button.copyWith(
                  color: AppPalette.textSecondaryLight,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'CERRAR SESIÓN',
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cajaProvider,
      builder: (context, _) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppPalette.backgroundLight,
          drawer: CajaDrawer(
            selectedIndex: _selectedNavIndex,
            onSectionSelected: (index) {
              setState(() {
                _selectedNavIndex = index;
              });
              if (index == 0) {
                _cajaProvider.cargarCobrosPendientes(sucursalId: _idSucursal);
              } else if (index == 1) {
                _historialKey.currentState?.refrescar();
              }
            },
          ),
          body: SafeArea(
            child: Row(
              children: [
                // ── 1. SIDEBAR DINÁMICO COLAPSABLE (256px / 80px) ──
                _buildSidebar(),

                // ── 2. ÁREA DE CONTENIDO PRINCIPAL ──
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedNavIndex.clamp(0, 2),
                          children: [
                            _buildBandejaCobrosView(),
                            _buildHistorialPagosView(),
                            const SoporteDesktopView(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    final width = _sidebarOpen ? 256.0 : 80.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: width,
      clipBehavior: Clip.hardEdge,
      color: AppPalette.tertiary,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              // Logo CRESAL
              Container(
                padding: EdgeInsets.fromLTRB(
                  _sidebarOpen ? 20 : 12,
                  24,
                  _sidebarOpen ? 20 : 12,
                  20,
                ),
            alignment: _sidebarOpen ? Alignment.centerLeft : Alignment.center,
            child: _sidebarOpen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'CRESAL',
                              style: AppTypography.headline.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'MÓDULO DE CAJA',
                        style: AppTypography.small.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  )
                : const CresalLogo(
                    size: 40,
                    showGlow: false,
                  ),
          ),

          Divider(
            color: Colors.white.withValues(alpha: 0.15),
            height: 1,
          ),

          // Navegación Vertical
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
              children: [
                _buildSidebarItem(
                  icon: Icons.point_of_sale_rounded,
                  title: 'Caja',
                  subtitle: 'Bandeja de Cobros',
                  isSelected: _selectedNavIndex == 0,
                  onTap: () {
                    setState(() {
                      _selectedNavIndex = 0;
                    });
                    if (_cajaProvider.cobros.isEmpty) {
                      _cajaProvider.cargarCobrosPendientes(sucursalId: _idSucursal);
                    } else {
                      _cajaProvider.cargarCobrosPendientesSilencioso(sucursalId: _idSucursal);
                    }
                  },
                ),
                const SizedBox(height: 6),
                _buildSidebarItem(
                  icon: Icons.history_rounded,
                  title: 'Historial',
                  subtitle: 'Historial de Pagos',
                  isSelected: _selectedNavIndex == 1,
                  onTap: () {
                    setState(() {
                      _selectedNavIndex = 1;
                    });
                    _historialKey.currentState?.refrescarSilencioso();
                  },
                ),
                const SizedBox(height: 6),
                _buildSidebarItem(
                  icon: Icons.contact_support_rounded,
                  title: 'Soporte',
                  subtitle: 'Tickets de Soporte',
                  isSelected: _selectedNavIndex == 2,
                  onTap: () {
                    setState(() {
                      _selectedNavIndex = 2;
                    });
                  },
                ),
              ],
            ),
          ),

          Divider(
            color: Colors.white.withValues(alpha: 0.15),
            height: 1,
          ),

            // Footer de Cajera & Logout
            _buildSidebarFooter(),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final itemContent = Container(
      padding: EdgeInsets.symmetric(
        horizontal: _sidebarOpen ? 14 : 0,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              )
            : null,
      ),
      child: _sidebarOpen
          ? Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.75),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.body.copyWith(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.75),
                size: 22,
              ),
            ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: _sidebarOpen
            ? itemContent
            : Tooltip(
                message: '$title - $subtitle',
                child: itemContent,
              ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    final displayName = _cajeraNombre.startsWith('Caja')
        ? _cajeraNombre
        : 'Caja 01 - $_cajeraNombre';

    if (!_sidebarOpen) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Tooltip(
              message: '$displayName\nOperario de Caja',
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Tooltip(
              message: 'Cerrar Sesión',
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _handleLogout,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: AppTypography.small.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Operario de Caja',
                      style: AppTypography.small.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                foregroundColor: Colors.white,
                backgroundColor: AppPalette.error.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppPalette.error.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
              label: Text(
                'CERRAR SESIÓN',
                style: AppTypography.button.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
              onPressed: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: AppPalette.neutral.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Botón Hamburguesa para Colapsar/Expandir Sidebar
          IconButton(
            icon: Icon(
              _sidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: AppPalette.textPrimaryLight,
              size: 22,
            ),
            tooltip: _sidebarOpen ? 'Colapsar menú lateral' : 'Expandir menú lateral',
            onPressed: () {
              setState(() {
                _sidebarOpen = !_sidebarOpen;
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedNavIndex == 0
                  ? 'Bandeja de Cobros'
                  : _selectedNavIndex == 1
                      ? 'Historial de Pagos'
                      : 'Soporte Técnico',
              style: AppTypography.title.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Badge Sucursal Activa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppPalette.backgroundLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppPalette.neutral.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.store_rounded,
                  size: 15,
                  color: AppPalette.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _sucursalNombre,
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Campana de Notificaciones
          Container(
            decoration: BoxDecoration(
              color: AppPalette.backgroundLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppPalette.neutral.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: AppPalette.textSecondaryLight,
              ),
              tooltip: 'Notificaciones del turno',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandejaCobrosView() {
    // ── Proporciones Master-Detail (Desktop Grid: flex 4 / flex 8) ──
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda: Bandeja de Cobros (4/12 de ancho)
        Expanded(
          flex: 4,
          child: BandejaCobrosPanel(provider: _cajaProvider),
        ),
        // Columna Derecha: Panel de Detalle y Cobro (8/12 de ancho)
        Expanded(
          flex: 8,
          child: PanelDetalleCobro(provider: _cajaProvider),
        ),
      ],
    );
  }

  Widget _buildHistorialPagosView() {
    return HistorialCajaScreen(
      key: _historialKey,
      sucursalId: _idSucursal,
    );
  }
}
