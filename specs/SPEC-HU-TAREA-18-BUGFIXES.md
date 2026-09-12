# SPEC-HU-TAREA-18: Resolución de Bugs Críticos, Refrescos de Estado y Fugas de UI (RenderFlex y Congelamientos)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Solucionar un conjunto de bugs operacionales reportados en múltiples flujos (Ventas, Bodega y Jefatura) relacionados con la falta de reactividad (refrescos automáticos), desbordamientos visuales (RenderFlex Overflow) y caídas de la aplicación (crashes por `setState` durante el `build`).
- **Archivos a modificar**:
  - Frontend: `lib/features/ventas/presentation/screens/bandeja_precios_screen.dart` (o donde ocurra la tasación).
  - Frontend: `lib/features/ventas/presentation/screens/catalogo_screen.dart` (o el Provider que controla el estado del catálogo).
  - Frontend: `lib/features/ventas/presentation/screens/carrito_screen.dart` (y sus widgets hijos para solucionar el desbordamiento de píxeles).
  - Frontend: `lib/features/ventas/presentation/screens/mis_ordenes_screen.dart` (Para inyectar el refresco tras la creación de la orden).
  - Frontend: `lib/features/ventas/presentation/screens/detalle_activo_screen.dart` (Para agregar el `Navigator.pop` al agregar al carrito).
  - Frontend: `lib/features/alertas/presentation/screens/alertas_screen.dart` (Para solucionar el error fatal de concurrencia de `setState` durante el build al salir de la vista).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend**: No se requieren cambios en el backend. Estos errores son de ciclo de vida (Lifecycle), renderizado y manejo de estado local en Flutter.
- **Modelos Frontend (Dart)**: 
  - Se requiere un manejo riguroso de los `ChangeNotifier` / `Bloc` o `StatefulWidget` para forzar la recarga de listas (`fetchData()`) tras acciones exitosas.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz de Resolución)

A continuación se detalla la expectativa técnica para la solución de cada bug reportado:

1. **Falta de Auto-Refresh en Catálogo tras Tasación (Jefe de Ventas / Vendedor)**:
   - *Problema*: Al tasar un repuesto y pasarlo a "Disponible", el estado de la vista de catálogo no se entera del cambio, forzando recargas manuales.
   - *Solución*: Al retornar exitosamente de la función de tasación (`await tasarActivo()`), se debe llamar al método de recarga del catálogo (ej. `context.read<CatalogoProvider>().cargarInventario()`) para que el nuevo activo figure inmediatamente.

2. **Desbordamiento de Píxeles (RenderFlex Overflow) en el Carrito**:
   - *Problema*: Pantallas con resoluciones más pequeñas muestran franjas amarillas/negras indicando que el contenido excede el espacio disponible.
   - *Solución*: Envolver las columnas o filas problemáticas del carrito en widgets `Expanded`, `Flexible` o `SingleChildScrollView`. Revisar contenedores con alturas o anchuras fijas (hardcoded) y reemplazarlas por proporciones relativas.

3. **Falta de Auto-Refresh en "Mis Órdenes" tras Crear Orden**:
   - *Problema*: Al terminar el Checkout Wizard y generar una venta, la lista de órdenes del vendedor no muestra la orden recién creada.
   - *Solución*: Asegurar que en el flujo de retorno a la vista de "Mis Órdenes", o al emitir el estado de "Éxito" en el Checkout, se dispare un trigger que invalide la caché local y vuelva a ejecutar la petición `GET` del historial de órdenes.

4. **Navegación Intuitiva al Agregar al Carrito desde el Detalle**:
   - *Problema*: El vendedor entra al detalle de la pieza, toca "Agregar al Carrito" y se queda en la misma pantalla.
   - *Solución*: Una vez completada la animación o el guardado en el estado del carrito, ejecutar `if (mounted) Navigator.pop(context);` junto con un `SnackBar` de éxito para devolver al usuario al flujo rápido de ventas.

5. **Congelamiento y Crash Fatal al Salir de Alertas en Bodega**:
   - *Problema*: La app crashea de forma silenciosa (tombstoned) o muestra en consola `setState() or markNeedsBuild() called during build`.
   - *Solución*: Este error ocurre porque algún widget, diálogo o listener en la pantalla de alertas está modificando el estado del árbol de widgets mientras este se está dibujando o desmontando. Se debe auditar el `dispose()` de `alertas_screen.dart` y asegurar que no haya *timers* o *listeners* huérfanos disparando actualizaciones. Si es necesario mutar un estado durante el inicio/cierre, envolverlo en `WidgetsBinding.instance.addPostFrameCallback((_) { ... });`.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Refresh Tasación)**: Conectar la promesa asíncrona de Tasación con la función de recarga del Catálogo General.
- [ ] **Tarea 2 (UI Carrito - RenderFlex)**: Depurar la UI de `carrito_screen.dart`, reemplazando tamaños fijos por layouts flexibles (`Expanded`, `Wrap`, listviews dinámicos).
- [ ] **Tarea 3 (Refresh Mis Órdenes)**: Añadir recarga automática del historial de órdenes al finalizar el Wizard de Checkout.
- [ ] **Tarea 4 (UX Agregar al Carrito)**: Implementar `Navigator.pop(context)` tras un `await agregarAlCarrito()` exitoso en el detalle del activo.
- [ ] **Tarea 5 (Crash Bodega - Lifecycle)**: Solucionar el problema de renderizado asíncrono en `alertas_screen.dart` utilizando `addPostFrameCallback` o corrigiendo fugas de memoria en el método `dispose()`.
- [ ] **Tarea 6 (Pruebas Manuales e Integración)**: Simular todos los escenarios reportados en un emulador con pantalla pequeña para garantizar la desaparición del RenderFlex Overflow y la fluidez de las navegaciones.

## 5. Criterios de Validación Automatizada
- Frontend Linter: Ejecutar `flutter analyze` para asegurar que no existan variables asíncronas mutando estados sin la protección de `mounted`.
- Pruebas E2E / Integración Visual (si aplica): Navegar por las pantallas mencionadas verificando que los errores visuales y lógicos han sido superados.
