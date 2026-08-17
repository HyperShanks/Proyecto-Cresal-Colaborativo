// lib/features/alertas/services/bodega_polling_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tarea_alerta.dart';
import 'logistica_service.dart';
import '../../auth/services/auth_service.dart';

/// Servicio de Polling y Notificaciones Locales de Bodega con control granular:
/// 1. Deduplicación de tareas nuevas en ciclos de 1 minuto (Set de IDs notificados).
/// 2. Recordatorio periódico de tareas pendientes cada 2 horas.
class BodegaPollingService {
  static final BodegaPollingService _instance = BodegaPollingService._internal();
  factory BodegaPollingService() => _instance;
  static BodegaPollingService get instance => _instance;

  BodegaPollingService._internal();

  Timer? _pollingTimer;

  /// Set en memoria para deduplicar alertas y evitar notificaciones repetidas
  final Set<String> _tareasNotificadas = {};

  /// Marca de tiempo de la última notificación de resumen emitida
  DateTime? _ultimaAlertaResumen;

  /// Callback personalizable para disparar notificaciones locales o avisos en UI
  void Function(String titulo, String cuerpo)? onNotificacion;

  /// Notifiers reactivos para la UI
  final ValueNotifier<int> totalPendientesNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> tieneTrasladosNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<TareaAlerta>> tareasNotifier = ValueNotifier<List<TareaAlerta>>([]);

  bool _isPolling = false;

  Set<String> get tareasNotificadas => Set.unmodifiable(_tareasNotificadas);
  DateTime? get ultimaAlertaResumen => _ultimaAlertaResumen;
  bool get isPollingActive => _pollingTimer != null && _pollingTimer!.isActive;

  /// Inicia el temporizador de polling (por defecto cada 1 minuto)
  void iniciarPolling({
    int? sucursalId,
    Duration interval = const Duration(minutes: 1),
  }) {
    detenerPolling();
    // Ejecutar ciclo inicial
    procesarCiclo(sucursalId: sucursalId);

    _pollingTimer = Timer.periodic(interval, (_) {
      procesarCiclo(sucursalId: sucursalId);
    });
  }

  /// Detiene el ciclo de polling
  void detenerPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Reinicia el estado interno del servicio (al cambiar de usuario o cerrar sesión)
  void reset() {
    detenerPolling();
    _tareasNotificadas.clear();
    _ultimaAlertaResumen = null;
    totalPendientesNotifier.value = 0;
    tieneTrasladosNotifier.value = false;
    tareasNotifier.value = [];
  }

  /// Ejecuta un ciclo completo de verificación de alertas y recordatorios
  Future<void> procesarCiclo({int? sucursalId, List<TareaAlerta>? tareasMock}) async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      List<TareaAlerta> tareas;
      if (tareasMock != null) {
        tareas = tareasMock;
      } else {
        final targetSucursal = sucursalId ?? await AuthService.getSucursalId();
        tareas = await LogisticaService.obtenerAlertas(sucursalId: targetSucursal);
      }

      // Actualizar estados reactivos para la UI
      tareasNotifier.value = tareas;
      totalPendientesNotifier.value = tareas.length;
      tieneTrasladosNotifier.value = tareas.any((t) => t.esTraslado || t.tipoAlerta == 'TRASLADO');

      // ── 1. Deduplicación de Tareas Nuevas (Ciclo de 1 minuto) ─────────────
      final tareasNuevas = tareas.where((t) {
        final idClave = t.idDetalle ?? t.idTarea;
        return idClave.isNotEmpty && !_tareasNotificadas.contains(idClave);
      }).toList();

      if (tareasNuevas.isNotEmpty) {
        final esTraslado = tareasNuevas.any((t) => t.esTraslado || t.tipoAlerta == 'TRASLADO');
        final titulo = '¡Nueva tarea de bodega!';
        final cuerpo = esTraslado
            ? 'Se ha asignado un nuevo traslado inter-sucursal pendiente de preparación.'
            : 'Se ha asignado una nueva preparación/traslado.';

        _emitirNotificacion(titulo, cuerpo);

        for (final t in tareasNuevas) {
          final idClave = t.idDetalle ?? t.idTarea;
          if (idClave.isNotEmpty) {
            _tareasNotificadas.add(idClave);
          }
        }
      }

      // Sincronizar el set: Retener solo los IDs que sigan existiendo en el backend
      final idsActuales = tareas
          .map((t) => t.idDetalle ?? t.idTarea)
          .where((id) => id.isNotEmpty)
          .toSet();

      _tareasNotificadas.removeWhere((id) => !idsActuales.contains(id));

      // ── 2. Recordatorio Periódico (Ciclo de 2 horas) ──────────────────────
      final ahora = DateTime.now();
      if (tareas.isNotEmpty) {
        final bool debeEmitirResumen = _ultimaAlertaResumen == null ||
            ahora.difference(_ultimaAlertaResumen!) >= const Duration(hours: 2);

        if (debeEmitirResumen) {
          final total = tareas.length;
          _emitirNotificacion(
            'Recordatorio de Bodega',
            'Tienes $total ${total == 1 ? "tarea pendiente" : "tareas pendientes"} en tu sucursal.',
          );
          _ultimaAlertaResumen = ahora;
        }
      }
    } catch (e) {
      debugPrint('BodegaPollingService error en ciclo: $e');
    } finally {
      _isPolling = false;
    }
  }

  void _emitirNotificacion(String titulo, String cuerpo) {
    debugPrint('[BODEGA NOTIFICACIÓN] $titulo - $cuerpo');
    if (onNotificacion != null) {
      onNotificacion!(titulo, cuerpo);
    }
  }
}
