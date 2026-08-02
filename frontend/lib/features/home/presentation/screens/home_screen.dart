import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — Panel principal protegido por sesión
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Blindaje de ruta: si se accede directo por URL sin token, redirige a login
    _guardRoute();
  }

  Future<void> _guardRoute() async {
    final token = await AuthService.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    // Cierra el Drawer si está abierto
    Navigator.of(context).pop();

    // Confirmar logout
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
    // Navegar a /login limpiando completamente el historial de navegación
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(context),
      body: _buildBody(context),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppPalette.surface,
      foregroundColor: AppPalette.textPrimary,
      elevation: 0,
      title: Text(
        'Cresal Industrial System',
        style: AppTypography.title.copyWith(fontSize: 17),
      ),
      // El ícono de hamburguesa (≡) es automático cuando existe un Drawer
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: AppPalette.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menú',
        ),
      ),
    );
  }

  // ── Drawer (Menú Lateral) ─────────────────────────────────────────────────

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
                  'OPERADOR',
                  style: AppTypography.title.copyWith(
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text('Zona Norte', style: AppTypography.small),
              ],
            ),
          ),

          // ── Opciones de menú ─────────────────────────────────────────────
          _buildDrawerItem(
            icon: Icons.confirmation_number_outlined,
            label: 'TICKET',
            onTap: () {
              Navigator.of(context).pop();
              // TODO: navegar a la pantalla de tickets
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings_outlined,
            label: 'CONFIGURACIÓN',
            onTap: () {
              Navigator.of(context).pop();
              // TODO: navegar a configuración
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
      leading: Icon(icon, color: AppPalette.primary, size: 22),
      title: Text(
        label,
        style: AppTypography.button.copyWith(fontSize: 14, letterSpacing: 1.0),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: AppPalette.primary.withValues(alpha: 0.08),
    );
  }

  // ── Body (Panel de Control) ───────────────────────────────────────────────

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel de Control',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Bienvenido al sistema de operaciones.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildModuleList(context),
        ],
      ),
    );
  }

  Widget _buildModuleList(BuildContext context) {
    return Column(
      children: [
        _buildModuleCard(
          context: context,
          title: 'RECEPCIÓN DE VEHÍCULO',
          icon: Icons.local_shipping_outlined,
          onTap: () {
            // ¡El enlace mágico hacia tu HU-2.2!
            Navigator.pushNamed(context, '/recepcion');
          },
        ),
        const SizedBox(height: 16),
        _buildModuleCard(
          context: context,
          title: 'PALETIZADO DE PIEZAS',
          icon: Icons.inventory_2_outlined,
          onTap: () {}, // Futuro módulo
        ),
        const SizedBox(height: 16),
        _buildModuleCard(
          context: context,
          title: 'BUSCADOR DE INVENTARIO',
          icon: Icons.search,
          onTap: () {}, // Futuro módulo
        ),
        const SizedBox(height: 16),
        _buildModuleCard(
          context: context,
          title: 'ALERTA TAREAS',
          icon: Icons.notifications_none,
          onTap: () {}, // Futuro módulo
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppPalette.primary, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Icon(icon, size: 32, color: AppPalette.primary),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: AppTypography.cardTitle)),
            ],
          ),
        ),
      ),
    );
  }
}
