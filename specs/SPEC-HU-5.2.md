# SPEC-HU-5.2: Visor Histórico Centralizado de Órdenes y Auditoría (Espejo de Caja)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Proveer a la gerencia de un visor histórico centralizado y de solo lectura ("Modo Auditoría") para consultar la trazabilidad completa de todas las órdenes del sistema, reutilizando los componentes visuales existentes del módulo de Caja e inyectándoles capacidades avanzadas de búsqueda multidimensional.
- **Archivos a crear**:
  - Frontend: `lib/features/gerencia/presentation/screens/ordenes_gerencia_view.dart` (Pantalla orquestadora principal).
  - Frontend: `lib/features/gerencia/presentation/widgets/panel_filtros_avanzados.dart` (Barra superior de filtros y búsqueda predictiva).
- **Archivos a modificar**:
  - Backend: `backend/routers/ordenes.py` (Ajustar o ampliar `GET /api/v1/ordenes` para incluir soporte completo de filtros multidimensionales).
  - Frontend: `lib/features/caja/presentation/widgets/historial_tabla_view.dart` (Adaptar para recibir un flag `isReadOnly`).
  - Frontend: `lib/features/caja/presentation/widgets/detalle_auditoria_dialog.dart` (Adaptar para inhabilitar acciones transaccionales en modo lectura).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  Se asume la existencia de `OrdenVentaHistorialDTO` y `OrdenVentaDetalleCompletoDTO`. Asegurarse de que el detalle retorne el árbol jerárquico completo:
  ```python
  from pydantic import BaseModel, ConfigDict
  from typing import List, Optional
  from uuid import UUID

  class TransaccionResumenDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      metodo_pago: str
      monto: int
      estado_pago: str

  class DetalleOrdenEstadoDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      id_activo: UUID
      estado_preparacion: str

  class OrdenVentaAuditoriaDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      id_orden: UUID
      estado_orden: str
      # ... campos base ...
      detalles: List[DetalleOrdenEstadoDTO]
      pagos_aplicados: List[TransaccionResumenDTO]
  ```

- **Endpoints Backend**:
  - `GET /api/v1/ordenes`:
    - Ampliar Query Parameters: `?id_sucursal=X&estado=Pagada&fecha_inicio=Y&fecha_fin=Z&metodo_pago=Efectivo&search=12.345.678-9`
    - **Headers**: JWT Bearer (Permiso Gerencial, Administrador o Caja).
    - **Respuesta 200**: Lista paginada o completa de `OrdenVentaHistorialDTO`.

- **Modelos Frontend (Dart)**:
  - Consumir el endpoint mediante el servicio ya existente (e.g. `OrdenesService.getHistorial(filtros)`).
  - Orquestar el estado en un Provider/Bloc que comunique `PanelFiltrosAvanzados` con `HistorialTablaView`.

## 3. Reglas de Negocio, Casos de Borde y Seguridad
- **Modo Auditoría (Solo Lectura Seguro)**: La inyección de componentes de Caja (`historial_tabla_view.dart`, `detalle_auditoria_dialog.dart`) debe realizarse garantizando la regla de seguridad UI de "Zero Trust Visual". Se debe enviar una bandera explícita (`isReadOnly = true`) para ocultar/destruir cualquier botón de cobro, anulación o modificación transaccional. Además, el backend rechazará (403) cualquier mutación si el usuario solo tiene rol de Gerente y no de Caja.
- **Búsqueda Predictiva y Tolerante**: El parámetro `search` del endpoint `GET /api/v1/ordenes` debe realizar búsquedas `ILIKE` tolerantes sobre el RUT (limpiando puntos y guiones si es numérico), el nombre del cliente y el Folio de la orden.
- **Manejo de Zona Horaria (Filtros Temporales)**: Al seleccionar "Hoy", "Esta Semana" o "Este Mes", el frontend debe calcular los rangos de fecha en base al huso horario del usuario (Chile) y enviar las estampillas ISO 8601 o rangos convertidos a UTC. El backend procesará los `datetime` asegurando coincidencia horaria comercial.
- **Aislamiento en Backend**: El endpoint de consulta debe usar `db.query()` optimizado (preferentemente con `.options(joinedload(...))` o estructuras afines) para evitar problemas de n+1 query al retornar el árbol completo (Transacciones y Detalles), mitigando latencias cuando se elija el filtro "Todo".
- **Lifecycle Guards**: Al aplicar filtros pesados en la tabla de orquestación, se debe utilizar `if (!mounted) return;` al momento de inyectar el resultado de la petición asíncrona de red para evitar crashes.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Endpoint y Filtros)**: Auditar el endpoint `GET /api/v1/ordenes`. Agregar los parámetros de consulta requeridos (búsqueda de texto, sucursal, método pago, estado) y la lógica de filtrado SQLAlquemy dinámico.
- [ ] **Tarea 2 (Backend - Árbol de Detalle)**: Verificar y ajustar que el endpoint de detalle de la orden devuelva el DTO anidado (`Detalle_Orden` con sus estados y `Transaccion_Pago`).
- [ ] **Tarea 3 (Backend - Pruebas Pytest)**: Escribir tests de integración asegurando que la búsqueda por RUT parcial o nombre parcial devuelve la orden correcta y que el detalle contiene los arreglos de transacciones y piezas.
- [ ] **Tarea 4 (Frontend - Adaptación de Componentes)**: Modificar `historial_tabla_view.dart` y `detalle_auditoria_dialog.dart` en el feature de `caja` para soportar el flag `isReadOnly` ocultando botones.
- [ ] **Tarea 5 (Frontend - Orquestación en Gerencia)**: Crear `OrdenesGerenciaView.dart` y maquetar el `PanelFiltrosAvanzados` en la cabecera con sus comboboxes dinámicos.
- [ ] **Tarea 6 (Frontend - Pruebas Widget)**: Redactar un Test en Flutter para asegurar que, al inyectar `isReadOnly: true` en el componente reciclado, el botón transaccional de "Cobrar" o "Anular" no se renderice en el árbol de widgets.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_ordenes_filtros.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/ordenes.py`.
- Frontend Tests: Ejecutar `flutter test test/features/gerencia/visor_ordenes_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/gerencia/ lib/features/caja/`.
