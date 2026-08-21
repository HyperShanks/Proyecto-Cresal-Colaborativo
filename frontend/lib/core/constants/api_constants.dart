// lib/core/constants/api_constants.dart

class ApiConstants {
  // ==========================================
  // SINGLE SOURCE OF TRUTH (URL BASE)
  // ==========================================

  // URL DE PRODUCCIÓN (Render)
  static const String _baseUrl = 'https://cresal-backend-dev.onrender.com/api';

  // ==========================================
  // ENDPOINTS ESPECÍFICOS
  // ==========================================

  // Autenticación (No utiliza v1)
  static const String authEndpoint = '$_baseUrl/auth';

  // Módulos principales (Utilizan v1)
  static const String ticketsEndpoint = '$_baseUrl/v1/tickets';
  static const String vehiculosEndpoint = '$_baseUrl/v1/vehiculos';
  static const String inventarioEndpoint = '$_baseUrl/v1/inventario';
  static const String bodegaEndpoint = '$_baseUrl/v1/bodega';
  static const String ordenesEndpoint = '$_baseUrl/v1/ordenes';
  static const String clientesEndpoint = '$_baseUrl/v1/clientes';
  static const String despachosEndpoint = '$_baseUrl/v1/despachos';

  static String get baseUrl => _baseUrl;
}
