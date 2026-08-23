import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../models/cobro_pendiente_model.dart';

abstract class ICajaService {
  Future<List<CobroPendienteModel>> obtenerCobrosPendientes({
    required int sucursalId,
    String? busqueda,
    String? tipoOperacion,
  });
}

class CajaService implements ICajaService {
  final String _endpoint;

  CajaService({String? endpoint})
      : _endpoint = endpoint ?? ApiConstants.cajaEndpoint;

  @override
  Future<List<CobroPendienteModel>> obtenerCobrosPendientes({
    required int sucursalId,
    String? busqueda,
    String? tipoOperacion,
  }) async {
    final queryParams = <String, String>{
      'sucursal_id': sucursalId.toString(),
    };

    if (busqueda != null && busqueda.trim().isNotEmpty) {
      queryParams['busqueda'] = busqueda.trim();
    }

    if (tipoOperacion != null && tipoOperacion.trim().isNotEmpty) {
      queryParams['tipo_operacion'] = tipoOperacion.trim().toUpperCase();
    }

    final uri = Uri.parse('$_endpoint/pendientes').replace(
      queryParameters: queryParams,
    );

    final response = await ApiService.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final itemsRaw = data['items'] as List<dynamic>? ?? [];
      return itemsRaw
          .map((e) => CobroPendienteModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      String mensaje = 'Error al obtener cobros pendientes (${response.statusCode})';
      try {
        final errJson = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (errJson.containsKey('detail')) {
          mensaje = errJson['detail'].toString();
        }
      } catch (_) {}
      throw Exception(mensaje);
    }
  }
}
