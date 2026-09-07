// frontend/lib/features/gerencia/services/gerencia_service.dart
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../models/gerencia_models.dart';
import '../../caja/models/historial_caja_model.dart';

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

  /// Consulto el listado histórico y auditoría de órdenes de venta (HU-5.2).
  /// Permite filtros multidimensionales por sucursal, estado oficial, periodo temporal,
  /// método de pago, búsqueda predictiva y paginación.
  static Future<HistorialCajaResponseModel> obtenerHistorialOrdenes({
    int? idSucursal,
    String? estado,
    String? periodo,
    String? fechaInicio,
    String? fechaFin,
    String? metodoPago,
    String? busqueda,
    int pagina = 1,
    int limite = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'pagina': pagina.toString(),
        'limite': limite.toString(),
      };
      if (idSucursal != null) {
        queryParams['id_sucursal'] = idSucursal.toString();
      }
      if (estado != null &&
          estado.isNotEmpty &&
          estado.toLowerCase() != 'todos') {
        queryParams['estado'] = estado;
      }
      if (periodo != null && periodo.isNotEmpty) {
        queryParams['periodo'] = periodo;
      }
      if (fechaInicio != null && fechaInicio.isNotEmpty) {
        queryParams['fecha_inicio'] = fechaInicio;
      }
      if (fechaFin != null && fechaFin.isNotEmpty) {
        queryParams['fecha_fin'] = fechaFin;
      }
      if (metodoPago != null &&
          metodoPago.isNotEmpty &&
          metodoPago.toLowerCase() != 'todos') {
        queryParams['metodo_pago'] = metodoPago;
      }
      if (busqueda != null && busqueda.trim().isNotEmpty) {
        queryParams['search'] = busqueda.trim();
      }

      final uri = Uri.parse(ApiConstants.ordenesEndpoint)
          .replace(queryParameters: queryParams);
      final response = await ApiService.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return HistorialCajaResponseModel.fromJson(data);
      } else {
        final msg = ApiService.extraerMensajeError(
          response,
          fallback: 'No fue posible consultar el historial de órdenes.',
        );
        throw CustomApiException(
          messageUser: msg,
          errorCode: 'ORDEN_AUDITORIA_DATA_ERROR',
          statusCode: response.statusCode,
        );
      }
    } on CustomApiException {
      rethrow;
    } catch (e) {
      throw CustomApiException(
        messageUser: 'Error de red al consultar el historial de órdenes.',
        errorCode: 'ORDEN_AUDITORIA_NETWORK_ERROR',
        messageDev: e.toString(),
      );
    }
  }

  /// Consulto el detalle jerárquico 360° de una orden para auditoría forense (HU-5.2).
  static Future<Map<String, dynamic>> obtenerDetalleOrden(
      String idOrden) async {
    try {
      final uri = Uri.parse('${ApiConstants.ordenesEndpoint}/$idOrden');
      final response = await ApiService.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final msg = ApiService.extraerMensajeError(
          response,
          fallback: 'No se encontró la orden especificada.',
        );
        throw CustomApiException(
          messageUser: msg,
          errorCode: 'ORDEN_AUDITORIA_NOT_FOUND',
          statusCode: response.statusCode,
        );
      }
    } on CustomApiException {
      rethrow;
    } catch (e) {
      throw CustomApiException(
        messageUser: 'Error al cargar el detalle de la orden.',
        errorCode: 'ORDEN_AUDITORIA_NETWORK_ERROR',
        messageDev: e.toString(),
      );
    }
  }
}
