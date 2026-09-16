// lib/core/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../features/auth/services/auth_service.dart';

/// Excepción estandarizada para errores de API y red (SPEC-HU-07).
class CustomApiException implements Exception {
  final String messageUser;
  final String errorCode;
  final int? statusCode;
  final String? messageDev;

  const CustomApiException({
    required this.messageUser,
    this.errorCode = 'API_ERROR',
    this.statusCode,
    this.messageDev,
  });

  @override
  String toString() => messageUser;
}

/// Cliente HTTP centralizado con soporte para:
/// 1. Intercepción automática de respuestas 401 Unauthorized (Sesión Expirada).
/// 2. Inyección automática de token de autenticación Bearer.
/// 3. Normalización y sanitización de respuestas de error (SPEC-HU-07).
/// 4. Captura resiliente de fallos de red (Timeouts, desconexiones).
class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Timeout estándar para todas las peticiones HTTP (resiliente a redes lentas y cold-starts)
  static const Duration defaultTimeout = Duration(seconds: 35);

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

  /// Extrae el mensaje de error sanitizado para el usuario desde la respuesta HTTP
  static String extraerMensajeError(
    http.Response response, {
    String fallback = 'Ocurrió un error al procesar la solicitud.',
  }) {
    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded['message_user'] != null &&
              decoded['message_user'].toString().trim().isNotEmpty) {
            return decoded['message_user'].toString().trim();
          }
          if (decoded['detail'] != null &&
              decoded['detail'].toString().trim().isNotEmpty) {
            return decoded['detail'].toString().trim();
          }
          if (decoded['message'] != null &&
              decoded['message'].toString().trim().isNotEmpty) {
            return decoded['message'].toString().trim();
          }
          if (decoded['msg'] != null &&
              decoded['msg'].toString().trim().isNotEmpty) {
            return decoded['msg'].toString().trim();
          }
        }
      }
    } catch (_) {
      // Si el cuerpo no es JSON válido, usamos el mapeo por código de estado
    }

    switch (response.statusCode) {
      case 400:
        return 'Solicitud incorrecta o parámetros inválidos.';
      case 401:
        return 'Credenciales inválidas o sesión expirada.';
      case 403:
        return 'No tienes permisos suficientes para realizar esta acción.';
      case 404:
        return 'El recurso solicitado no fue encontrado.';
      case 409:
        return 'El registro ya existe o se encuentra en conflicto con otra operación.';
      case 422:
        return 'Los datos ingresados no tienen un formato válido.';
      case 503:
        return 'El servicio no está disponible temporalmente. Intenta más tarde.';
      case 500:
      default:
        return 'Ocurrió un error inesperado en el servidor. Intenta nuevamente.';
    }
  }

  /// Envoltorio resiliente para ejecutar peticiones HTTP y mapear errores de red
  static Future<T> ejecutarConManejoErrores<T>(
    Future<T> Function() accion,
  ) async {
    try {
      return await accion();
    } on TimeoutException {
      throw const CustomApiException(
        messageUser: 'Problemas de conexión con el servidor. Reintentando...',
        errorCode: 'NETWORK_TIMEOUT',
      );
    } on SocketException {
      throw const CustomApiException(
        messageUser: 'Problemas de conexión con el servidor. Reintentando...',
        errorCode: 'NETWORK_SOCKET_ERROR',
      );
    } on http.ClientException {
      throw const CustomApiException(
        messageUser: 'Problemas de conexión con el servidor. Reintentando...',
        errorCode: 'NETWORK_CLIENT_ERROR',
      );
    } on CustomApiException {
      rethrow;
    } catch (e) {
      throw CustomApiException(
        messageUser: e.toString().replaceFirst('Exception: ', '').trim(),
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// GET con interceptor 401 y timeout
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    return ejecutarConManejoErrores(() async {
      final finalHeaders = await getHeaders(
        extraHeaders: headers,
        includeAuth: includeAuth,
      );
      final response = await http
          .get(url, headers: finalHeaders)
          .timeout(timeout ?? defaultTimeout);
      _checkStatusCode(response.statusCode);
      return response;
    });
  }

  /// POST con interceptor 401 y timeout
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    return ejecutarConManejoErrores(() async {
      final finalHeaders = await getHeaders(
        extraHeaders: headers,
        includeAuth: includeAuth,
      );
      final response = await http
          .post(
            url,
            headers: finalHeaders,
            body: body,
            encoding: encoding,
          )
          .timeout(timeout ?? defaultTimeout);
      _checkStatusCode(response.statusCode);
      return response;
    });
  }

  /// PUT con interceptor 401 y timeout
  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    return ejecutarConManejoErrores(() async {
      final finalHeaders = await getHeaders(
        extraHeaders: headers,
        includeAuth: includeAuth,
      );
      final response = await http
          .put(
            url,
            headers: finalHeaders,
            body: body,
            encoding: encoding,
          )
          .timeout(timeout ?? defaultTimeout);
      _checkStatusCode(response.statusCode);
      return response;
    });
  }

  /// PATCH con interceptor 401 y timeout
  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    return ejecutarConManejoErrores(() async {
      final finalHeaders = await getHeaders(
        extraHeaders: headers,
        includeAuth: includeAuth,
      );
      final response = await http
          .patch(
            url,
            headers: finalHeaders,
            body: body,
            encoding: encoding,
          )
          .timeout(timeout ?? defaultTimeout);
      _checkStatusCode(response.statusCode);
      return response;
    });
  }

  /// DELETE con interceptor 401 y timeout
  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    return ejecutarConManejoErrores(() async {
      final finalHeaders = await getHeaders(
        extraHeaders: headers,
        includeAuth: includeAuth,
      );
      final response = await http
          .delete(
            url,
            headers: finalHeaders,
            body: body,
            encoding: encoding,
          )
          .timeout(timeout ?? defaultTimeout);
      _checkStatusCode(response.statusCode);
      return response;
    });
  }

  /// Enviar petición personalizada / MultipartRequest con verificación de 401
  static Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return ejecutarConManejoErrores(() async {
      final response = await request.send();
      _checkStatusCode(response.statusCode);
      return response;
    });
  }
}
