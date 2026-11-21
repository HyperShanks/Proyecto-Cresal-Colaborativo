# SPEC-HU-5.1: Dashboard Ejecutivo: Pulso Financiero y Carga de Bodega en Tiempo Real

## 1. Contexto y Archivos Afectados
- **Objetivo**: Proveer un panel de control gerencial que consolide métricas financieras (Ventas del Día, MTD, Ticket Promedio) y operativas (Bodega, Despachos, Alertas) en tiempo real, permitiendo filtros por sucursal y garantizando visualizaciones de datos mediante gráficos.
- **Archivos a crear**:
  - Backend: `backend/routers/gerencia.py` (Nuevos endpoints analíticos).
  - Backend: `backend/schemas/gerencia_schemas.py` (DTOs de respuesta para el dashboard).
  - Frontend: `lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart` (Layout principal).
  - Frontend: `lib/features/gerencia/presentation/widgets/kpi_card_widget.dart` (Tarjetas de métricas reutilizables).
  - Frontend: `lib/features/gerencia/presentation/widgets/metodos_pago_chart.dart` (Gráfico de Dona con `fl_chart`).
  - Frontend: `lib/features/gerencia/services/gerencia_service.dart`.
- **Archivos a modificar**:
  - Backend: `backend/main.py` (Incluir el nuevo router de gerencia).
  - Frontend: Enrutador principal (`app_routes.dart` o `main.dart`) para inyectar la vista de Gerencia validando los roles correspondientes.

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict
  from typing import List, Optional

  class KpiFinancieroDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      ventas_del_dia: int
      transacciones_hoy: int
      acumulado_mensual_mtd: int
      ticket_promedio: float
      margen_bruto: Optional[float] = None

  class DesglosePagoDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      metodo_pago: str
      monto_total: int
      porcentaje: float

  class ResumenPagosDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      efectivo_fisico: int
      canales_electronicos: int
      desglose: List[DesglosePagoDTO]

  class FlujoOperativoDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      en_preparacion: int
      listos_mostrador: int
      enviados_courier: int
      alertas_saldo_pendiente: int
      cuellos_botella_paletizados: int
  ```

- **Endpoints Backend**:
  - `GET /api/v1/gerencia/dashboard/kpis?id_sucursal={id}`
    - **Headers**: JWT Bearer (Rol Gerencia/Admin).
    - **Respuesta 200**: `KpiFinancieroDTO`
  - `GET /api/v1/gerencia/dashboard/pagos?id_sucursal={id}`
    - **Headers**: JWT Bearer.
    - **Respuesta 200**: `ResumenPagosDTO`
  - `GET /api/v1/gerencia/dashboard/operativa?id_sucursal={id}`
    - **Headers**: JWT Bearer.
    - **Respuesta 200**: `FlujoOperativoDTO`

- **Modelos Frontend (Dart)**:
  - Crear clases serializables equivalentes (`KpiFinancieroModel`, `ResumenPagosModel`, `FlujoOperativoModel`).
  - `GerenciaService` con métodos asíncronos que consuman los endpoints y capturen errores de red devolviendo estados de falla limpios a la UI.

## 3. Reglas de Negocio, Casos de Borde y Seguridad
- **Zero Trust & RBAC**: Todos los endpoints de `/gerencia` deben validar estrictamente el `id_rol` asegurando que solo usuarios con privilegios gerenciales (o administradores) puedan acceder a los reportes financieros.
- **Manejo de Zona Horaria (Cálculos de Fechas)**: Para las "Ventas del Día" y "MTD" (Acumulado Mensual), el backend debe usar la zona horaria de Chile convirtiéndola adecuadamente a UTC mediante `datetime.combine` y utilidades de timezone (ej: `pytz.timezone('America/Santiago')`), de manera que el corte del día a medianoche coincida con la operación comercial real y no con el servidor genérico.
- **Cálculo de Pagos Eficaces**: `Transaccion_Pago` solo debe sumar si `estado_pago = 'Procesado'`. `Orden_Venta` se consulta para tickets y promedios.
- **Aislamiento Analítico**: Las consultas a las tablas `Transaccion_Pago`, `Orden_Venta` y `Activo_Inventariado` (estados de bodega) para el dashboard deben ser consultas optimizadas de solo lectura (Aggregation queries). Al no realizar mutaciones, no requieren el bloque transaccional ACID estricto de mutación, pero deben manejar timeouts eficientemente si la data crece.
- **Filtro Consolidado**: Si `id_sucursal` es `null` o no se envía, las consultas deben sumarizar los datos globales de toda la cadena.
- **Resiliencia UI Frontend**: Al aplicar "Refresco Manual", se activará un indicador de carga (Spin). Todas las inyecciones asíncronas de datos en los Widgets deben asegurar `if (!mounted) return;` para prevenir fugas si el gerente cambia rápido de pantalla.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Schemas & Modelos)**: Generar los modelos Pydantic V2 (`KpiFinancieroDTO`, `ResumenPagosDTO`, `FlujoOperativoDTO`).
- [ ] **Tarea 2 (Backend - Endpoints y Lógica Analítica)**: Crear `routers/gerencia.py` e implementar las 3 rutas solicitadas asegurando los filtros por `id_sucursal` y las conversiones estrictas de zonas horarias para los cálculos MTD y Día.
- [ ] **Tarea 3 (Backend - Pruebas Pytest)**: Escribir tests asegurando que solo los pagos "Procesados" suman, que el filtro de sucursal aísla los montos correctamente, y que se rechazan accesos sin el rol gerencial adecuado.
- [ ] **Tarea 4 (Frontend - Servicio y Arquitectura)**: Crear feature `gerencia` en Flutter, programando el `GerenciaService` y los Providers/Blocs para la gestión del estado (cargando, error, éxito).
- [ ] **Tarea 5 (Frontend - Maquetación y Gráficos)**: 
  - Diseñar el layout principal `DashboardGerenciaView` con Topbar (incluyendo botón de refresco y selector de sucursal) y Sidebar integrado con Auth existente.
  - Implementar las `KPI Cards` reutilizables.
  - Integrar el paquete `fl_chart` para el gráfico tipo Dona (`metodos_pago_chart.dart`) contrastando Efectivo vs Canales Electrónicos.
- [ ] **Tarea 6 (Frontend - Integración y Testing)**: Asegurar el control `!mounted` en las llamadas. Escribir pruebas de widget comprobando que la interfaz maneja estados de error amigablemente si falla el servicio.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_gerencia_dashboard.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/gerencia.py backend/schemas/gerencia_schemas.py`.
- Frontend Tests: Ejecutar `flutter test test/features/gerencia/dashboard_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/gerencia/`.
