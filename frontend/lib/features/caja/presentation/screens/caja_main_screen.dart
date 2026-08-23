import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../widgets/caja_drawer.dart';

/// Contenedor principal de escritorio para el Módulo de Caja (CRES-213).
/// Soporta resoluciones de escritorio (>= 1366x768) con AppBar corporativo,
/// tabs de navegación (Bandeja / Historial) y menú lateral restringido.
class CajaMainScreen extends StatefulWidget {
  const CajaMainScreen({super.key});

  @override
  State<CajaMainScreen> createState() => _CajaMainScreenState();
}

class _CajaMainScreenState extends State<CajaMainScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _cajeraNombre = 'Operario de Caja';
  String _sucursalNombre = 'Casa Matriz';
  int _idSucursal = 1;
  final int _pendientesCobroCount = 3;
  final int _totalRecaudadoHoy = 450000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _cargarDatosCajera();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
  }

  void _onDrawerItemSelected(int index) {
    if (index >= 0 && index < 2) {
      _tabController.animateTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppPalette.background,
      drawer: CajaDrawer(
        selectedIndex: _tabController.index,
        onSectionSelected: _onDrawerItemSelected,
      ),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatsHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBandejaCobrosTab(),
                  _buildHistorialPagosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppPalette.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
        tooltip: 'Abrir menú lateral',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          const SizedBox(width: 12),
          Text(
            'MÓDULO DE CAJA',
            style: AppTypography.title.copyWith(fontSize: 18, color: Colors.white),
          ),
        ],
      ),
      actions: [
        // Badge de Sucursal Activa
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppPalette.neutral.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.store_rounded,
                size: 16,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Sucursal: $_sucursalNombre',
                style: AppTypography.small.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Cajera Info Chip
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppPalette.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppPalette.primary.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_circle_rounded,
                size: 18,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _cajeraNombre,
                style: AppTypography.small.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
      ],

      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppPalette.primary,
        indicatorWeight: 3,
        labelColor: AppPalette.primary,
        unselectedLabelColor: AppPalette.textSecondary,
        labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppTypography.body,
        tabs: const [
          Tab(
            icon: Icon(Icons.point_of_sale_rounded),
            text: 'Bandeja de Cobros',
          ),
          Tab(
            icon: Icon(Icons.history_rounded),
            text: 'Historial de Pagos',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border(
          bottom: BorderSide(
            color: AppPalette.neutral.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.pending_actions_rounded,
            title: 'Órdenes por Cobrar',
            value: '$_pendientesCobroCount',
            color: AppPalette.secondary,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            icon: Icons.attach_money_rounded,
            title: 'Recaudación del Turno',
            value: '\$${_totalRecaudadoHoy.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
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
          color: AppPalette.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
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
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  Widget _buildBandejaCobrosTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    hintText: 'Buscar orden por Folio, RUT de cliente o Vendedor...',
                    hintStyle: const TextStyle(color: AppPalette.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppPalette.textSecondary),
                    filled: true,
                    fillColor: AppPalette.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppPalette.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('ACTUALIZAR BANDEJA', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: _cargarDatosCajera,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.3), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: AppPalette.surface,
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('FOLIO / CÓDIGO', style: TextStyle(fontWeight: FontWeight.w700, color: AppPalette.textSecondary))),
                          Expanded(flex: 3, child: Text('CLIENTE', style: TextStyle(fontWeight: FontWeight.w700, color: AppPalette.textSecondary))),
                          Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700, color: AppPalette.textSecondary))),
                          Expanded(flex: 2, child: Text('ESTADO', style: TextStyle(fontWeight: FontWeight.w700, color: AppPalette.textSecondary))),
                          Expanded(flex: 2, child: Text('ACCIÓN', style: TextStyle(fontWeight: FontWeight.w700, color: AppPalette.textSecondary), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    _buildOrdenRow(
                      folio: 'ORD-2026-0891',
                      cliente: '15.443.210-9 • Juan Pérez',
                      total: '\$145.000',
                      estado: 'Pendiente Pago',
                      estadoColor: AppPalette.secondary,
                    ),
                    _buildOrdenRow(
                      folio: 'ORD-2026-0892',
                      cliente: '18.765.432-1 • AutoDesarme Spa',
                      total: '\$320.000',
                      estado: 'Pendiente Pago',
                      estadoColor: AppPalette.secondary,
                    ),
                    _buildOrdenRow(
                      folio: 'ORD-2026-0893',
                      cliente: 'Consumidor Final',
                      total: '\$65.000',
                      estado: 'Pendiente Pago',
                      estadoColor: AppPalette.secondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdenRow({
    required String folio,
    required String cliente,
    required String total,
    required String estado,
    required Color estadoColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.neutral.withValues(alpha: 0.2), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              folio,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              cliente,
              style: AppTypography.body.copyWith(color: AppPalette.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              total,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w700,
                color: AppPalette.success,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: estadoColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  estado,
                  style: AppTypography.small.copyWith(
                    color: estadoColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.payment_rounded, size: 16),
                label: const Text('PROCESAR COBRO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Iniciando cobro de $folio'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppPalette.surface,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialPagosTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: AppPalette.neutral.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Historial de Órdenes y Pagos',
            style: AppTypography.title.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Consulte los comprobantes emitidos durante el turno actual.',
            style: AppTypography.body.copyWith(color: AppPalette.textSecondary),
          ),
        ],
      ),
    );
  }
}
