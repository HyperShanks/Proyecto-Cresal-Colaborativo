# backend/schemas/gerencia_schemas.py
"""
Esquemas Pydantic V2 para el módulo de Gerencia y Dashboard Ejecutivo (HU-5.1).
Defino los DTOs analíticos para métricas, pagos y flujo operativo.
"""

from typing import List, Optional
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

    model_config = ConfigDict(from_attributes=True)


class DesglosePagoDTO(BaseModel):
    """
    DTO que representa la recaudación individual por cada método de pago.
    Lo programé para alimentar la leyenda y segmentos del gráfico de dona.
    """
    metodo_pago: str = Field(
        description="Método: Efectivo, Débito, Crédito, etc."
    )
    monto_total: int = Field(
        description="Monto total recaudado en CLP por este método"
    )
    porcentaje: float = Field(
        description="Porcentaje respecto al total recaudado hoy"
    )

    model_config = ConfigDict(from_attributes=True)


class ResumenPagosDTO(BaseModel):
    """
    DTO consolidado para el gráfico y desglose de recaudación.
    Permite contrastar arqueo físico frente a canales electrónicos.
    """
    efectivo_fisico: int = Field(
        description="Total recaudado en efectivo físico en caja"
    )
    canales_electronicos: int = Field(
        description="Total en canales electrónicos (Tarjetas, Transferencias)"
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
