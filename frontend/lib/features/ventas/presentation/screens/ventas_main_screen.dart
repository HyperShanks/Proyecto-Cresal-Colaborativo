// lib/features/ventas/presentation/screens/ventas_main_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../../controllers/cart_controller.dart';
import 'carrito_screen.dart';
import 'catalogo_screen.dart';

/// Contenedor Principal para el rol de Vendedor.
/// Implementa un BottomNavigationBar con IndexedStack para navegación fluida
/// y un Drawer lateral replicando las opciones del sistema (Tickets, Configuración, Cerrar Sesión).
class VentasMainScreen extends StatefulWidget {
  const VentasMainScreen({super.key});

  @override
  State<VentasMainScreen> createState() => _VentasMainScreenState();
}

class _VentasMainScreenState extends State<VentasMainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<CatalogoScreenState> _catalogoKey = GlobalKey<CatalogoScreenState>();
  int _currentIndex = 0;
  String? _userRol;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final rol = await AuthService.getRol();
    if (mounted) {
      setState(() {
        _userRol = rol;
      });
    }
  }

  // ── Cerrar Sesión ──────────────────────────────────────────────────────────

  Future<void> _logout() async {
    Navigator.of(context).pop(); // Cierra el Drawer

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Cerrar sesión', style: AppTypography.title),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: AppTypography.small,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: AppTypography.button.copyWith(color: AppPalette.neutral),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'CERRAR SESIÓN',
              style: AppTypography.button.copyWith(color: AppPalette.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await AuthService.clearToken();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // ── Menú Lateral (Drawer) ─────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppPalette.surface,
      child: Column(
        children: [
          // ── Encabezado de perfil ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: const BoxDecoration(
              color: AppPalette.background,
              border: Border(
                bottom: BorderSide(color: AppPalette.surface, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar de usuario
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppPalette.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppPalette.textPrimary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _userRol != null && _userRol!.isNotEmpty
                      ? _userRol!.toUpperCase()
                      : 'VENDEDOR',
                  style: AppTypography.title.copyWith(
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Módulo de Ventas', style: AppTypography.small),
              ],
            ),
          ),

          // ── Opciones de menú ─────────────────────────────────────────────
          _buildDrawerItem(
            icon: Icons.confirmation_number_outlined,
            label: 'TICKET',
            onTap: () {
              Navigator.of(context).pop(); // Cierra el Drawer
              Navigator.of(context).pushNamed('/tickets');
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings_outlined,
            label: 'CONFIGURACIÓN',
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Módulo de Configuración en desarrollo'),
                ),
              );
            },
          ),

          const Spacer(),

          // ── Botón de Cerrar Sesión (anclado en la parte inferior) ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 20),
                label: Text(
                  'CERRAR SESIÓN',
                  style: AppTypography.button.copyWith(
                    fontSize: 14,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.error,
                  foregroundColor: AppPalette.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: AppPalette.textPrimary, size: 22),
      title: Text(
        label,
        style: AppTypography.body.copyWith(
          letterSpacing: 1.0,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }

  // ── Construcción de la Vista ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppPalette.background,
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          CatalogoScreen(
            key: _catalogoKey,
            onOpenMenuDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          _buildPlaceholderTab(
            title: 'Mis Órdenes',
            icon: Icons.receipt_long_outlined,
            description: 'Historial y estado de cotizaciones y órdenes de venta.',
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          _buildPlaceholderTab(
            title: 'Tasación de Vehículos',
            icon: Icons.sell_outlined,
            description: 'Módulo de cálculo de tasación y sugerencia de precios.',
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          CarritoScreen(
            onOpenMenuDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            onNavigateToCatalogo: () {
              _catalogoKey.currentState?.refrescarCatalogo();
              setState(() => _currentIndex = 0);
            },
          ),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: CartController.instance,
        builder: (context, _) {
          final totalItems = CartController.instance.totalItems;

          return Container(
            decoration: const BoxDecoration(
              color: AppPalette.surface,
              border: Border(
                top: BorderSide(
                  color: Colors.white10,
                  width: 1.0,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: AppPalette.surface,
              selectedItemColor: AppPalette.primary,
              unselectedItemColor: AppPalette.neutral,
              selectedLabelStyle: AppTypography.small.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: AppTypography.small.copyWith(
                fontSize: 11,
              ),
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_outlined),
                  activeIcon: Icon(Icons.storefront),
                  label: 'Catálogo',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Mis Órdenes',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.sell_outlined),
                  activeIcon: Icon(Icons.sell),
                  label: 'Tasación',
                ),
                BottomNavigationBarItem(
                  icon: totalItems > 0
                      ? Badge.count(
                          count: totalItems,
                          backgroundColor: AppPalette.secondary,
                          textColor: AppPalette.background,
                          child: const Icon(Icons.shopping_cart_outlined),
                        )
                      : const Icon(Icons.shopping_cart_outlined),
                  activeIcon: totalItems > 0
                      ? Badge.count(
                          count: totalItems,
                          backgroundColor: AppPalette.secondary,
                          textColor: AppPalette.background,
                          child: const Icon(Icons.shopping_cart),
                        )
                      : const Icon(Icons.shopping_cart),
                  label: 'Carrito',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderTab({
    required String title,
    required IconData icon,
    required String description,
    required VoidCallback onOpenDrawer,
  }) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppPalette.textPrimary),
          onPressed: onOpenDrawer,
          tooltip: 'Menú principal',
        ),
        title: Text(title, style: AppTypography.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 36, color: AppPalette.primary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: AppTypography.headline.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: AppTypography.small.copyWith(color: AppPalette.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.construction, size: 16, color: AppPalette.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'Módulo en desarrollo',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
