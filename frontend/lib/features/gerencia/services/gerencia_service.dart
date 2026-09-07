// frontend/lib/features/gerencia/services/gerencia_service.dart
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../models/gerencia_models.dart';

/// Servicio de integración para el módulo de Gerencia (HU-5.1).
/// Implementé métodos asíncronos para consultar los 3 endpoints analíticos,
/// capturando posibles fallas de red y extrayendo mensajes sanitizados.
class GerenciaService {
  /// Consulto las métricas financieras (Ventas hoy, MTD, Ticket promedio, Margen).
  static Future<KpiFinancieroModel> obtenerKpis({int? idSucursal}) async {
    try {
      final queryParam =
          idSucursal != null ? '?id_sucursal=$idSucursal' : '';
      final url =
          Uri.parse('${ApiConstants.gerenciaEndpoint}/dashboard/kpis$queryParam');

      final response = await ApiService.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return KpiFinancieroModel.fromJson(data);
      } else {
        final msg = ApiService.extraerMensajeError(
          response,
          fallback: 'No fue posible cargar los KPIs financieros.',
        );
        throw CustomApiException(
          messageUser: msg,
          errorCode: 'GERENCIA_DATA_ERROR',
          statusCode: response.statusCode,
        );
      }
    } on CustomApiException {
      rethrow;
    } catch (e) {
      throw CustomApiException(
        messageUser:
            'No fue posible cargar las métricas gerenciales. Reintentando...',
        errorCode: 'GERENCIA_NETWORK_ERROR',
        messageDev: e.toString(),
      );
    }
  }

  /// Consulto el desglose de métodos de pago y comparativa efectivo vs electrónico.
  static Future<ResumenPagosModel> obtenerResumenPagos({int? idSucursal}) async {
    try {
      final queryParam =
          idSucursal != null ? '?id_sucursal=$idSucursal' : '';
      final url =
          Uri.parse('${ApiConstants.gerenciaEndpoint}/dashboard/pagos$queryParam');

      final response = await ApiService.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ResumenPagosModel.fromJson(data);
      } else {
        final msg = ApiService.extraerMensajeError(
          response,
          fallback: 'No fue posible cargar el resumen de medios de pago.',
        );
        throw CustomApiException(
          messageUser: msg,
          errorCode: 'GERENCIA_DATA_ERROR',
          statusCode: response.statusCode,
        );
      }
    } on CustomApiException {
      rethrow;
    } catch (e) {
      throw CustomApiException(
        messageUser:
            'Error al consultar la distribución de pagos. Reintentando...',
        errorCode: 'GERENCIA_NETWORK_ERROR',
        messageDev: e.toString(),
      );
    }
  }

  /// Consulto el flujo operativo de bodega, cuellos de botella y saldos pendientes.
  static Future<FlujoOperativoModel> obtenerFlujoOperativo(
      {int? idSucursal}) async {
    try {
      final queryParam =
          idSucursal != null ? '?id_sucursal=$idSucursal' : '';
      final url = Uri.parse(
          '${ApiConstants.gerenciaEndpoint}/dashboard/operativa$queryParam');

      final response = await ApiService.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FlujoOperativoModel.fromJson(data);
      } else {
        final msg = ApiService.extraerMensajeError(
          response,
          fallback: 'No fue posible cargar el flujo operativo de bodega.',
        );
        throw CustomApiException(
          messageUser: msg,
          errorCode: 'GERENCIA_DATA_ERROR',
          statusCode: response.statusCode,
        );
      }
    } on CustomApiException {
      rethrow;
    } catch (e) {
      throw CustomApiException(
        messageUser:
            'Error de conexión con el pulso de bodega. Reintentando...',
        errorCode: 'GERENCIA_NETWORK_ERROR',
        messageDev: e.toString(),
      );
    }
  }
}
