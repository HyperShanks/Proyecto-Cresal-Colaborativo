# DOCUMENTACIÓN TÉCNICA — HISTORIA DE USUARIO HU-5.2
## Visor Histórico Centralizado de Órdenes y Auditoría de Ventas

---

### 1. Resumen Ejecutivo de la HU-5.2

La Historia de Usuario **HU-5.2: Visor Histórico Centralizado de Órdenes y Auditoría de Ventas** entrega a la Gerencia General (Rol 4), Administradores (Rol 5) y Operarios de Caja (Rol 3) una consola de auditoría forense y trazabilidad transaccional en tiempo real para todas las operaciones comerciales de la cadena Cresal (Casa Matriz Viña del Mar y Patio Desarme Limache).

- **Rama de Trabajo**: `feature/hu-5.1-dashboard-ejecutivo` (sin cambio de rama, de acuerdo a la instrucción explícita del usuario).
- **Roles Autorizados (RBAC Zero Trust)**:
  - `3`: Operario de Caja (auditoría operativa y conciliación diaria de su caja).
  - `4`: Gerente General (auditoría multidimensional consolidada de toda la empresa).
  - `5`: Administrador (acceso y supervisión integral del sistema).
  - *Roles 1 (Bodeguero) y 2 (Vendedor)*: Acceso denegado con `403 Forbidden` (`ORDEN_AUDITORIA_ACCESS_DENIED`).
- **Fidelidad al Prototipo de Diseño**:
  - Implementación en Flutter Dart inspirada en el prototipo funcional oficial `prototipo_gerencia_v1.html` (Pantalla 2: Historial & Auditoría de Ventas).
  - Sidebar corporativa de fondo azul marino oscuro (`#004c89`), switch de navegación reactivo entre **Dashboard Ejecutivo** (HU-5.1) e **Historial & Auditoría** (HU-5.2).
  - Barra de filtros avanzada de fila única compacta con buscador predictivo tolerante a RUTs sin formato, botones rápidos de período ("Hoy", "Esta Semana", "Este Mes", "Todo"), selectores desplegables de Estado y Medio de Pago, y botón de limpieza inmediata.
  - Banner informativo con total de órdenes encontradas y sumatoria consolidada recaudada/vendida en formato CLP (`$ XX.XXX.XXX`).
  - Tabla densa con columna de sucursal en vista consolidada, indicador de QR transaccional, saldo pendiente, y botón de acción **"Auditar"**.
  - Modal forense 360° de solo lectura con 5 secciones: Cabecera y Estado, Cliente y Logística, Responsables de Auditoría (Vendedor y Cajera), Desglose de Artículos con SKU QR, Desglose de Pagos y Línea de Tiempo de Trazabilidad.

---

### 2. Arquitectura de la Solución

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                           DashboardGerenciaView (Flutter Shell)                             │
│  ┌────────────────────────┐  ┌────────────────────────────────────────────────────────────┐ │
│  │   Sidebar Corporativo  │  │  TopBar Oficial (Logo Cresal + Switch Sucursal + Perfil)   │ │
│  │   - Azul #004c89       │  ├────────────────────────────────────────────────────────────┤ │
│  │   - [1] Dashboard 5.1  │  │  OrdenesGerenciaView (HU-5.2)                              │ │
│  │   - [2] Auditoría 5.2  │  │  ├── PanelFiltrosAvanzados (Buscador + Períodos + Selects) │ │
│  └───────────┬────────────┘  │  ├── Banner Total Consolidado ($ CLP y N° órdenes)         │ │
│              │               │  ├── HistorialTablaView (isReadOnly: true, Auditar)        │ │
│              │               │  └── DetalleAuditoriaDialog (Modal Forense 360° Solo Lect) │ │
│              │               └────────────────────────────┬───────────────────────────────┘ │
└──────────────┼────────────────────────────────────────────┼─────────────────────────────────┘
               │                                            │
               │ HTTP GET (Bearer JWT)                      │ HTTP GET /api/v1/ordenes
               ▼                                            ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   Backend FastAPI (Python)                                  │
│                                                                                             │
│  [Seguridad RBAC: require_auditoria_or_caja_role] -> 403 Forbidden si id_rol not in (3, 4, 5)│
│                                                                                             │
│  Endpoints en routers/ordenes.py:                                                           │
│  1. GET /api/v1/ordenes                                                                     │
│     - Parámetros: id_sucursal, estado, periodo, fecha_inicio, fecha_fin, metodo_pago, search │
│     - Normalización temporal: America/Santiago -> UTC naive                                 │
│     - Búsqueda predictiva tolerante: Folio, RUT sin puntos/guion, Nombres, Vendedor         │
│     - Sumatoria consolidada server-side: func.sum(Orden_Venta.total_venta)                  │
│  2. GET /api/v1/ordenes/{id_orden}                                                          │
│     - Árbol jerárquico 360°: Cliente, Despacho, Detalle con SKU QR, Pagos y Responsables   │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │ SQLAlchemy ORM
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                Base de Datos PostgreSQL (Cresal)                            │
│  - ordenes_ventas (Cabecera, estado, total, saldo pendiente, QR transaccional)              │
│  - detalles_ordenes (Artículos inventariados, SKU, preparación)                             │
│  - transacciones_pagos (Métodos de pago, montos, transacciones)                            │
│  - clientes, usuarios, sucursales, despachos                                                │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3. Componentes Desarrollados y Modificados

#### 3.1 Backend (Python / FastAPI)

1. **Control de Acceso RBAC** ([backend/core/security.py](file:///d:/CresalRepoCapstone/backend/core/security.py)):
   - Implementé `require_auditoria_or_caja_role(current_user)` validando que el usuario autenticado cuente con `id_rol` en `[3, 4, 5]`. Emite un error HTTP `403 Forbidden` (`ORDEN_AUDITORIA_ACCESS_DENIED`) ante intentos no autorizados.
2. **Propiedades de Modelo** ([backend/models.py](file:///d:/CresalRepoCapstone/backend/models.py)):
   - Añadí la propiedad `@property def folio(self)` en `Orden_Venta` para resolver uniformemente el identificador visible de la orden (`qr_transaccional_salida` o fallback `ORD-{id[:8]}`).
3. **Esquemas y DTOs** ([backend/schemas.py](file:///d:/CresalRepoCapstone/backend/schemas.py)):
   - Enriquecí `HistorialOrdenItemResponse` con los atributos `id_sucursal`, `sucursal_nombre` y `monto_pendiente` para soportar la visualización multidimensional de la gerencia.
   - Agregué `total_monto_consolidado: int = 0` en `HistorialCajaResponse` para retornar la sumatoria de ventas calculada en base de datos.
4. **Endpoint de Listado y Auditoría** ([backend/routers/ordenes.py](file:///d:/CresalRepoCapstone/backend/routers/ordenes.py)):
   - Implementé la función `parse_periodo_ordenes_chile(periodo, fecha_desde, fecha_hasta)` que convierte las fechas locales chilenas (`America/Santiago`) a UTC sin zona horaria (naive) para consultas precisas en PostgreSQL.
   - Implementé `GET /api/v1/ordenes` (`listar_ordenes_auditoria`) con:
     - Filtro por `id_sucursal` (admite `None` para consolidado general o IDs numéricos específicos).
     - Filtro por `estado` de la orden (`Pagada`, `Reservada`, `Anulada`, `Completada`).
     - Filtro temporal dinámico (`HOY`, `7D`, `ESTA_SEMANA`, `30D`, `ESTE_MES`, `RANGO`, `TODOS`).
     - Filtro por `metodo_pago` mediante subconsulta a `transacciones_pagos` procesadas.
     - Búsqueda predictiva tolerante que elimina puntuación de RUTs (`123456789` encuentra `12.345.678-9`), busca en nombres de cliente, folio y vendedor asignado.
     - Sumatoria agregada server-side `total_monto_consolidado`.
   - Modifiqué `GET /api/v1/ordenes/{id_orden}` (`obtener_orden`) para incluir el árbol forense 360°: `sku` físico de repuestos, `pagos` con id de transacción y monto, `sucursal_nombre`, `vendedor_nombre` y `cajera_nombre`.
5. **Pruebas Automatizadas Backend** ([backend/tests/test_ordenes_filtros.py](file:///d:/CresalRepoCapstone/backend/tests/test_ordenes_filtros.py)):
   - 6 pruebas unitarias y de integración que verifican:
     - RBAC estricto (403 para vendedor y bodeguero; 200 para gerente, admin y cajero).
     - Filtro de sucursal individual vs consolidado.
     - Filtros combinados de estado y método de pago.
     - Búsqueda predictiva por folio, nombre y RUT limpio.
     - Retorno del árbol jerárquico forense completo.
     - Rango de fechas con conversión horaria chilena.

---

#### 3.2 Frontend (Dart / Flutter)

1. **Modelos de Datos** ([frontend/lib/features/caja/models/historial_caja_model.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/caja/models/historial_caja_model.dart)):
   - Enriquecí `HistorialOrdenItemModel` con `idSucursal`, `sucursalNombre` y `montoPendiente`.
   - Incorporé `totalMontoConsolidado` en `HistorialCajaResponseModel`.
2. **Barra de Filtros Avanzados** ([frontend/lib/features/gerencia/presentation/widgets/panel_filtros_avanzados.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/presentation/widgets/panel_filtros_avanzados.dart)):
   - Diseñé el componente replicando la barra compacta de una fila del prototipo HTML:
     - Buscador interactivo con icono de lupa y debounce.
     - Segmented button / chips de período rápido ("Hoy", "Esta Semana", "Este Mes", "Todo").
     - Selector de rango de fechas personalizado (`showDateRangePicker`).
     - Menús desplegables estilizados para Estado y Método de Pago.
     - Botón de limpieza con icono de refresco.
3. **Pantalla del Visor de Órdenes** ([frontend/lib/features/gerencia/presentation/screens/ordenes_gerencia_view.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/presentation/screens/ordenes_gerencia_view.dart)):
   - Diseñé la pantalla ejecutiva que orquesta los filtros y la obtención de datos paginados.
   - Banner superior con estilo glassmorphic que despliega el conteo de órdenes y el total consolidado formateado en moneda chilena.
   - Manejo de estados de carga (shimmer), error amigable con botón de reintento, estado vacío y paginación inferior.
4. **Tabla de Historial en Modo Auditoría** ([frontend/lib/features/caja/presentation/widgets/historial_tabla_view.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/caja/presentation/widgets/historial_tabla_view.dart)):
   - Añadí los parámetros `isReadOnly` y `mostrarSucursal`.
   - Si `mostrarSucursal` es verdadero, despliega la columna de sucursal (`Casa Matriz` o `Patio Desarme`).
   - Si `isReadOnly` es verdadero, cambia la acción por un botón de borde índigo/tertiary con icono `manage_search_rounded` y etiqueta **"Auditar"**.
   - Mostrado seguro de textos con `Flexible` y `TextOverflow.ellipsis` para evitar cualquier desbordamiento visual.
5. **Modal de Auditoría Forense 360°** ([frontend/lib/features/caja/presentation/widgets/detalle_auditoria_dialog.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/caja/presentation/widgets/detalle_auditoria_dialog.dart)):
   - Adapté el modal a modo de auditoría de solo lectura: sin botones de pago ni anulación que alteren el registro histórico.
   - Substring seguro para identificadores de transacción de cualquier longitud.
   - Visualización de la sucursal de emisión en la tarjeta de responsables.
6. **Integración en Shell Gerencial** ([frontend/lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart)):
   - Incorporé el Sidebar azul marino oscuro (`#004c89`) idéntico al prototipo `prototipo_gerencia_v1.html`.
   - Implementé el switch reactivo entre `VistaGerencia.dashboard` (HU-5.1) y `VistaGerencia.ordenes` (HU-5.2), sincronizando la sucursal activa seleccionada en el TopBar.
7. **Servicio de Gerencia** ([frontend/lib/features/gerencia/services/gerencia_service.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/services/gerencia_service.dart)):
   - Agregué `obtenerHistorialOrdenes(...)` y `obtenerDetalleOrden(...)` delegando la llamada HTTP autenticada hacia `/api/v1/ordenes`.
8. **Pruebas Automatizadas Frontend** ([frontend/test/features/gerencia/visor_ordenes_test.dart](file:///d:/CresalRepoCapstone/frontend/test/features/gerencia/visor_ordenes_test.dart)):
   - 4 grupos de pruebas que validan:
     - Renderizado y callbacks del `PanelFiltrosAvanzados`.
     - `HistorialTablaView` en modo auditoría con columna sucursal y botón "Auditar".
     - `DetalleAuditoriaDialog` con desglose 360° de SKU, pagos y clientes.
     - Integración completa de la pantalla `OrdenesGerenciaView`.

---

### 4. Diccionario de Errores Actualizado (Módulo 7)

En cumplimiento de las reglas del proyecto, se incorporaron los códigos estandarizados en [DICCIONARIO_ERRORES.md](file:///d:/CresalRepoCapstone/DICCIONARIO_ERRORES.md):

| Módulo | Código de Error (`error_code`) | Disparador (Cuándo se activa) | Mensaje al Usuario (`message_user`) | HTTP Status | Acción Sugerida en UI |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Auditoría** | `ORDEN_AUDITORIA_ACCESS_DENIED` | Intento de consultar órdenes o detalle forense sin contar con roles autorizados (requiere Caja [3], Gerente General [4] o Administrador [5]). | *"Acceso restringido: No posee permisos de auditoría o caja para consultar este registro."* | `403 Forbidden` | Bloquea la apertura del diálogo de auditoría y notifica vía snackbar de seguridad. |
| **Auditoría** | `ORDEN_AUDITORIA_NOT_FOUND` | Búsqueda o apertura de detalle de una orden inexistente o eliminada en la base de datos (`/api/v1/ordenes/{id_orden}`). | *"La orden de venta seleccionada no fue encontrada o no existe en el sistema."* | `404 Not Found` | Cierra el modal de carga y refresca la lista de órdenes activas. |
| **Auditoría** | `ORDEN_AUDITORIA_NETWORK_ERROR` | Imposibilidad de conectar con el servidor al filtrar u obtener el historial multidimensional de órdenes. | *"Error de comunicación al recuperar el historial de ventas. Verifique su conexión."* | N/A (Socket / Timeout) | Muestra estado de error en la tabla con botón de reintento manual. |
| **Auditoría** | `ORDEN_AUDITORIA_DATA_ERROR` | Error de deserialización o estructura inconsistente de los datos forenses de la orden (artículos, pagos o movimientos). | *"Ocurrió un problema al procesar el detalle de auditoría de la orden."* | `500 Internal` / `422 Unprocessable` | Muestra mensaje amigable sin exponer trazas internas ni interrumpir la sesión. |

---

### 5. Matriz de Verificación y Calidad de Código

| Herramienta | Comando Ejecutado | Resultado Obtenido | Observaciones |
| :--- | :--- | :---: | :--- |
| **Pytest Backend** | `pytest tests/test_ordenes_filtros.py -v` | **6/6 pasadas (100%)** | Pruebas específicas de HU-5.2 verificadas. |
| **Pytest Full Suite** | `pytest` | **185/185 pasadas (100%)** | Toda la suite transaccional de Cresal intacta. |
| **Flake8 Crítico** | `flake8 . --exclude=venv --count --select=E9,F63,F7,F82` | **0 errores** | Conforme a la regla de `RULES.md`. |
| **Flutter Test (HU-5.2)** | `flutter test test/features/gerencia/visor_ordenes_test.dart` | **4/4 pasadas (100%)** | Pruebas de widgets, tabla y diálogo de auditoría. |
| **Flutter Test (HU-5.1)** | `flutter test test/features/gerencia/dashboard_test.dart` | **8/8 pasadas (100%)** | No regresión en dashboard ejecutivo. |
| **Flutter Full Suite** | `flutter test` | **288/288 pasadas (100%)** | Total de pruebas unitarias y de integración aprobadas. |
| **Flutter Analyze** | `flutter analyze lib/features/gerencia/ lib/features/caja/` | **0 advertencias, 0 errores** | Código Dart 100% limpio y optimizado. |

---

### 6. Conclusión y Entrega

La implementación de la **HU-5.2** cumple con la totalidad de los requisitos especificados en `SPEC-HU-5.2.md` y replica fielmente el diseño gerencial corporativo de `prototipo_gerencia_v1.html`. No se generó duplicación de código, se mantuvieron los comentarios explicativos en primera persona y se preservó la integridad transaccional de todo el ecosistema de Cresal.
