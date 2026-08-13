import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/api_constants.dart';

// Claves de almacenamiento seguro
const String _tokenKey = 'access_token';
const String _rolKey = 'user_rol';

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
        final rolText = usuarioMap?['nombre_rol']?.toString() ??
            usuarioMap?['rol']?['nombre_rol']?.toString() ??
            '';

        // Guardar token y rol de forma segura en el dispositivo
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _rolKey, value: rolText);
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

  /// Elimina el token y el rol (para logout o sesiones expiradas).
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _rolKey);
  }
}

