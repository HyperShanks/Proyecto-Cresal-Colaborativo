// lib/features/alertas/services/bodega_polling_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tarea_alerta.dart';
import 'logistica_service.dart';
import '../../auth/services/auth_service.dart';

/// Servicio de Polling Reactivo de Bodega (SPEC-HU-06):
/// Controla la carga operativa y actualiza el Badge numérico en tiempo real
/// sin emitir notificaciones emergentes invasivas en la UI principal.
class BodegaPollingService {
  static final BodegaPollingService _instance = BodegaPollingService._internal();
  factory BodegaPollingService() => _instance;
  static BodegaPollingService get instance => _instance;

  BodegaPollingService._internal();

  Timer? _pollingTimer;

  /// Set en memoria para deduplicar alertas (compatibilidad)
  final Set<String> _tareasNotificadas = {};

  /// Marca de tiempo de la última notificación de resumen emitida
  DateTime? _ultimaAlertaResumen;

  /// Callback personalizable para disparar notificaciones locales o avisos en UI
  void Function(String titulo, String cuerpo)? onNotificacion;

  /// Notifiers reactivos para el Badge del AppBar y el Panel Desplegable
  final ValueNotifier<int> totalPendientesNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> tieneTrasladosNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<TareaAlerta>> tareasNotifier = ValueNotifier<List<TareaAlerta>>([]);
  final ValueNotifier<ResumenAlertasModel> resumenNotifier = ValueNotifier<ResumenAlertasModel>(ResumenAlertasModel.vacio());

  bool _isPolling = false;

  Set<String> get tareasNotificadas => Set.unmodifiable(_tareasNotificadas);
  DateTime? get ultimaAlertaResumen => _ultimaAlertaResumen;
  bool get isPollingActive => _pollingTimer != null && _pollingTimer!.isActive;

  /// Inicia el temporizador de polling (por defecto cada 30-60 segundos)
  void iniciarPolling({
    int? sucursalId,
    Duration interval = const Duration(seconds: 45),
  }) {
    detenerPolling();
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
    resumenNotifier.value = ResumenAlertasModel.vacio();
  }

  /// Decrementa manualmente el contador reactivo tras completar una tarea (Zero Latency UI)
  void decrementarPendiente() {
    if (totalPendientesNotifier.value > 0) {
      totalPendientesNotifier.value--;
    }
  }

  /// Ejecuta un ciclo completo de sincronización de alertas y resumen con el backend
  Future<void> procesarCiclo({int? sucursalId, List<TareaAlerta>? tareasMock}) async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      List<TareaAlerta> tareas;
      ResumenAlertasModel resumen;

      if (tareasMock != null) {
        tareas = tareasMock;
        final prep = tareas.where((t) => t.tipoAlerta == 'PREPARACION' || t.tipoAlerta == 'TRASLADO').length;
        final ent = tareas.where((t) => t.tipoAlerta == 'LIBERADA' || t.tipoAlerta == 'IMPRESION').length;
        final reing = tareas.where((t) => t.tipoAlerta == 'REINGRESO').length;
        resumen = ResumenAlertasModel(
          totalTareas: tareas.length,
          desglosePreparacion: prep,
          desgloseEntregas: ent,
          desgloseReingresos: reing,
        );
      } else {
        final targetSucursal = sucursalId ?? await AuthService.getSucursalId();
        final futures = await Future.wait([
          LogisticaService.obtenerAlertas(sucursalId: targetSucursal),
          LogisticaService.obtenerResumenAlertas(sucursalId: targetSucursal),
        ]);
        tareas = futures[0] as List<TareaAlerta>;
        resumen = futures[1] as ResumenAlertasModel;
      }

      // Actualizar estados reactivos para la UI (Badge y Panel)
      tareasNotifier.value = tareas;
      resumenNotifier.value = resumen;
      // Sincronizar el total pendiente con el valor más preciso
      totalPendientesNotifier.value = resumen.totalTareas > 0 ? resumen.totalTareas : tareas.length;
      tieneTrasladosNotifier.value = tareas.any((t) => t.esTraslado || t.tipoAlerta == 'TRASLADO');

      // ── Deduplicación y Notificaciones Opcionales ─────────────────────────
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

      // Recordatorio Periódico (Ciclo de 2 horas)
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
