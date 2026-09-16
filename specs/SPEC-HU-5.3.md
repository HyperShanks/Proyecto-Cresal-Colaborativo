# SPEC-HU-5.3: Maestro de Inventario Global y Tasación de Repuestos Paletizados

## 1. Contexto y Archivos Afectados
- **Objetivo**: Proveer a la gerencia y jefaturas autorizadas de un visor maestro multi-sucursal para auditar todo el stock físico de repuestos (`Activo_Inventariado`) en sus respectivas ubicaciones de galpón y rack, otorgando la facultad exclusiva de fijar o actualizar el precio de referencia comercial (`precio_referencia`) para repuestos almacenados en estado Paletizado (`id_estado = 7`), transicionándolos atómicamente a Disponible (`id_estado = 1`) y habilitándolos inmediatamente para la venta en catálogo y mostrador.
- **Archivos a crear**:
  - Backend: `backend/tests/test_gerencia_inventario_maestro.py` (Suite de pruebas automatizadas Pytest para RBAC, filtros y tasación).
  - Frontend: `lib/features/gerencia/presentation/screens/inventario_gerencia_view.dart` (Visor maestro con doble modo: Grid de Tarjetas responsivas y Tabla Densa, barra de filtros avanzados y modal de tasación).
  - Frontend: `test/features/gerencia/inventario_gerencia_test.dart` (Pruebas de widgets y deserialización de modelos en Flutter).
- **Archivos a modificar**:
  - Backend: `backend/core/security.py` (Creación del validador de dependencia `verificar_rol_tasacion` restringido a roles 4, 5 y 6).
  - Backend: `backend/schemas.py` (Extensión del DTO `PaginatedCatalogoResponse` con el campo `pendientes_tasacion_count`).
  - Backend: `backend/routers/inventario.py` (Implementación de `GET /api/v1/inventario/maestro` y blindaje transaccional de `PATCH /api/v1/inventario/{id_activo}/precio`).
  - Frontend: `lib/features/ventas/models/catalogo_model.dart` (Inclusión de `ubicacionGalpon`, `observacionEstado` en `CatalogoItem` y `pendientesTasacionCount` en `PaginatedCatalogoResponse`).
  - Frontend: `lib/features/gerencia/services/gerencia_service.dart` (Adición de métodos asíncronos `obtenerMaestroInventario()` y `tasarActivo()`).
  - Frontend: `lib/features/gerencia/presentation/screens/dashboard_gerencia_view.dart` (Activación del ítem 3 en el sidebar corporativo, badge numérico de cuellos de botella y títulos contextuales en Topbar).

---

## 2. Contratos de Datos y Firmas de API

### Modelos Backend (Pydantic V2)
```python
from pydantic import BaseModel, ConfigDict, Field
from typing import List, Optional
from uuid import UUID

class AsignarPrecioRequest(BaseModel):
    """Payload de entrada para fijar o mutar el precio de tasación comercial."""
    precio_referencia: int = Field(
        ...,
        gt=0,
        description="Precio de referencia comercial en CLP (debe ser estrictamente positivo)"
    )

class AsignarPrecioResponse(BaseModel):
    """Respuesta transaccional tras tasación exitosa."""
    msg: str = "Precio actualizado correctamente"
    id_activo: UUID
    nuevo_precio: int
    estado_anterior: str
    nuevo_estado: str = "Disponible"
    version_lock: int

class PaginatedCatalogoResponse(BaseModel):
    """Respuesta paginada del maestro de inventario multi-sucursal."""
    items: List[CatalogoItemResponse]
    total_count: int
    limit: int
    offset: int
    pendientes_tasacion_count: Optional[int] = 0

    model_config = ConfigDict(from_attributes=True)
```

### Endpoints Backend
1. **`GET /api/v1/inventario/maestro`**
   - **Propósito**: Consulta consolidada de stock físico para auditoría ejecutiva.
   - **Headers**: `Authorization: Bearer <token_jwt>` (Rol Gerencia `4` o Admin `5`).
   - **Query Parameters**:
     - `id_sucursal` (int, opcional): Filtra por sucursal física actual (si se omite, retorna consolidado global de toda la cadena).
     - `id_categoria` (int, opcional): Filtra por tipo (1: Motores, 2: Cajas de Cambio).
     - `id_estado` / `estado` (int/str, opcional): Filtra por estado de ciclo de vida del repuesto.
     - `solo_sin_tasar` (bool, default `false`): Retorna exclusivamente repuestos en estado Paletizado o con precio nulo/cero.
     - `combustible` (str, opcional): Bencina, Diesel, Híbrido, etc.
     - `transmision` (str, opcional): Mecánica, Automática, etc.
     - `ubicacion` (str, opcional): Galpón 1, Galpón 2, Patio, etc.
     - `q` (str, opcional): Búsqueda predictiva insensible a mayúsculas/minúsculas sobre SKU QR, marca, modelo, N° de ingreso o ubicación en rack.
     - `limit` (int, default `12`), `offset` (int, default `0`).
   - **Respuesta 200**: `PaginatedCatalogoResponse`.
   - **Respuesta 403**: Si el rol no pertenece a Gerencia (`4`) ni Administrador (`5`).

2. **`PATCH /api/v1/inventario/{id_activo}/precio`**
   - **Propósito**: Tasación comercial con transición de estado y control de concurrencia.
   - **Headers**: `Authorization: Bearer <token_jwt>` (`verificar_rol_tasacion`: Roles `4`, `5` o `6`).
   - **Path Parameter**: `id_activo` (UUID).
   - **Body**: `{"precio_referencia": 1450000}`.
   - **Comportamiento Transaccional ACID**:
     - Valida `precio_referencia > 0` (retorna 422 si es `<= 0`).
     - Actualiza `precio_referencia`.
     - Si el activo se encuentra en estado `Paletizado` (`id_estado = 7`), transiciona a `Disponible` (`id_estado = 1`).
     - Actualiza `fecha_actualizacion = datetime.utcnow()` (UTC).
     - Incrementa `version_lock = version_lock + 1`.
   - **Respuesta 200**: `AsignarPrecioResponse`.
   - **Respuesta 404**: Si el repuesto no existe en base de datos.
   - **Respuesta 403**: Si un rol no autorizado (Cajero, Vendedor, Bodeguero) intenta tasar.

---

## 3. Reglas de Negocio, Casos de Borde y Seguridad

1. **Matriz RBAC Estricta**:
   - Lectura del inventario maestro (`GET /maestro`): Exclusivo para Gerente (`id_rol = 4`) y Administrador (`id_rol = 5`).
   - Tasación de repuestos (`PATCH /precio`): Autorizado para Gerente (`4`), Administrador (`5`) y Jefe de Ventas (`6`). Bloqueo con 403 Forbidden para Vendedores (`2`), Cajeros (`3`) o Bodegueros (`1`).
2. **Concurrencia Optimista (`version_lock`)**:
   - Cada actualización de precio incrementa monótonamente `version_lock` para salvaguardar la coherencia en caso de tasaciones concurrentes desde múltiples terminales.
3. **Manejo Defensivo de Datos Técnicos y Nulos**:
   - La UI debe tolerar activos sin vehículo de origen asociado (`id_vehiculo == null`), mostrando `"S/A"` (Sin Año) o `"N/A"` en especificaciones complementarias sin provocar fallas de renderizado.
   - Formateo monetario en CLP (`$ 1.450.000`) aplicado transversalmente con expresiones regulares sobre enteros, evitando discrepancias de redondeo por punto flotante.
4. **Protección Anti-Overflow (`RenderFlex`)**:
   - La vista de tarjetas (`Grid`) define `mainAxisExtent: 410` en su `SliverGridDelegateWithFixedCrossAxisCount` y adapta el conteo de columnas responsivamente (1 columna en móviles/pantallas estrechas, hasta 4 columnas en escritorios Full HD).
   - La vista de tabla densa se encapsula en `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
5. **Ciclo de Vida en UI (`mounted` guards)**:
   - Toda llamada asíncrona a `GerenciaService` dentro de `InventarioGerenciaView` cuenta con salvaguardas `if (!mounted) return;` antes de ejecutar `setState()`.

---

## 4. Checklist de Tareas de Implementación (TDD)

- [x] **Tarea 1 (Backend - Seguridad RBAC)**: Crear `verificar_rol_tasacion` en `backend/core/security.py` autorizando roles `4`, `5` y `6`.
- [x] **Tarea 2 (Backend - Endpoints y Esquemas)**:
  - Extender `PaginatedCatalogoResponse` en `backend/schemas.py` con `pendientes_tasacion_count`.
  - Implementar `GET /api/v1/inventario/maestro` en `backend/routers/inventario.py` soportando filtros multidimensionales y búsqueda predictiva `q`.
  - Asegurar que `PATCH /api/v1/inventario/{id_activo}/precio` muta atómicamente el estado de `Paletizado` (7) a `Disponible` (1) e incrementa `version_lock`.
- [x] **Tarea 3 (Backend - Pruebas Pytest)**:
  - Crear `backend/tests/test_gerencia_inventario_maestro.py` con 8 pruebas automatizadas: RBAC de Gerente y Admin, bloqueo a Vendedor, filtros de sucursal, cuellos de botella `solo_sin_tasar`, búsqueda `q`, tasación exitosa y rechazo de precios `<= 0`.
- [x] **Tarea 4 (Frontend - Modelos y Servicios)**:
  - Extender `CatalogoItem` con `ubicacionGalpon` y `observacionEstado` en `catalogo_model.dart`.
  - Añadir métodos `obtenerMaestroInventario()` y `tasarActivo()` en `gerencia_service.dart`.
- [x] **Tarea 5 (Frontend - Interfaz de Usuario)**:
  - Maquetar `InventarioGerenciaView` con modo Tarjetas y Tabla Densa, barra de búsqueda reactiva (debounce 350ms), chip de filtro rápido *"Sin Tasar"* con badge contador y modal interactivo de tasación `_TasacionDialog`.
  - Integrar la vista en `DashboardGerenciaView` (ítem 3 del sidebar, badge de cuellos de botella y sincronización con el selector de sucursales).
- [x] **Tarea 6 (Frontend - Testing)**:
  - Crear `frontend/test/features/gerencia/inventario_gerencia_test.dart` verificando deserialización de DTOs y montaje de componentes de UI.

---

## 5. Criterios de Validación Automatizada

```bash
# 1. Pruebas Backend
pytest backend/tests/test_gerencia_inventario_maestro.py -v

# 2. Análisis Estático Frontend
flutter analyze lib/features/gerencia

# 3. Pruebas Frontend
flutter test test/features/gerencia/inventario_gerencia_test.dart
```
