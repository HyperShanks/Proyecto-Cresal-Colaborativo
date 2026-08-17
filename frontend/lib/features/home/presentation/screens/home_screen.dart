import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../../../alertas/services/logistica_service.dart';
import '../../../alertas/services/bodega_polling_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN — Panel principal protegido por sesión
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _userRol;
  String? _userSucursal;
  DateTime? _pausedTime;
  int _conteoTareas = 0;
  bool _tieneTraslados = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Escuchar notificaciones reactivas de BodegaPollingService
    BodegaPollingService.instance.totalPendientesNotifier.addListener(_actualizarEstadoTareas);
    BodegaPollingService.instance.tieneTrasladosNotifier.addListener(_actualizarEstadoTareas);

    // Blindaje de ruta: si se accede directo por URL sin token, redirige a login
    _guardRoute();
  }

  void _actualizarEstadoTareas() {
    if (mounted) {
      setState(() {
        _conteoTareas = BodegaPollingService.instance.totalPendientesNotifier.value;
        _tieneTraslados = BodegaPollingService.instance.tieneTrasladosNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BodegaPollingService.instance.totalPendientesNotifier.removeListener(_actualizarEstadoTareas);
    BodegaPollingService.instance.tieneTrasladosNotifier.removeListener(_actualizarEstadoTareas);
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
          // Reactivar polling si fue reanudado
          BodegaPollingService.instance.procesarCiclo();
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
    if (mounted) {
      if (rol?.toLowerCase() == 'vendedor') {
        Navigator.of(context).pushReplacementNamed('/ventas_main');
        return;
      }
      setState(() {
        _userRol = rol;
        _userSucursal = sucursal;
      });
      _iniciarServicioPolling();
    }
  }

  Future<void> _iniciarServicioPolling() async {
    final sucursalId = await AuthService.getSucursalId();
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
    BodegaPollingService.instance.iniciarPolling(sucursalId: sucursalId);
  }

  Future<void> _cargarConteoTareas() async {
    await BodegaPollingService.instance.procesarCiclo();
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

    BodegaPollingService.instance.reset();
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
                  _userRol != null && _userRol!.isNotEmpty
                      ? _userRol!.toUpperCase()
                      : 'OPERADOR',
                  style: AppTypography.title.copyWith(
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userSucursal != null && _userSucursal!.isNotEmpty
                      ? _userSucursal!
                      : 'Sucursal Central',
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                ),
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
        // 📦 Si el rol es Bodeguero (o por defecto en el panel de HomeScreen) -> Módulos de Logística
        if (_userRol == null ||
            _userRol!.isEmpty ||
            _userRol?.toLowerCase() == 'bodeguero' ||
            _userRol?.toLowerCase() == 'administrador') ...[
          _buildModuleCard(
            context: context,
            title: 'RECEPCIÓN DE VEHÍCULO',
            icon: Icons.local_shipping_outlined,
            onTap: () {
              Navigator.pushNamed(context, '/recepcion');
            },
          ),
          const SizedBox(height: 16),
          _buildModuleCard(
            context: context,
            title: 'PALETIZADO DE PIEZAS',
            icon: Icons.inventory_2_outlined,
            onTap: () {
              Navigator.pushNamed(context, '/paletizado');
            },
          ),
          const SizedBox(height: 16),
        ],

        // 🔍 Módulos compartidos por todos
        _buildModuleCard(
          context: context,
          title: 'BUSCADOR DE INVENTARIO',
          icon: Icons.search,
          onTap: () {
            Navigator.pushNamed(context, '/buscador');
          },
        ),
        const SizedBox(height: 16),
        _buildModuleCard(
          context: context,
          title: 'ALERTA TAREAS',
          icon: _tieneTraslados ? Icons.warning_amber_rounded : Icons.notifications_none,
          badgeCount: _conteoTareas,
          isHighlighted: _tieneTraslados,
          highlightTag: _tieneTraslados ? 'TRASLADO PENDIENTE' : null,
          onTap: () async {
            // Conexión hacia la vista del tablero y refresco al regresar
            await Navigator.pushNamed(context, '/alertas');
            _cargarConteoTareas();
          },
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    int? badgeCount,
    bool isHighlighted = false,
    String? highlightTag,
  }) {
    final borderColor = isHighlighted ? AppPalette.secondary : AppPalette.primary;

    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor, width: isHighlighted ? 6 : 4),
            ),
            color: isHighlighted ? AppPalette.secondary.withValues(alpha: 0.05) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Row(
            children: [
              Icon(
                icon,
                size: 36,
                color: isHighlighted ? AppPalette.secondary : AppPalette.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.cardTitle),
                    if (highlightTag != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        highlightTag,
                        style: AppTypography.small.copyWith(
                          color: AppPalette.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  key: const Key('home_badge_alertas'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHighlighted ? AppPalette.secondary : AppPalette.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
