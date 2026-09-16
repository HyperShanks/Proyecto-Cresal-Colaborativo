# SPEC-HU-4.5: Historial de Órdenes y Auditoría de Cobros con Filtros (CRES-217)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Implementar el módulo de historial de órdenes y auditoría de caja con filtros multicriterio en tiempo real, normalización de zona horaria local (`America/Santiago` a UTC), métricas de arqueo/cuadre en cabecera y diálogo modal de trazabilidad detallada de pagos e ítems[cite: 2].
- **Archivos Backend a Crear / Modificar**:
  - `backend/schemas.py` (Modificar: Declarar esquemas Pydantic V2 `HistorialPagoDetalleResponse`, `HistorialOrdenItemResponse`, `ResumenCuadreCajaResponse` y `HistorialCajaResponse`).
  - `backend/routers/caja.py` (Modificar: Implementar endpoint atómico `GET /api/v1/caja/historial` con filtros multicriterio, sumatorias agregadas de cuadre y optimización con `joinedload`).
  - `backend/tests/test_caja_historial.py` (Crear: Suite de pruebas unitarias e integración para consistencia matemática de arqueo, filtros de fecha/zona horaria, paginación y RBAC).
- **Archivos Frontend Flutter a Crear / Modificar**:
  - `frontend/lib/features/caja/models/historial_caja_model.dart` (Crear: Modelos tipados Dart para transacciones, auditoría de ítems, resumen de cuadre y respuesta paginada).
  - `frontend/lib/features/caja/services/caja_service.dart` (Modificar: Agregar firma e implementación del método `obtenerHistorialCaja(...)`).
  - `frontend/lib/features/caja/presentation/providers/historial_caja_provider.dart` (Crear: Gestor de estado reactivo para filtros de período, búsqueda con debounce, control de estado y orden seleccionada para auditoría)[cite: 2].
  - `frontend/lib/features/caja/presentation/screens/historial_caja_screen.dart` (Crear: Pantalla principal de auditoría e historial con navegación conectada al sidebar)[cite: 2].
  - `frontend/lib/features/caja/presentation/widgets/historial_metricas_panel.dart` (Crear: Panel superior de 4 tarjetas con métricas de arqueo: Total Recaudado, Efectivo, POS y Transf./Cheques)[cite: 2].
  - `frontend/lib/features/caja/presentation/widgets/historial_tabla_view.dart` (Crear: Tabla de datos estructurada con badges de estado, desglose de métodos y botón de auditoría)[cite: 2].
  - `frontend/lib/features/caja/presentation/widgets/detalle_auditoria_dialog.dart` (Crear: Diálogo modal con ficha de cliente, personal responsable, desglose de ítems, pagos exactos y trazabilidad)[cite: 2].
  - `frontend/lib/features/caja/presentation/widgets/filtro_rango_fechas_dialog.dart` (Crear: Diálogo modal para rango de fechas contables con atajos: Ayer, Semana Anterior y Mes Anterior)[cite: 2].
  - `frontend/test/features/caja/historial_caja_test.dart` (Crear: Suite de pruebas unitarias de servicio y pruebas de widgets para renderizado de métricas, filtros y modales).

## 2. Contratos de Datos y Firmas de API

### 2.1 Backend (FastAPI / SQLAlchemy / Pydantic V2)

**Esquemas Pydantic V2 (`backend/schemas.py`):**

```python
from pydantic import BaseModel, ConfigDict, Field
from typing import List, Optional
from datetime import datetime
import uuid


class HistorialPagoDetalleDTO(BaseModel):
    id_transaccion: Optional[uuid.UUID] = None
    metodo_pago: str = Field(description="Efectivo, Débito, Crédito, Transferencia o Cheque")
    monto: int = Field(ge=0, description="Monto cubierto por este método específico")
    fecha_pago: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class HistorialArticuloDTO(BaseModel):
    cantidad: int
    tipo: str = Field(description="'INVENTARIADO' o 'DESARME'")
    descripcion: str
    sku: Optional[str] = None
    precio: int
    subtotal: int

    model_config = ConfigDict(from_attributes=True)


class HistorialMovimientoDTO(BaseModel):
    hora: str = Field(description="Hora del evento (HH:mm)")
    evento: str = Field(description="Descripción del hito de auditoría")

    model_config = ConfigDict(from_attributes=True)


class ResumenCuadreCajaDTO(BaseModel):
    total_recaudado: int = Field(default=0, description="Suma total de pagos en el rango y filtros aplicados")
    total_ordenes_pagadas: int = Field(default=0, description="Cantidad total de órdenes en estado Pagada/Despachada")
    total_efectivo: int = Field(default=0, description="Arqueo físico de gaveta (Billetes y monedas)")
    total_pos: int = Field(default=0, description="Total tarjetas voucher Transbank (Débito + Crédito)")
    total_debito: int = Field(default=0)
    total_credito: int = Field(default=0)
    total_transferencia: int = Field(default=0)
    total_cheque: int = Field(default=0)

    model_config = ConfigDict(from_attributes=True)


class HistorialOrdenItemResponse(BaseModel):
    id_orden: uuid.UUID
    folio: str = Field(description="Ej: ORD-9778 o RES-5401")
    tipo_operacion: str = Field(description="'VENTA' o 'BACKORDER'")
    emite_qr: bool = Field(description="True si la orden liquida el 100% de la venta para barrera")
    fecha_iso: str = Field(description="YYYY-MM-DD en hora local America/Santiago")
    hora: str = Field(description="HH:mm en hora local")
    fecha_hora_formateada: str = Field(description="HH:mm - DD/MM/YYYY")
    
    # Datos de Cliente y Personal Responsable
    cliente_nombre: str
    cliente_rut: Optional[str] = None
    vendedor_nombre: str
    cajera_nombre: str
    
    # Estados y Pagos
    estado_orden: str = Field(description="'Pagada', 'Despachada', 'Reservada', 'Anulada'")
    modalidad_pago: str = Field(description="'unico' o 'split'")
    metodos_resumen: str = Field(description="Ej: Débito: $420.000 + Transferencia: $180.000")
    total_venta: int
    abono_previo: int = 0
    total_liquidado: int = Field(description="Monto total pagado en ventanilla")
    
    # Desgloses Detallados para Auditoría
    desglose_pagos: List[HistorialPagoDetalleDTO] = Field(default_factory=list)
    articulos: List[HistorialArticuloDTO] = Field(default_factory=list)
    historial_movimientos: List[HistorialMovimientoDTO] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class HistorialCajaResponse(BaseModel):
    total_registros: int
    pagina_actual: int
    limite_por_pagina: int
    total_paginas: int
    resumen_cuadre: ResumenCuadreCajaDTO
    items: List[HistorialOrdenItemResponse]

    model_config = ConfigDict(from_attributes=True)

### 2.2 Endpoints de API

* **GET /api/v1/caja/historial**
  * **Acceso**: Privado (`Depends(require_caja_role)` — `id_rol in [3, 5]`).
  * **Headers**: `Authorization: Bearer <token>`
  * **Query Parameters**:
    * `sucursal_id` (int, obligatorio): ID de la sucursal activa para forzar aislamiento multi-tenant.
    * `periodo` (str, opcional, default: `'HOY'`): Atajos de período contable (`'HOY'`, `'ESTA_SEMANA'`, `'ESTE_MES'`, `'RANGO'`).
    * `fecha_desde` (date/str, opcional): Fecha inicio en formato `YYYY-MM-DD` (obligatorio si `periodo == 'RANGO'`).
    * `fecha_hasta` (date/str, opcional): Fecha fin en formato `YYYY-MM-DD` (obligatorio si `periodo == 'RANGO'`).
    * `estado_orden` (str, opcional, default: `'TODOS'`): `'TODOS'`, `'Pagada'`, `'Despachada'`, `'Reservada'`, `'Anulada'`.
    * `metodo_pago` (str, opcional, default: `'TODOS'`): `'TODOS'`, `'Efectivo'`, `'Débito'`, `'Crédito'`, `'Transferencia'`, `'Cheque'`.
    * `busqueda` (str, opcional): Texto para búsqueda reactiva por Folio (`ORD-`), Nombre de Cliente, RUT, Vendedor o Cajera.
    * `monto_min` (int, opcional): Límite inferior de monto total.
    * `monto_max` (int, opcional): Límite superior de monto total.
    * `id_cajera` (uuid, opcional): Filtrar por operario/a de caja responsable.
    * `id_vendedor` (uuid, opcional): Filtrar por vendedor que originó la orden en mesón.
    * `pagina` (int, opcional, default: 1): Número de página para paginación.
    * `limite` (int, opcional, default: 20): Cantidad de registros por página.
  * **Respuesta Exitosa (200 OK)**:
    ```json
    {
      "total_registros": 3,
      "pagina_actual": 1,
      "limite_por_pagina": 20,
      "total_paginas": 1,
      "resumen_cuadre": {
        "total_recaudado": 1250000,
        "total_ordenes_pagadas": 2,
        "total_efectivo": 650000,
        "total_pos": 420000,
        "total_debito": 420000,
        "total_credito": 0,
        "total_transferencia": 180000,
        "total_cheque": 0
      },
      "items": [
        {
          "id_orden": "8f3b201a-63b7-4dc4-8392-8094a942b001",
          "folio": "ORD-9778",
          "tipo_operacion": "VENTA",
          "emite_qr": true,
          "fecha_iso": "2026-08-21",
          "hora": "10:14",
          "fecha_hora_formateada": "10:14 - 21/08/2026",
          "cliente_nombre": "Taller Mecánico San Cristóbal SpA",
          "cliente_rut": "77.301.992-1",
          "vendedor_nombre": "Andrés Morales (Mesón 2)",
          "cajera_nombre": "Lorena Valenzuela (Caja 01)",
          "estado_orden": "Pagada",
          "modalidad_pago": "split",
          "metodos_resumen": "Débito: $420.000 + Transferencia: $180.000",
          "total_venta": 600000,
          "abono_previo": 0,
          "total_liquidado": 600000,
          "desglose_pagos": [
            {
              "id_transaccion": "1c7a911e-2879-43c3-9821-2e557b451001",
              "metodo_pago": "Débito",
              "monto": 420000,
              "fecha_pago": "2026-08-21T10:14:00Z"
            },
            {
              "id_transaccion": "2d8b022f-3980-54d4-a932-3f668c562002",
              "metodo_pago": "Transferencia",
              "monto": 180000,
              "fecha_pago": "2026-08-21T10:14:30Z"
            }
          ],
          "articulos": [
            {
              "cantidad": 1,
              "tipo": "INVENTARIADO",
              "descripcion": "Caja de Cambios Automática Toyota Hilux 2.8",
              "sku": "CAJ-TOY-HIL-28-091",
              "precio": 500000,
              "subtotal": 500000
            },
            {
              "cantidad": 1,
              "tipo": "DESARME",
              "descripcion": "Filtro y Sensor de Caja de Cambios",
              "sku": null,
              "precio": 100000,
              "subtotal": 100000
            }
          ],
          "historial_movimientos": [
            {
              "hora": "09:45",
              "evento": "Orden emitida en Mesón 2 por Andrés Morales"
            },
            {
              "hora": "10:14",
              "evento": "Pago liquidado en ventanilla (Débito + Transf.) por Lorena Valenzuela"
            },
            {
              "hora": "10:15",
              "evento": "QR Transaccional generado para barrera de salida"
            }
          ]
        },
        {
          "id_orden": "9a4c312b-74c8-5ed5-94a3-9105b053c002",
          "folio": "ORD-9773",
          "tipo_operacion": "VENTA",
          "emite_qr": true,
          "fecha_iso": "2026-08-21",
          "hora": "09:30",
          "fecha_hora_formateada": "09:30 - 21/08/2026",
          "cliente_nombre": "Pedro Aguirres Molina",
          "cliente_rut": "15.420.301-8",
          "vendedor_nombre": "Juaquin Leiva (Mesón 1)",
          "cajera_nombre": "Lorena Valenzuela (Caja 01)",
          "estado_orden": "Despachada",
          "modalidad_pago": "unico",
          "metodos_resumen": "Efectivo: $650.000",
          "total_venta": 650000,
          "abono_previo": 0,
          "total_liquidado": 650000,
          "desglose_pagos": [
            {
              "id_transaccion": "3e9c133a-4091-65e5-ba43-4a779d673003",
              "metodo_pago": "Efectivo",
              "monto": 650000,
              "fecha_pago": "2026-08-21T09:30:00Z"
            }
          ],
          "articulos": [
            {
              "cantidad": 1,
              "tipo": "INVENTARIADO",
              "descripcion": "Motor Suzuki Swift 1.2 K12M Semiequipado",
              "sku": "MOT-SUZ-SW-12-044",
              "precio": 650000,
              "subtotal": 650000
            }
          ],
          "historial_movimientos": [
            {
              "hora": "09:10",
              "evento": "Orden emitida en Mesón 1 por Juaquin Leiva"
            },
            {
              "hora": "09:30",
              "evento": "Cobro total liquidado en efectivo en Caja 01"
            },
            {
              "hora": "09:42",
              "evento": "Pieza entregada en mesón y validada en barrera de salida"
            }
          ]
        }
      ]
    }
    ```
  * **Respuestas de Error**:
    * `401 Unauthorized`: Token JWT inválido, ausente o expirado.
    * `403 Forbidden`: El usuario no tiene rol de Cajera (`id_rol == 3`) ni Administrador (`id_rol == 5`).
    * `422 Unprocessable Entity`: Formato inválido en fechas o query parameters.

### 2.3 Modelos Frontend (Dart)

**Modelos DTO (`frontend/lib/features/caja/models/historial_caja_model.dart`):**

```dart
class HistorialPagoDetalleModel {
  final String? idTransaccion;
  final String metodoPago;
  final int monto;
  final DateTime? fechaPago;

  HistorialPagoDetalleModel({
    this.idTransaccion,
    required this.metodoPago,
    required this.monto,
    this.fechaPago,
  });

  factory HistorialPagoDetalleModel.fromJson(Map<String, dynamic> json) =>
      HistorialPagoDetalleModel(
        idTransaccion: json['id_transaccion'] as String?,
        metodoPago: json['metodo_pago'] as String? ?? 'Efectivo',
        monto: json['monto'] as int? ?? 0,
        fechaPago: json['fecha_pago'] != null
            ? DateTime.tryParse(json['fecha_pago'] as String)
            : null,
      );
}

class HistorialArticuloModel {
  final int cantidad;
  final String tipo;
  final String descripcion;
  final String? sku;
  final int precio;
  final int subtotal;

  HistorialArticuloModel({
    required this.cantidad,
    required this.tipo,
    required this.descripcion,
    this.sku,
    required this.precio,
    required this.subtotal,
  });

  factory HistorialArticuloModel.fromJson(Map<String, dynamic> json) =>
      HistorialArticuloModel(
        cantidad: json['cantidad'] as int? ?? 1,
        tipo: json['tipo'] as String? ?? 'INVENTARIADO',
        descripcion: json['descripcion'] as String? ?? '',
        sku: json['sku'] as String?,
        precio: json['precio'] as int? ?? 0,
        subtotal: json['subtotal'] as int? ?? 0,
      );
}

class HistorialMovimientoModel {
  final String hora;
  final String evento;

  HistorialMovimientoModel({
    required this.hora,
    required this.evento,
  });

  factory HistorialMovimientoModel.fromJson(Map<String, dynamic> json) =>
      HistorialMovimientoModel(
        hora: json['hora'] as String? ?? '',
        evento: json['evento'] as String? ?? '',
      );
}

class ResumenCuadreCajaModel {
  final int totalRecaudado;
  final int totalOrdenesPagadas;
  final int totalEfectivo;
  final int totalPos;
  final int totalDebito;
  final int totalCredito;
  final int totalTransferencia;
  final int totalCheque;

  ResumenCuadreCajaModel({
    required this.totalRecaudado,
    required this.totalOrdenesPagadas,
    required this.totalEfectivo,
    required this.totalPos,
    required this.totalDebito,
    required this.totalCredito,
    required this.totalTransferencia,
    required this.totalCheque,
  });

  factory ResumenCuadreCajaModel.empty() => ResumenCuadreCajaModel(
        totalRecaudado: 0,
        totalOrdenesPagadas: 0,
        totalEfectivo: 0,
        totalPos: 0,
        totalDebito: 0,
        totalCredito: 0,
        totalTransferencia: 0,
        totalCheque: 0,
      );

  factory ResumenCuadreCajaModel.fromJson(Map<String, dynamic> json) =>
      ResumenCuadreCajaModel(
        totalRecaudado: json['total_recaudado'] as int? ?? 0,
        totalOrdenesPagadas: json['total_ordenes_pagadas'] as int? ?? 0,
        totalEfectivo: json['total_efectivo'] as int? ?? 0,
        totalPos: json['total_pos'] as int? ?? 0,
        totalDebito: json['total_debito'] as int? ?? 0,
        totalCredito: json['total_credito'] as int? ?? 0,
        totalTransferencia: json['total_transferencia'] as int? ?? 0,
        totalCheque: json['total_cheque'] as int? ?? 0,
      );
}

class HistorialOrdenItemModel {
  final String idOrden;
  final String folio;
  final String tipoOperacion;
  final bool emiteQr;
  final String fechaIso;
  final String hora;
  final String fechaHoraFormateada;
  final String clienteNombre;
  final String? clienteRut;
  final String vendedorNombre;
  final String cajeraNombre;
  final String estadoOrden;
  final String modalidadPago;
  final String metodosResumen;
  final int totalVenta;
  final int abonoPrevio;
  final int totalLiquidado;
  final List<HistorialPagoDetalleModel> desglosePagos;
  final List<HistorialArticuloModel> articulos;
  final List<HistorialMovimientoModel> historialMovimientos;

  HistorialOrdenItemModel({
    required this.idOrden,
    required this.folio,
    required this.tipoOperacion,
    required this.emiteQr,
    required this.fechaIso,
    required this.hora,
    required this.fechaHoraFormateada,
    required this.clienteNombre,
    this.clienteRut,
    required this.vendedorNombre,
    required this.cajeraNombre,
    required this.estadoOrden,
    required this.modalidadPago,
    required this.metodosResumen,
    required this.totalVenta,
    required this.abonoPrevio,
    required this.totalLiquidado,
    required this.desglosePagos,
    required this.articulos,
    required this.historialMovimientos,
  });

  factory HistorialOrdenItemModel.fromJson(Map<String, dynamic> json) =>
      HistorialOrdenItemModel(
        idOrden: json['id_orden'] as String,
        folio: json['folio'] as String,
        tipoOperacion: json['tipo_operacion'] as String? ?? 'VENTA',
        emiteQr: json['emite_qr'] as bool? ?? false,
        fechaIso: json['fecha_iso'] as String? ?? '',
        hora: json['hora'] as String? ?? '',
        fechaHoraFormateada: json['fecha_hora_formateada'] as String? ?? '',
        clienteNombre: json['cliente_nombre'] as String? ?? 'Cliente Mostrador',
        clienteRut: json['cliente_rut'] as String?,
        vendedorNombre: json['vendedor_nombre'] as String? ?? '',
        cajeraNombre: json['cajera_nombre'] as String? ?? 'Caja 01',
        estadoOrden: json['estado_orden'] as String? ?? 'Pagada',
        modalidadPago: json['modalidad_pago'] as String? ?? 'unico',
        metodosResumen: json['metodos_resumen'] as String? ?? '',
        totalVenta: json['total_venta'] as int? ?? 0,
        abonoPrevio: json['abono_previo'] as int? ?? 0,
        totalLiquidado: json['total_liquidado'] as int? ?? 0,
        desglosePagos: (json['desglose_pagos'] as List<dynamic>?)
                ?.map((e) =>
                    HistorialPagoDetalleModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        articulos: (json['articulos'] as List<dynamic>?)
                ?.map((e) =>
                    HistorialArticuloModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        historialMovimientos: (json['historial_movimientos'] as List<dynamic>?)
                ?.map((e) =>
                    HistorialMovimientoModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class HistorialCajaResponseModel {
  final int totalRegistros;
  final int paginaActual;
  final int limitePorPagina;
  final int totalPaginas;
  final ResumenCuadreCajaModel resumenCuadre;
  final List<HistorialOrdenItemModel> items;

  HistorialCajaResponseModel({
    required this.totalRegistros,
    required this.paginaActual,
    required this.limitePorPagina,
    required this.totalPaginas,
    required this.resumenCuadre,
    required this.items,
  });

  factory HistorialCajaResponseModel.fromJson(Map<String, dynamic> json) =>
      HistorialCajaResponseModel(
        totalRegistros: json['total_registros'] as int? ?? 0,
        paginaActual: json['pagina_actual'] as int? ?? 1,
        limitePorPagina: json['limite_por_pagina'] as int? ?? 20,
        totalPaginas: json['total_paginas'] as int? ?? 1,
        resumenCuadre: json['resumen_cuadre'] != null
            ? ResumenCuadreCajaModel.fromJson(
                json['resumen_cuadre'] as Map<String, dynamic>)
            : ResumenCuadreCajaModel.empty(),
        items: (json['items'] as List<dynamic>?)
                ?.map((e) =>
                    HistorialOrdenItemModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

### 2.4 Estado Reactivo Frontend y Controladores (Dart)

**Enums y Estado del Provider (`frontend/lib/features/caja/presentation/providers/historial_caja_provider.dart`):**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/historial_caja_model.dart';
import '../services/caja_service.dart';

enum PeriodoHistorial {
  hoy('HOY', 'Hoy'),
  estaSemana('ESTA_SEMANA', 'Esta Semana'),
  esteMes('ESTE_MES', 'Este Mes'),
  rango('RANGO', 'Rango');

  final String codigo;
  final String label;
  const PeriodoHistorial(this.codigo, this.label);
}

class HistorialCajaState {
  final bool isLoading;
  final String? errorMessage;
  final HistorialCajaResponseModel? data;
  
  // Filtros Activos
  final PeriodoHistorial periodo;
  final String? fechaDesde;
  final String? fechaHasta;
  final String estadoOrden; // 'TODOS', 'Pagada', 'Despachada', 'Anulada'
  final String metodoPago;  // 'TODOS', 'Efectivo', 'Débito', 'Crédito', 'Transferencia', 'Cheque'
  final String busqueda;
  final int? montoMin;
  final int? montoMax;
  final int paginaActual;
  
  // Auditoría Seleccionada
  final HistorialOrdenItemModel? ordenAuditoria;

  HistorialCajaState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
    this.periodo = PeriodoHistorial.hoy,
    this.fechaDesde,
    this.fechaHasta,
    this.estadoOrden = 'TODOS',
    this.metodoPago = 'TODOS',
    this.busqueda = '',
    this.montoMin,
    this.montoMax,
    this.paginaActual = 1,
    this.ordenAuditoria,
  });

  HistorialCajaState copyWith({
    bool? isLoading,
    String? errorMessage,
    HistorialCajaResponseModel? data,
    PeriodoHistorial? periodo,
    String? fechaDesde,
    String? fechaHasta,
    String? estadoOrden,
    String? metodoPago,
    String? busqueda,
    int? montoMin,
    int? montoMax,
    int? paginaActual,
    HistorialOrdenItemModel? ordenAuditoria,
    bool clearAuditoria = false,
    bool clearRango = false,
  }) {
    return HistorialCajaState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      data: data ?? this.data,
      periodo: periodo ?? this.periodo,
      fechaDesde: clearRango ? null : (fechaDesde ?? this.fechaDesde),
      fechaHasta: clearRango ? null : (fechaHasta ?? this.fechaHasta),
      estadoOrden: estadoOrden ?? this.estadoOrden,
      metodoPago: metodoPago ?? this.metodoPago,
      busqueda: busqueda ?? this.busqueda,
      montoMin: montoMin ?? this.montoMin,
      montoMax: montoMax ?? this.montoMax,
      paginaActual: paginaActual ?? this.paginaActual,
      ordenAuditoria: clearAuditoria ? null : (ordenAuditoria ?? this.ordenAuditoria),
    );
  }
}

class HistorialCajaProvider extends ChangeNotifier {
  final ICajaService _cajaService;
  final int sucursalId;

  HistorialCajaState _state = HistorialCajaState();
  HistorialCajaState get state => _state;

  Timer? _debounceTimer;

  HistorialCajaProvider({
    required ICajaService cajaService,
    required this.sucursalId,
  }) : _cajaService = cajaService {
    cargarHistorial();
  }

  Future<void> cargarHistorial({int pagina = 1}) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null, paginaActual: pagina);
    notifyListeners();

    try {
      final response = await _cajaService.obtenerHistorialCaja(
        sucursalId: sucursalId,
        periodo: _state.periodo.codigo,
        fechaDesde: _state.fechaDesde,
        fechaHasta: _state.fechaHasta,
        estadoOrden: _state.estadoOrden,
        metodoPago: _state.metodoPago,
        busqueda: _state.busqueda.isEmpty ? null : _state.busqueda,
        montoMin: _state.montoMin,
        montoMax: _state.montoMax,
        pagina: pagina,
      );

      _state = _state.copyWith(
        isLoading: false,
        data: response,
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Error al obtener historial de auditoría: $e',
      );
    } finally {
      notifyListeners();
    }
  }

  void cambiarPeriodo(PeriodoHistorial nuevoPeriodo) {
    if (_state.periodo == nuevoPeriodo && nuevoPeriodo != PeriodoHistorial.rango) return;
    _state = _state.copyWith(
      periodo: nuevoPeriodo,
      clearRango: nuevoPeriodo != PeriodoHistorial.rango,
      paginaActual: 1,
    );
    cargarHistorial();
  }

  void aplicarRangoFechas(String desde, String hasta) {
    _state = _state.copyWith(
      periodo: PeriodoHistorial.rango,
      fechaDesde: desde,
      fechaHasta: hasta,
      paginaActual: 1,
    );
    cargarHistorial();
  }

  void cambiarFiltroEstado(String nuevoEstado) {
    if (_state.estadoOrden == nuevoEstado) return;
    _state = _state.copyWith(estadoOrden: nuevoEstado, paginaActual: 1);
    cargarHistorial();
  }

  void cambiarFiltroMetodo(String nuevoMetodo) {
    if (_state.metodoPago == nuevoMetodo) return;
    _state = _state.copyWith(metodoPago: nuevoMetodo, paginaActual: 1);
    cargarHistorial();
  }

  void actualizarBusqueda(String texto) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _state = _state.copyWith(busqueda: texto.trim(), paginaActual: 1);
      cargarHistorial();
    });
  }

  void seleccionarOrdenAuditoria(HistorialOrdenItemModel? orden) {
    _state = _state.copyWith(
      ordenAuditoria: orden,
      clearAuditoria: orden == null,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

## 3. Reglas de Negocio, Casos de Borde y Seguridad

1. **Aislamiento Multi-Tenant y Control de Acceso (RBAC & Zero Trust)**:
   - Todo llamado a `GET /api/v1/caja/historial` debe exigir un token JWT válido y validar que el usuario posea `id_rol in [3, 5]` (Cajera o Administrador). Si no cumple la condición, retornar inmediatamente `HTTP 403 Forbidden`.
   - La consulta SQL debe filtrar estrictamente por `id_sucursal == sucursal_id`. Una cajera no puede visualizar ni auditar transacciones ocurridas en otra sucursal.

2. **Conversión y Normalización de Zona Horaria (`America/Santiago` $\leftrightarrow$ UTC)**:
   - Los filtros de tiempo deben interpretarse en el huso horario local de Chile (`America/Santiago`, UTC-3 o UTC-4 según horario de verano):
     * **`HOY`**: Desde las `00:00:00` hasta las `23:59:59.999999` del día calendario actual en Chile, convertidos a UTC antes de ejecutar la cláusula `WHERE fecha_emision BETWEEN ...`.
     * **`ESTA_SEMANA`**: Desde el lunes a las `00:00:00` de la semana en curso hasta el domingo a las `23:59:59.999999`.
     * **`ESTE_MES`**: Desde el primer día del mes actual a las `00:00:00` hasta el último día del mes a las `23:59:59.999999`.
     * **`RANGO`**: Conversión del rango `[fecha_desde 00:00:00, fecha_hasta 23:59:59]`. Si `fecha_desde > fecha_hasta`, backend debe rechazar la solicitud con `HTTP 422 Unprocessable Entity`.

3. **Consistencia Matemática del Arqueo y Cuadre de Caja**:
   - El objeto `resumen_cuadre` debe calcularse sobre el **universo completo de registros filtrados** en la base de datos (independiente de la página actual o del límite de paginación).
   - **Tratamiento de Órdenes Anuladas**: Las órdenes con `estado_orden == 'Anulada'` deben listarse en la tabla histórica con su badge rojo correspondiente para trazabilidad de auditoría, pero se **excluyen** estrictamente de las sumatorias de dinero (`total_recaudado`, `total_efectivo`, `total_pos`, `total_transferencia`, `total_cheque` y `total_ordenes_pagadas`).
   - **Reglas de Sumatoria**:
     * $\text{Total POS} = \text{Total Débito} + \text{Total Crédito}$
     * $\text{Total Recaudado} = \text{Total Efectivo} + \text{Total Débito} + \text{Total Crédito} + \text{Total Transferencia} + \text{Total Cheque}$

4. **Optimización de Consultas SQL y Prevención de Problema N+1**:
   - La consulta ORM en SQLAlchemy debe utilizar `joinedload` o `selectinload` sobre las relaciones `Orden_Venta.pagos` (`Transaccion_Pago`), `Orden_Venta.detalles` (`Detalle_Orden`), `Orden_Venta.cliente` y `Orden_Venta.vendedor` / `cajera`.
   - Queda prohibido emitir subconsultas lazy-loading por cada fila en el bucle de serialización.

5. **Búsqueda Reactiva Multicriterio y Debounce**:
   - La búsqueda de texto debe ser insensible a mayúsculas/minúsculas (`ILIKE` en PostgreSQL) y aplicarse de forma disyuntiva (`OR`) sobre:
     * Folio de orden (`ORD-XXXX`, `RES-XXXX`).
     * Nombre y apellido del cliente.
     * RUT del cliente (soportando búsqueda con y sin puntos/guión, ej: `148924012` o `14.892.401-2`).
     * Nombre del vendedor o de la cajera responsable.
   - En frontend, la caja de texto debe aplicar **Debounce de 300 ms** antes de disparar la consulta al provider.

6. **Manejo de Ciclo de Vida y Estado Vacío en Flutter**:
   - En toda operación asíncrona dentro de diálogos y pantallas (`DetalleAuditoriaDialog`, `FiltroRangoFechasDialog`, `HistorialCajaScreen`), es obligatorio verificar `if (!mounted) return;` antes de manipular el árbol de widgets o invocar `Navigator.pop(context)`.
   - **Zero State**: Si la consulta no arroja registros tras aplicar filtros, la vista debe renderizar un contenedor con icono `inbox`, texto descriptivo *"No hay registros con los filtros seleccionados"* y botón para restablecer filtros a predeterminados (`Periodo: HOY`, `Estado: TODOS`, `Método: TODOS`).

## 4. Checklist de Tareas de Implementation (TDD)

- [x] **Tarea 1 (Backend - Schemas Pydantic V2 en `backend/schemas.py`)**:
  - Declarar `HistorialPagoDetalleDTO`, `HistorialArticuloDTO`, `HistorialMovimientoDTO` y `ResumenCuadreCajaDTO` utilizando `ConfigDict(from_attributes=True)`.
  - Declarar `HistorialOrdenItemResponse` y `HistorialCajaResponse` con validaciones de tipos estrictas y campos descriptivos.
- [x] **Tarea 2 (Backend - Endpoint `GET /api/v1/caja/historial` en `backend/routers/caja.py`)**:
  - Implementar la función de conversión de zona horaria local (`America/Santiago` a UTC) para preajustes (`HOY`, `ESTA_SEMANA`, `ESTE_MES`) y rango manual (`fecha_desde`, `fecha_hasta`).
  - Construir la consulta principal optimizada con `joinedload(Orden_Venta.pagos)`, `joinedload(Orden_Venta.detalles)`, `joinedload(Orden_Venta.cliente)` y `joinedload(Orden_Venta.usuario)`.
  - Implementar filtros dinámicos por `id_sucursal`, `estado_orden`, `metodo_pago`, `busqueda` (ILIKE sobre Folio, RUT, Cliente, Vendedor), `monto_min`, `monto_max`, `id_cajera` e `id_vendedor`.
  - Calcular agregaciones de `resumen_cuadre` sobre el conjunto filtrado (excluyendo órdenes en estado `Anulada`) y aplicar paginación (`limit`, `offset`) sobre los ítems.
  - Proteger con dependencia `require_caja_role` (`id_rol in [3, 5]`).
- [x] **Tarea 3 (Backend - Pruebas Pytest en `backend/tests/test_caja_historial.py`)**:
  - Test 1: Filtrado correcto de órdenes por sucursal activa y período `HOY` en zona horaria de Chile.
  - Test 2: Validación matemática de `resumen_cuadre` (suma exacta de Efectivo, POS, Transferencias y exclusión estricta de órdenes `Anulada`).
  - Test 3: Búsqueda reactiva parcial (RUT con/sin formato, Folio `ORD-`, nombre de cliente y vendedor).
  - Test 4: Filtrado por método de pago específico (solo órdenes que incluyan transacciones con dicho método).
  - Test 5: Paginación consistente y cálculo exacto de `total_registros` y `total_paginas`.
  - Test 6: Control de acceso RBAC devolviendo `HTTP 403 Forbidden` a usuarios no autorizados (`id_rol == 1` o `id_rol == 2`).
- [x] **Tarea 4 (Frontend - DTOs y Servicio `caja_service.dart`)**:
  - Crear `frontend/lib/features/caja/models/historial_caja_model.dart` con mapeo seguro `fromJson`.
  - Implementar el método `obtenerHistorialCaja(...)` en `frontend/lib/features/caja/services/caja_service.dart` serializando query parameters y gestionando headers JWT y excepciones HTTP.
- [x] **Tarea 5 (Frontend - Proveedor Reactivo `historial_caja_provider.dart`)**:
  - Crear `frontend/lib/features/caja/presentation/providers/historial_caja_provider.dart` con gestión de estados (`isLoading`, `errorMessage`, `data`), debounce de 300 ms en búsqueda, cambio de períodos y selección de orden para auditoría.
- [x] **Tarea 6 (Frontend - Widgets de Métricas y Diálogos Modales)**:
  - Crear `frontend/lib/features/caja/presentation/widgets/historial_metricas_panel.dart` con las 4 tarjetas de arqueo (Total Recaudado, Efectivo en Gaveta, Total POS y Transferencias/Cheques) consumiendo `AppPalette` y `AppTypography`.
  - Crear `frontend/lib/features/caja/presentation/widgets/filtro_rango_fechas_dialog.dart` con selectores de fecha y atajos rápidos (*Ayer*, *Semana Anterior*, *Mes Anterior*).
  - Crear `frontend/lib/features/caja/presentation/widgets/detalle_auditoria_dialog.dart` con ficha de cliente, responsables, desglose de ítems, pagos exactos y línea de tiempo de auditoría.
- [x] **Tarea 7 (Frontend - Pantalla `HistorialCajaScreen` y Tabla de Auditoría)**:
  - Crear `frontend/lib/features/caja/presentation/widgets/historial_tabla_view.dart` con badges de estado, formatos monetarios en CLP y botón "Ver Detalle".
  - Crear `frontend/lib/features/caja/presentation/screens/historial_caja_screen.dart` integrando cabecera de períodos, barra de filtros avanzados, panel de métricas, tabla y estado vacío (*Zero State*).
  - Conectar la pantalla en el sidebar de navegación (`caja_main_screen.dart`) bajo la opción *Historial*.
- [x] **Tarea 8 (Frontend - Pruebas Unitarias y de Widgets en `historial_caja_test.dart`)**:
  - Crear `frontend/test/features/caja/historial_caja_test.dart` verificando:
    1. Renderizado y sumatoria correcta en las 4 tarjetas del banner de cuadre.
    2. Cambio reactivo de filtros de período (*Hoy*, *Esta Semana*, *Este Mes*).
    3. Apertura del diálogo `DetalleAuditoriaDialog` al pulsar "Ver Detalle" en una fila.
    4. Renderizado del estado vacío cuando no existen coincidencias.

## 5. Criterios de Validación Automatizada

El agente autónomo solo considerará completada la especificación cuando los siguientes comandos se ejecuten sin errores:

1. **Backend Tests**:
   ```bash
   cd backend && pytest tests/test_caja_historial.py -v

Backend Linting (Zero Fatal Errors):

Bash
flake8 backend/routers/caja.py backend/schemas.py --count --select=E9,F63,F7,F82
Frontend Tests:

Bash
cd frontend && flutter test test/features/caja/historial_caja_test.dart
Frontend Analyzer:

Bash
flutter analyze lib/features/caja/