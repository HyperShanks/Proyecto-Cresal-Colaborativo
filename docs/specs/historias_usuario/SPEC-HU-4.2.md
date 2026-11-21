# SPEC-HU-4.2: Bandeja de Órdenes Pendientes y Búsqueda Reactiva (CRES-214)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Proveer una bandeja unificada y reactiva de cobros pendientes para el operario de caja, consolidando ventas con saldo por pagar y solicitudes de reserva en verde (*backorder*) filtradas por sucursal, con búsqueda multicriterio en tiempo real y soporte Master-Detail[cite: 1, 2].
- **Archivos Backend a Crear / Modificar**:
  - `backend/schemas.py` (Modificar: Agregar DTOs Pydantic V2 `CobroPendienteItemResponse` y `CobroPendienteListResponse`)[cite: 2].
  - `backend/routers/caja.py` (Modificar: Implementar endpoint `GET /api/v1/caja/pendientes` con consulta combinada `Orden_Venta` y `Reservas_Backorder`)[cite: 1, 2].
  - `backend/tests/test_caja_pendientes.py` (Crear: Suite de pruebas unitarias y de integración para aislamiento de sucursal, filtros y consolidación)[cite: 1, 2].
- **Archivos Frontend Flutter a Crear / Modificar**:
  - `frontend/lib/features/caja/models/cobro_pendiente_model.dart` (Crear: DTO tipado para órdenes de venta y reservas backorder)[cite: 2].
  - `frontend/lib/features/caja/services/caja_service.dart` (Crear: Capa de consumo HTTP con manejo de query parameters y caché)[cite: 2].
  - `frontend/lib/features/caja/presentation/providers/caja_provider.dart` (Crear/Modificar: Estado reactivo de selección de orden, filtros de píldoras y debounce de búsqueda)[cite: 2].
  - `frontend/lib/features/caja/presentation/widgets/bandeja_cobros_panel.dart` (Crear: Panel lateral izquierdo Master-Detail con cabecera de sincronización y lista scrolleable)[cite: 2].
  - `frontend/lib/features/caja/presentation/widgets/cobro_pendiente_card.dart` (Crear: Tarjeta individual con badges adaptativos Ámbar/Índigo, desglose de montos y cálculo de tiempo)[cite: 2].
  - `frontend/lib/features/caja/presentation/screens/caja_main_screen.dart` (Modificar: Integrar `BandejaCobrosPanel` en el layout de 12 columnas junto al panel de detalle)[cite: 2].
  - `frontend/test/features/caja/bandeja_cobros_test.dart` (Crear: Pruebas unitarias de servicio y pruebas de widget para tarjetas, buscador y selección Master-Detail)[cite: 2].

## 2. Contratos de Datos y Firmas de API

### 2.1 Backend (FastAPI / Pydantic V2)

**Esquemas Pydantic V2 (`backend/schemas.py`):**

```python
from pydantic import BaseModel, ConfigDict, Field
from typing import List, Optional
from datetime import datetime
import uuid

class BackorderEspecificacionesDTO(BaseModel):
    marca: str
    modelo: str
    anio: Optional[int] = None
    categoria: str
    cilindrada: Optional[str] = None
    combustible: Optional[str] = None
    transito: Optional[str] = "En Tránsito Marítimo / Bodega"

    model_config = ConfigDict(from_attributes=True)

class ArticuloResumenDTO(BaseModel):
    cantidad: int
    tipo: str  # 'INVENTARIADO' | 'DESARME'
    descripcion: str
    sku: Optional[str] = None
    precio: int
    subtotal: int

    model_config = ConfigDict(from_attributes=True)

class CobroPendienteItemResponse(BaseModel):
    id_referencia: uuid.UUID = Field(description="id_orden o id_reserva según la entidad de origen")
    folio_documento: str = Field(description="Ej: ORD-9780 o RES-5401")
    tipo_operacion: str = Field(description="'VENTA' para Orden_Venta, 'BACKORDER' para Reservas_Backorder")
    estado_documento: str = Field(description="'Reservada', 'Pendiente', etc.")
    
    # Datos del Cliente
    cliente_nombre: str
    cliente_rut: str
    
    # Datos del Vendedor Originador
    vendedor_nombre: str
    
    # Temporalidad
    fecha_emision: datetime
    fecha_emision_formateada: str  # dd/MM/yyyy
    hora_emision_formateada: str   # HH:mm
    
    # Datos Financieros
    total_operacion: int = Field(description="Total venta o precio acordado de reserva")
    abono_previo: int = Field(default=0, description="Monto ya pagado previamente")
    monto_a_cobrar: int = Field(description="Saldo pendiente o abono fijado requerido")
    
    # Detalles complementarios
    articulos: List[ArticuloResumenDTO] = Field(default_factory=list)
    especificaciones_backorder: Optional[BackorderEspecificacionesDTO] = None

    model_config = ConfigDict(from_attributes=True)

class CobroPendienteListResponse(BaseModel):
    total: int
    sucursal_id: int
    items: List[CobroPendienteItemResponse]

    model_config = ConfigDict(from_attributes=True)

### 2.2 Endpoints de API

* **GET /api/v1/caja/pendientes**
  * **Acceso**: Privado (`Depends(require_caja_role)`).
  * **Headers**: `Authorization: Bearer <token>`
  * **Query Parameters**:
    * `sucursal_id` (int, obligatorio): ID de la sucursal activa donde opera la cajera.
    * `busqueda` (str, opcional): Cadena para filtrar por folio (`ORD-`, `RES-`), RUT del cliente, nombre de cliente o nombre de vendedor.
    * `tipo_operacion` (str, opcional): `'TODOS'`, `'VENTA'` o `'BACKORDER'`.
  * **Respuesta Exitosa (200 OK)**:
    ```json
    {
      "total": 3,
      "sucursal_id": 1,
      "items": [
        {
          "id_referencia": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          "folio_documento": "ORD-9780",
          "tipo_operacion": "VENTA",
          "estado_documento": "Reservada",
          "cliente_nombre": "Cristobal Alejandro Espinoza Perez",
          "cliente_rut": "14.892.401-2",
          "vendedor_nombre": "Juaquin Leiva",
          "fecha_emision": "2026-08-21T11:38:00Z",
          "fecha_emision_formateada": "21/08/2026",
          "hora_emision_formateada": "11:38",
          "total_operacion": 650000,
          "abono_previo": 150000,
          "monto_a_cobrar": 500000,
          "articulos": [
            {
              "cantidad": 1,
              "tipo": "INVENTARIADO",
              "descripcion": "Motor MG ZS 1.5 VTi-Tech Completo",
              "sku": "MOT-MG-ZS-15-089",
              "precio": 550000,
              "subtotal": 550000
            }
          ],
          "especificaciones_backorder": null
        },
        {
          "id_referencia": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
          "folio_documento": "RES-5401",
          "tipo_operacion": "BACKORDER",
          "estado_documento": "Pendiente",
          "cliente_nombre": "Camila Andrea Soto Lagos",
          "cliente_rut": "18.432.109-K",
          "vendedor_nombre": "Juaquin Leiva",
          "fecha_emision": "2026-08-21T12:20:00Z",
          "fecha_emision_formateada": "21/08/2026",
          "hora_emision_formateada": "12:20",
          "total_operacion": 1200000,
          "abono_previo": 0,
          "monto_a_cobrar": 300000,
          "articulos": [],
          "especificaciones_backorder": {
            "marca": "Hyundai",
            "modelo": "Tucson 2.0 CRDi Turbo Diesel",
            "anio": 2022,
            "categoria": "Conjunto Motor y Turbo",
            "cilindrada": "2.0L Turbo Diesel (D4HA)",
            "combustible": "Diésel",
            "transito": "En Tránsito Marítimo (Arribo est.: 10 días)"
          }
        }
      ]
    }
    ```
  * **Respuestas de Error**:
    * `401 Unauthorized`: Token JWT inválido, expirado o ausente.
    * `403 Forbidden`: Usuario no posee rol de Cajera (`id_rol == 3`) ni Administrador (`id_rol == 5`).
    * `422 Unprocessable Entity`: Parámetros de consulta no válidos o faltantes.

### 2.3 Modelos Frontend (Dart)

**Modelo DTO (`frontend/lib/features/caja/models/cobro_pendiente_model.dart`):**

```dart
class ArticuloResumenModel {
  final int cantidad;
  final String tipo;
  final String descripcion;
  final String? sku;
  final int precio;
  final int subtotal;

  ArticuloResumenModel({
    required this.cantidad,
    required this.tipo,
    required this.descripcion,
    this.sku,
    required this.precio,
    required this.subtotal,
  });

  factory ArticuloResumenModel.fromJson(Map<String, dynamic> json) => ArticuloResumenModel(
    cantidad: json['cantidad'] as int? ?? 1,
    tipo: json['tipo'] as String? ?? 'DESARME',
    descripcion: json['descripcion'] as String? ?? '',
    sku: json['sku'] as String?,
    precio: json['precio'] as int? ?? 0,
    subtotal: json['subtotal'] as int? ?? 0,
  );
}

class BackorderEspecificacionesModel {
  final String marca;
  final String modelo;
  final int? anio;
  final String categoria;
  final String? cilindrada;
  final String? combustible;
  final String transito;

  BackorderEspecificacionesModel({
    required this.marca,
    required this.modelo,
    this.anio,
    required this.categoria,
    this.cilindrada,
    this.combustible,
    required this.transito,
  });

  factory BackorderEspecificacionesModel.fromJson(Map<String, dynamic> json) => BackorderEspecificacionesModel(
    marca: json['marca'] as String? ?? '',
    modelo: json['modelo'] as String? ?? '',
    anio: json['anio'] as int?,
    categoria: json['categoria'] as String? ?? '',
    cilindrada: json['cilindrada'] as String?,
    combustible: json['combustible'] as String?,
    transito: json['transito'] as String? ?? 'En Tránsito',
  );
}

class CobroPendienteModel {
  final String idReferencia;
  final String folioDocumento;
  final String tipoOperacion; // 'VENTA' | 'BACKORDER'
  final String estadoDocumento;
  final String clienteNombre;
  final String clienteRut;
  final String vendedorNombre;
  final DateTime fechaEmision;
  final String fechaEmisionFormateada;
  final String horaEmisionFormateada;
  final int totalOperacion;
  final int abonoPrevio;
  final int montoACobrar;
  final List<ArticuloResumenModel> articulos;
  final BackorderEspecificacionesModel? especificacionesBackorder;

  CobroPendienteModel({
    required this.idReferencia,
    required this.folioDocumento,
    required this.tipoOperacion,
    required this.estadoDocumento,
    required this.clienteNombre,
    required this.clienteRut,
    required this.vendedorNombre,
    required this.fechaEmision,
    required this.fechaEmisionFormateada,
    required this.horaEmisionFormateada,
    required this.totalOperacion,
    required this.abonoPrevio,
    required this.montoACobrar,
    required this.articulos,
    this.especificacionesBackorder,
  });

  bool get esVenta => tipoOperacion == 'VENTA';
  bool get esBackorder => tipoOperacion == 'BACKORDER';

  factory CobroPendienteModel.fromJson(Map<String, dynamic> json) => CobroPendienteModel(
    idReferencia: json['id_referencia'] as String,
    folioDocumento: json['folio_documento'] as String,
    tipoOperacion: json['tipo_operacion'] as String,
    estadoDocumento: json['estado_documento'] as String,
    clienteNombre: json['cliente_nombre'] as String,
    clienteRut: json['cliente_rut'] as String,
    vendedorNombre: json['vendedor_nombre'] as String,
    fechaEmision: DateTime.parse(json['fecha_emision'] as String),
    fechaEmisionFormateada: json['fecha_emision_formateada'] as String,
    horaEmisionFormateada: json['hora_emision_formateada'] as String,
    totalOperacion: json['total_operacion'] as int? ?? 0,
    abonoPrevio: json['abono_previo'] as int? ?? 0,
    montoACobrar: json['monto_a_cobrar'] as int? ?? 0,
    articulos: (json['articulos'] as List<dynamic>?)
            ?.map((e) => ArticuloResumenModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    especificacionesBackorder: json['especificaciones_backorder'] != null
        ? BackorderEspecificacionesModel.fromJson(json['especificaciones_backorder'] as Map<String, dynamic>)
        : null,
  );
}

Firma del Servicio (frontend/lib/features/caja/services/caja_service.dart):

Dart
abstract class ICajaService {
  Future<List<CobroPendienteModel>> obtenerCobrosPendientes({
    required int sucursalId,
    String? busqueda,
    String? tipoOperacion,
  });
}

## 3. Reglas de Negocio, Casos de Borde y Seguridad

1. **Aislamiento Multi-Tenant por Sucursal (RBAC & Zero Trust)**:
   - El endpoint `GET /api/v1/caja/pendientes` debe forzar el filtrado por `id_sucursal`[cite: 1]. Una cajera solo puede consultar y cobrar órdenes emitidas en su propia sucursal física activa.
   - Si el token JWT no posee `id_rol in [3, 5]`, la petición debe ser rechazada inmediatamente con `HTTP 403 Forbidden`[cite: 1].
2. **Consolidación de Fuentes de Datos (Dualidad Venta vs. Backorder)**:
   - **Ventas Tradicionales (`Orden_Venta`)**: Se seleccionan registros donde `id_sucursal == sucursal_id`, `estado_orden in ['Reservada', 'Pendiente']` y `monto_pendiente > 0`[cite: 1]. Se genera el folio representativo `ORD-<ultimos_4_digitos_uuid>` o folio secuencial.
   - **Reservas Backorder (`Reservas_Backorder`)**: Se seleccionan registros donde `id_sucursal_registro == sucursal_id`, `estado_reserva == 'Pendiente'` y abono pendiente de confirmación[cite: 1]. Se genera el folio `RES-<ultimos_4_digitos_uuid>`.
3. **Búsqueda Reactiva Multicriterio y Debounce**:
   - La búsqueda debe operar insensible a mayúsculas/minúsculas (`ILIKE` en backend o `.toLowerCase()` en frontend) y tolerar formatos con o sin puntos/guión en el RUT del cliente.
   - En frontend, el campo de búsqueda debe aplicar un **Debounce de 300 ms** para optimizar el consumo de recursos y permitir borrado rápido con botón `x`[cite: 1].
4. **Diferenciación Visual Estricta (Fiel al Prototipo HTML)**:
   - **Venta / Retiro en Tienda**: Badge con fondo ámbar (`bg-amber-50 text-amber-700 border-amber-300`), etiqueta "Venta en Tienda", desglose de "Saldo a Pagar" o "Total a Pagar" con énfasis en color primario `#2596BE`[cite: 1].
   - **Reserva en Verde / Backorder**: Badge con fondo índigo (`bg-indigo-50 text-indigo-700 border-indigo-300`), etiqueta "Reserva Backorder", y monto de "Abono Inicial" destacado en color `#4F46E5`[cite: 1].
5. **Arquitectura Master-Detail Sin Desplazamiento de Rutas**:
   - Al pulsar cualquier tarjeta de la bandeja, el estado reactivo (`cajaProvider.seleccionarOrden(orden)`) debe actualizarse instantáneamente, aplicando el borde activo `#2596BE` a la tarjeta y precargando el panel derecho de cobro sin abrir diálogos modales ni navegar de pantalla[cite: 1].
6. **Manejo de Estado Vacío (*Zero State*)**:
   - Si no existen cobros pendientes tras aplicar filtros o criterios de búsqueda, la bandeja debe mostrar un contenedor con borde punteado, icono `inbox` y el texto "No se encontraron órdenes pendientes" con opción para restablecer filtros[cite: 1].

## 4. Checklist de Tareas de Implementación (TDD)

- [x] **Tarea 1 (Backend - DTOs Pydantic V2 en `schemas.py`)**:
  - Declarar `BackorderEspecificacionesDTO`, `ArticuloResumenDTO`, `CobroPendienteItemResponse` y `CobroPendienteListResponse` utilizando `ConfigDict(from_attributes=True)`[cite: 1].
- [x] **Tarea 2 (Backend - Endpoint `GET /api/v1/caja/pendientes` en `routers/caja.py`)**:
  - Implementar la consulta unificada entre `Orden_Venta` y `Reservas_Backorder`[cite: 1].
  - Aplicar filtros SQL parametrizados por `id_sucursal`, `busqueda` (RUT, cliente, vendedor, folio) y `tipo_operacion` (`TODOS`, `VENTA`, `BACKORDER`)[cite: 1].
  - Proteger con el helper de dependencias `require_caja_role` (`id_rol in [3, 5]`)[cite: 1].
- [x] **Tarea 3 (Backend - Pruebas Pytest `tests/test_caja_pendientes.py`)**:
  - Test 1: Listado correcto de órdenes de venta y reservas backorder de la sucursal activa de la cajera[cite: 1].
  - Test 2: Validación de aislamiento multi-tenant estricto (no listar órdenes de otras sucursales)[cite: 1].
  - Test 3: Filtrado por texto (búsqueda parcial de RUT, Folio y Nombre)[cite: 1].
  - Test 4: Bloqueo de acceso con `HTTP 403 Forbidden` a usuarios no autorizados (`id_rol == 1` o `id_rol == 2`)[cite: 1].
- [x] **Tarea 4 (Frontend - DTOs y Servicio `caja_service.dart`)**:
  - Crear `cobro_pendiente_model.dart` con mapeo seguro `fromJson` y getters booleanos (`esVenta`, `esBackorder`)[cite: 1].
  - Implementar `caja_service.dart` consumiendo el endpoint `GET /api/v1/caja/pendientes` con headers JWT y manejo de errores HTTP[cite: 1].
- [x] **Tarea 5 (Frontend - Proveedor Reactivo `caja_provider.dart`)**:
  - Implementar estado reactivo que controle la lista de cobros, la orden seleccionada, los filtros rápidos de píldoras, la búsqueda con debounce de 300 ms y el estado de refresco (`isRefreshing`)[cite: 1].
- [x] **Tarea 6 (Frontend - Widget `CobroPendienteCard`)**:
  - Construir tarjeta adaptativa con borde resaltado (`#2596BE`) según selección activa, badges ámbar (Venta) e índigo (Backorder), tiempo transcurrido con icono de reloj y montos formateados en CLP[cite: 1].
- [x] **Tarea 7 (Frontend - Panel de Bandeja `BandejaCobrosPanel` y Estado Vacío)**:
  - Construir la columna izquierda (4 cols) con cabecera, contador dinámico, botón de refresco animado, selector de píldoras, buscador con botón para limpiar y lista con scroll independiente[cite: 1].
  - Integrar el componente de estado vacío (*Zero State*) con icono `inbox` cuando no existan coincidencias[cite: 1].
- [x] **Tarea 8 (Frontend - Ensamblado en `CajaMainScreen` y Pruebas Unitarias/Widgets)**:
  - Integrar `BandejaCobrosPanel` dentro del layout de `caja_main_screen.dart`[cite: 1].
  - Escribir suite `frontend/test/features/caja/bandeja_cobros_test.dart` verificando:
    1. Renderizado de tarjetas y badges según tipo de operación[cite: 1].
    2. Filtrado reactivo por píldoras y buscador de texto[cite: 1].
    3. Notificación y actualización de selección al interactuar con una tarjeta[cite: 1].

## 5. Criterios de Validación Automatizada

El agente autónomo solo considerará completada la especificación cuando los siguientes comandos se ejecuten sin errores:

1. **Backend Tests**:
   ```bash
   cd backend && pytest tests/test_caja_pendientes.py -v

Backend Linting (Zero Fatal Errors):

Bash
flake8 backend/routers/caja.py backend/schemas.py --count --select=E9,F63,F7,F82
Frontend Tests:

Bash
cd frontend && flutter test test/features/caja/bandeja_cobros_test.dart
Frontend Analyzer:

Bash
flutter analyze lib/features/caja/