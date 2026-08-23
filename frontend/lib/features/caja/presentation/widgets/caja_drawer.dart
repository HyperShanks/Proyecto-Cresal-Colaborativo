import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';

/// Menú lateral / Sidebar restringido exclusivamente para el rol Caja.
class CajaDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int>? onSectionSelected;

  const CajaDrawer({
    super.key,
    this.selectedIndex = 0,
    this.onSectionSelected,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppPalette.neutral.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppPalette.error.withValues(alpha: 0.15),
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
                style: AppTypography.title.copyWith(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            '¿Está seguro de que desea cerrar la sesión del turno de caja actual?',
            style: AppTypography.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'CANCELAR',
                style: AppTypography.button.copyWith(color: AppPalette.textSecondary),
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
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppPalette.surface,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Divider(color: AppPalette.neutral.withValues(alpha: 0.25), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                children: [
                  _buildMenuItem(
                    context: context,
                    icon: Icons.point_of_sale_rounded,
                    title: 'Bandeja de Cobros',
                    subtitle: 'Órdenes pendientes de pago',
                    isSelected: selectedIndex == 0,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSectionSelected?.call(0);
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.history_edu_rounded,
                    title: 'Historial de Órdenes y Pagos',
                    subtitle: 'Consultas y comprobantes',
                    isSelected: selectedIndex == 1,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSectionSelected?.call(1);
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildMenuItem(
                    context: context,
                    icon: Icons.support_agent_rounded,
                    title: 'Tickets de Soporte',
                    subtitle: 'Reporte de incidencias',
                    isSelected: false,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/tickets');
                    },
                  ),
                ],
              ),
            ),
            Divider(color: AppPalette.neutral.withValues(alpha: 0.25), height: 1),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _loadUserData(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final nombre = data?['nombre'] ?? 'Operario de Caja';
        final sucursal = data?['sucursal'] ?? 'Sucursal Casa Matriz';
        final rol = data?['rol'] ?? 'CAJA';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppPalette.primary.withValues(alpha: 0.15),
                AppPalette.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: AppTypography.title.copyWith(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppPalette.primary.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            rol.toUpperCase(),
                            style: AppTypography.small.copyWith(
                              color: AppPalette.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: AppPalette.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sucursal,
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, String?>> _loadUserData() async {
    final nombre = await AuthService.getNombreUsuario();
    final sucursal = await AuthService.getNombreSucursal();
    final rol = await AuthService.getRol();
    return {
      'nombre': (nombre != null && nombre.isNotEmpty) ? nombre : 'Operario de Caja',
      'sucursal': (sucursal != null && sucursal.isNotEmpty) ? sucursal : 'Sucursal Matriz',
      'rol': (rol != null && rol.isNotEmpty) ? rol : 'CAJA',
    };
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppPalette.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppPalette.primary.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppPalette.primary : AppPalette.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        color: isSelected ? Colors.white : AppPalette.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppPalette.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            foregroundColor: AppPalette.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: AppPalette.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: const Text(
            'CERRAR SESIÓN',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          onPressed: () => _handleLogout(context),
        ),
      ),
    );
  }
}
