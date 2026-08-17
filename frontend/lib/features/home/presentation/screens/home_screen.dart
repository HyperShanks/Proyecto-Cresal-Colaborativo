import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../../../alertas/services/bodega_polling_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — Panel principal de Bodega (Terminal Bodega) protegido por sesión
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _userRol;
  String? _userSucursal;
  String? _userNombre;
  int? _userSucursalId;
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _guardRoute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BodegaPollingService.instance.detenerPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final difference = DateTime.now().difference(_pausedTime!);
        if (difference.inMinutes >= 5) {
          _pausedTime = null;
          BodegaPollingService.instance.reset();
          AuthService.clearToken();
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        } else {
          _pausedTime = null;
          _cargarConteoTareas();
        }
      }
    }
  }

  Future<void> _guardRoute() async {
    final token = await AuthService.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    final rol = await AuthService.getRol();
    final sucursal = await AuthService.getNombreSucursal();
    final nombre = await AuthService.getNombreUsuario();
    final sucursalId = await AuthService.getSucursalId();

    if (mounted) {
      if (rol?.toLowerCase() == 'vendedor') {
        Navigator.of(context).pushReplacementNamed('/ventas_main');
        return;
      }
      setState(() {
        _userRol = rol;
        _userSucursal = sucursal;
        _userNombre = nombre;
        _userSucursalId = sucursalId;
      });
      _iniciarServicioPolling(sucursalId: sucursalId);
    }
  }

  Future<void> _iniciarServicioPolling({int? sucursalId}) async {
    final targetSucursalId = sucursalId ?? await AuthService.getSucursalId();
    BodegaPollingService.instance.onNotificacion = (titulo, cuerpo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppPalette.surface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppPalette.secondary, width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: AppPalette.secondary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: AppTypography.title.copyWith(fontSize: 14, color: AppPalette.secondary)),
                      const SizedBox(height: 2),
                      Text(cuerpo, style: AppTypography.small.copyWith(fontSize: 12, color: AppPalette.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    };
    BodegaPollingService.instance.iniciarPolling(sucursalId: targetSucursalId);
  }

  Future<void> _cargarConteoTareas() async {
    final targetSucursalId = _userSucursalId ?? await AuthService.getSucursalId();
    await BodegaPollingService.instance.procesarCiclo(sucursalId: targetSucursalId);
  }

  String _getNombreSaludo() {
    if (_userNombre == null || _userNombre!.trim().isEmpty) return 'Operador';
    final parts = _userNombre!.trim().split(' ');
    return parts.first;
  }

  Future<void> _logout() async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cerrar sesión', style: AppTypography.title),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?', style: AppTypography.small),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: AppTypography.button.copyWith(color: AppPalette.neutral)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('CERRAR SESIÓN', style: AppTypography.button.copyWith(color: AppPalette.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    BodegaPollingService.instance.reset();
    await AuthService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(context),
      body: _buildBody(context),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppPalette.surface,
      foregroundColor: AppPalette.textPrimary,
      elevation: 0,
      title: Text(
        'Terminal Bodega',
        style: AppTypography.title.copyWith(fontSize: 17),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: AppPalette.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menú',
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final nombreCompleto = (_userNombre != null && _userNombre!.trim().isNotEmpty) ? _userNombre!.trim() : (_userRol != null && _userRol!.isNotEmpty ? _userRol!.toUpperCase() : 'OPERADOR');
    final sucursal = (_userSucursal != null && _userSucursal!.trim().isNotEmpty) ? _userSucursal!.trim() : 'Sucursal Central';

    return Drawer(
      backgroundColor: AppPalette.surface,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: const BoxDecoration(
              color: AppPalette.background,
              border: Border(bottom: BorderSide(color: AppPalette.surface, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: AppPalette.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person, color: AppPalette.textPrimary, size: 32),
                ),
                const SizedBox(height: 12),
                Text(nombreCompleto, style: AppTypography.title.copyWith(fontSize: 15, letterSpacing: 0.8), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_userRol != null && _userRol!.isNotEmpty ? _userRol!.toUpperCase() : 'OPERADOR DE BODEGA', style: AppTypography.small.copyWith(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 11)),
                Text(sucursal, style: AppTypography.small.copyWith(color: AppPalette.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _buildDrawerItem(icon: Icons.confirmation_number_outlined, label: 'TICKET', onTap: () { Navigator.of(context).pop(); Navigator.of(context).pushNamed('/tickets'); }),
          _buildDrawerItem(icon: Icons.settings_outlined, label: 'CONFIGURACIÓN', onTap: () => Navigator.of(context).pop()),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 20),
                label: Text('CERRAR SESIÓN', style: AppTypography.button.copyWith(fontSize: 14, letterSpacing: 0.8)),
                style: ElevatedButton.styleFrom(backgroundColor: AppPalette.error, foregroundColor: AppPalette.textPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon, color: AppPalette.primary, size: 22),
      title: Text(label, style: AppTypography.button.copyWith(fontSize: 14, letterSpacing: 1.0)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOperativeHeader(),
          const SizedBox(height: 20),
          _buildHeroAlertaCard(context),
          const SizedBox(height: 24),
          Text('ACCIONES FRECUENTES', style: AppTypography.cardTitle.copyWith(fontSize: 12, color: AppPalette.textSecondary, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          _buildFrequentActionsGrid(context),
          const SizedBox(height: 24),
          Text('CONSULTA', style: AppTypography.cardTitle.copyWith(fontSize: 12, color: AppPalette.textSecondary, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          _buildSearchCard(context),
        ],
      ),
    );
  }

  Widget _buildOperativeHeader() {
    final saludoNombre = _getNombreSaludo();
    final sucursalTexto = (_userSucursal != null && _userSucursal!.trim().isNotEmpty) ? _userSucursal!.trim() : 'Sucursal Central';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hola, $saludoNombre 👋', style: AppTypography.headline.copyWith(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Operador de Bodega', style: AppTypography.small.copyWith(color: AppPalette.textSecondary, fontWeight: FontWeight.w500, fontSize: 13)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppPalette.primary.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppPalette.primary, size: 15),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text('📍 $sucursalTexto', style: AppTypography.small.copyWith(color: AppPalette.textPrimary, fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroAlertaCard(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BodegaPollingService.instance.totalPendientesNotifier,
      builder: (context, totalPendientes, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: BodegaPollingService.instance.tieneTrasladosNotifier,
          builder: (context, tieneTraslados, _) {
            final tieneTareas = totalPendientes > 0;
            return Material(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  await Navigator.pushNamed(context, '/alertas');
                  _cargarConteoTareas();
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: tieneTareas ? AppPalette.secondary : AppPalette.success.withValues(alpha: 0.4),
                      width: tieneTareas ? 2.0 : 1.2,
                    ),
                    color: tieneTareas ? AppPalette.secondary.withValues(alpha: 0.07) : AppPalette.success.withValues(alpha: 0.03),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: tieneTareas ? AppPalette.secondary.withValues(alpha: 0.18) : AppPalette.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tieneTareas ? (tieneTraslados ? Icons.warning_amber_rounded : Icons.notifications_active_rounded) : Icons.check_circle_outline_rounded,
                          color: tieneTareas ? AppPalette.secondary : AppPalette.success,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('ALERTA TAREAS', style: AppTypography.cardTitle.copyWith(fontSize: 14, letterSpacing: 0.8, color: tieneTareas ? AppPalette.secondary : AppPalette.textPrimary)),
                            const SizedBox(height: 4),
                            Text(
                              tieneTareas
                                  ? (tieneTraslados ? 'Requiere atención inmediata • Incluye traslados prioritarios' : 'Requiere atención inmediata')
                                  : 'Sin tareas pendientes en sucursal',
                              style: AppTypography.small.copyWith(fontSize: 12, color: tieneTareas ? AppPalette.textPrimary : AppPalette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (tieneTareas) ...[
                        Container(
                          key: const Key('home_badge_alertas'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppPalette.secondary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            totalPendientes.toString(),
                            style: const TextStyle(color: AppPalette.background, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(Icons.arrow_forward_ios_rounded, color: tieneTareas ? AppPalette.secondary : AppPalette.neutral, size: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFrequentActionsGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context: context,
            title: 'Recepción de Vehículo',
            subtitle: 'Requiere OCR: Fotografiar el N° de ingreso físico del vehículo',
            icon: Icons.local_shipping_outlined,
            onTap: () => Navigator.pushNamed(context, '/recepcion'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            context: context,
            title: 'Paletizado de Piezas',
            subtitle: 'Validación OCR o selección manual del N° de ingreso',
            icon: Icons.inventory_2_outlined,
            onTap: () => Navigator.pushNamed(context, '/paletizado'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.primary.withValues(alpha: 0.25), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppPalette.primary, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.title.copyWith(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.small.copyWith(fontSize: 11, color: AppPalette.textSecondary, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/buscador'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.primary.withValues(alpha: 0.25), width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded, color: AppPalette.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Buscador de Inventario', style: AppTypography.title.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Consulta rápida por SKU, QR, Pasillo o Modelo', style: AppTypography.small.copyWith(fontSize: 12, color: AppPalette.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppPalette.primary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
