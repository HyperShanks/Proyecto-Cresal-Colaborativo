import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/tokens/app_palette.dart';
import '../../../core/services/api_service.dart';
import '../../alertas/services/bodega_polling_service.dart';

// Claves de almacenamiento seguro
const String _tokenKey = 'access_token';
const String _rolKey = 'user_rol';
const String _idRolKey = 'user_id_rol';
const String _sucursalKey = 'user_sucursal_id';
const String _sucursalNombreKey = 'user_sucursal_nombre';
const String _nombreUsuarioKey = 'user_nombre_completo';

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS DE RESULTADO (evita mezclar lógica HTTP en la UI)
// ─────────────────────────────────────────────────────────────────────────────
class AuthResult {
  final bool success;
  final String? errorMessage;

  const AuthResult.ok() : success = true, errorMessage = null;
  const AuthResult.fail(this.errorMessage) : success = false;
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  static const _storage = FlutterSecureStorage();

  /// Envía el PIN al backend y persiste el JWT y el rol si la autenticación es exitosa.
  ///
  /// Retorna [AuthResult.ok()] si el login fue correcto,
  /// o [AuthResult.fail(mensaje)] con el detalle del error del servidor.
  static Future<AuthResult> loginConPin(String pin) async {
    try {
      final uri = Uri.parse('${ApiConstants.authEndpoint}/login-pin');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pin': pin}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = body['access_token'] as String;
        // Extraemos el rol en formato texto (ej. "Bodeguero", "Vendedor")
        final usuarioMap = body['usuario'] as Map<String, dynamic>?;
        String rolText = usuarioMap?['nombre_rol']?.toString() ??
            usuarioMap?['rol']?['nombre_rol']?.toString() ??
            '';
        final dynamic rawIdRol = usuarioMap?['id_rol'] ?? usuarioMap?['rol']?['id_rol'];
        final int? idRol = rawIdRol is int ? rawIdRol : int.tryParse(rawIdRol?.toString() ?? '');

        if (rolText.isEmpty && idRol != null) {
          if (idRol == 1) rolText = 'Bodeguero';
          if (idRol == 2) rolText = 'Vendedor';
          if (idRol == 3) rolText = 'Caja';
          if (idRol == 4) rolText = 'Gerente';
          if (idRol == 5) rolText = 'Administrador';
          if (idRol == 6) rolText = 'Jefe de Ventas';
          if (idRol == 7) rolText = 'Vendedor Online';
        }
        final sucursalId = usuarioMap?['id_sucursal']?.toString();
        final sucursalNombre = usuarioMap?['nombre_sucursal']?.toString() ??
            usuarioMap?['sucursal']?['nombre_sucursal']?.toString() ??
            '';
        final nombres = usuarioMap?['nombres']?.toString() ?? '';
        final apellidos = usuarioMap?['apellidos']?.toString() ?? '';

        // Guardar token, rol, id_rol y sucursal de forma segura en el dispositivo
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _rolKey, value: rolText);
        if (idRol != null) {
          await _storage.write(key: _idRolKey, value: idRol.toString());
        }
        if (sucursalId != null) {
          await _storage.write(key: _sucursalKey, value: sucursalId);
        }
        if (sucursalNombre.isNotEmpty) {
          await _storage.write(key: _sucursalNombreKey, value: sucursalNombre);
        }
        if (nombres.isNotEmpty) {
          await _storage.write(
            key: _nombreUsuarioKey,
            value: '$nombres $apellidos'.trim(),
          );
        }
        return const AuthResult.ok();
      }

      // Camino triste: el backend retornó un error (401, 422, etc.)
      final detail = body['detail'] ?? 'Error desconocido del servidor';
      return AuthResult.fail(detail.toString());
    } on Exception catch (e) {
      return AuthResult.fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Recupera el token almacenado (útil para inyectarlo en peticiones futuras).
  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Recupera el rol textual almacenado (ej. "Bodeguero", "Vendedor", "Jefe de Ventas", "Vendedor Online").
  static Future<String?> getRol() => _storage.read(key: _rolKey);

  /// Recupera el ID numérico del rol del usuario (ej. 2 para Vendedor, 6 para Jefe de Ventas, 7 para VendedorOnline).
  static Future<int?> getIdRol() async {
    final val = await _storage.read(key: _idRolKey);
    return val != null ? int.tryParse(val) : null;
  }

  /// Verifica si el usuario actual pertenece al módulo de ventas (Vendedor [2], Jefe de Ventas [6], Vendedor Online [7]).
  static Future<bool> esModuloVentas() async {
    final idRol = await getIdRol();
    if (idRol != null && (idRol == 2 || idRol == 6 || idRol == 7)) return true;
    final rol = await getRol();
    final rLower = rol?.toLowerCase() ?? '';
    return rLower == 'vendedor' ||
        rLower == 'vendedoronline' ||
        rLower == 'vendedor online' ||
        rLower == 'jefe de ventas' ||
        rLower == 'auditor';
  }

  /// Verifica si el usuario actual es VendedorOnline (id_rol == 7).
  static Future<bool> esVendedorOnline() async {
    final idRol = await getIdRol();
    if (idRol == 7) return true;
    final rol = await getRol();
    final rLower = rol?.toLowerCase() ?? '';
    return rLower == 'vendedoronline' || rLower == 'vendedor online';
  }

  /// Verifica si el usuario actual posee permisos de Jefe de Ventas (id_rol == 6).
  static Future<bool> esJefeDeVentas() async {
    final idRol = await getIdRol();
    if (idRol == 6) return true;
    final rol = await getRol();
    final rLower = rol?.toLowerCase() ?? '';
    return rLower == 'jefe de ventas' || rLower == 'auditor';
  }

  /// Recupera el ID de sucursal del usuario autenticado (para Radar de Stock).
  static Future<int?> getSucursalId() async {
    final val = await _storage.read(key: _sucursalKey);
    return val != null ? int.tryParse(val) : null;
  }

  /// Alias de getSucursalId para compatibilidad
  static Future<int?> getIdSucursal() => getSucursalId();

  /// Recupera el nombre de la sucursal del usuario autenticado.
  static Future<String?> getNombreSucursal() =>
      _storage.read(key: _sucursalNombreKey);

  /// Recupera el nombre completo del usuario autenticado.
  static Future<String?> getNombreUsuario() => _storage.read(key: _nombreUsuarioKey);

  /// Elimina el token, rol y datos de sesión (para logout o sesiones expiradas).
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _rolKey);
    await _storage.delete(key: _idRolKey);
    await _storage.delete(key: _sucursalKey);
    await _storage.delete(key: _sucursalNombreKey);
    await _storage.delete(key: _nombreUsuarioKey);
  }

  /// Alias de clearToken para logout explícito
  static Future<void> logout() => clearToken();

  /// Manejador global invocado cuando se detecta un 401 Unauthorized
  static Future<void> manejarSesionExpirada() async {
    await logout();
    BodegaPollingService.instance.reset();

    // Redirigir a login
    final navigator = ApiService.navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    }

    // Mostrar SnackBar explicativo
    final messenger = ApiService.scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Tu sesión ha expirado. Ingresa tu PIN nuevamente',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppPalette.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

