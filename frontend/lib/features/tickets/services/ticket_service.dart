import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/services/auth_service.dart';
import '../models/ticket_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONFIGURACIÓN DE URL BASE
//   • localhost → Windows / Web / macOS desktop
//   • 10.0.2.2  → Emulador Android (apunta al localhost del PC host)
// ─────────────────────────────────────────────────────────────────────────────
//const String _baseUrl = 'http://localhost:8000/api/v1/tickets';
const String _baseUrl =
    'https://cresal-backend-dev.onrender.com/api/v1/tickets';
//const String _baseUrl = 'http://192.168.1.85:8000/api/v1/tickets';

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO TIPADO DE OPERACIONES DE TICKET
// Evita mezclar lógica HTTP con la UI, siguiendo el patrón de AuthResult.
// ─────────────────────────────────────────────────────────────────────────────
class TicketResult {
  final bool success;
  final String? errorMessage;
  final TicketModel? ticket;

  const TicketResult.ok(this.ticket) : success = true, errorMessage = null;

  const TicketResult.fail(this.errorMessage) : success = false, ticket = null;
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO PRINCIPAL DE TICKETS
// ─────────────────────────────────────────────────────────────────────────────
class TicketService {
  // ── Helpers privados ───────────────────────────────────────────────────────

  /// Construye los headers HTTP con el token JWT del operario autenticado.
  /// Lanza un [Exception] si no hay sesión activa.
  static Future<Map<String, String>> _buildAuthHeaders() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception(
        'Sin sesión activa. Por favor, inicie sesión nuevamente.',
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── POST / — Crear un nuevo ticket ────────────────────────────────────────

  /// Envía una petición POST al backend para crear un ticket de soporte.
  ///
  /// El campo [id_usuario_creador] es inyectado automáticamente por el backend
  /// al decodificar el JWT, por lo que no se incluye en el payload.
  ///
  /// Retorna [TicketResult.ok(ticket)] si el ticket fue creado exitosamente,
  /// o [TicketResult.fail(mensaje)] con el detalle del error del servidor.
  static Future<TicketResult> crearTicket({
    required String tipoTicket,
    required String prioridad,
    required String asunto,
    required String descripcion,
    String? tablaReferencia,
    String? idReferencia,
  }) async {
    try {
      final headers = await _buildAuthHeaders();
      final uri = Uri.parse(_baseUrl);

      final body = jsonEncode({
        'tipo_ticket': tipoTicket,
        'prioridad': prioridad,
        'asunto': asunto,
        'descripcion': descripcion,
        if (tablaReferencia != null) 'tabla_referencia': tablaReferencia,
        if (idReferencia != null) 'id_referencia': idReferencia,
      });

      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final ticket = TicketModel.fromJson(json);
        return TicketResult.ok(ticket);
      }

      // Camino triste: el backend retornó un error (401, 422, etc.)
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = errorBody['detail'] ?? 'Error desconocido del servidor';
      return TicketResult.fail(detail.toString());
    } on Exception catch (e) {
      return TicketResult.fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── GET /mis-tickets — Listar los tickets del usuario autenticado ──────────

  /// Obtiene la lista de tickets creados por el operario autenticado,
  /// ordenados por fecha de creación descendente.
  ///
  /// Retorna la lista de [TicketModel] o lanza una excepción con el detalle
  /// del error para que la UI la capture y muestre al usuario.
  static Future<List<TicketModel>> obtenerMisTickets() async {
    try {
      final headers = await _buildAuthHeaders();
      final uri = Uri.parse('$_baseUrl/mis-tickets');

      final response = await http
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList =
            jsonDecode(response.body) as List<dynamic>;
        return jsonList
            .map((item) => TicketModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // Camino triste: error del servidor
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = errorBody['detail'] ?? 'Error al obtener los tickets';
      throw Exception(detail.toString());
    } on Exception {
      rethrow; // Propaga la excepción para que la UI la maneje
    }
  }
}
