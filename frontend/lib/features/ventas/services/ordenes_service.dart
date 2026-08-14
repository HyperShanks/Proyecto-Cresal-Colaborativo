// lib/features/ventas/services/ordenes_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_service.dart';

/// DTO de respuesta para la creación y consulta de órdenes de venta.
class OrdenResponseModel {
  final String idOrden;
  final String estadoOrden;
  final int totalVenta;
  final int montoPendiente;
  final String? qrTransaccionalSalida;
  final String mensaje;
  final String? fechaCreacion;
  final int totalItems;

  const OrdenResponseModel({
    required this.idOrden,
    required this.estadoOrden,
    required this.totalVenta,
    required this.montoPendiente,
    this.qrTransaccionalSalida,
    required this.mensaje,
    this.fechaCreacion,
    required this.totalItems,
  });

  factory OrdenResponseModel.fromJson(Map<String, dynamic> json) {
    return OrdenResponseModel(
      idOrden: json['id_orden']?.toString() ?? '',
      estadoOrden: json['estado_orden']?.toString() ?? 'Reservada',
      totalVenta: json['total_venta'] as int? ?? 0,
      montoPendiente: json['monto_pendiente'] as int? ?? 0,
      qrTransaccionalSalida: json['qr_transaccional_salida']?.toString(),
      mensaje: json['mensaje']?.toString() ?? 'Orden generada exitosamente',
      fechaCreacion: json['fecha_creacion']?.toString(),
      totalItems: json['total_items'] as int? ?? 0,
    );
  }

  /// Retorna el monto formateado en pesos chilenos (ej: $520.000)
  String get totalVentaFormateado {
    final str = totalVenta.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return '\$${buffer.toString().split('').reversed.join('')}';
  }
}

/// Servicio HTTP para la gestión de órdenes de venta en FastAPI (HU-3.4).
class OrdenesService {
  /// Envía la orden de venta transaccional al backend FastAPI (POST /api/v1/ordenes)
  /// inyectando el Bearer Token del usuario autenticado.
  static Future<OrdenResponseModel> crearOrden(
    Map<String, dynamic> payload, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(ApiConstants.ordenesEndpoint);
      final token = await AuthService.getToken();

      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
              'Tiempo de espera agotado al comunicarse con el servidor.',
            ),
          );

      dynamic decodedBody;
      try {
        decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        try {
          decodedBody = jsonDecode(response.body);
        } catch (_) {
          decodedBody = null;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decodedBody is Map<String, dynamic>) {
          return OrdenResponseModel.fromJson(decodedBody);
        }
        throw Exception('Formato de respuesta no válido del servidor.');
      } else if (response.statusCode == 409) {
        final detail = decodedBody is Map ? decodedBody['detail'] : null;
        throw Exception(
          detail?.toString() ??
              'Conflicto de stock: Uno o más repuestos ya no se encuentran disponibles.',
        );
      } else if (response.statusCode == 400) {
        final detail = decodedBody is Map ? decodedBody['detail'] : null;
        throw Exception(
          detail?.toString() ?? 'Datos de la orden inválidos. Revisa el formulario.',
        );
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Por favor vuelve a iniciar sesión.');
      } else if (response.statusCode == 404) {
        final detail = decodedBody is Map ? decodedBody['detail'] : null;
        throw Exception(
          detail?.toString() ?? 'Recurso o repuesto no encontrado en el sistema.',
        );
      } else {
        final detail = decodedBody is Map ? decodedBody['detail'] : null;
        throw Exception(
          detail?.toString() ??
              'Error en el servidor al procesar la orden (${response.statusCode}).',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error inesperado al generar la orden: $e');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Busca un cliente en el backend por su RUT para autocompletar el formulario de Micro-CRM.
  /// Si el cliente existe (200), retorna un mapa con sus datos.
  /// Si no existe (404) o hay error de red, retorna `null` silenciosamente sin romper el flujo de UI.
  static Future<Map<String, dynamic>?> buscarClientePorRut(
    String rut, {
    http.Client? client,
  }) async {
    final cleanRut = rut.trim();
    if (cleanRut.isEmpty) return null;

    final httpClient = client ?? http.Client();

    try {
      final encodedRut = Uri.encodeComponent(cleanRut);
      final uri = Uri.parse('${ApiConstants.clientesEndpoint}/$encodedRut');
      final token = await AuthService.getToken();

      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        dynamic decoded;
        try {
          decoded = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          decoded = jsonDecode(response.body);
        }
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}
