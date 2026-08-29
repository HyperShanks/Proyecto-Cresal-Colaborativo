import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/tokens/app_palette.dart';
import '../../../core/services/api_service.dart';
import '../../alertas/services/bodega_polling_service.dart';
import '../models/auth_user_model.dart';

// Claves de almacenamiento seguro para sesión
const String _tokenKey = 'access_token';
const String _rolKey = 'user_rol';
const String _idRolKey = 'user_id_rol';
const String _sucursalKey = 'user_sucursal_id';
const String _sucursalNombreKey = 'user_sucursal_nombre';
const String _nombreUsuarioKey = 'user_nombre_completo';
const String _userModelKey = 'user_model_json';

// Claves de almacenamiento seguro para enrolamiento de terminal
const String _enrolledUserIdKey = 'enrolled_user_id';
const String _enrolledUserEmailKey = 'enrolled_user_email';
const String _enrolledUserNameKey = 'enrolled_user_name';

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS DE RESULTADO (evita mezclar lógica HTTP en la UI)
// ─────────────────────────────────────────────────────────────────────────────
class AuthResult {
  final bool success;
  final String? errorMessage;
  final AuthUserModel? user;

  const AuthResult.ok([this.user]) : success = true, errorMessage = null;
  const AuthResult.fail(this.errorMessage) : success = false, user = null;
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  static const _storage = FlutterSecureStorage();

  /// Enrola el terminal vinculándolo al usuario corporativo vía email y contraseña.
  /// Guarda el JWT de sesión y fija el `enrolled_user_id`, `enrolled_user_email` y `enrolled_user_name`.
  static Future<AuthResult> enrolarTerminal(String email, String password) async {
    try {
      final uri = Uri.parse('${ApiConstants.authEndpoint}/login');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = body['access_token'] as String;
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
        final rutUsuario = usuarioMap?['rut_usuario']?.toString() ?? '';
        final userEmail = usuarioMap?['email']?.toString() ?? email.trim().toLowerCase();
        final idUsuario = usuarioMap?['id_usuario']?.toString() ?? '';
        final nombreCompleto = '$nombres $apellidos'.trim();

        final userModel = AuthUserModel(
          idUsuario: idUsuario,
          rutUsuario: rutUsuario,
          nombres: nombres,
          apellidos: apellidos,
          email: userEmail,
          idRol: idRol ?? 0,
          nombreRol: rolText,
          idSucursal: int.tryParse(sucursalId ?? '1') ?? 1,
        );

        // Guardar token, rol, id_rol, sucursal y modelo de usuario
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
        if (nombreCompleto.isNotEmpty) {
          await _storage.write(key: _nombreUsuarioKey, value: nombreCompleto);
        }
        await _storage.write(key: _userModelKey, value: jsonEncode(userModel.toJson()));

        // Guardar datos de enrolamiento del terminal
        if (idUsuario.isNotEmpty) {
          await _storage.write(key: _enrolledUserIdKey, value: idUsuario);
        }
        if (userEmail.isNotEmpty) {
          await _storage.write(key: _enrolledUserEmailKey, value: userEmail);
        }
        if (nombreCompleto.isNotEmpty) {
          await _storage.write(key: _enrolledUserNameKey, value: nombreCompleto);
        }

        return AuthResult.ok(userModel);
      }

      final detail = body['detail'] ?? 'Error desconocido del servidor';
      return AuthResult.fail(detail.toString());
    } on Exception catch (e) {
      return AuthResult.fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Envía el PIN junto al ID del usuario previamente enrolado al backend.
  /// Persiste el nuevo JWT de sesión y los datos del usuario si la autenticación es exitosa.
  static Future<AuthResult> loginConPin(String pin, [String? idUsuarioEnrolado]) async {
    try {
      final targetUserId = idUsuarioEnrolado ?? await getEnrolledUserId();
      if (targetUserId == null || targetUserId.isEmpty) {
        return const AuthResult.fail('Terminal no enrolado. Inicie sesión con email y contraseña.');
      }

      final uri = Uri.parse('${ApiConstants.authEndpoint}/login-pin');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pin_acceso': pin,
              'id_usuario': targetUserId,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final token = body['access_token'] as String;
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
        final rutUsuario = usuarioMap?['rut_usuario']?.toString() ?? '';
        final email = usuarioMap?['email']?.toString() ?? '';
        final idUsuario = usuarioMap?['id_usuario']?.toString() ?? targetUserId;
        final nombreCompleto = '$nombres $apellidos'.trim();

        final userModel = AuthUserModel(
          idUsuario: idUsuario,
          rutUsuario: rutUsuario,
          nombres: nombres,
          apellidos: apellidos,
          email: email,
          idRol: idRol ?? 0,
          nombreRol: rolText,
          idSucursal: int.tryParse(sucursalId ?? '1') ?? 1,
        );

        // Guardar token y datos de sesión activa
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
        if (nombreCompleto.isNotEmpty) {
          await _storage.write(
            key: _nombreUsuarioKey,
            value: nombreCompleto,
          );
        }
        await _storage.write(key: _userModelKey, value: jsonEncode(userModel.toJson()));

        // Asegurar que las claves de enrolamiento se mantengan persistidas
        await _storage.write(key: _enrolledUserIdKey, value: idUsuario);
        if (email.isNotEmpty) {
          await _storage.write(key: _enrolledUserEmailKey, value: email);
        }
        if (nombreCompleto.isNotEmpty) {
          await _storage.write(key: _enrolledUserNameKey, value: nombreCompleto);
        }

        return AuthResult.ok(userModel);
      }

      // Camino triste: el backend retornó un error (401, 422, etc.)
      final detail = body['detail'] ?? 'Error desconocido del servidor';
      return AuthResult.fail(detail.toString());
    } on Exception catch (e) {
      return AuthResult.fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Recupera el ID del usuario previamente enrolado en este terminal.
  static Future<String?> getEnrolledUserId() => _storage.read(key: _enrolledUserIdKey);

  /// Recupera el email del usuario enrolado en este terminal.
  static Future<String?> getEnrolledUserEmail() => _storage.read(key: _enrolledUserEmailKey);

  /// Recupera el nombre completo del usuario enrolado en este terminal.
  static Future<String?> getEnrolledUserName() => _storage.read(key: _enrolledUserNameKey);

  /// Comprueba si el terminal actual cuenta con un usuario enrolado.
  static Future<bool> isTerminalEnrolled() async {
    final id = await getEnrolledUserId();
    return id != null && id.isNotEmpty;
  }

  /// Desenrola completamente el terminal eliminando tanto la sesión activa como el enrolamiento.
  static Future<void> desenrolarTerminal() async {
    await clearToken();
    await _storage.delete(key: _enrolledUserIdKey);
    await _storage.delete(key: _enrolledUserEmailKey);
    await _storage.delete(key: _enrolledUserNameKey);
  }

  /// Recupera el token almacenado (útil para inyectarlo en peticiones futuras).
  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Recupera el rol textual almacenado (ej. "Bodeguero", "Vendedor", "Caja", "Jefe de Ventas").
  static Future<String?> getRol() => _storage.read(key: _rolKey);

  /// Recupera el ID numérico del rol del usuario (ej. 1=Bodega, 2=Ventas, 3=Caja, 5=Admin, 6=Jefe).
  static Future<int?> getIdRol() async {
    final val = await _storage.read(key: _idRolKey);
    return val != null ? int.tryParse(val) : null;
  }

  /// Verifica si el usuario actual pertenece al rol Caja (id_rol == 3).
  static Future<bool> esCaja() async {
    final idRol = await getIdRol();
    if (idRol != null) return idRol == 3;
    final rol = await getRol();
    final rLower = rol?.toLowerCase() ?? '';
    return rLower == 'caja' || rLower == 'operario de caja';
  }

  /// Verifica si el usuario actual posee rol Administrador (id_rol == 5).
  static Future<bool> esAdmin() async {
    final idRol = await getIdRol();
    if (idRol != null) return idRol == 5;
    final rol = await getRol();
    final rLower = rol?.toLowerCase() ?? '';
    return rLower == 'administrador' || rLower == 'admin';
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

  /// Recupera el modelo completo de sesión AuthUserModel si está disponible.
  static Future<AuthUserModel?> getAuthUser() async {
    final jsonStr = await _storage.read(key: _userModelKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AuthUserModel.fromJson(map);
      } catch (_) {}
    }
    // Reconstruir con claves sueltas si no existe el JSON compuesto
    final token = await getToken();
    if (token == null) return null;
    final idRol = await getIdRol() ?? 0;
    final rol = await getRol() ?? '';
    final nombreCompleto = await getNombreUsuario() ?? '';
    final sucursalId = await getSucursalId() ?? 1;

    return AuthUserModel(
      idUsuario: '',
      rutUsuario: '',
      nombres: nombreCompleto,
      apellidos: '',
      email: '',
      idRol: idRol,
      nombreRol: rol,
      idSucursal: sucursalId,
    );
  }

  /// Elimina el token, rol y datos de sesión activa (para logout o sesiones expiradas),
  /// preservando la vinculación/enrolamiento del terminal al operario.
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _rolKey);
    await _storage.delete(key: _idRolKey);
    await _storage.delete(key: _sucursalKey);
    await _storage.delete(key: _sucursalNombreKey);
    await _storage.delete(key: _nombreUsuarioKey);
    await _storage.delete(key: _userModelKey);
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
