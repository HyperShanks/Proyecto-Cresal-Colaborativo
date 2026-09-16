// lib/core/routes/route_observer.dart
import 'package:flutter/material.dart';

/// Observador global de rutas para toda la aplicación (SPEC-HU-TAREA-20).
/// Permite a cualquier pantalla suscrita mediante `RouteAware` recibir notificaciones
/// del ciclo de vida de navegación, en particular `didPopNext()` para auto-refrescar
/// datos cuando una pantalla vuelve a quedar en primer plano.
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
