import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURACIÓN DE URL BASE
//   • 10.0.2.2  → Emulador Android (apunta al localhost del PC host)
//   • 127.0.0.1 → Windows / Web / macOS desktop
// ─────────────────────────────────────────────────────────────────────────────

//const String _baseUrl = 'https://cresal-backend-dev.onrender.com/api/auth';
const String _baseUrl = 'http://192.168.1.85:8000/api/auth';

// Clave bajo la que se guarda el JWT en el almacenamiento seguro
const String _tokenKey = 'access_token';

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

  /// Envía el PIN al backend y persiste el JWT si la autenticación es exitosa.
  ///
  /// Retorna [AuthResult.ok()] si el login fue correcto,
  /// o [AuthResult.fail(mensaje)] con el detalle del error del servidor.
  static Future<AuthResult> loginConPin(String pin) async {
    try {
      final uri = Uri.parse('$_baseUrl/login-pin');

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
        // Guardar el token de forma segura en el dispositivo
        await _storage.write(key: _tokenKey, value: token);
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

  /// Elimina el token (para logout o sesiones expiradas).
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
