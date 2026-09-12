# SPEC-HU-TAREA-20: Auto-Refresh Universal y Reactividad de Pestañas (Global State Refresh)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Implementar una estrategia de recarga automática (auto-refresh) en toda la aplicación para todos los roles (Bodeguero, Mesón de Ventas, Caja, Gerencia). Cada vez que el usuario navega a una pestaña, cambia de tab, o retorna de una vista secundaria (pop), la vista recuperada debe actualizar sus datos contra el servidor, eliminando por completo la visualización de datos "estancados" (stale data).
- **Archivos a modificar**:
  - `lib/main.dart` (Configuración del `RouteObserver`).
  - `lib/features/ventas/presentation/screens/ventas_main_screen.dart` (Gestión de keys en `IndexedStack`).
  - `lib/features/caja/presentation/screens/caja_main_screen.dart` (Gestión del TabTap).
  - `lib/features/alertas/presentation/screens/alertas_screen.dart` (Reemplazo a `TabController` explícito).
  - Y todas las vistas base (Catálogo, Mis Órdenes, Bandeja de Tasación) para inyectar el mixin `RouteAware`.

## 2. Contratos de Datos y Firmas de API
- **Modelos**: No hay cambios en el backend.
- **Flutter Framework**: Integración nativa del objeto `RouteObserver<ModalRoute<void>>` en el `MaterialApp`.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Estrategia de Refresco)

Para abarcar todas las vistas en sus distintas naturalezas de navegación, la estrategia exige dos enfoques concurrentes:

### Enfoque A: Navegación de Nivel Inferior (Tabs / IndexedStack)
Cuando se usa un `BottomNavigationBar` con `IndexedStack` (como en Ventas o Caja), Flutter NO destruye ni reconstruye el widget, preservando el scroll pero reteniendo datos viejos.
- **Solución para IndexedStacks (Ventas / Caja)**: 
  Asignar un `GlobalKey` al estado de cada vista (ej. `GlobalKey<HistorialScreenState>`). En la función `_onTabTapped(int index)`, una vez completado el `setState` del `_currentIndex`, invocar programáticamente el método de recarga de la pestaña objetivo (ej. `_historialKey.currentState?.refrescar()`).
- **Solución para TabBarViews (Alertas Bodega)**: 
  Sustituir el widget contenedor `DefaultTabController` por un `TabController` declarado con `SingleTickerProviderStateMixin`. Añadir un `addListener` a este controlador para que, cada vez que el índice cambie (sea por Swipe o Tap), ejecute la promesa `_refreshAlertas()`.

### Enfoque B: Navegación de Nivel Superior (Rutas Push/Pop)
Cuando un usuario ingresa al detalle de una pieza, la añade al carrito y la aplicación ejecuta `Navigator.pop()` para volver al catálogo.
- **Solución para Rutas (RouteAware)**:
  1. Declarar un `routeObserver` global y pasarlo a `navigatorObservers` en `MaterialApp`.
  2. En vistas como `CatalogoScreenState` y `HistorialScreenState`, suscribir el estado usando `with RouteAware`.
  3. En `didChangeDependencies`, ejecutar `routeObserver.subscribe(this, ModalRoute.of(context)!)`.
  4. Sobrescribir el método `@override void didPopNext() { refrescarDatos(); }`. Esto forzará una recarga silenciosa en background justo cuando la pantalla recupera la visibilidad.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Infraestructura)**: Crear el `RouteObserver` en un archivo `core/routes/route_observer.dart` e inyectarlo en `main.dart`.
- [ ] **Tarea 2 (Mesón de Ventas)**: Crear y conectar los `GlobalKey` en `VentasMainScreen` para Catálogo, Historial y Tasación. Llamar a sus refrescos en `_onTabTapped`. Implementar `RouteAware` en dichas vistas.
- [ ] **Tarea 3 (Caja)**: Implementar la misma lógica de Tab y `RouteAware` en `CajaMainScreen` e `HistorialCajaScreen`.
- [ ] **Tarea 4 (Bodega Alertas)**: Refactorizar `alertas_screen.dart` para utilizar un `TabController` con estado e invocar `_refreshAlertas()` en el evento `addListener` del índice.
- [ ] **Tarea 5 (Gerencia)**: Confirmar que `DashboardGerenciaView` realiza auto-refresh al cambiar el `_vistaActiva` (ya lo hace por su renderizado condicional, pero implementar `RouteAware` por si saltan a otra ruta modal y vuelven).
- [ ] **Tarea 6 (Pruebas Manuales)**: Navegar, interactuar, cambiar de tab y volver atrás para certificar que el frontend siempre trae el estado definitivo de la BD sin parpadeos severos (manteniendo estado de scroll en listas).

## 5. Criterios de Validación Automatizada
- Frontend Linter: `flutter analyze` para verificar el correcto uso y `dispose()` del `RouteObserver` en cada vista suscrita.
