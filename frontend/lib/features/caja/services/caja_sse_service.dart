import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../auth/services/auth_service.dart';

/// Cliente ligero Server-Sent Events (SSE) para sincronización en tiempo real (<1s)
/// del Módulo de Caja sin dependencias externas.
///
/// Características:
/// - Usa un [http.Client] dedicado para no interferir con peticiones REST de [ApiService].
/// - Reconexión automática con backoff exponencial (2s -> 5s -> 10s -> 30s) ante microcortes.
/// - Respeta el ciclo de vida del SO (se cierra al minimizar y reconecta al volver).
/// - Se detiene automáticamente ante HTTP 401/403 para evitar bucles de reconexión.
class CajaSseService with WidgetsBindingObserver {
  int _sucursalId;
  final String _endpoint;
  final Future<void> Function()? onPendientesChanged;
  final Future<void> Function()? onHistorialChanged;

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  Timer? _reconnectTimer;

  bool _isStarted = false;
  bool _isDisposed = false;
  bool _isAppResumed = true;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;

  static const List<int> _backoffSeconds = [2, 5, 10, 30];

  CajaSseService({
    required int sucursalId,
    String? endpoint,
    this.onPendientesChanged,
    this.onHistorialChanged,
  })  : _sucursalId = sucursalId,
        _endpoint = endpoint ?? ApiConstants.cajaEndpoint {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isConnected => _subscription != null;

  void start() {
    if (_isDisposed || _isStarted) return;
    _isStarted = true;
    _connect();
  }

  void updateSucursal(int nuevaSucursalId) {
    if (_isDisposed || nuevaSucursalId == _sucursalId) return;
    _sucursalId = nuevaSucursalId;
    if (_isStarted) {
      _closeCurrentConnection();
      _reconnectAttempts = 0;
      _connect();
    }
  }

  Future<void> _connect() async {
    if (_isDisposed || !_isStarted || !_isAppResumed || _isConnecting) return;

    _isConnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      final token = await AuthService.getToken();
      if (_isDisposed || !_isStarted || !_isAppResumed) return;
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      _closeCurrentConnection();
      final client = http.Client();
      _client = client;

      final uri = Uri.parse('$_endpoint/stream').replace(
        queryParameters: {'sucursal_id': _sucursalId.toString()},
      );

      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));

      if (_isDisposed || !_isStarted || !_isAppResumed) {
        client.close();
        return;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint(
          '⚠️ [CajaSSE] Acceso denegado (${response.statusCode}). Stream detenido.',
        );
        client.close();
        _client = null;
        return;
      }

      if (response.statusCode != 200) {
        client.close();
        _client = null;
        _scheduleReconnect();
        return;
      }

      // Conexión SSE establecida correctamente
      _reconnectAttempts = 0;
      debugPrint(
        '📡 [CajaSSE] Canal en tiempo real conectado (sucursal $_sucursalId).',
      );

      String? currentEvent;

      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (_isDisposed) return;
              if (line.isEmpty) {
                if (currentEvent != null) {
                  _dispatchEvent(currentEvent!);
                  currentEvent = null;
                }
                return;
              }
              if (line.startsWith(':')) {
                // Heartbeat / comentario SSE (: ping / : connected)
                return;
              }
              if (line.startsWith('event:')) {
                currentEvent = line.substring(6).trim();
              }
            },
            onError: (Object err) {
              debugPrint('⚠️ [CajaSSE] Error en stream: $err');
              _closeCurrentConnection();
              _scheduleReconnect();
            },
            onDone: () {
              debugPrint('🔌 [CajaSSE] Stream cerrado por el servidor.');
              _closeCurrentConnection();
              _scheduleReconnect();
            },
            cancelOnError: true,
          );
    } catch (e) {
      debugPrint('⚠️ [CajaSSE] No se pudo abrir stream (reintentando): $e');
      _closeCurrentConnection();
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _dispatchEvent(String eventName) {
    if (_isDisposed) return;
    if (eventName == 'pendientes_changed') {
      onPendientesChanged?.call();
    } else if (eventName == 'historial_changed') {
      onHistorialChanged?.call();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || !_isStarted || !_isAppResumed) return;
    _reconnectTimer?.cancel();

    final idx = _reconnectAttempts < _backoffSeconds.length
        ? _reconnectAttempts
        : _backoffSeconds.length - 1;
    final delaySecs = _backoffSeconds[idx];
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySecs), () {
      _connect();
    });
  }

  void _closeCurrentConnection() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _isAppResumed;
    _isAppResumed = (state == AppLifecycleState.resumed);

    if (!_isAppResumed) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _closeCurrentConnection();
    } else if (!wasResumed && _isAppResumed && _isStarted && !_isDisposed) {
      _reconnectAttempts = 0;
      _connect();
    }
  }

  void dispose() {
    _isDisposed = true;
    _isStarted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeCurrentConnection();
    WidgetsBinding.instance.removeObserver(this);
  }
}
