import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';

// Claves de almacenamiento seguro
const String _tokenKey = 'access_token';
const String _rolKey = 'user_rol';
const String _sucursalKey = 'user_sucursal_id';
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
        if (rolText.isEmpty && usuarioMap?['id_rol'] != null) {
          final idRol = usuarioMap!['id_rol'];
          if (idRol == 1) rolText = 'Bodeguero';
          if (idRol == 2) rolText = 'Vendedor';
          if (idRol == 3) rolText = 'Caja';
          if (idRol == 4) rolText = 'Gerente';
          if (idRol == 5) rolText = 'Administrador';
          if (idRol == 6) rolText = 'Auditor';
        }
        final sucursalId = usuarioMap?['id_sucursal']?.toString();
        final nombres = usuarioMap?['nombres']?.toString() ?? '';
        final apellidos = usuarioMap?['apellidos']?.toString() ?? '';

        // Guardar token, rol y sucursal de forma segura en el dispositivo
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _rolKey, value: rolText);
        if (sucursalId != null) {
          await _storage.write(key: _sucursalKey, value: sucursalId);
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

  /// Recupera el rol textual almacenado (ej. "Bodeguero", "Vendedor").
  static Future<String?> getRol() => _storage.read(key: _rolKey);

  /// Recupera el ID de sucursal del usuario autenticado (para Radar de Stock).
  static Future<int?> getSucursalId() async {
    final val = await _storage.read(key: _sucursalKey);
    return val != null ? int.tryParse(val) : null;
  }

  /// Recupera el nombre completo del usuario autenticado.
  static Future<String?> getNombreUsuario() => _storage.read(key: _nombreUsuarioKey);

  /// Elimina el token, rol y datos de sesión (para logout o sesiones expiradas).
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _rolKey);
    await _storage.delete(key: _sucursalKey);
    await _storage.delete(key: _nombreUsuarioKey);
  }
}

