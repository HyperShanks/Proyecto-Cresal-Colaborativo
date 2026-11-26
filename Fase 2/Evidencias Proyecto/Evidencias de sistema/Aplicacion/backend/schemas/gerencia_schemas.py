# backend/schemas/gerencia_schemas.py
"""
Esquemas Pydantic V2 para el módulo de Gerencia y Dashboard Ejecutivo (HU-5.1).
Defino los DTOs analíticos para métricas, pagos y flujo operativo.
"""

from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel, ConfigDict, Field


class KpiFinancieroDTO(BaseModel):
    """
    DTO para las 4 métricas financieras superiores del Dashboard Ejecutivo.
    Diseñé este esquema para transferir la facturación diaria, transacciones,
    acumulado mensual MTD y ticket promedio calculado.
    """
    ventas_del_dia: int = Field(
        description="Suma total de pagos liquidados hoy en CLP"
    )
    transacciones_hoy: int = Field(
        description="Cantidad de órdenes pagadas durante el día de hoy"
    )
    acumulado_mensual_mtd: int = Field(
        description="Suma acumulada de facturación del mes actual"
    )
    ticket_promedio: float = Field(
        description="Monto promedio recaudado por transacción de venta"
    )
    margen_bruto: Optional[float] = Field(
        default=64.8,
        description="Porcentaje estimado de margen bruto"
    )
    salidas_motores_hoy: int = Field(
        default=0,
        description="Cantidad de motores inventariados (MOT-XXXX) salidos/vendidos hoy"
    )
    salidas_cajas_hoy: int = Field(
        default=0,
        description="Cantidad de cajas de cambio inventariadas (CAJ-XXXX) salidas/vendidas hoy"
    )
    total_salidas_hoy: int = Field(
        default=0,
        description="Total de piezas inventariadas (MOT y CAJ) salidas/vendidas hoy"
    )

    model_config = ConfigDict(from_attributes=True)


class DesglosePagoDTO(BaseModel):
    """
    DTO que representa la recaudación individual por cada método de pago.
    Lo programé para alimentar la leyenda y segmentos del gráfico de dona,
    permitiendo alternar entre métrica monetaria ($) y volumen de transacciones (#).
    """
    metodo_pago: str = Field(
        description="Método: Efectivo, Débito, Crédito, etc."
    )
    monto_total: int = Field(
        description="Monto total recaudado en CLP por este método"
    )
    porcentaje: float = Field(
        description="Porcentaje respecto al total monetario recaudado hoy"
    )
    cantidad: int = Field(
        default=1,
        description="Cantidad de pagos procesados por este método"
    )
    porcentaje_cantidad: float = Field(
        default=0.0,
        description="Porcentaje respecto al total de transacciones de pago de hoy"
    )

    model_config = ConfigDict(from_attributes=True)


class ResumenPagosDTO(BaseModel):
    """
    DTO consolidado para el gráfico y desglose de recaudación.
    Permite contrastar arqueo físico frente a canales electrónicos y total transacciones.
    """
    efectivo_fisico: int = Field(
        description="Total recaudado en efectivo físico en caja"
    )
    canales_electronicos: int = Field(
        description="Total en canales electrónicos (Tarjetas, Transferencias)"
    )
    total_transacciones: int = Field(
        default=0,
        description="Total de pagos individuales registrados hoy"
    )
    desglose: List[DesglosePagoDTO] = Field(
        default_factory=list,
        description="Lista detallada por medio de pago"
    )

    model_config = ConfigDict(from_attributes=True)


class FlujoOperativoDTO(BaseModel):
    """
    DTO con el pulso operativo de bodega y alertas ejecutivas.
    Programé estos contadores para el Bento de logística y riesgo.
    """
    en_preparacion: int = Field(
        description="Ítems en proceso de bajada de rack o preparación física"
    )
    listos_mostrador: int = Field(
        description="Piezas preparadas esperando retiro de cliente en mesón"
    )
    enviados_courier: int = Field(
        description="Órdenes despachadas en tránsito con courier"
    )
    alertas_saldo_pendiente: int = Field(
        description="Órdenes con saldo retenido o pendiente de pago"
    )
    cuellos_botella_paletizados: int = Field(
        description="Repuestos paletizados sin precio comercial asignado"
    )

    model_config = ConfigDict(from_attributes=True)


# ==========================================
# DTOs PARA SUPERVISIÓN DE BACKORDERS (HU-5.4)
# ==========================================

class BackorderGerenciaItemDTO(BaseModel):
    """
    DTO que representa una reserva de compra por encargo (Backorder / compra en verde)
    para el visor maestro de supervisión de gerencia (HU-5.4).
    """
    id_reserva: str = Field(description="UUID de la reserva")
    folio: str = Field(description="Folio amigable (ej. RES-5401)")
    fecha_creacion: str = Field(description="Fecha formateada o relativa")
    fecha_creacion_iso: str = Field(description="Fecha ISO completa en UTC")
    id_cliente: str = Field(description="UUID del cliente")
    cliente_nombre: str = Field(description="Nombre completo del cliente CRM")
    cliente_telefono: Optional[str] = Field(default=None, description="Teléfono del cliente")
    cliente_rut: Optional[str] = Field(default=None, description="RUT del cliente")
    id_vendedor: str = Field(description="UUID del vendedor")
    vendedor_nombre: str = Field(description="Nombre del vendedor")
    id_sucursal: int = Field(description="ID de la sucursal de registro")
    sucursal_nombre: str = Field(description="Nombre de la sucursal")
    id_categoria_requerida: int = Field(description="ID de la categoría requerida")
    categoria_nombre: str = Field(description="Nombre de la categoría requerida (Motor, Caja, etc.)")
    marca_requerida: str = Field(description="Marca solicitada")
    modelo_requerido: str = Field(description="Modelo solicitado")
    anio_requerido: Optional[int] = Field(default=None, description="Año solicitado")
    cilindrada_requerida: Optional[str] = Field(default=None, description="Cilindrada")
    combustible_requerido: Optional[str] = Field(default=None, description="Combustible")
    transmision_requerida: Optional[str] = Field(default=None, description="Transmisión")
    notas_preparacion: Optional[str] = Field(default=None, description="Notas técnicas o de tránsito")
    precio_acordado: int = Field(description="Precio comercial pactado con el cliente en CLP")
    descuento: int = Field(default=0, description="Descuento comercial aplicado a la orden en CLP")
    monto_abonado: int = Field(description="Seña recaudada en caja en CLP")
    saldo_pendiente: int = Field(description="Saldo por pagar")
    estado_reserva: str = Field(description="Pendiente, Confirmada, Completada, Anulada")
    id_activo_asignado: Optional[str] = Field(default=None, description="UUID del repuesto donante asignado")
    activo_asignado_sku: Optional[str] = Field(default=None, description="SKU QR físico del repuesto asignado")
    id_orden: Optional[str] = Field(default=None, description="UUID de la orden de venta final generada")
    orden_folio: Optional[str] = Field(default=None, description="Folio comercial de la orden vinculada (ej. ORD-0436)")
    estado_orden: Optional[str] = Field(default=None, description="Estado operativo de la orden vinculada (Reservada, Pagada, Anulada, Completada)")

    model_config = ConfigDict(from_attributes=True)


class BackorderGerenciaListResponse(BaseModel):
    """Respuesta paginada del visor maestro de backorders."""
    items: List[BackorderGerenciaItemDTO] = Field(default_factory=list)
    total_count: int = Field(description="Total de encargos registrados que coinciden con filtros")
    total_recaudado_senas: int = Field(description="Total de dinero recaudado en señas de los encargos filtrados")

    model_config = ConfigDict(from_attributes=True)


class BackorderGerenciaKpisDTO(BaseModel):
    """Cabecera de 3 tarjetas de resumen ejecutivo de backorders."""
    total_activos: int = Field(description="Total backorders activos en estado Pendiente o Confirmada")
    capital_retenido: int = Field(description="Suma total de montos abonados como seña en reservas activas")
    listos_para_liquidar: int = Field(description="Backorders activos que ya cuentan con un repuesto físico asignado (match)")
    total_registrados: int = Field(default=0, description="Total histórico de encargos")
    total_recaudado_senas: int = Field(default=0, description="Total histórico de señas recaudadas")

    model_config = ConfigDict(from_attributes=True)


class SucursalGerenciaDTO(BaseModel):
    """DTO para listado de sucursales activas en módulo de Gerencia."""
    id_sucursal: int = Field(description="ID único de la sucursal en base de datos")
    nombre_sucursal: str = Field(description="Nombre oficial de la sucursal")
    es_casa_matriz: bool = Field(default=False, description="Indica si corresponde a la Casa Matriz de Cresal")

    model_config = ConfigDict(from_attributes=True)


# ==========================================
# DTOs PARA AUDITORÍA Y PERITAJE DE BACKORDERS
# ==========================================

class BackorderMovimientoDTO(BaseModel):
    """Hito cronológico con marca temporal y descripción de auditoría forense."""
    hora: str = Field(description="Fecha y hora del evento (ej: '27/10/26 15:30 hrs')")
    evento: str = Field(description="Descripción del hito con responsable y detalles")

    model_config = ConfigDict(from_attributes=True)


class BackorderPagoDetalleDTO(BaseModel):
    """Detalle individual de abono o pago registrado."""
    id_transaccion: Optional[str] = Field(default=None, description="UUID de la transacción de pago")
    metodo_pago: str = Field(description="Método de pago: Efectivo, Débito, Crédito, etc.")
    monto: int = Field(description="Monto liquidado o abonado en CLP")
    fecha_pago: Optional[str] = Field(default=None, description="Fecha formateada del pago")
    cajero_nombre: Optional[str] = Field(default=None, description="Nombre de la cajera o cajero receptor")

    model_config = ConfigDict(from_attributes=True)


class BackorderAuditoriaResponseDTO(BaseModel):
    """
    DTO exhaustivo para el peritaje y auditoría 360° de una Venta en Verde (Backorder).
    Estructurado en 3 secciones requeridas:
    1. Cabecera y Resumen de la Operación (Folios, estado, ficha técnica repuesto, balance financiero).
    2. Ficha de Identificación del Cliente (Nombre, RUT, Teléfono, Correo).
    3. Línea de Tiempo y Trazabilidad Cronológica (Timeline secuencial de hitos con responsable).
    """
    id_reserva: str = Field(description="UUID de la reserva")
    folio: str = Field(description="Folio amigable de la reserva (ej. RES-5401)")
    fecha_creacion: str = Field(description="Fecha amigable o relativa de creación")
    fecha_creacion_iso: str = Field(description="Estampa temporal ISO UTC")
    estado_reserva: str = Field(description="Estado operativo actual unificado")

    # Folio y Orden vinculada
    id_orden: Optional[str] = Field(default=None, description="UUID de la orden vinculada")
    orden_folio: Optional[str] = Field(default=None, description="Folio comercial ORD-XXXX")
    estado_orden: Optional[str] = Field(default=None, description="Estado de la orden vinculada")

    # Ficha del Cliente
    id_cliente: str = Field(description="UUID del cliente")
    cliente_nombre: str = Field(description="Nombre completo o Razón Social del cliente")
    cliente_rut: Optional[str] = Field(default=None, description="RUT o Cédula de Identidad")
    cliente_telefono: Optional[str] = Field(default=None, description="Teléfono de contacto")
    cliente_correo: Optional[str] = Field(default=None, description="Correo electrónico del cliente")

    # Responsables
    id_vendedor: str = Field(description="UUID del vendedor")
    vendedor_nombre: str = Field(description="Nombre del vendedor emisor")
    id_sucursal: int = Field(description="ID de la sucursal de registro")
    sucursal_nombre: str = Field(description="Nombre de la sucursal emisora")

    # Ficha Técnica Requerida
    id_categoria_requerida: int = Field(description="ID de categoría requerida")
    categoria_nombre: str = Field(description="Nombre de la categoría (Motor, Caja de Cambios)")
    marca_requerida: str = Field(description="Marca del repuesto")
    modelo_requerido: str = Field(description="Modelo del vehículo")
    anio_requerido: Optional[int] = Field(default=None, description="Año del vehículo")
    cilindrada_requerida: Optional[str] = Field(default=None, description="Cilindrada")
    combustible_requerido: Optional[str] = Field(default=None, description="Tipo de combustible")
    transmision_requerida: Optional[str] = Field(default=None, description="Tipo de transmisión")
    notas_preparacion: Optional[str] = Field(default=None, description="Notas técnicas o de mesón")

    # Desglose Financiero
    precio_acordado: int = Field(description="Precio comercial pactado con el cliente")
    descuento: int = Field(default=0, description="Descuento comercial aplicado")
    monto_abonado: int = Field(description="Monto acumulado recaudado en abonos y señas")
    saldo_pendiente: int = Field(description="Saldo restante por pagar")

    # Asignación de Pieza Física / Vehículo Donante
    id_activo_asignado: Optional[str] = Field(default=None, description="UUID del activo asignado")
    activo_asignado_sku: Optional[str] = Field(default=None, description="SKU QR físico del repuesto")
    vehiculo_donante_ingreso: Optional[str] = Field(default=None, description="N° de Ingreso del vehículo donante")
    vehiculo_donante_patente: Optional[str] = Field(default=None, description="Patente del vehículo donante")
    vehiculo_donante_descripcion: Optional[str] = Field(default=None, description="Marca, modelo y año del donante")

    # Desglose de pagos y línea de tiempo
    desglose_pagos: List[BackorderPagoDetalleDTO] = Field(default_factory=list, description="Lista de pagos y abonos")
    movimientos: List[BackorderMovimientoDTO] = Field(default_factory=list, description="Línea de tiempo cronológica de hitos")

    model_config = ConfigDict(from_attributes=True)


# ==========================================
# DTOs PARA PREDICCIÓN ML DE VENTAS Y STOCK (CRES-281)
# ==========================================

class MetadataModeloDTO(BaseModel):
    """Metadatos técnicos de rendimiento y latencia de inferencia del modelo XGBoost."""
    algoritmo: str = Field(description="Algoritmo productivo utilizado para la inferencia")
    exactitud_wape_pct: float = Field(description="Exactitud global (100 - WAPE) en validación histórica")
    wape_promedio_pct: float = Field(description="Error porcentual absoluto ponderado (WAPE) promedio")
    r2_promedio: float = Field(description="Coeficiente de determinación R2 promedio")
    id_sucursal_filtro: Optional[int] = Field(default=None, description="ID de sucursal filtrada o None para consolidado")
    semana_proyectada_inicio: str = Field(description="Fecha de inicio (lunes) de la próxima semana proyectada (ISO YYYY-MM-DD)")
    tiempo_inferencia_ms: float = Field(description="Latencia total de consulta y predicción en milisegundos")

    model_config = ConfigDict(from_attributes=True)


class ProyeccionSemanalItemDTO(BaseModel):
    """Proyección multi-target de demanda y montos CLP para una semana futura."""
    semana_inicio: str = Field(description="Fecha de inicio (lunes) de la semana proyectada")
    dias_habiles: int = Field(description="Días hábiles considerados en el ajuste calendario")
    unidades_motor: float = Field(description="Unidades proyectadas de motores (id_categoria = 1)")
    monto_motor_clp: int = Field(description="Ingreso proyectado de motores en CLP")
    unidades_caja: float = Field(description="Unidades proyectadas de cajas de cambio (id_categoria = 2)")
    monto_caja_clp: int = Field(description="Ingreso proyectado de cajas de cambio en CLP")
    unidades_accesorio: float = Field(description="Unidades proyectadas de accesorios/manuales (id_categoria = 3)")
    monto_accesorio_clp: int = Field(description="Ingreso proyectado de accesorios/manuales en CLP")

    model_config = ConfigDict(from_attributes=True)


class PrediccionSemanalT1DTO(ProyeccionSemanalItemDTO):
    """Predicción inmediata para la próxima semana (t+1) con totales y clasificación de régimen."""
    venta_total_proyectada_clp: int = Field(description="Suma total proyectada de ventas en CLP para t+1")
    regimen_motor: str = Field(description="Régimen de demanda esperado para motores: Baja, Normal o Alta")
    regimen_caja: str = Field(description="Régimen de demanda esperado para cajas: Baja, Normal o Alta")
    regimen_accesorio: str = Field(description="Régimen de demanda esperado para accesorios: Baja, Normal o Alta")

    model_config = ConfigDict(from_attributes=True)


class ProyeccionMensual4SemanasDTO(BaseModel):
    """Proyección acumulada recursiva a 4 semanas (~1 mes operativo) con desglose semanal."""
    unidades_motor: float = Field(description="Total unidades de motores proyectadas en 4 semanas")
    monto_motor_clp: int = Field(description="Monto acumulado proyectado de motores en CLP (4 semanas)")
    unidades_caja: float = Field(description="Total unidades de cajas proyectadas en 4 semanas")
    monto_caja_clp: int = Field(description="Monto acumulado proyectado de cajas en CLP (4 semanas)")
    unidades_accesorio: float = Field(description="Total unidades de accesorios proyectadas en 4 semanas")
    monto_accesorio_clp: int = Field(description="Monto acumulado proyectado de accesorios en CLP (4 semanas)")
    venta_total_proyectada_clp: int = Field(description="Ingreso total proyectado a 4 semanas en CLP")
    desglose_semanal: List[ProyeccionSemanalItemDTO] = Field(
        default_factory=list,
        description="Desglose semana a semana (t+1 a t+4)",
    )

    model_config = ConfigDict(from_attributes=True)


class MixPorcentualVentasDTO(BaseModel):
    """Participación porcentual estimada de cada categoría sobre la venta proyectada de t+1."""
    motor_pct: float = Field(description="Porcentaje de participación de Motores en CLP")
    caja_pct: float = Field(description="Porcentaje de participación de Cajas de Cambios en CLP")
    accesorio_pct: float = Field(description="Porcentaje de participación de Accesorios/Manuales en CLP")

    model_config = ConfigDict(from_attributes=True)


class CoberturaStockCriticoItemDTO(BaseModel):
    """Análisis de cobertura entre inventario físico real, backorders pendientes y demanda predicha."""
    id_categoria: int = Field(description="ID de categoría crítica (1=Motor, 2=Caja de Cambios)")
    categoria: str = Field(description="Nombre de la categoría")
    stock_disponible_tasado: int = Field(description="Unidades en estado Disponible con tasación fijada")
    stock_paletizado_sin_tasar: int = Field(description="Unidades en estado Paletizado en rack pendientes de tasación")
    stock_en_desarme: int = Field(default=0, description="Unidades en estado En Desarme en patio")
    stock_en_proceso_interno: int = Field(default=0, description="Suma de Paletizado + En Desarme en preparación interna")
    stock_total_disponible: int = Field(description="Total físico disponible + paletizado para venta")
    stock_vina_del_mar: int = Field(description="Stock disponible en Casa Matriz Viña del Mar")
    stock_limache: int = Field(description="Stock disponible en Sucursal Limache")
    stock_disponible_vina: int = Field(default=0, description="Stock en estado Disponible en Viña del Mar")
    stock_disponible_limache: int = Field(default=0, description="Stock en estado Disponible en Limache")
    stock_proceso_vina: int = Field(default=0, description="Stock Paletizado + En Desarme en Viña del Mar")
    stock_proceso_limache: int = Field(default=0, description="Stock Paletizado + En Desarme en Limache")
    paletizado_vina: int = Field(default=0, description="Stock Paletizado en Viña del Mar")
    paletizado_limache: int = Field(default=0, description="Stock Paletizado en Limache")
    desarme_vina: int = Field(default=0, description="Stock En Desarme en Viña del Mar")
    desarme_limache: int = Field(default=0, description="Stock En Desarme en Limache")
    backorders_pendientes: int = Field(description="Backorders activos sin activo físico asignado aún")
    demanda_predicha_semanal: float = Field(description="Demanda semanal predicha (t+1) en unidades")
    demanda_predicha_mensual_4sem: float = Field(description="Demanda acumulada predicha en 4 semanas en unidades")
    requerimiento_total: int = Field(default=0, description="Requerimiento semanal: ceil(demanda_semanal) + backorders_pendientes")
    balance_unidades: int = Field(description="Balance neto en vitrina: stock_disponible_tasado - requerimiento_total")
    deficit_neto_compra: int = Field(default=0, description="Unidades adicionales requeridas en remates tras considerar stock interno en proceso")
    semanas_cobertura: float = Field(description="Semanas de inventario en vitrina estimadas al ritmo de demanda t+1")
    estado_alerta: str = Field(description="Semáforo CRES-284: Cobertura Óptima, Atención / En Proceso o Déficit Crítico")
    recomendacion_accionable: str = Field(default="", description="Recomendación prescriptiva accionable para horizonte semanal (t+1)")
    requerimiento_total_mensual_4sem: int = Field(default=0, description="Requerimiento acumulado 4 semanas: ceil(demanda_4sem) + backorders_pendientes")
    balance_unidades_mensual_4sem: int = Field(default=0, description="Balance neto en vitrina para horizonte de 4 semanas")
    deficit_neto_compra_mensual_4sem: int = Field(default=0, description="Déficit neto a adquirir en horizonte de 4 semanas")
    estado_alerta_mensual_4sem: str = Field(default="Cobertura Óptima", description="Semáforo prescriptivo para horizonte mensual (4 semanas)")
    recomendacion_accionable_mensual_4sem: str = Field(default="", description="Recomendación prescriptiva accionable para horizonte de 4 semanas")
    precio_referencia_promedio: int = Field(
        default=0,
        description="Precio de referencia promedio actual en bodega (CLP) para activos Disponibles o Paletizados con tasación > 0",
    )
    precio_referencia_min: int = Field(
        default=0,
        description="Precio de referencia mínimo actual en bodega (CLP)",
    )
    precio_referencia_max: int = Field(
        default=0,
        description="Precio de referencia máximo actual en bodega (CLP)",
    )

    model_config = ConfigDict(from_attributes=True)


class HistorialSemanalItemDTO(BaseModel):
    """Punto semanal histórico (ventana de 8 semanas con Cold-Start padding si aplica)."""
    semana_inicio: str = Field(description="Fecha de inicio (lunes) de la semana histórica")
    unidades_motor: float = Field(description="Unidades vendidas de motores")
    monto_motor_clp: int = Field(description="Monto vendido en CLP de motores")
    unidades_caja: float = Field(description="Unidades vendidas de cajas de cambio")
    monto_caja_clp: int = Field(description="Monto vendido en CLP de cajas de cambio")
    unidades_accesorio: float = Field(description="Unidades vendidas de accesorios/manuales")
    monto_accesorio_clp: int = Field(description="Monto vendido en CLP de accesorios/manuales")
    venta_total_clp: int = Field(description="Venta total semanal en CLP")

    model_config = ConfigDict(from_attributes=True)


class DesgloseDemandaCategoriaItemDTO(BaseModel):
    """Desglose de demanda física de las últimas 4 semanas cerradas por categoría (Stock Físico vs. Backorders)."""
    id_categoria: int = Field(description="ID de categoría (1=Motor, 2=Caja de Cambios, 3=Accesorio / Manual)")
    categoria: str = Field(description="Nombre legible de la categoría")
    unidades_stock_fisico: int = Field(
        default=0,
        description="Unidades vendidas desde stock físico en los últimos 28 días (nro_pago=1)",
    )
    unidades_backorder: int = Field(
        default=0,
        description="Unidades originadas en Reservas_Backorder / compras en verde en los últimos 28 días",
    )
    unidades_totales_mes: int = Field(
        default=0,
        description="Suma total de demanda física del último mes (stock físico + backorders)",
    )

    model_config = ConfigDict(from_attributes=True)


class PrediccionVentasStockResponseDTO(BaseModel):
    """Respuesta consolidada del endpoint predictivo de Gerencia (CRES-281 / CRES-283)."""
    metadata_modelo: MetadataModeloDTO
    prediccion_semanal_t1: PrediccionSemanalT1DTO
    proyeccion_mensual_4_semanas: ProyeccionMensual4SemanasDTO
    mix_porcentual_ventas: MixPorcentualVentasDTO
    cobertura_stock_critico: List[CoberturaStockCriticoItemDTO] = Field(default_factory=list)
    historial_reciente_8_semanas: List[HistorialSemanalItemDTO] = Field(default_factory=list)
    desglose_demanda_ultimo_mes: List[DesgloseDemandaCategoriaItemDTO] = Field(
        default_factory=list,
        description="Desglose de demanda física de los últimos 28 días: Stock Físico vs. Reservas_Backorder",
    )

    model_config = ConfigDict(from_attributes=True)


PrediccionGerenciaResponseDTO = PrediccionVentasStockResponseDTO


# ==========================================
# GESTIÓN ADMINISTRATIVA DE ÓRDENES (HU-TAREA-25)
# ==========================================

class EditarOrdenGerenciaRequest(BaseModel):
    """Payload para edición administrativa integral de órdenes desde Gerencia."""
    nuevo_estado: Optional[str] = Field(
        None,
        description="Estado destino: Reservada, Pagada, Despachada, Completada, Anulada",
    )
    liquidar_saldo_pendiente: bool = Field(
        True,
        description="Si es True y el estado destino es Pagada/Despachada/Completada, registra automáticamente el pago del saldo pendiente",
    )
    metodo_pago_liquidacion: Optional[str] = Field(
        "Efectivo",
        description="Método de pago para el saldo auto-liquidado: Efectivo, Débito/Debito, Crédito/Credito, Transferencia, Cheque",
    )
    id_nuevo_vendedor: Optional[UUID] = Field(
        None,
        description="UUID del nuevo vendedor titular si se desea reasignar",
    )
    motivo: Optional[str] = Field(
        None,
        description="Motivo u observación administrativa del cambio o anulación",
    )


class EditarOrdenGerenciaResponse(BaseModel):
    """Respuesta tras editar administrativamente una orden desde Gerencia."""
    id_orden: UUID
    folio: str
    estado_anterior: str
    estado_nuevo: str
    monto_auto_liquidado: int = 0
    metodo_pago_aplicado: Optional[str] = None
    monto_pendiente_actual: int = 0
    vendedor_reasignado: bool = False
    activos_actualizados: int = 0
    mensaje: str

    model_config = ConfigDict(from_attributes=True)


class EliminarOrdenGerenciaResponse(BaseModel):
    """Respuesta tras eliminar físicamente una orden del historial desde Gerencia."""
    id_orden: UUID
    folio: str
    activos_restaurados: int = 0
    pagos_eliminados: int = 0
    mensaje: str

    model_config = ConfigDict(from_attributes=True)



