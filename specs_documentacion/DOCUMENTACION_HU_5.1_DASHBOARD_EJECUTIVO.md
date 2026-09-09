# DOCUMENTACIÓN TÉCNICA — HISTORIA DE USUARIO HU-5.1
## Dashboard Ejecutivo: Pulso Financiero y Carga de Bodega en Tiempo Real

---

### 1. Resumen Ejecutivo de la HU-5.1

La Historia de Usuario **HU-5.1: Dashboard Ejecutivo: Pulso Financiero y Carga de Bodega en Tiempo Real** dota a la Gerencia General (Rol 4) y Administradores (Rol 5) de Cresal de una herramienta analítica de alto impacto visual y operacional. Permite supervisar el pulso de ventas, cuadratura de ingresos, conciliación de medios de pago y flujo logístico de bodega, tanto de forma consolidada para toda la cadena como segmentada individualmente por sucursal (Viña del Mar / Limache).

- **Rama de Trabajo**: `feature/hu-5.1-dashboard-ejecutivo`
- **Roles Autorizados (RBAC Zero Trust)**: 
  - `4`: Gerente General
  - `5`: Administrador
- **Principios Aplicados**:
  - `RULES.md`: Manejo riguroso de zonas horarias (`America/Santiago` convertida a UTC en backend), sanitización Zero Technical Leaks, descarte de métodos obsoletos en Flutter (`.withValues(alpha: ...)` en vez de `.withOpacity()`), protección contra pérdidas de contexto (`if (!mounted) return;`) y liberación explícita de recursos en `dispose()`.
  - No duplicación de código existente (reutilización de tokens `AppPalette`, utilitarios, `ApiService`, `AuthService` y modelos ya presentes).

---

### 2. Arquitectura de la Solución

```
                               ┌──────────────────────────────────────────────┐
                               │       DashboardGerenciaView (Flutter)         │
                               │  - Selector Sucursal (Consolidado / Suc 1,2) │
                               │  - 4 KPI Cards Superiores                    │
                               │  - Trío Bento: Donut, Alertas, Flujo Bodega  │
                               └──────────────────────┬───────────────────────┘
                                                      │ HTTP GET (Bearer JWT)
                                                      ▼
                               ┌──────────────────────────────────────────────┐
                               │           GerenciaService (Dart)             │
                               │  - obtenerKpis()                             │
                               │  - obtenerResumenPagos()                     │
                               │  - obtenerFlujoOperativo()                   │
                               └──────────────────────┬───────────────────────┘
                                                      │ /api/v1/gerencia/*
                                                      ▼
 ┌─────────────────────────────────────────────────────────────────────────────────────────────┐
 │                                   Backend FastAPI (Python)                                  │
 │                                                                                             │
 │   [RBAC Guard: require_gerencia_role] -> 403 si id_rol not in (4, 5)                        │
 │                                                                                             │
 │   Endpoints en routers/gerencia.py:                                                         │
 │   1. GET /dashboard/kpis       -> KpiFinancieroDTO (Ventas hoy, transacciones, MTD, ticket) │
 │   2. GET /dashboard/pagos      -> ResumenPagosDTO (Efectivo, canales electrónicos, desglose)│
 │   3. GET /dashboard/operativa  -> FlujoOperativoDTO (Preparación, mostrador, courier, etc) │
 │                                                                                             │
 │   Cálculo Temporal:                                                                         │
 │   ZoneInfo("America/Santiago") -> UTC (Límites Inicio/Fin de Día y MTD)                     │
 └──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                                │ SQLAlchemy ORM
                                                ▼
                               ┌──────────────────────────────────────────────┐
                               │           PostgreSQL Database (Cresal)       │
                               │  - transacciones_pagos (estado='Procesado')  │
                               │  - ordenes_ventas                            │
                               │  - activos_inventariados                     │
                               │  - despachos                                 │
                               └──────────────────────────────────────────────┘
```

---

### 3. Componentes Desarrollados y Modificados

#### 3.1 Backend (Python / FastAPI)

1. **DTOs Pydantic V2** ([backend/schemas/gerencia_schemas.py](file:///d:/CresalRepoCapstone/backend/schemas/gerencia_schemas.py)):
   - `KpiFinancieroDTO`: Modela facturación de hoy, transacciones, acumulado mensual MTD, ticket promedio y margen bruto estimado.
   - `DesglosePagoDTO`: Modela recaudación por método de pago y porcentaje sobre el total.
   - `ResumenPagosDTO`: Modela total recaudado, totales por tipo (efectivo vs canales electrónicos) y lista de desglose.
   - `FlujoOperativoDTO`: Modela los conteos en vivo de piezas en rack, listas para mesón, en courier, alertas por saldo y cuellos de botella de tasación.
2. **Configuración de Schemas** ([backend/schemas.py](file:///d:/CresalRepoCapstone/backend/schemas.py)):
   - Se habilitó la resolución dinámica mediante `__path__` para importar submódulos de esquemas y se reexportaron los DTOs de gerencia.
3. **Seguridad y RBAC** ([backend/core/security.py](file:///d:/CresalRepoCapstone/backend/core/security.py)):
   - Se implementó la dependencia `require_gerencia_role`, la cual valida que el usuario autenticado posea `id_rol` 4 (Gerente General) o 5 (Administrador). Para cualquier otro rol, emite un error `403 Forbidden` sanitizado.
4. **Router Analítico** ([backend/routers/gerencia.py](file:///d:/CresalRepoCapstone/backend/routers/gerencia.py)):
   - `GET /api/v1/gerencia/dashboard/kpis`: Realiza sumatorias de pagos liquidados (`estado = 'Procesado'`) en el día de hoy y en el mes actual (MTD), calculando el ticket promedio y filtrando por sucursal cuando corresponda.
   - `GET /api/v1/gerencia/dashboard/pagos`: Consolida la recaudación diaria agrupada por método de pago (`Efectivo`, `Transferencia`, `Tarjeta Débito`, `Tarjeta Crédito`, `Webpay`), calculando porcentajes relativos y la comparativa de efectivo versus canales electrónicos.
   - `GET /api/v1/gerencia/dashboard/operativa`: Monitorea en tiempo real las piezas en preparación física (`En Preparacion`), listas en mostrador (`Listo Retiro`), despachadas por courier (`En Ruta` / `Despachado`), alertas de saldo pendiente en mesón y cuellos de botella de activos paletizados sin precio fijado por Jefe de Ventas.
   - Conversión de zona horaria rigurosa: Los límites temporales se calculan utilizando `ZoneInfo("America/Santiago")` y se convierten a UTC para consultar la base de datos de manera determinista.
5. **Registro en la Aplicación** ([backend/main.py](file:///d:/CresalRepoCapstone/backend/main.py)):
   - Se registró el router `gerencia_router` bajo el prefijo `/api/v1/gerencia`.
6. **Batería de Pruebas Backend** ([backend/tests/test_gerencia_dashboard.py](file:///d:/CresalRepoCapstone/backend/tests/test_gerencia_dashboard.py)):
   - Se desarrollaron 6 pruebas exhaustivas que validan denegación de acceso para roles no autorizados (vendedores, cajeros, bodegueros), autorización para gerente y admin, aislamiento de datos por sucursal, consolidación global, exclusión de pagos pendientes/anulados y cálculo de etapas operativas.

---

#### 3.2 Frontend (Dart / Flutter)

1. **Dependencias** ([frontend/pubspec.yaml](file:///d:/CresalRepoCapstone/frontend/pubspec.yaml)):
   - Se añadió `fl_chart: ^1.2.0` para la visualización del gráfico de dona interactivo.
2. **Constantes de Red** ([frontend/lib/core/constants/api_constants.dart](file:///d:/CresalRepoCapstone/frontend/lib/core/constants/api_constants.dart)):
   - Se incorporó `gerenciaEndpoint = '$apiBaseUrl/gerencia'`.
3. **Formateador de Moneda** ([frontend/lib/core/utils/currency_formatter.dart](file:///d:/CresalRepoCapstone/frontend/lib/core/utils/currency_formatter.dart)):
   - Se implementó `CurrencyFormatter.formatCLP(num)` con separadores de miles con punto (`$ 1.850.000`), normalizando la presentación financiera chilena.
4. **Modelos de Datos** ([frontend/lib/features/gerencia/models/gerencia_models.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/models/gerencia_models.dart)):
   - `KpiFinancieroModel`, `DesglosePagoModel`, `ResumenPagosModel` y `FlujoOperativoModel`, con serializadores y deserializadores JSON seguros y tolerantes a nulos.
5. **Servicio de Red** ([frontend/lib/features/gerencia/services/gerencia_service.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/services/gerencia_service.dart)):
   - Métodos asíncronos `obtenerKpis`, `obtenerResumenPagos` y `obtenerFlujoOperativo` con soporte para filtrado opcional por `idSucursal`, interceptores de red y mapeo de excepciones `CustomApiException`.
6. **Tarjeta de Indicador Ejecutivo** ([frontend/lib/features/gerencia/presentation/widgets/kpi_card_widget.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/presentation/widgets/kpi_card_widget.dart)):
   - Componente visual para métricas financieras con badge de variación porcentual, micro-animación de hover, sombra difusa y soporte responsive.
7. **Gráfico de Medios de Pago** ([frontend/lib/features/gerencia/presentation/widgets/metodos_pago_chart.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/presentation/widgets/metodos_pago_chart.dart)):
   - Gráfico de dona (`fl_chart`) con toggle interactivo superior `[$ Monto / # Cant]`, centro reactivo optimizado para 60+ FPS sin lag en hover, leyenda lateral tonal y pie con indicador de conciliación Transbank & Webpay.
8. **Pantalla Principal del Dashboard Ejecutivo** ([frontend/lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart](file:///d:/CresalRepoCapstone/frontend/lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart)):
   - **Topbar**: Identidad corporativa ejecutiva, saludo personalizado, badge "En Vivo" con spinner animado, selector segmentado de sucursal (Consolidado / Viña / Limache) y botón de actualización manual con feedback visual.
   - **Banner de Bienvenida**: Saludo dinámico al gerente, fecha actual en español chileno y estado de cajas en línea.
   - **Grid Superior de 3 KPIs**: Ventas del día (Facturación Hoy, sin meta diaria), Acumulado mensual MTD y Ticket promedio (tarjetas compactas con contenido centrado y sin excesos verticales de espacio).
   - **Trío Bento**:
     - *Bento 1*: Recaudación Medios de Pago (Gráfico Donut + Toggle Monto/Cantidad + Transbank & Webpay Conciliado).
     - *Bento 2*: Control de Riesgo & Alertas Operativas (Saldos por cobrar retenidos y cuellos de botella de tasación con Nivel de Riesgo Operativo dinámico: Controlado / Moderado / Crítico).
     - *Bento 3*: Flujo de Despacho en Bodega (Monitoreo de etapas logísticas: En preparación en rack, listos en mostrador y enviados por courier).
   - **Resiliencia de Red**: Estado de carga inicial con spinner corporativo, manejo de errores de conexión con ilustración y botón "Reintentar", y soporte para Pull-to-Refresh.
9. **Rutas y Navegación** ([frontend/lib/routes/app_routes.dart](file:///d:/CresalRepoCapstone/frontend/lib/routes/app_routes.dart)):
   - Registro de la ruta `/gerencia` mapeada a `DashboardGerenciaView`.
10. **Pruebas Frontend** ([frontend/test/features/gerencia/dashboard_test.dart](file:///d:/CresalRepoCapstone/frontend/test/features/gerencia/dashboard_test.dart)):
    - Pruebas unitarias de deserialización y cálculo en modelos.
    - Pruebas de widget para `KpiCardWidget` y `MetodosPagoChart` (estados vacío y con datos).
    - Pruebas de integración de `DashboardGerenciaView` (resiliencia de red, renderizado de Topbar y selector de sucursal).

---

### 4. Actualización del Diccionario de Errores

Se documentaron los nuevos códigos de error en [DICCIONARIO_ERRORES.md](file:///d:/CresalRepoCapstone/DICCIONARIO_ERRORES.md) bajo la sección **Módulo 7: Gerencia y Control Ejecutivo (`/gerencia`, `SPEC-HU-5.1`)**:

| Módulo | Código de Error (`error_code`) | Disparador (Cuándo se activa) | Mensaje al Usuario (`message_user`) | HTTP Status | Acción Sugerida en UI |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **Gerencia** | `GERENCIA_ACCESS_DENIED` | Intentos de acceso a endpoints de gerencia por roles no autorizados (distintos de Administrador [5] o Gerente General [4]) (`/api/v1/gerencia/*`). | *"Acceso restringido: Se requieren permisos de Gerencia o Administración para acceder a este panel."* | `403 Forbidden` | Bloquea la navegación, redirige al home del rol o muestra pantalla de acceso no autorizado. |
| **Gerencia** | `GERENCIA_NETWORK_ERROR` | Falla de conexión, timeout o socket al consultar los endpoints de analítica ejecutiva (`/kpis`, `/pagos`, `/operativa`). | *"No fue posible cargar las métricas gerenciales. Reintentando..."* | N/A (Socket / Timeout) | Despliega `CustomErrorSnackbar` con botón de **"Reintentar"** y muestra botón de reintento en el estado de error de la pantalla sin bloquear la UI. |
| **Gerencia** | `GERENCIA_DATA_ERROR` | Error de deserialización de datos analíticos o respuesta no exitosa desde el backend de gerencia. | *"No fue posible procesar la información analítica de la sucursal seleccionada."* | `500 Internal` / `422 Unprocessable` | Muestra estado de error con ilustración y botón interactivo de **"Reintentar"**. |

---

### 5. Resultados de Validación y Verificación

| Herramienta / Suite | Ámbito | Resultado | Observaciones |
| :--- | :--- | :---: | :--- |
| `flake8` | `routers/gerencia.py`, `schemas/gerencia_schemas.py`, `tests/test_gerencia_dashboard.py` | **0 errores, 0 advertencias** | Código Python 100% conforme a PEP 8. |
| `pytest` | `tests/test_gerencia_dashboard.py` | **6/6 pasadas (100%)** | Cobertura total de RBAC, filtros temporales y sucursales. |
| `pytest` | Suite completa del Backend (`179 tests`) | **179/179 pasadas (100%)** | Ninguna regresión introducida en otros módulos. |
| `flutter analyze` | `lib/features/gerencia/` | **No issues found!** | Cero errores, cero advertencias, cero sugerencias. |
| `flutter test` | `test/features/gerencia/dashboard_test.dart` | **8/8 pasadas (100%)** | Pruebas de modelos, tarjetas KPI, gráficos y vista principal. |
| `flutter test` | `test/features/auth/auth_rbac_guards_test.dart` | **9/9 pasadas (100%)** | Compatibilidad con guards de rutas RBAC. |
