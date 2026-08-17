import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tarea_alerta.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_service.dart';

class LogisticaService {
  /// Obtiene la lista de tareas operativas pendientes de bodega para la sucursal del usuario
  static Future<List<TareaAlerta>> obtenerAlertas({int? sucursalId}) async {
    try {
      final token = await AuthService.getToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Si no se provee sucursalId, intentamos obtenerlo de la sesión o usamos 1 por defecto
      int targetSucursal = sucursalId ?? 1;
      final uri = Uri.parse('${ApiConstants.bodegaEndpoint}/tareas-pendientes?sucursal_id=$targetSucursal');

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        // Aseguramos decodificación correcta para caracteres especiales/tildes
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => TareaAlerta.fromJson(item)).toList();
      } else {
        throw Exception(
          'Error al cargar alertas del servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Marca la preparación de pre-entrega de una pieza como 'Listo'
  static Future<bool> completarPreentrega(String idDetalle) async {
    try {
      final token = await AuthService.getToken();
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final uri = Uri.parse('${ApiConstants.bodegaEndpoint}/tareas/$idDetalle/completar-preentrega');
      final response = await http.patch(uri, headers: headers);

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['detail'] ?? 'Error al completar pre-entrega: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al marcar listo: $e');
    }
  }
}
