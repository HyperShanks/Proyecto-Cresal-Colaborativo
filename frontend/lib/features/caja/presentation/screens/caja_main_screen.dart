import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../providers/caja_provider.dart';
import '../widgets/caja_drawer.dart';
import '../widgets/bandeja_cobros_panel.dart';
import '../widgets/cobro_pendiente_card.dart';

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

class _CajaMainScreenState extends State<CajaMainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final CajaProvider _cajaProvider;
  bool _providerInterno = false;

  bool _sidebarOpen = true;
  int _selectedNavIndex = 0; // 0: Caja, 1: Historial
  String _cajeraNombre = 'Lorena Valenzuela';
  String _sucursalNombre = 'Casa Matriz • Viña del Mar';
  int _idSucursal = 1;
  final int _totalRecaudadoHoy = 450000;

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
  }

  @override
  void dispose() {
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
                        child: _selectedNavIndex == 0
                            ? _buildBandejaCobrosView()
                            : _buildHistorialPagosView(),
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
                            child: const Text(
                              'CRESAL',
                              style: TextStyle(
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
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'C',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
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
                  },
                ),
                const SizedBox(height: 6),
                _buildSidebarItem(
                  icon: Icons.support_agent_rounded,
                  title: 'Soporte',
                  subtitle: 'Tickets de Soporte',
                  isSelected: false,
                  onTap: () {
                    Navigator.of(context).pushNamed('/tickets');
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
              label: const Text(
                'CERRAR SESIÓN',
                style: TextStyle(
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
          Text(
            _selectedNavIndex == 0 ? 'Bandeja de Cobros' : 'Historial de Pagos',
            style: AppTypography.title.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppPalette.textPrimaryLight,
            ),
          ),
          const Spacer(),
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
                Text(
                  _sucursalNombre,
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
          const SizedBox(width: 12),
          // Cajera Info Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_circle_rounded,
                  size: 16,
                  color: AppPalette.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  _cajeraNombre,
                  style: AppTypography.small.copyWith(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
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
          child: _buildDetalleCobroPanel(),
        ),
      ],
    );
  }

  Widget _buildDetalleCobroPanel() {
    final orden = _cajaProvider.ordenSeleccionada;

    if (orden == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 64,
              color: AppPalette.neutral.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'Seleccione una orden para procesar el cobro',
              style: AppTypography.title.copyWith(
                color: AppPalette.textPrimaryLight,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Haga clic en cualquiera de las tarjetas de la bandeja izquierda para ver los detalles.',
              style: AppTypography.body.copyWith(
                color: AppPalette.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final isVenta = orden.esVenta;

    return Container(
      color: AppPalette.backgroundLight,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del Detalle
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppPalette.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppPalette.neutral.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            orden.folioDocumento,
                            style: AppTypography.headline.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppPalette.textPrimaryLight,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (isVenta
                                      ? AppPalette.secondary
                                      : const Color(0xFF4F46E5))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (isVenta
                                        ? AppPalette.secondary
                                        : const Color(0xFF4F46E5))
                                    .withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isVenta ? 'Venta en Tienda' : 'Reserva Backorder',
                              style: AppTypography.small.copyWith(
                                color: isVenta
                                    ? const Color(0xFFB78103)
                                    : const Color(0xFF4F46E5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cliente: ${orden.clienteNombre} • RUT: ${orden.clienteRut}',
                        style: AppTypography.body.copyWith(
                          color: AppPalette.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Vendedor: ${orden.vendedorNombre} • Emitida el ${orden.fechaEmisionFormateada} a las ${orden.horaEmisionFormateada}',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondaryLight,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payment_rounded, size: 20),
                  label: Text(
                    'COBRAR ${CobroPendienteCard.formatClp(orden.montoACobrar)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Iniciando cobro de ${orden.folioDocumento}'),
                        backgroundColor: AppPalette.surfaceLight,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Contenido: Artículos (Venta) o Especificaciones (Backorder)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppPalette.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppPalette.neutral.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isVenta
                  ? _buildArticulosTable(orden)
                  : _buildBackorderSpecs(orden),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticulosTable(dynamic orden) {
    final articulos = orden.articulos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETALLE DE REPUESTOS Y ARTÍCULOS',
          style: AppTypography.title.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppPalette.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: articulos.length,
            separatorBuilder: (context, index) => Divider(
              color: AppPalette.neutral.withValues(alpha: 0.15),
              height: 16,
            ),
            itemBuilder: (context, idx) {
              final art = articulos[idx];
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppPalette.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppPalette.neutral.withValues(alpha: 0.2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${art.cantidad}x',
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppPalette.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          art.descripcion,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimaryLight,
                          ),
                        ),
                        if (art.sku != null)
                          Text(
                            'SKU: ${art.sku}',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textSecondaryLight,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    CobroPendienteCard.formatClp(art.subtotal),
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimaryLight,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBackorderSpecs(dynamic orden) {
    final bo = orden.especificacionesBackorder;
    if (bo == null) {
      return const Center(child: Text('Sin especificaciones disponibles'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESPECIFICACIONES DE LA RESERVA BACKORDER',
            style: AppTypography.title.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppPalette.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          _buildSpecRow('Marca Requerida', bo.marca),
          _buildSpecRow('Modelo Requerido', bo.modelo),
          if (bo.anio != null) _buildSpecRow('Año Requerido', '${bo.anio}'),
          _buildSpecRow('Categoría', bo.categoria),
          if (bo.cilindrada != null) _buildSpecRow('Cilindrada', bo.cilindrada!),
          if (bo.combustible != null) _buildSpecRow('Combustible', bo.combustible!),
          _buildSpecRow('Estado de Tránsito', bo.transito),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: AppTypography.small.copyWith(
                color: AppPalette.textSecondaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                color: AppPalette.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialPagosView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de Métricas del Turno en Historial
          Row(
            children: [
              _buildStatCard(
                icon: Icons.pending_actions_rounded,
                title: 'Órdenes por Cobrar',
                value: '${_cajaProvider.totalCobros}',
                color: AppPalette.secondary,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                icon: Icons.attach_money_rounded,
                title: 'Recaudación del Turno',
                value: CobroPendienteCard.formatClp(_totalRecaudadoHoy),
                color: AppPalette.success,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                icon: Icons.verified_user_rounded,
                title: 'Estado del Turno',
                value: 'Turno Activo',
                color: AppPalette.primary,
                subtitle: 'ID Sucursal: $_idSucursal',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppPalette.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppPalette.neutral.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 56,
                    color: AppPalette.neutral.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Historial de Comprobantes y Pagos',
                    style: AppTypography.title.copyWith(
                      color: AppPalette.textPrimaryLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Consulte los comprobantes emitidos durante el turno actual.',
                    style: AppTypography.body.copyWith(
                      color: AppPalette.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppPalette.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppPalette.neutral.withValues(alpha: 0.2),
            width: 1,
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
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.small.copyWith(
                        color: color,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
