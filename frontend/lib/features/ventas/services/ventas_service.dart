import 'package:http/http.dart' as http;
import 'ordenes_service.dart';

/// Servicio de alto nivel para el módulo de Ventas y Mesón
class VentasService {
  /// Ejecuta la anulación de una orden en el Mesón de Ventas con motivo y reversa de pagos (SPEC-HU-TAREA-4).
  static Future<Map<String, dynamic>> anularOrden(
    String idOrden, {
    String? motivoAnulacion,
    http.Client? client,
  }) async {
    return OrdenesService.anularOrden(
      idOrden,
      motivoAnulacion: motivoAnulacion,
      usePost: true,
      client: client,
    );
  }
}
