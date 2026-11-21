# SPEC-HU-TAREA-21: Filtros Avanzados y Refactorización Semántica de "Mis Órdenes"

## 1. Contexto y Archivos Afectados
- **Objetivo**: Implementar un nuevo filtro para identificar ventas con abonos parciales, corregir la confusión semántica del estado "Reservado", reparar el botón de Historial Completo y añadir un selector dinámico de Año/Mes basado puramente en la existencia de datos.
- **Archivos a modificar**:
  - `frontend/lib/features/ventas/presentation/screens/historial_screen.dart`
  - `frontend/lib/features/ventas/presentation/widgets/historial_filtros_drawer.dart`
  - `frontend/lib/features/ventas/presentation/widgets/orden_card.dart`
  - `frontend/lib/features/ventas/services/ordenes_service.dart`

## 2. Contratos de Datos y Firmas de API
- **Restricción Técnica de Backend**: **No se debe modificar la base de datos ni los Endpoints de la API.** El backend seguirá devolviendo el estado como `Reservada`. La diferenciación entre una Venta en Verde y un Abono convencional, así como el filtro por rango mensual, deben resolverse íntegramente mediante inteligencia local en el Frontend (Frontend Mapper & Local Cache Filtering).

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz de Resolución)

### 3.1. Filtro rápido "Abonados" en el Toggle Superior
- **Problema**: El vendedor no puede localizar rápidamente las ventas que tienen saldos pendientes reales por cobrar (abonos).
- **Solución**: En `historial_screen.dart` (`_buildQuickFilterChips`), agregar un nuevo chip rotulado como **"Abonados"**.
- **Lógica de Filtrado**: Cuando este chip esté activo, la lista mostrará solo aquellas órdenes donde:
  - `orden.montoPendiente > 0`
  - `orden.totalVenta > orden.montoPendiente` (lo que implica que ya se pagó algo).

### 3.2. Desacople Semántico: "Reservado" vs "Abonado / Verde"
- **Problema**: El estado `Reservada` (BD) genera confusión. En la cultura de la empresa, "Reserva" significa Venta en Verde. Si una venta normal queda con saldo pendiente, no debe llamarse "Reservada".
- **Solución (Modelo)**: En `OrdenHistorialModel` (dentro de `ordenes_service.dart`), agregar el getter:
  ```dart
  bool get esVentaEnVerde => detalles.any((d) =>
      d.titulo.toUpperCase().contains('RESERVA EN VERDE') ||
      d.titulo.toUpperCase().contains('VENTA EN VERDE') ||
      (d.descripcionManual != null &&
          (d.descripcionManual!.toUpperCase().contains('RESERVA EN VERDE') ||
           d.descripcionManual!.toUpperCase().contains('VENTA EN VERDE'))));
  ```
- **Solución (Vista)**: En `orden_card.dart` (método `_buildStatusBadge`), al evaluar `if (orden.esReservada)`:
  - Si `orden.esVentaEnVerde` es `true` $\rightarrow$ Renderizar como **"Venta en Verde"** (Color `success` / Icono `Icons.eco_outlined`).
  - Si `orden.esVentaEnVerde` es `false` $\rightarrow$ Renderizar como **"Abonado"** o "Saldo Pendiente" (Color Ámbar / Icono de billetera `Icons.account_balance_wallet_outlined`).

### 3.3. Resolución de Bug: Botón "Historial Completo"
- **Problema**: En `historial_screen.dart`, la lógica de limpieza del botón falla debido a una condición sobreescrita (`_filtroEstado = null` justo antes del bloque `if`).
- **Solución**: Reescribir el callback `onPressed` del botón. Si el botón dice "Ver Historial Completo", forzar `_verTodas = true` de forma unívoca y solicitar las órdenes. Si dice "Limpiar Filtros", forzar `_verTodas = false` y `_filtroEstado = null`.

### 3.4. Selector Dinámico Inteligente de Año y Mes (Caché Frontend)
- **Problema**: El filtro temporal no debe mostrar meses donde la sucursal no operó o no hay ventas registradas.
- **Estrategia (Local Data Mapping)**:
  1. En `historial_screen.dart`, mantener una caché local inmutable `List<OrdenHistorialModel> _historicoGlobalCache`. Cuando se obtengan las órdenes con `todas = true`, poblar esta caché.
  2. A partir de `_historicoGlobalCache`, extraer las fechas de creación y generar una lista de objetos únicos de Año/Mes reales.
  3. En `HistorialFiltrosDrawer`, reemplazar los botones binarios ("Hoy" vs "Historial") por un `DropdownButton` (o similar selector estético) de Periodo.
  4. La lista incluirá: "Todo el Historial" y luego iteraciones como "Septiembre 2026", "Agosto 2026".
  5. Al seleccionar un mes específico, el frontend no hará un nuevo request al backend; en su lugar, iterará sobre `_historicoGlobalCache` localmente, extraerá las ventas que calzan con el `YYYY-MM` elegido, y las asignará a la variable de visualización. Esto garantiza velocidad, no modifica el backend, e implementa el requisito a la perfección.

## 4. Checklist de Implementación (TDD)
- [ ] Incorporar `esVentaEnVerde` en `OrdenHistorialModel`.
- [ ] Refactorizar el mapeo de UI en `OrdenCard` suprimiendo "Reservado" visualmente para ventas normales.
- [ ] Agregar el chip "Abonados" en la cinta de estados superiores de `HistorialScreen`.
- [ ] Simplificar y reparar la lógica del botón "Historial Completo" en `historial_screen.dart`.
- [ ] Adaptar `HistorialFiltrosDrawer` para recibir la lista dinámica de periodos extraídos y retornarlos como filtro local a la pantalla principal.
