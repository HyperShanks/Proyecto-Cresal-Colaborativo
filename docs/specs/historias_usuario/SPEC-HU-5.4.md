# SPEC-HU-5.4: Acoplamiento de Tasación de Vehículos para Desarme y Monitoreo Centralizado de Backorders

## 1. Contexto y Archivos Afectados
- **Objetivo**: Proveer a la gerencia ejecutiva de un panel centralizado de supervisión y auditoría en tiempo real para todas las compras por encargo en verde (`Reservas_Backorder`), monitoreando las señas y abonos recaudados en caja, balances económicos pendientes por cobrar, estado del ciclo de vida de la reserva, y la trazabilidad de asignación física (match) cuando un vehículo donante ingresa a desarme y su repuesto es catalogado en bodega.
- **Archivos a crear**:
  - Backend: `backend/tests/test_gerencia_backorders.py` (Suite de pruebas Pytest para RBAC, cálculo de KPIs, filtros y trazabilidad de asignación física).
  - Frontend: `lib/features/gerencia/models/backorder_gerencia_models.dart` (Estructuras de datos inmutables `BackorderItemModel`, `BackordersKpisModel` y `PaginatedBackordersResponse`).
  - Frontend: `lib/features/gerencia/presentation/screens/backorders_gerencia_view.dart` (Vista orquestadora con cabecera de 3 tarjetas KPI, buscador con debounce, selector de estado, tabla densa de 9 columnas con enlace a repuesto físico y footer consolidado).
  - Frontend: `test/features/gerencia/backorders_gerencia_test.dart` (Pruebas unitarias de modelos DTO y prueba de widget de renderizado).
- **Archivos a modificar**:
  - Backend: `backend/schemas/gerencia_schemas.py` y `backend/schemas.py` (Definición y exportación de `BackorderGerenciaItemDTO`, `BackorderGerenciaListResponse` y `BackorderGerenciaKpisDTO`).
  - Backend: `backend/routers/gerencia.py` (Implementación de endpoints `GET /api/v1/gerencia/backorders`, `GET /api/v1/gerencia/backorders/kpis`, y helper `format_relative_chile_date`).
  - Frontend: `lib/features/gerencia/services/gerencia_service.dart` (Implementación de `obtenerBackorders()` y `obtenerBackordersKpis()`).
  - Frontend: `lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart` (Activación del ítem 4 en sidebar, topbar corporativo y renderizado condicional según `VistaGerencia.backorders`).

---

## 2. Contratos de Datos y Firmas de API

### Modelos Backend (Pydantic V2)
```python
from pydantic import BaseModel, ConfigDict, Field
from typing import List, Optional

class BackorderGerenciaItemDTO(BaseModel):
    """Representación consolidada de una reserva backorder para auditoría gerencial."""
    id_reserva: str = Field(description="UUID de la reserva")
    folio: str = Field(description="Folio formateado amigable (ej. RES-5401)")
    fecha_creacion: str = Field(description="Fecha relativa o formateada para UI chilena")
    fecha_creacion_iso: str = Field(description="Fecha ISO en UTC")
    id_cliente: str
    cliente_nombre: str
    cliente_telefono: Optional[str] = None
    cliente_rut: Optional[str] = None
    id_vendedor: str
    vendedor_nombre: str
    id_sucursal: int
    sucursal_nombre: str
    id_categoria_requerida: int
    categoria_nombre: str
    marca_requerida: str
    modelo_requerido: str
    anio_requerido: Optional[int] = None
    cilindrada_requerida: Optional[str] = None
    combustible_requerido: Optional[str] = None
    transmision_requerida: Optional[str] = None
    notas_preparacion: Optional[str] = None
    precio_acordado: int = Field(description="Precio comercial pactado con cliente en CLP")
    monto_abonado: int = Field(description="Seña recaudada en caja en CLP")
    saldo_pendiente: int = Field(description="Saldo pendiente = max(0, precio_acordado - monto_abonado)")
    estado_reserva: str = Field(description="Pendiente, Confirmada, Completada, Anulada")
    id_activo_asignado: Optional[str] = None
    activo_asignado_sku: Optional[str] = None
    id_orden: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class BackorderGerenciaListResponse(BaseModel):
    """Respuesta paginada del visor maestro de backorders."""
    items: List[BackorderGerenciaItemDTO] = Field(default_factory=list)
    total_count: int
    total_recaudado_senas: int

    model_config = ConfigDict(from_attributes=True)

class BackorderGerenciaKpisDTO(BaseModel):
    """Resumen cuantitativo de la cabecera ejecutiva."""
    total_activos: int = Field(description="Conteo de reservas en Pendiente o Confirmada")
    capital_retenido: int = Field(description="Suma de monto_abonado de reservas activas")
    listos_para_liquidar: int = Field(description="Reservas activas con id_activo_asignado != null")
    total_registrados: int = 0
    total_recaudado_senas: int = 0

    model_config = ConfigDict(from_attributes=True)
```

### Endpoints Backend
1. **`GET /api/v1/gerencia/backorders`**
   - **Propósito**: Consulta multi-sucursal de reservas por encargo con filtros analíticos y resolución de pieza física asignada.
   - **Headers**: `Authorization: Bearer <token_jwt>` (Rol Gerencia `4` o Admin `5`).
   - **Query Parameters**:
     - `id_sucursal` (int, opcional): Sucursal de registro (omisión = global multi-sucursal).
     - `estado` (str, opcional): `Pendiente`, `Confirmada`, `Completada`, `Anulada`.
     - `q` (str, opcional): Búsqueda predictiva `ILIKE` sobre marca, modelo, nombres/apellidos de cliente o vendedor.
     - `limit` (int, default `20`), `offset` (int, default `0`).
   - **Mapeo Relacional (SQLAlchemy)**:
     - Joins con `Cliente`, `Usuario` (Vendedor), `Sucursal` y `Categoria_Activo`.
     - Outer join con `Activo_Inventariado` sobre `id_activo_asignado == Activo_Inventariado.id_activo` para obtener `sku_qr_fisico`.
   - **Respuesta 200**: `BackorderGerenciaListResponse`.

2. **`GET /api/v1/gerencia/backorders/kpis`**
   - **Propósito**: Cálculo en tiempo real de los 3 indicadores de cabecera ejecutiva.
   - **Headers**: `Authorization: Bearer <token_jwt>` (Rol Gerencia `4` o Admin `5`).
   - **Query Parameters**: `id_sucursal` (int, opcional).
   - **Lógica de Agregación**:
     - `total_activos`: Conteo donde `estado_reserva IN ('Pendiente', 'Confirmada')`.
     - `capital_retenido`: `func.sum(Reservas_Backorder.monto_abonado)` para reservas activas.
     - `listos_para_liquidar`: Conteo de activas con `id_activo_asignado IS NOT NULL`.
     - `total_registrados`: Conteo histórico total.
     - `total_recaudado_senas`: Suma histórica total de abonos.
   - **Respuesta 200**: `BackorderGerenciaKpisDTO`.

---

## 3. Reglas de Negocio, Casos de Borde y Seguridad

1. **Defensa contra Balances Negativos**:
   - `saldo_pendiente` se evalúa mediante `max(0, precio_acordado - monto_abonado)`. En caso de sobreejecución de abonos, el saldo nunca será negativo en la interfaz de auditoría.
2. **Convención de Folio Amigable**:
   - Los UUIDs de reserva se presentan como `RES-{str(id_reserva).replace('-', '')[:4].upper()}` (ej. `RES-5401`), garantizando una experiencia visual idéntica al prototipo corporativo.
3. **Formateo Temporal en Huso Chileno**:
   - Las fechas de creación se transforman mediante `format_relative_chile_date()` comparando contra `datetime.now(ZoneInfo('America/Santiago'))`:
     - Mismo día: `"Hoy HH:MM"`
     - Día anterior: `"Ayer HH:MM"`
     - Menos de 7 días: `"Hace N días"`
     - Resto: `"DD/MM/YYYY HH:MM"`
4. **Tolerancia a Nulos en Asignación Física**:
   - Si `id_activo_asignado == null`, la columna *Match / Asignación* muestra el texto cursivo en gris suave `"En búsqueda"`.
   - Si `id_activo_asignado != null`, se despliega un badge verde esmeralda con icono `link` y el SKU del activo (`MOT-XXXX-XX` o `CAJ-XXXX-XX`). Si el activo fue eliminado o no existe en inventario, se degrada elegantemente a los primeros 8 dígitos del UUID sin romper la tabla.
5. **Debounce en Búsqueda Predictiva**:
   - El input de búsqueda en frontend implementa un temporizador `Timer` de 350 ms para mitigar ráfagas de peticiones HTTP mientras el usuario escribe en el teclado.

---

## 4. Checklist de Tareas de Implementación (TDD)

- [x] **Tarea 1 (Backend - Esquemas DTO)**:
  - Definir `BackorderGerenciaItemDTO`, `BackorderGerenciaListResponse` y `BackorderGerenciaKpisDTO` en `backend/schemas/gerencia_schemas.py`.
  - Re-exportar los esquemas en `backend/schemas.py`.
- [x] **Tarea 2 (Backend - Endpoints y Lógica)**:
  - Implementar `GET /api/v1/gerencia/backorders` con soporte de filtros, joins relacionales y outer join a `Activo_Inventariado`.
  - Implementar `GET /api/v1/gerencia/backorders/kpis` con agregaciones matemáticas exactas.
  - Implementar función auxiliar `format_relative_chile_date()` para representación temporal amigable.
- [x] **Tarea 3 (Backend - Pruebas Pytest)**:
  - Crear `backend/tests/test_gerencia_backorders.py` con 7 pruebas: RBAC Gerente/Admin, bloqueo 403 a Vendedor, precisión matemática de KPIs, filtros de sucursal y estado, búsqueda predictiva `q` y trazabilidad de repuesto asignado.
- [x] **Tarea 4 (Frontend - Modelos y Servicios)**:
  - Crear `lib/features/gerencia/models/backorder_gerencia_models.dart`.
  - Agregar `obtenerBackorders()` y `obtenerBackordersKpis()` a `lib/features/gerencia/services/gerencia_service.dart`.
- [x] **Tarea 5 (Frontend - Interfaz de Usuario)**:
  - Desarrollar `BackordersGerenciaView`:
    - 3 tarjetas KPI ejecutivas en cabecera con `KpiCardWidget`.
    - Barra de filtros con buscador (debounce 350ms), dropdown de estados y botón Limpiar Filtros.
    - Tabla densa de 9 columnas con badges cromáticos para categoría (`Motor` celeste vs `Caja de Cambios` ámbar), estados de reserva y match de asignación física.
    - Footer consolidado con total de encargos y total recaudado en señas.
  - Integrar en `DashboardGerenciaView` (ítem 4 del sidebar y topbar dinámico).
- [x] **Tarea 6 (Frontend - Testing y Linter)**:
  - Crear `frontend/test/features/gerencia/backorders_gerencia_test.dart` validando modelos y renderizado de widgets.
  - Ejecutar `flutter analyze` asegurando 0 issues en `lib/features/gerencia`.

---

## 5. Criterios de Validación Automatizada

```bash
# 1. Pruebas Backend
pytest backend/tests/test_gerencia_backorders.py -v

# 2. Análisis Estático Frontend
flutter analyze lib/features/gerencia

# 3. Pruebas Frontend
flutter test test/features/gerencia/backorders_gerencia_test.dart
```
