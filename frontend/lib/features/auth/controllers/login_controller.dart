import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Controlador de autenticación y enrutamiento post-login por rol.
class LoginController {
  /// Redirige al operario a su vista correspondiente según su rol asignado.
  ///
  /// • Rol 3 (Caja)                -> `/caja`
  /// • Rol 2, 6, 7 (Ventas)         -> `/ventas_main`
  /// • Rol 1 u otros (Bodega/Gral) -> `/home`
  static Future<void> handlePostLoginNavigation(
    BuildContext context, {
    int? idRol,
    String? rol,
  }) async {
    final effectiveIdRol = idRol ?? await AuthService.getIdRol();
    final effectiveRol = (rol ?? await AuthService.getRol())?.trim().toLowerCase() ?? '';

    if (!context.mounted) return;

    if (effectiveIdRol == 3 || effectiveRol == 'caja' || effectiveRol == 'operario de caja') {
      Navigator.of(context).pushReplacementNamed('/caja');
      return;
    }

    final esVentas = await AuthService.esModuloVentas();
    if (!context.mounted) return;

    if (esVentas) {
      Navigator.of(context).pushReplacementNamed('/ventas_main');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  /// Ejecuta el flujo de login por PIN y despacha la navegación correspondiente si es exitoso.
  static Future<AuthResult> submitPin(BuildContext context, String pin) async {
    final result = await AuthService.loginConPin(pin);

    if (!context.mounted) return result;

    if (result.success) {
      await handlePostLoginNavigation(
        context,
        idRol: result.user?.idRol,
        rol: result.user?.nombreRol,
      );
    }

    return result;
  }
}
