# SPEC-HU-TAREA-13: Segmentación por Tipo de Operación en el Centro de Alertas y Tareas de Bodega PDA

## 1. Contexto y Archivos Afectados
- **Objetivo**: Reestructurar la vista de Centro de Alertas de Bodega PDA implementando un sistema de navegación por pestañas (Tabs) que divida el flujo de trabajo en 3 categorías claras: Pre-entrega, Re-impresión y Re-integración, reutilizando los componentes existentes de la Tarea 4 y 6.
- **Archivos a crear**:
  - Frontend: `lib/features/alertas/presentation/widgets/alerta_preentrega_tab.dart` (Vista de lista para Pre-entrega).
  - Frontend: `lib/features/alertas/presentation/widgets/alerta_reimpresion_tab.dart` (Vista de lista para Re-impresiones).
  - Frontend: `lib/features/alertas/presentation/widgets/alerta_reintegracion_tab.dart` (Vista de lista para Logística Inversa).
- **Archivos a modificar**:
  - Backend: `backend/routers/bodega.py` (No requiere cambios estructurales si `/tareas-pendientes` y `/reingresos-pendientes` ya retornan la data necesaria; solo auditar o ajustar campos menores como `ubicacion_galpon`).
  - Frontend: `lib/features/alertas/presentation/screens/alertas_screen.dart` (Reemplazar la lista plana por un `DefaultTabController` con 3 pestañas).
  - Frontend: `lib/features/alertas/services/bodega_polling_service.dart` (Agregar agrupaciones separadas en el estado reactivo para alimentar los `badges` de cada pestaña).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend**: Se reutilizan `TareaAlertaResponse` (que incluye tipo `PREPARACION`, `IMPRESION`, `TRASLADO`) y `TareaReingresoDTO`.
- **Endpoints**:
  - `GET /api/v1/bodega/tareas-pendientes`
  - `GET /api/v1/bodega/reingresos-pendientes`
- **Modelos Frontend (Dart)**:
  - Extender `BodegaPollingService` para proveer tres `ValueNotifier<List<Tarea>>` separados, permitiendo inyectarlos a cada pestaña respectiva.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz de Errores)
- **Segmentación Lógica**:
  - *Pre-entrega*: Tareas de preparación para despacho o retiro (órdenes pagadas).
  - *Re-impresión*: Tareas de generación de etiquetas QR nuevas.
  - *Re-integración*: Activos anulados que vuelven al rack (`estado_orden = 'Anulada'`).
- **Estado Reactivo (Badges y Empty States)**:
  - La cantidad de tareas en cada sección debe reflejarse en tiempo real en la pestaña del TabBar (Badge numérico).
  - Si una pestaña no tiene tareas, debe mostrar una ilustración/mensaje amigable (Ej. "No hay tareas de pre-entrega pendientes").
- **Manejo de Roles**: Solo roles operativos de bodega (o Admin) pueden visualizar y procesar estas tareas.

**Mensajería Intuitiva Exigida y Control de Excepciones**:
1. **Frontend: Falla de Conexión al Cargar Alertas**:
   - *Mensaje UI*: `"No se pudieron cargar las tareas. Reintentando conexión con la bodega..."` (Mostrar botón manual de recarga).
2. **Frontend: Error al Completar Tarea**:
   - *Mensaje UI*: `"Ocurrió un error al intentar marcar la pieza como lista. Verifique su conexión y vuelva a intentarlo."`

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Auditoría)**: Verificar que los endpoints actuales `/tareas-pendientes` y `/reingresos-pendientes` exponen todos los datos de ubicación solicitados en la HU.
- [ ] **Tarea 2 (Frontend - Polling Service)**: Segmentar el estado de `BodegaPollingService` en tres listas diferenciadas para nutrir los Tabs.
- [ ] **Tarea 3 (Frontend - UI TabBar)**: Refactorizar `alertas_screen.dart` integrando un `TabBar` superior con 3 pestañas y sus respectivos Badges.
- [ ] **Tarea 4 (Frontend - Tabs Components)**: Crear las vistas internas de lista (`alerta_preentrega_tab.dart`, etc.) reutilizando las tarjetas de alerta ya creadas.
- [ ] **Tarea 5 (Frontend - Empty States)**: Configurar mensajes/ilustraciones de estado vacío cuando el conteo de una pestaña llegue a 0.
- [ ] **Tarea 6 (Frontend - Pruebas Widget)**: Comprobar el correcto ruteo interno de los tabs y el decremento dinámico de los badges al marcar una tarea como lista.
- [ ] **Tarea 7 (Documentación)**: Registrar posibles nuevos errores de red de este módulo en el `DICCIONARIO_ERRORES.md`.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_bodega_alertas.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/bodega.py`.
- Frontend Tests: Ejecutar `flutter test test/features/alertas/alertas_tabs_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/alertas/`.
