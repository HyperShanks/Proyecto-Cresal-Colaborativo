import os
import re
import json
import time
import struct
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, List, Set
from zoneinfo import ZoneInfo

import joblib
import numpy as np
import pandas as pd
import xgboost.core as _xgb_core
from sqlalchemy import text, func
from sqlalchemy.orm import Session

from models import (
    Activo_Inventariado,
    Detalle_Orden,
    Estado_Activo,
    Orden_Venta,
    Reservas_Backorder,
    Transaccion_Pago,
    Usuario,
)

logger = logging.getLogger("cresal.ml_prediction")

TZ_CHILE = ZoneInfo("America/Santiago")

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, "ml_models", "modelo_predictivo_cresal.joblib")
SCALER_PATH = os.path.join(BASE_DIR, "ml_models", "scaler_cresal.joblib")

TARGETS_Y = [
    "unidades_motor", "monto_motor_clp",
    "unidades_caja", "monto_caja_clp",
    "unidades_accesorio", "monto_accesorio_clp",
]

# Medianas semanales históricas auditadas (EDA 2023-2025, N=162 semanas completas)
# Utilizadas para Cold-Start padding y para gasto_operativo_clp_lag_1 (sin tabla en BD)
MEDIANAS_HISTORICAS_SEMANALES = {
    "unidades_motor": 4.0,
    "monto_motor_clp": 4126000.0,
    "unidades_caja": 3.0,
    "monto_caja_clp": 1892500.0,
    "unidades_accesorio": 171.0,
    "monto_accesorio_clp": 13870050.0,
    "dias_habiles_trabajados": 6.0,
    "transacciones_totales_caja": 180.0,
    "gasto_operativo_clp": 1001750.0,
}

UMBRALES_REGIMEN = {
    "unidades_motor": (3.25, 4.50),
    "monto_motor_clp": (3600000.0, 5200000.0),
    "unidades_caja": (3.00, 4.25),
    "monto_caja_clp": (1650000.0, 2350000.0),
    "unidades_accesorio": (158.0, 188.0),
    "monto_accesorio_clp": (12800000.0, 15200000.0),
}

_EXCLUSIONES_MOTOR_RE = re.compile(
    r"(cremallera|partida|arranque|limpiaparabris|limpia parabris|limpiavidrio|"
    r"limpia vidrio|alzavidrio|alza vidrio|calefacci|ventilador|electroventilador|"
    r"soplador|blower|espejo|antena|bomba|paso a paso|ralent|sunroof|techo|"
    r"actuador|regulador|direcci|columna|biela|perno|cubre|tensor|volante|"
    r"soporte|culata)",
    re.IGNORECASE,
)

_EXCLUSIONES_CAJA_RE = re.compile(
    r"(fusible|fusilera|direcci|filtro|evaporador|bateria|batería|rele|relé|"
    r"mariposa|termostato|herramienta|soporte|selectora|piola|carcasa|reparac)",
    re.IGNORECASE,
)


class MLPredictionSingleton:
    """Contenedor Singleton en memoria para evitar lectura de disco en cada request."""
    _instance = None

    def __init__(self):
        self.modelos_xgb: Optional[Dict[str, Any]] = None
        self.features_modelo: List[str] = []
        self.scaler_X: Optional[Any] = None
        self.cargado: bool = False
        self.error_carga: Optional[str] = None

    @classmethod
    def get_instance(cls) -> "MLPredictionSingleton":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def load_artifacts(self) -> bool:
        if self.cargado and self.modelos_xgb is not None and self.scaler_X is not None:
            return True
        try:
            if not os.path.exists(MODEL_PATH) or not os.path.exists(SCALER_PATH):
                self.error_carga = (
                    f"Artefactos ML no encontrados en {os.path.dirname(MODEL_PATH)}. "
                    "Copie modelo_predictivo_cresal.joblib y scaler_cresal.joblib."
                )
                logger.error(self.error_carga)
                return False

            paquete_ml = _cargar_paquete_xgb_portable(MODEL_PATH)
            paquete_scalers = joblib.load(SCALER_PATH)

            self.modelos_xgb = paquete_ml["modelos_xgb"]
            self.features_modelo = list(paquete_ml["features_modelo"])
            self.scaler_X = paquete_scalers["scaler_X"]
            self.cargado = True
            self.error_carga = None
            logger.info("Artefactos XGBoost y RobustScaler cargados exitosamente en memoria.")
            return True
        except Exception as exc:
            self.error_carga = f"Error cargando modelos ML: {str(exc)}"
            logger.exception(self.error_carga)
            return False


def _parse_ubjson_buffer(buf: bytes) -> Any:
    """Decodifica un buffer UBJSON serializado por XGBoost para extraer la sección portable Model."""
    pos = 0

    def read_type(t: Optional[str] = None) -> Any:
        nonlocal pos
        if t is None:
            t = chr(buf[pos])
            pos += 1
        while t == "N":
            t = chr(buf[pos])
            pos += 1
        if t == "Z":
            return None
        if t == "T":
            return True
        if t == "F":
            return False
        if t == "i":
            v = struct.unpack(">b", buf[pos:pos + 1])[0]
            pos += 1
            return v
        if t == "U":
            v = buf[pos]
            pos += 1
            return v
        if t == "I":
            v = struct.unpack(">h", buf[pos:pos + 2])[0]
            pos += 2
            return v
        if t == "l":
            v = struct.unpack(">i", buf[pos:pos + 4])[0]
            pos += 4
            return v
        if t == "L":
            v = struct.unpack(">q", buf[pos:pos + 8])[0]
            pos += 8
            return v
        if t == "d":
            v = struct.unpack(">f", buf[pos:pos + 4])[0]
            pos += 4
            return v
        if t == "D":
            v = struct.unpack(">d", buf[pos:pos + 8])[0]
            pos += 8
            return v
        if t == "C":
            v = chr(buf[pos])
            pos += 1
            return v
        if t == "S":
            ln = read_type()
            s = buf[pos:pos + ln].decode("utf-8")
            pos += ln
            return s
        if t == "[":
            arr = []
            elem_t = None
            nxt = chr(buf[pos])
            if nxt == "$":
                pos += 1
                elem_t = chr(buf[pos])
                pos += 1
                nxt = chr(buf[pos])
            if nxt == "#":
                pos += 1
                cnt = read_type()
                for _ in range(cnt):
                    arr.append(read_type(elem_t))
                return arr
            while chr(buf[pos]) != "]":
                arr.append(read_type(elem_t))
            pos += 1
            return arr
        if t == "{":
            obj = {}
            elem_t = None
            nxt = chr(buf[pos])
            if nxt == "$":
                pos += 1
                elem_t = chr(buf[pos])
                pos += 1
                nxt = chr(buf[pos])
            if nxt == "#":
                pos += 1
                cnt = read_type()
                for _ in range(cnt):
                    ln = read_type()
                    k = buf[pos:pos + ln].decode("utf-8")
                    pos += ln
                    obj[k] = read_type(elem_t)
                return obj
            while chr(buf[pos]) != "}":
                ln = read_type()
                k = buf[pos:pos + ln].decode("utf-8")
                pos += ln
                obj[k] = read_type(elem_t)
            pos += 1
            return obj
        raise ValueError(f"Marcador UBJSON no soportado: {t}")

    return read_type()


def _cargar_paquete_xgb_portable(model_path: str) -> Dict[str, Any]:
    """
    Carga el archivo .joblib de XGBoost preservando compatibilidad cruzada Linux/GCC -> Windows/MSVC.
    Si Booster.__setstate__ falla por incompatibilidad de rng_state (std::mt19937), reconstruye
    cada Booster desde la sección UBJSON portable 'Model' sin modificar los archivos en disco.
    """
    orig_setstate = _xgb_core.Booster.__setstate__

    def safe_setstate(self, state: Dict[str, Any]) -> None:
        try:
            orig_setstate(self, dict(state))
        except _xgb_core.XGBoostError:
            raw_buf = state.get("handle")
            if raw_buf is None:
                raise
            parsed = _parse_ubjson_buffer(raw_buf)
            model_json = json.dumps(parsed["Model"]).encode("utf-8")
            new_booster = _xgb_core.Booster()
            new_booster.load_model(bytearray(model_json))
            state_copy = dict(state)
            state_copy["handle"] = new_booster.handle
            new_booster.handle = None
            self.__dict__.update(state_copy)

    _xgb_core.Booster.__setstate__ = safe_setstate
    try:
        return joblib.load(model_path)
    finally:
        _xgb_core.Booster.__setstate__ = orig_setstate


def inicializar_servicio_ml() -> bool:
    """Hook para invocar en el lifespan de FastAPI al iniciar el servidor."""
    return MLPredictionSingleton.get_instance().load_artifacts()


def _clasificar_regimen(target: str, valor: float) -> str:
    q1, q2 = UMBRALES_REGIMEN.get(target, (0.0, 0.0))
    if valor <= q1:
        return "Baja"
    if valor <= q2:
        return "Normal"
    return "Alta"


def _to_chile_date(dt: Optional[datetime]) -> Optional[datetime.date]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt_utc = dt.replace(tzinfo=timezone.utc)
    else:
        dt_utc = dt.astimezone(timezone.utc)
    return dt_utc.astimezone(TZ_CHILE).date()


def _clasificar_categoria_linea(
    activo: Optional[Activo_Inventariado],
    backorders_orden: List[Reservas_Backorder],
    detalle: Detalle_Orden,
) -> int:
    if activo is not None:
        if activo.id_categoria in (1, 2, 3):
            return int(activo.id_categoria)
        sku = (activo.sku_qr_fisico or "").strip().lower()
        if sku.startswith("mot"):
            return 1
        if sku.startswith("caj"):
            return 2

    desc_upper = (detalle.descripcion_manual or "").upper()
    es_linea_bo = (
        "VERDE" in desc_upper
        or "BACKORDER" in desc_upper
        or (
            detalle.id_activo is not None
            and any(rb.id_activo_asignado == detalle.id_activo for rb in backorders_orden)
        )
    )
    if es_linea_bo and backorders_orden:
        cat_bo = backorders_orden[0].id_categoria_requerida
        if cat_bo in (1, 2, 3):
            return int(cat_bo)

    desc_lower = (detalle.descripcion_manual or "").lower()
    if ("motor" in desc_lower or "block" in desc_lower) and not _EXCLUSIONES_MOTOR_RE.search(desc_lower):
        return 1
    if ("caja" in desc_lower or "transmisi" in desc_lower) and not _EXCLUSIONES_CAJA_RE.search(desc_lower):
        return 2
    return 3


def _consultar_historial_semanal_orm_fallback(
    db: Session,
    id_sucursal: Optional[int] = None,
) -> List[Dict[str, Any]]:
    """
    Fallback ORM compatible con SQLite en memoria (pytest) para entornos no PostgreSQL.
    Replica exactamente la lógica de atribución de pagos, abonos/saldos y backorders.
    """
    hoy_chile = datetime.now(TZ_CHILE).date()
    limite_fecha = hoy_chile - timedelta(days=95)

    pagos = (
        db.query(Transaccion_Pago)
        .filter(
            Transaccion_Pago.estado_pago == "Procesado",
            Transaccion_Pago.monto > 0,
        )
        .order_by(Transaccion_Pago.fecha_pago.asc(), Transaccion_Pago.id_pago.asc())
        .all()
    )

    if not pagos:
        return []

    reserva_ids = {p.id_reserva for p in pagos if p.id_reserva is not None}
    reservas_map: Dict[Any, Reservas_Backorder] = {}
    if reserva_ids:
        for rb in db.query(Reservas_Backorder).filter(Reservas_Backorder.id_reserva.in_(reserva_ids)).all():
            reservas_map[rb.id_reserva] = rb

    orden_ids: Set[Any] = set()
    for p in pagos:
        id_ord = p.id_orden
        if id_ord is None and p.id_reserva in reservas_map:
            id_ord = reservas_map[p.id_reserva].id_orden
        if id_ord is not None:
            orden_ids.add(id_ord)

    ordenes_map: Dict[Any, Orden_Venta] = {}
    vendedores_map: Dict[Any, Usuario] = {}
    detalles_por_orden: Dict[Any, List[Detalle_Orden]] = {}
    activos_map: Dict[Any, Activo_Inventariado] = {}
    backorders_por_orden: Dict[Any, List[Reservas_Backorder]] = {}

    if orden_ids:
        ordenes = db.query(Orden_Venta).filter(Orden_Venta.id_orden.in_(orden_ids)).all()
        ordenes_map = {o.id_orden: o for o in ordenes}
        vend_ids = {o.id_vendedor for o in ordenes if o.id_vendedor is not None}
        if vend_ids:
            vendedores_map = {
                u.id_usuario: u
                for u in db.query(Usuario).filter(Usuario.id_usuario.in_(vend_ids)).all()
            }

        detalles = db.query(Detalle_Orden).filter(Detalle_Orden.id_orden.in_(orden_ids)).all()
        act_ids = {d.id_activo for d in detalles if d.id_activo is not None}
        if act_ids:
            activos_map = {
                a.id_activo: a
                for a in db.query(Activo_Inventariado).filter(Activo_Inventariado.id_activo.in_(act_ids)).all()
            }
        for d in detalles:
            detalles_por_orden.setdefault(d.id_orden, []).append(d)

        bos = (
            db.query(Reservas_Backorder)
            .filter(
                Reservas_Backorder.id_orden.in_(orden_ids),
                func.lower(func.coalesce(Reservas_Backorder.estado_reserva, "")).notin_(["anulada", "cancelada"]),
            )
            .order_by(Reservas_Backorder.fecha_creacion.asc())
            .all()
        )
        for rb in bos:
            backorders_por_orden.setdefault(rb.id_orden, []).append(rb)

    vistos_orden: Set[Any] = set()
    vistos_reserva: Set[Any] = set()
    semanas_agg: Dict[Any, Dict[str, Any]] = {}

    for p in pagos:
        fecha_op = _to_chile_date(p.fecha_pago)
        if fecha_op is None:
            continue

        id_ord = p.id_orden
        if id_ord is None and p.id_reserva in reservas_map:
            id_ord = reservas_map[p.id_reserva].id_orden

        if id_ord is not None:
            ov = ordenes_map.get(id_ord)
            if ov is None or (ov.estado_orden or "") in ("Anulada", "Cancelada"):
                continue

            u_vend = vendedores_map.get(ov.id_vendedor)
            es_limache_ref = (
                ov.id_sucursal == 1
                and u_vend is not None
                and (
                    (u_vend.email or "").lower() == "limache@cresal.cl"
                    or "limache" in (u_vend.apellidos or "").lower()
                )
            )
            suc_efectiva = 2 if es_limache_ref else ov.id_sucursal
            if id_sucursal is not None and suc_efectiva != id_sucursal:
                continue

            es_primer_pago = id_ord not in vistos_orden
            vistos_orden.add(id_ord)

            if fecha_op < limite_fecha:
                continue

            u_cat = {1: 0.0, 2: 0.0, 3: 0.0}
            m_cat = {1: 0.0, 2: 0.0, 3: 0.0}
            bos_ord = backorders_por_orden.get(id_ord, [])
            for d in detalles_por_orden.get(id_ord, []):
                cant = float(d.cantidad if d.cantidad is not None else 1)
                if cant > 1 and d.precio_unitario is not None and d.precio_final == d.precio_unitario * int(cant):
                    subtotal = float(d.precio_final)
                else:
                    subtotal = float((d.precio_final or 0) * cant)
                cat_id = _clasificar_categoria_linea(activos_map.get(d.id_activo), bos_ord, d)
                u_cat[cat_id] += cant
                m_cat[cat_id] += subtotal

            total_det = max(m_cat[1] + m_cat[2] + m_cat[3], 1.0)
            monto_p = float(p.monto or 0)
            u_mot = u_cat[1] if es_primer_pago else 0.0
            u_caj = u_cat[2] if es_primer_pago else 0.0
            u_acc = u_cat[3] if es_primer_pago else 0.0
            m_mot = monto_p * (m_cat[1] / total_det)
            m_caj = monto_p * (m_cat[2] / total_det)
            m_acc = monto_p * (m_cat[3] / total_det)

        elif p.id_reserva is not None:
            rb = reservas_map.get(p.id_reserva)
            if rb is None or (rb.estado_reserva or "").lower() in ("anulada", "cancelada"):
                continue
            if id_sucursal is not None and rb.id_sucursal_registro != id_sucursal:
                continue

            es_primer_pago = rb.id_reserva not in vistos_reserva
            vistos_reserva.add(rb.id_reserva)

            if fecha_op < limite_fecha:
                continue

            cat_req = rb.id_categoria_requerida if rb.id_categoria_requerida in (1, 2, 3) else 3
            monto_p = float(p.monto or 0)
            u_mot = 1.0 if (es_primer_pago and cat_req == 1) else 0.0
            u_caj = 1.0 if (es_primer_pago and cat_req == 2) else 0.0
            u_acc = 1.0 if (es_primer_pago and cat_req == 3) else 0.0
            m_mot = monto_p if cat_req == 1 else 0.0
            m_caj = monto_p if cat_req == 2 else 0.0
            m_acc = monto_p if cat_req == 3 else 0.0
        else:
            continue

        semana_inicio = fecha_op - timedelta(days=fecha_op.weekday())
        bucket = semanas_agg.setdefault(
            semana_inicio,
            {
                "semana_inicio": semana_inicio,
                "dias": set(),
                "pagos": set(),
                "unidades_motor": 0.0,
                "monto_motor_clp": 0.0,
                "unidades_caja": 0.0,
                "monto_caja_clp": 0.0,
                "unidades_accesorio": 0.0,
                "monto_accesorio_clp": 0.0,
            },
        )
        bucket["dias"].add(fecha_op)
        bucket["pagos"].add(p.id_pago)
        bucket["unidades_motor"] += u_mot
        bucket["monto_motor_clp"] += m_mot
        bucket["unidades_caja"] += u_caj
        bucket["monto_caja_clp"] += m_caj
        bucket["unidades_accesorio"] += u_acc
        bucket["monto_accesorio_clp"] += m_acc

    resultado = []
    for semana_inicio in sorted(semanas_agg.keys()):
        b = semanas_agg[semana_inicio]
        resultado.append({
            "semana_inicio": b["semana_inicio"],
            "dias_habiles_trabajados": len(b["dias"]),
            "transacciones_totales_caja": len(b["pagos"]),
            "unidades_motor": b["unidades_motor"],
            "monto_motor_clp": b["monto_motor_clp"],
            "unidades_caja": b["unidades_caja"],
            "monto_caja_clp": b["monto_caja_clp"],
            "unidades_accesorio": b["unidades_accesorio"],
            "monto_accesorio_clp": b["monto_accesorio_clp"],
        })
    return resultado


def _consultar_historial_semanal_supabase(db: Session, id_sucursal: Optional[int] = None) -> pd.DataFrame:
    dialect_name = db.bind.dialect.name if db.bind is not None else "postgresql"

    if dialect_name == "postgresql":
        filtro_sucursal_ov = """
            AND (
                CASE
                    WHEN ov.id_sucursal = 1 AND (
                        LOWER(COALESCE(u_vend.email, '')) = 'limache@cresal.cl'
                        OR LOWER(COALESCE(u_vend.apellidos, '')) LIKE '%limache%'
                    )
                    THEN 2
                    ELSE ov.id_sucursal
                END
            ) = :id_sucursal
        """ if id_sucursal is not None else ""
        filtro_sucursal_rb = "AND rb.id_sucursal_registro = :id_sucursal" if id_sucursal is not None else ""
        params = {"id_sucursal": id_sucursal} if id_sucursal is not None else {}

        sql = text(f"""
            WITH pagos_resueltos AS (
                SELECT
                    tp.id_pago,
                    COALESCE(tp.id_orden, rb_link.id_orden) AS id_orden_resuelta,
                    CASE
                        WHEN COALESCE(tp.id_orden, rb_link.id_orden) IS NULL THEN tp.id_reserva
                        ELSE NULL
                    END AS id_reserva_huerfana,
                    ((tp.fecha_pago::timestamp AT TIME ZONE 'UTC') AT TIME ZONE 'America/Santiago')::date AS fecha_op,
                    tp.monto::numeric AS monto_pago,
                    tp.fecha_pago
                FROM "Transaccion_Pago" tp
                LEFT JOIN "Reservas_Backorder" rb_link
                    ON tp.id_reserva = rb_link.id_reserva
                WHERE tp.estado_pago = 'Procesado'
                  AND tp.monto > 0
                  AND tp.fecha_pago >= (NOW() - INTERVAL '120 days')
            ),
            pagos_orden AS (
                SELECT
                    pr.id_pago,
                    pr.id_orden_resuelta AS id_orden,
                    pr.fecha_op,
                    pr.monto_pago,
                    ROW_NUMBER() OVER (
                        PARTITION BY pr.id_orden_resuelta
                        ORDER BY pr.fecha_op ASC, pr.fecha_pago ASC, pr.id_pago ASC
                    ) AS nro_pago
                FROM pagos_resueltos pr
                WHERE pr.id_orden_resuelta IS NOT NULL
            ),
            detalles_categorizados AS (
                SELECT
                    d.id_orden,
                    COALESCE(d.cantidad, 1) AS cantidad,
                    CASE
                        WHEN COALESCE(d.cantidad, 1) > 1
                             AND d.precio_unitario IS NOT NULL
                             AND d.precio_final = d.precio_unitario * d.cantidad
                        THEN d.precio_final::numeric
                        ELSE (d.precio_final * COALESCE(d.cantidad, 1))::numeric
                    END AS subtotal_linea,
                    CASE
                        WHEN ai.id_categoria IN (1, 2, 3) THEN ai.id_categoria
                        WHEN LOWER(COALESCE(ai.sku_qr_fisico, '')) LIKE 'mot%' THEN 1
                        WHEN LOWER(COALESCE(ai.sku_qr_fisico, '')) LIKE 'caj%' THEN 2
                        WHEN rb.id_categoria_requerida IN (1, 2, 3) THEN rb.id_categoria_requerida
                        WHEN (
                            LOWER(COALESCE(d.descripcion_manual, '')) LIKE '%motor%'
                            OR LOWER(COALESCE(d.descripcion_manual, '')) LIKE '%block%'
                        )
                        AND LOWER(COALESCE(d.descripcion_manual, '')) NOT SIMILAR TO
                            '%(cremallera|partida|arranque|limpiaparabris|limpia parabris|limpiavidrio|limpia vidrio|alzavidrio|alza vidrio|calefacci|ventilador|electroventilador|soplador|blower|espejo|antena|bomba|paso a paso|ralent|sunroof|techo|actuador|regulador|direcci|columna|biela|perno|cubre|tensor|volante|soporte|culata)%'
                        THEN 1
                        WHEN (
                            LOWER(COALESCE(d.descripcion_manual, '')) LIKE '%caja%'
                            OR LOWER(COALESCE(d.descripcion_manual, '')) LIKE '%transmisi%'
                        )
                        AND LOWER(COALESCE(d.descripcion_manual, '')) NOT SIMILAR TO
                            '%(fusible|fusilera|direcci|filtro|evaporador|bateria|batería|rele|relé|mariposa|termostato|herramienta|soporte|selectora|piola|carcasa|reparac)%'
                        THEN 2
                        ELSE 3
                    END AS id_categoria_calc
                FROM "Detalle_Orden" d
                INNER JOIN (SELECT DISTINCT id_orden FROM pagos_orden) po_ids
                    ON po_ids.id_orden = d.id_orden
                LEFT JOIN "Activo_Inventariado" ai
                    ON d.id_activo = ai.id_activo
                LEFT JOIN LATERAL (
                    SELECT rb_sub.id_categoria_requerida
                    FROM "Reservas_Backorder" rb_sub
                    WHERE rb_sub.id_orden = d.id_orden
                      AND LOWER(COALESCE(rb_sub.estado_reserva, '')) NOT IN ('anulada', 'cancelada')
                      AND (
                          UPPER(COALESCE(d.descripcion_manual, '')) LIKE '%VERDE%'
                          OR UPPER(COALESCE(d.descripcion_manual, '')) LIKE '%BACKORDER%'
                          OR (d.id_activo IS NOT NULL AND rb_sub.id_activo_asignado = d.id_activo)
                      )
                    ORDER BY
                        CASE WHEN d.id_activo IS NOT NULL AND rb_sub.id_activo_asignado = d.id_activo THEN 0 ELSE 1 END,
                        CASE WHEN rb_sub.id_categoria_requerida = 1 AND LOWER(COALESCE(d.descripcion_manual, '')) LIKE '%motor%' THEN 0
                             WHEN rb_sub.id_categoria_requerida = 2 AND LOWER(COALESCE(d.descripcion_manual, '')) LIKE '%caja%' THEN 0
                             WHEN rb_sub.id_categoria_requerida = 3 AND LOWER(COALESCE(d.descripcion_manual, '')) NOT LIKE '%motor%' AND LOWER(COALESCE(d.descripcion_manual, '')) NOT LIKE '%caja%' THEN 0
                             ELSE 1 END,
                        CASE WHEN rb_sub.precio_acordado = d.precio_unitario THEN 0 ELSE 1 END,
                        rb_sub.fecha_creacion ASC
                    LIMIT 1
                ) rb ON TRUE
            ),
            orden_mix AS (
                SELECT
                    dc.id_orden,
                    SUM(CASE WHEN dc.id_categoria_calc = 1 THEN dc.cantidad ELSE 0 END) AS u_motor,
                    SUM(CASE WHEN dc.id_categoria_calc = 2 THEN dc.cantidad ELSE 0 END) AS u_caja,
                    SUM(CASE WHEN dc.id_categoria_calc = 3 THEN dc.cantidad ELSE 0 END) AS u_acc,
                    SUM(CASE WHEN dc.id_categoria_calc = 1 THEN dc.subtotal_linea ELSE 0 END) AS m_motor,
                    SUM(CASE WHEN dc.id_categoria_calc = 2 THEN dc.subtotal_linea ELSE 0 END) AS m_caja,
                    SUM(CASE WHEN dc.id_categoria_calc = 3 THEN dc.subtotal_linea ELSE 0 END) AS m_acc,
                    GREATEST(SUM(dc.subtotal_linea), 1) AS total_det
                FROM detalles_categorizados dc
                GROUP BY dc.id_orden
            ),
            pagos_reserva_huerfana AS (
                SELECT
                    pr.id_pago,
                    pr.id_reserva_huerfana,
                    pr.fecha_op,
                    pr.monto_pago,
                    ROW_NUMBER() OVER (
                        PARTITION BY pr.id_reserva_huerfana
                        ORDER BY pr.fecha_op ASC, pr.fecha_pago ASC, pr.id_pago ASC
                    ) AS nro_pago
                FROM pagos_resueltos pr
                WHERE pr.id_reserva_huerfana IS NOT NULL
            ),
            movimientos_unificados AS (
                SELECT
                    po.fecha_op,
                    po.id_pago,
                    CASE WHEN po.nro_pago = 1 THEN COALESCE(om.u_motor, 0) ELSE 0 END AS unidades_motor,
                    po.monto_pago * (COALESCE(om.m_motor, 0)::numeric / COALESCE(om.total_det, 1)) AS monto_motor_clp,
                    CASE WHEN po.nro_pago = 1 THEN COALESCE(om.u_caja, 0) ELSE 0 END AS unidades_caja,
                    po.monto_pago * (COALESCE(om.m_caja, 0)::numeric / COALESCE(om.total_det, 1)) AS monto_caja_clp,
                    CASE WHEN po.nro_pago = 1 THEN COALESCE(om.u_acc, 0) ELSE 0 END AS unidades_accesorio,
                    po.monto_pago * (COALESCE(om.m_acc, 0)::numeric / COALESCE(om.total_det, 1)) AS monto_accesorio_clp
                FROM pagos_orden po
                INNER JOIN "Orden_Venta" ov ON ov.id_orden = po.id_orden
                LEFT JOIN "Usuario" u_vend ON ov.id_vendedor = u_vend.id_usuario
                LEFT JOIN orden_mix om ON om.id_orden = po.id_orden
                WHERE COALESCE(ov.estado_orden, '') NOT IN ('Anulada', 'Cancelada')
                  {filtro_sucursal_ov}

                UNION ALL

                SELECT
                    prh.fecha_op,
                    prh.id_pago,
                    CASE WHEN prh.nro_pago = 1 AND rb.id_categoria_requerida = 1 THEN 1 ELSE 0 END AS unidades_motor,
                    CASE WHEN rb.id_categoria_requerida = 1 THEN prh.monto_pago ELSE 0 END AS monto_motor_clp,
                    CASE WHEN prh.nro_pago = 1 AND rb.id_categoria_requerida = 2 THEN 1 ELSE 0 END AS unidades_caja,
                    CASE WHEN rb.id_categoria_requerida = 2 THEN prh.monto_pago ELSE 0 END AS monto_caja_clp,
                    CASE WHEN prh.nro_pago = 1 AND (rb.id_categoria_requerida = 3 OR rb.id_categoria_requerida IS NULL) THEN 1 ELSE 0 END AS unidades_accesorio,
                    CASE WHEN (rb.id_categoria_requerida = 3 OR rb.id_categoria_requerida IS NULL) THEN prh.monto_pago ELSE 0 END AS monto_accesorio_clp
                FROM pagos_reserva_huerfana prh
                INNER JOIN "Reservas_Backorder" rb ON rb.id_reserva = prh.id_reserva_huerfana
                WHERE LOWER(COALESCE(rb.estado_reserva, '')) NOT IN ('anulada', 'cancelada')
                  {filtro_sucursal_rb}
            )
            SELECT
                DATE_TRUNC('week', fecha_op)::date AS semana_inicio,
                COUNT(DISTINCT fecha_op) AS dias_habiles_trabajados,
                COUNT(DISTINCT id_pago) AS transacciones_totales_caja,
                COALESCE(SUM(unidades_motor), 0)::float AS unidades_motor,
                COALESCE(SUM(monto_motor_clp), 0)::float AS monto_motor_clp,
                COALESCE(SUM(unidades_caja), 0)::float AS unidades_caja,
                COALESCE(SUM(monto_caja_clp), 0)::float AS monto_caja_clp,
                COALESCE(SUM(unidades_accesorio), 0)::float AS unidades_accesorio,
                COALESCE(SUM(monto_accesorio_clp), 0)::float AS monto_accesorio_clp
            FROM movimientos_unificados
            WHERE fecha_op >= (((NOW() AT TIME ZONE 'UTC') AT TIME ZONE 'America/Santiago')::date - 95)
            GROUP BY DATE_TRUNC('week', fecha_op)::date
            ORDER BY semana_inicio ASC
        """)

        rows = [dict(r) for r in db.execute(sql, params).mappings().all()]
    else:
        rows = _consultar_historial_semanal_orm_fallback(db, id_sucursal=id_sucursal)

    hoy_chile = datetime.now(TZ_CHILE).date()
    lunes_actual = hoy_chile - timedelta(days=hoy_chile.weekday())
    semanas_grilla = [lunes_actual - timedelta(days=7 * i) for i in range(8, 0, -1)]

    df_grid = pd.DataFrame({"semana_inicio": semanas_grilla})
    if rows:
        df_db = pd.DataFrame(rows)
        df_db["semana_inicio"] = pd.to_datetime(df_db["semana_inicio"]).dt.date
        df_merged = pd.merge(df_grid, df_db, on="semana_inicio", how="left")
    else:
        df_merged = df_grid.copy()
        for col in TARGETS_Y + ["dias_habiles_trabajados", "transacciones_totales_caja"]:
            df_merged[col] = np.nan

    factor_escala_sucursal = 0.65 if id_sucursal == 1 else (0.35 if id_sucursal == 2 else 1.0)
    for col in TARGETS_Y:
        fallback_val = MEDIANAS_HISTORICAS_SEMANALES[col] * factor_escala_sucursal
        df_merged[col] = df_merged[col].fillna(fallback_val).astype(float)

    df_merged["dias_habiles_trabajados"] = (
        df_merged["dias_habiles_trabajados"].fillna(6.0).replace(0, 6.0).astype(float)
    )
    df_merged["transacciones_totales_caja"] = (
        df_merged["transacciones_totales_caja"]
        .fillna(MEDIANAS_HISTORICAS_SEMANALES["transacciones_totales_caja"] * factor_escala_sucursal)
        .astype(float)
    )
    df_merged["gasto_operativo_clp"] = MEDIANAS_HISTORICAS_SEMANALES["gasto_operativo_clp"] * factor_escala_sucursal

    return df_merged


def _consultar_stock_y_backorders(db: Session, id_sucursal: Optional[int] = None) -> Dict[int, Dict[str, Any]]:
    dialect_name = db.bind.dialect.name if db.bind is not None else "postgresql"

    if dialect_name == "postgresql":
        filtro_suc_ai = "AND ai.id_sucursal_actual = :id_sucursal" if id_sucursal is not None else ""
        filtro_suc_rb = "AND rb.id_sucursal_registro = :id_sucursal" if id_sucursal is not None else ""
        params = {"id_sucursal": id_sucursal} if id_sucursal is not None else {}

        sql_stock = text(f"""
            SELECT
                ai.id_categoria,
                ai.id_sucursal_actual,
                LOWER(ea.nombre_estado) AS estado_nombre,
                COUNT(ai.id_activo)::int AS cantidad
            FROM "Activo_Inventariado" ai
            INNER JOIN "Estado_Activo" ea ON ai.id_estado = ea.id_estado
            WHERE ai.estado = 'Activo'
              AND ai.id_categoria IN (1, 2)
              AND LOWER(ea.nombre_estado) IN ('disponible', 'paletizado')
              {filtro_suc_ai}
            GROUP BY ai.id_categoria, ai.id_sucursal_actual, LOWER(ea.nombre_estado)
        """)

        sql_bo = text(f"""
            SELECT
                rb.id_categoria_requerida AS id_categoria,
                COUNT(rb.id_reserva)::int AS pendientes
            FROM "Reservas_Backorder" rb
            LEFT JOIN "Orden_Venta" ov ON rb.id_orden = ov.id_orden
            WHERE rb.id_categoria_requerida IN (1, 2)
              AND rb.id_activo_asignado IS NULL
              AND LOWER(COALESCE(rb.estado_reserva, '')) IN ('confirmada', 'pendiente', 'en_busqueda')
              AND COALESCE(ov.estado_orden, '') NOT IN ('Anulada', 'Completada')
              {filtro_suc_rb}
            GROUP BY rb.id_categoria_requerida
        """)

        res_stock = [dict(r) for r in db.execute(sql_stock, params).mappings().all()]
        res_bo = [dict(r) for r in db.execute(sql_bo, params).mappings().all()]
    else:
        q_stock = (
            db.query(
                Activo_Inventariado.id_categoria.label("id_categoria"),
                Activo_Inventariado.id_sucursal_actual.label("id_sucursal_actual"),
                func.lower(Estado_Activo.nombre_estado).label("estado_nombre"),
                func.count(Activo_Inventariado.id_activo).label("cantidad"),
            )
            .join(Estado_Activo, Activo_Inventariado.id_estado == Estado_Activo.id_estado)
            .filter(
                Activo_Inventariado.estado == "Activo",
                Activo_Inventariado.id_categoria.in_([1, 2]),
                func.lower(Estado_Activo.nombre_estado).in_(["disponible", "paletizado"]),
            )
        )
        if id_sucursal is not None:
            q_stock = q_stock.filter(Activo_Inventariado.id_sucursal_actual == id_sucursal)
        res_stock = [
            {
                "id_categoria": r.id_categoria,
                "id_sucursal_actual": r.id_sucursal_actual,
                "estado_nombre": r.estado_nombre,
                "cantidad": int(r.cantidad or 0),
            }
            for r in q_stock.group_by(
                Activo_Inventariado.id_categoria,
                Activo_Inventariado.id_sucursal_actual,
                func.lower(Estado_Activo.nombre_estado),
            ).all()
        ]

        q_bo = (
            db.query(
                Reservas_Backorder.id_categoria_requerida.label("id_categoria"),
                func.count(Reservas_Backorder.id_reserva).label("pendientes"),
            )
            .outerjoin(Orden_Venta, Reservas_Backorder.id_orden == Orden_Venta.id_orden)
            .filter(
                Reservas_Backorder.id_categoria_requerida.in_([1, 2]),
                Reservas_Backorder.id_activo_asignado.is_(None),
                func.lower(func.coalesce(Reservas_Backorder.estado_reserva, "")).in_(
                    ["confirmada", "pendiente", "en_busqueda"]
                ),
                func.coalesce(Orden_Venta.estado_orden, "").notin_(["Anulada", "Completada"]),
            )
        )
        if id_sucursal is not None:
            q_bo = q_bo.filter(Reservas_Backorder.id_sucursal_registro == id_sucursal)
        res_bo = [
            {"id_categoria": r.id_categoria, "pendientes": int(r.pendientes or 0)}
            for r in q_bo.group_by(Reservas_Backorder.id_categoria_requerida).all()
        ]

    estructura = {
        1: {
            "categoria": "Motor",
            "stock_disponible_tasado": 0,
            "stock_paletizado_sin_tasar": 0,
            "stock_total_disponible": 0,
            "stock_vina_del_mar": 0,
            "stock_limache": 0,
            "backorders_pendientes": 0,
        },
        2: {
            "categoria": "Caja de Cambios",
            "stock_disponible_tasado": 0,
            "stock_paletizado_sin_tasar": 0,
            "stock_total_disponible": 0,
            "stock_vina_del_mar": 0,
            "stock_limache": 0,
            "backorders_pendientes": 0,
        },
    }

    for r in res_stock:
        cat = int(r["id_categoria"])
        cant = int(r["cantidad"])
        est = r["estado_nombre"]
        suc = int(r["id_sucursal_actual"] or 0)
        if cat in estructura:
            estructura[cat]["stock_total_disponible"] += cant
            if est == "disponible":
                estructura[cat]["stock_disponible_tasado"] += cant
            elif est == "paletizado":
                estructura[cat]["stock_paletizado_sin_tasar"] += cant
            if suc == 1:
                estructura[cat]["stock_vina_del_mar"] += cant
            elif suc == 2:
                estructura[cat]["stock_limache"] += cant

    for r in res_bo:
        cat = int(r["id_categoria"])
        if cat in estructura:
            estructura[cat]["backorders_pendientes"] = int(r["pendientes"])

    return estructura


def generar_prediccion_ventas_y_stock(db: Session, id_sucursal: Optional[int] = None) -> Dict[str, Any]:
    t0 = time.perf_counter()
    singleton = MLPredictionSingleton.get_instance()
    if not singleton.load_artifacts():
        raise RuntimeError(singleton.error_carga or "Modelo ML no disponible en memoria.")

    df_hist = _consultar_historial_semanal_supabase(db, id_sucursal=id_sucursal)
    stock_info = _consultar_stock_y_backorders(db, id_sucursal=id_sucursal)

    df_suav = df_hist.copy()
    for col in TARGETS_Y:
        df_suav[col] = df_suav[col].rolling(window=4, min_periods=1).mean()

    hoy_chile = datetime.now(TZ_CHILE).date()
    lunes_actual = hoy_chile - timedelta(days=hoy_chile.weekday())
    proxima_semana = lunes_actual + timedelta(days=7)

    hist_series = {col: list(df_suav[col].values) for col in TARGETS_Y}
    hist_dias = list(df_suav["dias_habiles_trabajados"].values)

    venta_tot_t1 = max(
        hist_series["monto_motor_clp"][-1]
        + hist_series["monto_caja_clp"][-1]
        + hist_series["monto_accesorio_clp"][-1],
        1.0,
    )
    ratio_mix_motor = hist_series["monto_motor_clp"][-1] / venta_tot_t1
    ratio_mix_caja = hist_series["monto_caja_clp"][-1] / venta_tot_t1
    tx_lag_1 = float(df_suav["transacciones_totales_caja"].iloc[-1])
    gasto_lag_1 = float(df_suav["gasto_operativo_clp"].iloc[-1])

    proyecciones_4_semanas = []

    for paso in range(1, 5):
        fecha_p = lunes_actual + timedelta(days=7 * paso)
        mes_p = fecha_p.month
        sem_p = int(fecha_p.isocalendar().week)
        trim_p = (mes_p - 1) // 3 + 1
        dia_p = fecha_p.day
        dias_hab_p = 5.0 if (mes_p == 12 and dia_p >= 20) or (mes_p == 9 and 15 <= dia_p <= 21) else 6.0

        factor_cal = dias_hab_p / max(float(np.mean(hist_dias[-4:])), 1.0)

        fila_x: Dict[str, float] = {
            "dias_habiles_trabajados": dias_hab_p,
            "mes": float(mes_p),
            "semana_del_anio": float(sem_p),
            "trimestre": float(trim_p),
            "mes_sin": float(np.sin(2 * np.pi * mes_p / 12.0)),
            "mes_cos": float(np.cos(2 * np.pi * mes_p / 12.0)),
            "semana_sin": float(np.sin(2 * np.pi * sem_p / 52.0)),
            "semana_cos": float(np.cos(2 * np.pi * sem_p / 52.0)),
            "es_quincena_o_fin_mes": float(int((12 <= dia_p <= 16) or (dia_p >= 25) or (dia_p <= 3))),
            "ratio_mix_motor_t1": float(ratio_mix_motor),
            "ratio_mix_caja_t1": float(ratio_mix_caja),
            "transacciones_totales_caja_lag_1": tx_lag_1,
            "gasto_operativo_clp_lag_1": gasto_lag_1,
        }

        base_paso = {}
        for col in TARGETS_Y:
            h = hist_series[col]
            lag1, lag2, lag3 = h[-1], h[-2], h[-3]
            roll4 = float(np.mean(h[-4:]))
            roll8 = float(np.mean(h[-8:]))
            aj_cal = roll4 * factor_cal
            ema3 = 0.50 * lag1 + 0.30 * lag2 + 0.20 * lag3

            fila_x[f"{col}_lag_1"] = lag1
            fila_x[f"{col}_lag_2"] = lag2
            fila_x[f"{col}_lag_3"] = lag3
            fila_x[f"{col}_roll_mean_4"] = roll4
            fila_x[f"{col}_roll_mean_8"] = roll8
            fila_x[f"{col}_ajustado_calendario"] = aj_cal
            fila_x[f"{col}_ema_3_t1"] = ema3

            base_paso[col] = 0.25 * (lag1 + lag2 + lag3 + aj_cal)

        X_df = pd.DataFrame([fila_x])[singleton.features_modelo]
        X_scaled = pd.DataFrame(singleton.scaler_X.transform(X_df), columns=singleton.features_modelo)

        pred_paso: Dict[str, Any] = {"semana_inicio": fecha_p.isoformat(), "dias_habiles": int(dias_hab_p)}
        for col in TARGETS_Y:
            residuo = float(singleton.modelos_xgb[col].predict(X_scaled)[0])
            val = max(0.0, base_paso[col] + residuo)
            pred_paso[col] = round(val, 2) if "unidades" in col else int(round(val))
            hist_series[col].append(val)

        hist_dias.append(dias_hab_p)
        proyecciones_4_semanas.append(pred_paso)

    pred_t1 = proyecciones_4_semanas[0]
    total_clp_t1 = pred_t1["monto_motor_clp"] + pred_t1["monto_caja_clp"] + pred_t1["monto_accesorio_clp"]
    total_clp_4sem = sum(
        p["monto_motor_clp"] + p["monto_caja_clp"] + p["monto_accesorio_clp"]
        for p in proyecciones_4_semanas
    )

    denom_mix = max(total_clp_t1, 1)
    mix_porcentual = {
        "motor_pct": round((pred_t1["monto_motor_clp"] / denom_mix) * 100.0, 2),
        "caja_pct": round((pred_t1["monto_caja_clp"] / denom_mix) * 100.0, 2),
        "accesorio_pct": round((pred_t1["monto_accesorio_clp"] / denom_mix) * 100.0, 2),
    }

    cobertura_critica = []
    mapa_cat_target = {1: "unidades_motor", 2: "unidades_caja"}
    for cat_id, target_u in mapa_cat_target.items():
        info = stock_info[cat_id]
        demanda_sem = float(pred_t1[target_u])
        demanda_entera = int(np.ceil(demanda_sem))
        stock_disp = info["stock_total_disponible"]
        bo_pend = info["backorders_pendientes"]

        balance = stock_disp - (demanda_entera + bo_pend)
        semanas_cob = round(stock_disp / max(demanda_sem, 0.1), 2)

        if balance < 0:
            estado_alerta = "Déficit Crítico"
        elif balance < 2 or semanas_cob < 1.5:
            estado_alerta = "Riesgo de Quiebre"
        else:
            estado_alerta = "Óptimo"

        cobertura_critica.append({
            "id_categoria": cat_id,
            "categoria": info["categoria"],
            "stock_disponible_tasado": info["stock_disponible_tasado"],
            "stock_paletizado_sin_tasar": info["stock_paletizado_sin_tasar"],
            "stock_total_disponible": stock_disp,
            "stock_vina_del_mar": info["stock_vina_del_mar"],
            "stock_limache": info["stock_limache"],
            "backorders_pendientes": bo_pend,
            "demanda_predicha_semanal": demanda_sem,
            "demanda_predicha_mensual_4sem": round(sum(p[target_u] for p in proyecciones_4_semanas), 2),
            "balance_unidades": balance,
            "semanas_cobertura": semanas_cob,
            "estado_alerta": estado_alerta,
        })

    serie_historica = []
    for _, row in df_hist.iterrows():
        serie_historica.append({
            "semana_inicio": row["semana_inicio"].isoformat(),
            "unidades_motor": round(float(row["unidades_motor"]), 2),
            "monto_motor_clp": int(round(float(row["monto_motor_clp"]))),
            "unidades_caja": round(float(row["unidades_caja"]), 2),
            "monto_caja_clp": int(round(float(row["monto_caja_clp"]))),
            "unidades_accesorio": round(float(row["unidades_accesorio"]), 2),
            "monto_accesorio_clp": int(round(float(row["monto_accesorio_clp"]))),
            "venta_total_clp": int(round(float(row["monto_motor_clp"] + row["monto_caja_clp"] + row["monto_accesorio_clp"]))),
        })

    latencia_ms = round((time.perf_counter() - t0) * 1000.0, 2)

    return {
        "metadata_modelo": {
            "algoritmo": "XGBoost Multi-Target (CRISP-DM)",
            "exactitud_wape_pct": 90.39,
            "wape_promedio_pct": 9.61,
            "r2_promedio": 0.7247,
            "id_sucursal_filtro": id_sucursal,
            "semana_proyectada_inicio": proxima_semana.isoformat(),
            "tiempo_inferencia_ms": latencia_ms,
        },
        "prediccion_semanal_t1": {
            **pred_t1,
            "venta_total_proyectada_clp": total_clp_t1,
            "regimen_motor": _clasificar_regimen("unidades_motor", pred_t1["unidades_motor"]),
            "regimen_caja": _clasificar_regimen("unidades_caja", pred_t1["unidades_caja"]),
            "regimen_accesorio": _clasificar_regimen("unidades_accesorio", pred_t1["unidades_accesorio"]),
        },
        "proyeccion_mensual_4_semanas": {
            "unidades_motor": round(sum(p["unidades_motor"] for p in proyecciones_4_semanas), 2),
            "monto_motor_clp": sum(p["monto_motor_clp"] for p in proyecciones_4_semanas),
            "unidades_caja": round(sum(p["unidades_caja"] for p in proyecciones_4_semanas), 2),
            "monto_caja_clp": sum(p["monto_caja_clp"] for p in proyecciones_4_semanas),
            "unidades_accesorio": round(sum(p["unidades_accesorio"] for p in proyecciones_4_semanas), 2),
            "monto_accesorio_clp": sum(p["monto_accesorio_clp"] for p in proyecciones_4_semanas),
            "venta_total_proyectada_clp": total_clp_4sem,
            "desglose_semanal": proyecciones_4_semanas,
        },
        "mix_porcentual_ventas": mix_porcentual,
        "cobertura_stock_critico": cobertura_critica,
        "historial_reciente_8_semanas": serie_historica,
    }
