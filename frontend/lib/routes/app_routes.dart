import 'package:flutter/material.dart';
import '../features/auth/presentation/screens/pin_login_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/caja/presentation/screens/caja_main_screen.dart';
import '../features/ventas/presentation/screens/ventas_main_screen.dart';
import '../features/recepcion/presentation/screens/recepcion_vehiculo_screen.dart';
import '../features/tickets/presentation/screens/tickets_screen.dart';
import '../features/paletizado/presentation/screens/paletizado_screen.dart';
import '../features/paletizado/presentation/screens/etiqueta_preview_screen.dart';
import '../features/alertas/presentation/screens/alertas_screen.dart';
import '../features/inventario/presentation/screens/buscador_screen.dart';
import '../features/ventas/presentation/screens/catalogo_screen.dart';
import '../features/ventas/presentation/screens/checkout_crm_screen.dart';
import '../features/ventas/presentation/screens/bandeja_precios_screen.dart';
import '../features/ventas/presentation/screens/entregas_envios_screen.dart';

/// Registro central de rutas y guardas de seguridad RBAC.
class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String ventasMain = '/ventas_main';
  static const String caja = '/caja';
  static const String recepcion = '/recepcion';
  static const String tickets = '/tickets';
  static const String paletizado = '/paletizado';
  static const String etiquetaPreview = '/etiqueta-preview';
  static const String alertas = '/alertas';
  static const String buscador = '/buscador';
  static const String catalogo = '/catalogo';
  static const String checkoutCrm = '/checkout_crm';
  static const String bandejaPrecios = '/bandeja_precios';
  static const String entregasEnvios = '/entregas-envios';

  /// Rutas estrictamente restringidas para el rol Operario de Caja (id_rol == 3).
  static const List<String> _cajaRestrictedRoutes = [
    catalogo,
    '/carrito',
    recepcion,
    paletizado,
    etiquetaPreview,
    buscador,
    bandejaPrecios,
    checkoutCrm,
    entregasEnvios,
    alertas,
    home,
    ventasMain,
  ];

  /// Valida si una ruta específica está permitida para un rol determinado.
  static bool isRouteAllowedForRole(int? idRol, String route) {
    if (idRol == 3) {
      if (_cajaRestrictedRoutes.contains(route)) {
        return false;
      }
      return route == caja || route == login || route == tickets || route == '/';
    }
    return true;
  }

  /// Mapa global de rutas de la aplicación.
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const PinLoginScreen(),
      home: (context) => const HomeScreen(),
      caja: (context) => const CajaMainScreen(),
      ventasMain: (context) => const VentasMainScreen(),
      recepcion: (context) => const RecepcionVehiculoScreen(),
      tickets: (context) => const TicketsScreen(),
      paletizado: (context) => const PaletizadoScreen(),
      etiquetaPreview: (context) => const EtiquetaPreviewScreen(),
      alertas: (context) => const AlertasScreen(),
      buscador: (context) => const BuscadorScreen(),
      catalogo: (context) => const CatalogoScreen(),
      checkoutCrm: (context) => const CheckoutCrmScreen(),
      bandejaPrecios: (context) => const BandejaPreciosScreen(),
      entregasEnvios: (context) => const EntregasEnviosScreen(),
    };
  }
}
