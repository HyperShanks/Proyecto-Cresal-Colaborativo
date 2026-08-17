// lib/core/services/api_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../features/auth/services/auth_service.dart';

/// Cliente HTTP centralizado con soporte para:
/// 1. Intercepción automática de respuestas 401 Unauthorized (Sesión Expirada).
/// 2. Inyección automática de token de autenticación Bearer.
/// 3. Claves globales de navegación y ScaffoldMessenger para auto-logout.
class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Callback personalizable para manejar el evento 401 (útil en tests)
  static Future<void> Function()? onUnauthorized;

  /// Retorna los headers por defecto con el token Bearer si existe
  static Future<Map<String, String>> getHeaders({
    Map<String, String>? extraHeaders,
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?extraHeaders,
    };

    if (includeAuth) {
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Verifica si el código de estado es 401 y dispara el flujo de sesión expirada
  static void _checkStatusCode(int statusCode) {
    if (statusCode == 401) {
      if (onUnauthorized != null) {
        onUnauthorized!();
      } else {
        AuthService.manejarSesionExpirada();
      }
    }
  }

  /// GET con interceptor 401
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool includeAuth = true,
  }) async {
    final finalHeaders = await getHeaders(
      extraHeaders: headers,
      includeAuth: includeAuth,
    );
    final response = await http.get(url, headers: finalHeaders);
    _checkStatusCode(response.statusCode);
    return response;
  }

  /// POST con interceptor 401
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
  }) async {
    final finalHeaders = await getHeaders(
      extraHeaders: headers,
      includeAuth: includeAuth,
    );
    final response = await http.post(
      url,
      headers: finalHeaders,
      body: body,
      encoding: encoding,
    );
    _checkStatusCode(response.statusCode);
    return response;
  }

  /// PUT con interceptor 401
  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
  }) async {
    final finalHeaders = await getHeaders(
      extraHeaders: headers,
      includeAuth: includeAuth,
    );
    final response = await http.put(
      url,
      headers: finalHeaders,
      body: body,
      encoding: encoding,
    );
    _checkStatusCode(response.statusCode);
    return response;
  }

  /// PATCH con interceptor 401
  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
  }) async {
    final finalHeaders = await getHeaders(
      extraHeaders: headers,
      includeAuth: includeAuth,
    );
    final response = await http.patch(
      url,
      headers: finalHeaders,
      body: body,
      encoding: encoding,
    );
    _checkStatusCode(response.statusCode);
    return response;
  }

  /// DELETE con interceptor 401
  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
  }) async {
    final finalHeaders = await getHeaders(
      extraHeaders: headers,
      includeAuth: includeAuth,
    );
    final response = await http.delete(
      url,
      headers: finalHeaders,
      body: body,
      encoding: encoding,
    );
    _checkStatusCode(response.statusCode);
    return response;
  }

  /// Enviar petición personalizada / MultipartRequest con verificación de 401
  static Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await request.send();
    _checkStatusCode(response.statusCode);
    return response;
  }
}
