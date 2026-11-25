// frontend/lib/features/gerencia/models/gerencia_models.dart
// Modelos de datos para el módulo de Gerencia y Dashboard Ejecutivo (HU-5.1).
// Diseñé estas estructuras inmutables para deserializar de forma segura
// las respuestas analíticas del backend.

class KpiFinancieroModel {
  final int ventasDelDia;
  final int transaccionesHoy;
  final int acumuladoMensualMtd;
  final double ticketPromedio;
  final double? margenBruto;
  final int salidasMotoresHoy;
  final int salidasCajasHoy;
  final int totalSalidasHoy;

  const KpiFinancieroModel({
    required this.ventasDelDia,
    required this.transaccionesHoy,
    required this.acumuladoMensualMtd,
    required this.ticketPromedio,
    this.margenBruto,
    this.salidasMotoresHoy = 0,
    this.salidasCajasHoy = 0,
    this.totalSalidasHoy = 0,
  });

  factory KpiFinancieroModel.fromJson(Map<String, dynamic> json) {
    return KpiFinancieroModel(
      ventasDelDia: (json['ventas_del_dia'] as num?)?.toInt() ?? 0,
      transaccionesHoy: (json['transacciones_hoy'] as num?)?.toInt() ?? 0,
      acumuladoMensualMtd: (json['acumulado_mensual_mtd'] as num?)?.toInt() ?? 0,
      ticketPromedio: (json['ticket_promedio'] as num?)?.toDouble() ?? 0.0,
      margenBruto: (json['margen_bruto'] as num?)?.toDouble(),
      salidasMotoresHoy: (json['salidas_motores_hoy'] as num?)?.toInt() ?? 0,
      salidasCajasHoy: (json['salidas_cajas_hoy'] as num?)?.toInt() ?? 0,
      totalSalidasHoy: (json['total_salidas_hoy'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ventas_del_dia': ventasDelDia,
      'transacciones_hoy': transaccionesHoy,
      'acumulado_mensual_mtd': acumuladoMensualMtd,
      'ticket_promedio': ticketPromedio,
      'margen_bruto': margenBruto,
      'salidas_motores_hoy': salidasMotoresHoy,
      'salidas_cajas_hoy': salidasCajasHoy,
      'total_salidas_hoy': totalSalidasHoy,
    };
  }
}

class DesglosePagoModel {
  final String metodoPago;
  final int montoTotal;
  final double porcentaje;
  final int cantidad;
  final double porcentajeCantidad;

  const DesglosePagoModel({
    required this.metodoPago,
    required this.montoTotal,
    required this.porcentaje,
    this.cantidad = 1,
    this.porcentajeCantidad = 0.0,
  });

  factory DesglosePagoModel.fromJson(Map<String, dynamic> json) {
    final pctMonto = (json['porcentaje'] as num?)?.toDouble() ?? 0.0;
    return DesglosePagoModel(
      metodoPago: json['metodo_pago']?.toString() ?? 'Desconocido',
      montoTotal: (json['monto_total'] as num?)?.toInt() ?? 0,
      porcentaje: pctMonto,
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
      porcentajeCantidad:
          (json['porcentaje_cantidad'] as num?)?.toDouble() ?? pctMonto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metodo_pago': metodoPago,
      'monto_total': montoTotal,
      'porcentaje': porcentaje,
      'cantidad': cantidad,
      'porcentaje_cantidad': porcentajeCantidad,
    };
  }
}

class ResumenPagosModel {
  final int efectivoFisico;
  final int canalesElectronicos;
  final int totalTransacciones;
  final List<DesglosePagoModel> desglose;

  const ResumenPagosModel({
    required this.efectivoFisico,
    required this.canalesElectronicos,
    this.totalTransacciones = 0,
    required this.desglose,
  });

  int get totalRecaudado => efectivoFisico + canalesElectronicos;

  int get transaccionesCalculadas =>
      totalTransacciones > 0
          ? totalTransacciones
          : desglose.fold<int>(0, (acc, item) => acc + item.cantidad);

  factory ResumenPagosModel.fromJson(Map<String, dynamic> json) {
    final rawDesglose = json['desglose'] as List<dynamic>? ?? [];
    final desgloseList = rawDesglose
        .map((e) => DesglosePagoModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final transCount = (json['total_transacciones'] as num?)?.toInt() ??
        desgloseList.fold<int>(0, (acc, item) => acc + item.cantidad);

    return ResumenPagosModel(
      efectivoFisico: (json['efectivo_fisico'] as num?)?.toInt() ?? 0,
      canalesElectronicos:
          (json['canales_electronicos'] as num?)?.toInt() ?? 0,
      totalTransacciones: transCount,
      desglose: desgloseList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'efectivo_fisico': efectivoFisico,
      'canales_electronicos': canalesElectronicos,
      'total_transacciones': totalTransacciones,
      'desglose': desglose.map((e) => e.toJson()).toList(),
    };
  }
}

class FlujoOperativoModel {
  final int enPreparacion;
  final int listosMostrador;
  final int enviadosCourier;
  final int alertasSaldoPendiente;
  final int cuellosBotellaPaletizados;

  const FlujoOperativoModel({
    required this.enPreparacion,
    required this.listosMostrador,
    required this.enviadosCourier,
    required this.alertasSaldoPendiente,
    required this.cuellosBotellaPaletizados,
  });

  factory FlujoOperativoModel.fromJson(Map<String, dynamic> json) {
    return FlujoOperativoModel(
      enPreparacion: (json['en_preparacion'] as num?)?.toInt() ?? 0,
      listosMostrador: (json['listos_mostrador'] as num?)?.toInt() ?? 0,
      enviadosCourier: (json['enviados_courier'] as num?)?.toInt() ?? 0,
      alertasSaldoPendiente:
          (json['alertas_saldo_pendiente'] as num?)?.toInt() ?? 0,
      cuellosBotellaPaletizados:
          (json['cuellos_botella_paletizados'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'en_preparacion': enPreparacion,
      'listos_mostrador': listosMostrador,
      'enviados_courier': enviadosCourier,
      'alertas_saldo_pendiente': alertasSaldoPendiente,
      'cuellos_botella_paletizados': cuellosBotellaPaletizados,
    };
  }
}

/// Modelo de Sucursal para el selector dinámico del módulo de Gerencia.
class SucursalGerenciaModel {
  final int idSucursal;
  final String nombreSucursal;
  final bool esCasaMatriz;

  const SucursalGerenciaModel({
    required this.idSucursal,
    required this.nombreSucursal,
    this.esCasaMatriz = false,
  });

  factory SucursalGerenciaModel.fromJson(Map<String, dynamic> json) {
    return SucursalGerenciaModel(
      idSucursal: (json['id_sucursal'] as num?)?.toInt() ?? 0,
      nombreSucursal: json['nombre_sucursal']?.toString() ?? '',
      esCasaMatriz: json['es_casa_matriz'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_sucursal': idSucursal,
      'nombre_sucursal': nombreSucursal,
      'es_casa_matriz': esCasaMatriz,
    };
  }

  /// Título limpio para el selector respetando la identidad de Casa Matriz
  String get tituloDisplay {
    if (esCasaMatriz) {
      if (nombreSucursal.toLowerCase().contains('matriz')) {
        return nombreSucursal;
      }
      return '$nombreSucursal (Casa Matriz)';
    }
    return nombreSucursal;
  }

  /// Subtítulo descriptivo simple sin calles ni exclusividades erróneas
  String get subtituloDisplay {
    if (esCasaMatriz) {
      return 'Casa Matriz';
    }
    return 'Sucursal';
  }
}

// =========================================================================
// MODELOS PREDICTIVOS ML DE VENTAS Y COBERTURA (CRES-282 / CRES-283 / CRES-284)
// =========================================================================

class MetadataModeloModel {
  final String algoritmo;
  final double exactitudWapePct;
  final double wapePromedioPct;
  final double r2Promedio;
  final int? idSucursalFiltro;
  final String semanaProyectadaInicio;
  final double tiempoInferenciaMs;

  const MetadataModeloModel({
    required this.algoritmo,
    required this.exactitudWapePct,
    required this.wapePromedioPct,
    required this.r2Promedio,
    this.idSucursalFiltro,
    required this.semanaProyectadaInicio,
    required this.tiempoInferenciaMs,
  });

  factory MetadataModeloModel.fromJson(Map<String, dynamic> json) {
    return MetadataModeloModel(
      algoritmo: json['algoritmo']?.toString() ?? 'XGBoost Multi-Target',
      exactitudWapePct: (json['exactitud_wape_pct'] as num?)?.toDouble() ?? 0.0,
      wapePromedioPct: (json['wape_promedio_pct'] as num?)?.toDouble() ?? 0.0,
      r2Promedio: (json['r2_promedio'] as num?)?.toDouble() ?? 0.0,
      idSucursalFiltro: (json['id_sucursal_filtro'] as num?)?.toInt(),
      semanaProyectadaInicio:
          json['semana_proyectada_inicio']?.toString() ?? '',
      tiempoInferenciaMs:
          (json['tiempo_inferencia_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'algoritmo': algoritmo,
      'exactitud_wape_pct': exactitudWapePct,
      'wape_promedio_pct': wapePromedioPct,
      'r2_promedio': r2Promedio,
      'id_sucursal_filtro': idSucursalFiltro,
      'semana_proyectada_inicio': semanaProyectadaInicio,
      'tiempo_inferencia_ms': tiempoInferenciaMs,
    };
  }
}

class ProyeccionSemanalItemModel {
  final String semanaInicio;
  final int diasHabiles;
  final double unidadesMotor;
  final int montoMotorClp;
  final double unidadesCaja;
  final int montoCajaClp;
  final double unidadesAccesorio;
  final int montoAccesorioClp;

  const ProyeccionSemanalItemModel({
    required this.semanaInicio,
    required this.diasHabiles,
    required this.unidadesMotor,
    required this.montoMotorClp,
    required this.unidadesCaja,
    required this.montoCajaClp,
    required this.unidadesAccesorio,
    required this.montoAccesorioClp,
  });

  int get ventaTotalClp => montoMotorClp + montoCajaClp + montoAccesorioClp;

  factory ProyeccionSemanalItemModel.fromJson(Map<String, dynamic> json) {
    return ProyeccionSemanalItemModel(
      semanaInicio: json['semana_inicio']?.toString() ?? '',
      diasHabiles: (json['dias_habiles'] as num?)?.toInt() ?? 6,
      unidadesMotor: (json['unidades_motor'] as num?)?.toDouble() ?? 0.0,
      montoMotorClp: (json['monto_motor_clp'] as num?)?.toInt() ?? 0,
      unidadesCaja: (json['unidades_caja'] as num?)?.toDouble() ?? 0.0,
      montoCajaClp: (json['monto_caja_clp'] as num?)?.toInt() ?? 0,
      unidadesAccesorio:
          (json['unidades_accesorio'] as num?)?.toDouble() ?? 0.0,
      montoAccesorioClp: (json['monto_accesorio_clp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'semana_inicio': semanaInicio,
      'dias_habiles': diasHabiles,
      'unidades_motor': unidadesMotor,
      'monto_motor_clp': montoMotorClp,
      'unidades_caja': unidadesCaja,
      'monto_caja_clp': montoCajaClp,
      'unidades_accesorio': unidadesAccesorio,
      'monto_accesorio_clp': montoAccesorioClp,
    };
  }
}

class PrediccionSemanalT1Model {
  final String semanaInicio;
  final int diasHabiles;
  final double unidadesMotor;
  final int montoMotorClp;
  final double unidadesCaja;
  final int montoCajaClp;
  final double unidadesAccesorio;
  final int montoAccesorioClp;
  final int ventaTotalProyectadaClp;
  final String regimenMotor;
  final String regimenCaja;
  final String regimenAccesorio;

  const PrediccionSemanalT1Model({
    required this.semanaInicio,
    required this.diasHabiles,
    required this.unidadesMotor,
    required this.montoMotorClp,
    required this.unidadesCaja,
    required this.montoCajaClp,
    required this.unidadesAccesorio,
    required this.montoAccesorioClp,
    required this.ventaTotalProyectadaClp,
    required this.regimenMotor,
    required this.regimenCaja,
    required this.regimenAccesorio,
  });

  factory PrediccionSemanalT1Model.fromJson(Map<String, dynamic> json) {
    final motorClp = (json['monto_motor_clp'] as num?)?.toInt() ?? 0;
    final cajaClp = (json['monto_caja_clp'] as num?)?.toInt() ?? 0;
    final accClp = (json['monto_accesorio_clp'] as num?)?.toInt() ?? 0;

    return PrediccionSemanalT1Model(
      semanaInicio: json['semana_inicio']?.toString() ?? '',
      diasHabiles: (json['dias_habiles'] as num?)?.toInt() ?? 6,
      unidadesMotor: (json['unidades_motor'] as num?)?.toDouble() ?? 0.0,
      montoMotorClp: motorClp,
      unidadesCaja: (json['unidades_caja'] as num?)?.toDouble() ?? 0.0,
      montoCajaClp: cajaClp,
      unidadesAccesorio:
          (json['unidades_accesorio'] as num?)?.toDouble() ?? 0.0,
      montoAccesorioClp: accClp,
      ventaTotalProyectadaClp:
          (json['venta_total_proyectada_clp'] as num?)?.toInt() ??
          (motorClp + cajaClp + accClp),
      regimenMotor: json['regimen_motor']?.toString() ?? 'Normal',
      regimenCaja: json['regimen_caja']?.toString() ?? 'Normal',
      regimenAccesorio: json['regimen_accesorio']?.toString() ?? 'Normal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'semana_inicio': semanaInicio,
      'dias_habiles': diasHabiles,
      'unidades_motor': unidadesMotor,
      'monto_motor_clp': montoMotorClp,
      'unidades_caja': unidadesCaja,
      'monto_caja_clp': montoCajaClp,
      'unidades_accesorio': unidadesAccesorio,
      'monto_accesorio_clp': montoAccesorioClp,
      'venta_total_proyectada_clp': ventaTotalProyectadaClp,
      'regimen_motor': regimenMotor,
      'regimen_caja': regimenCaja,
      'regimen_accesorio': regimenAccesorio,
    };
  }
}

class ProyeccionMensual4SemanasModel {
  final double unidadesMotor;
  final int montoMotorClp;
  final double unidadesCaja;
  final int montoCajaClp;
  final double unidadesAccesorio;
  final int montoAccesorioClp;
  final int ventaTotalProyectadaClp;
  final List<ProyeccionSemanalItemModel> desgloseSemanal;

  const ProyeccionMensual4SemanasModel({
    required this.unidadesMotor,
    required this.montoMotorClp,
    required this.unidadesCaja,
    required this.montoCajaClp,
    required this.unidadesAccesorio,
    required this.montoAccesorioClp,
    required this.ventaTotalProyectadaClp,
    required this.desgloseSemanal,
  });

  factory ProyeccionMensual4SemanasModel.fromJson(Map<String, dynamic> json) {
    final motorClp = (json['monto_motor_clp'] as num?)?.toInt() ?? 0;
    final cajaClp = (json['monto_caja_clp'] as num?)?.toInt() ?? 0;
    final accClp = (json['monto_accesorio_clp'] as num?)?.toInt() ?? 0;
    final rawDesglose = json['desglose_semanal'] as List<dynamic>? ?? [];

    return ProyeccionMensual4SemanasModel(
      unidadesMotor: (json['unidades_motor'] as num?)?.toDouble() ?? 0.0,
      montoMotorClp: motorClp,
      unidadesCaja: (json['unidades_caja'] as num?)?.toDouble() ?? 0.0,
      montoCajaClp: cajaClp,
      unidadesAccesorio:
          (json['unidades_accesorio'] as num?)?.toDouble() ?? 0.0,
      montoAccesorioClp: accClp,
      ventaTotalProyectadaClp:
          (json['venta_total_proyectada_clp'] as num?)?.toInt() ??
          (motorClp + cajaClp + accClp),
      desgloseSemanal: rawDesglose
          .map(
            (e) =>
                ProyeccionSemanalItemModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unidades_motor': unidadesMotor,
      'monto_motor_clp': montoMotorClp,
      'unidades_caja': unidadesCaja,
      'monto_caja_clp': montoCajaClp,
      'unidades_accesorio': unidadesAccesorio,
      'monto_accesorio_clp': montoAccesorioClp,
      'venta_total_proyectada_clp': ventaTotalProyectadaClp,
      'desglose_semanal': desgloseSemanal.map((e) => e.toJson()).toList(),
    };
  }
}

class MixPorcentualVentasModel {
  final double motorPct;
  final double cajaPct;
  final double accesorioPct;

  const MixPorcentualVentasModel({
    required this.motorPct,
    required this.cajaPct,
    required this.accesorioPct,
  });

  factory MixPorcentualVentasModel.fromJson(Map<String, dynamic> json) {
    return MixPorcentualVentasModel(
      motorPct: (json['motor_pct'] as num?)?.toDouble() ?? 0.0,
      cajaPct: (json['caja_pct'] as num?)?.toDouble() ?? 0.0,
      accesorioPct: (json['accesorio_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'motor_pct': motorPct,
      'caja_pct': cajaPct,
      'accesorio_pct': accesorioPct,
    };
  }
}

class CoberturaStockCriticoItemModel {
  final int idCategoria;
  final String categoria;
  final int stockDisponibleTasado;
  final int stockPaletizadoSinTasar;
  final int stockEnDesarme;
  final int stockEnProcesoInterno;
  final int stockTotalDisponible;
  final int stockVinaDelMar;
  final int stockLimache;
  final int stockDisponibleVina;
  final int stockDisponibleLimache;
  final int stockProcesoVina;
  final int stockProcesoLimache;
  final int paletizadoVina;
  final int paletizadoLimache;
  final int desarmeVina;
  final int desarmeLimache;
  final int backordersPendientes;
  final double demandaPredichaSemanal;
  final double demandaPredichaMensual4Sem;
  final int requerimientoTotal;
  final int balanceUnidades;
  final int deficitNetoCompra;
  final double semanasCobertura;
  final String estadoAlerta;
  final String recomendacionAccionable;
  final int requerimientoTotalMensual4Sem;
  final int balanceUnidadesMensual4Sem;
  final int deficitNetoCompraMensual4Sem;
  final String estadoAlertaMensual4Sem;
  final String recomendacionAccionableMensual4Sem;
  final int precioReferenciaPromedio;
  final int precioReferenciaMin;
  final int precioReferenciaMax;

  const CoberturaStockCriticoItemModel({
    required this.idCategoria,
    required this.categoria,
    required this.stockDisponibleTasado,
    required this.stockPaletizadoSinTasar,
    this.stockEnDesarme = 0,
    this.stockEnProcesoInterno = 0,
    required this.stockTotalDisponible,
    required this.stockVinaDelMar,
    required this.stockLimache,
    this.stockDisponibleVina = 0,
    this.stockDisponibleLimache = 0,
    this.stockProcesoVina = 0,
    this.stockProcesoLimache = 0,
    this.paletizadoVina = 0,
    this.paletizadoLimache = 0,
    this.desarmeVina = 0,
    this.desarmeLimache = 0,
    required this.backordersPendientes,
    required this.demandaPredichaSemanal,
    required this.demandaPredichaMensual4Sem,
    this.requerimientoTotal = 0,
    required this.balanceUnidades,
    this.deficitNetoCompra = 0,
    required this.semanasCobertura,
    required this.estadoAlerta,
    this.recomendacionAccionable = '',
    this.requerimientoTotalMensual4Sem = 0,
    this.balanceUnidadesMensual4Sem = 0,
    this.deficitNetoCompraMensual4Sem = 0,
    this.estadoAlertaMensual4Sem = 'Cobertura Óptima',
    this.recomendacionAccionableMensual4Sem = '',
    this.precioReferenciaPromedio = 0,
    this.precioReferenciaMin = 0,
    this.precioReferenciaMax = 0,
  });

  factory CoberturaStockCriticoItemModel.fromJson(Map<String, dynamic> json) {
    final stockVitrina =
        (json['stock_disponible_tasado'] as num?)?.toInt() ?? 0;
    final stockPal =
        (json['stock_paletizado_sin_tasar'] as num?)?.toInt() ?? 0;
    final stockDes = (json['stock_en_desarme'] as num?)?.toInt() ?? 0;
    final stockProceso =
        (json['stock_en_proceso_interno'] as num?)?.toInt() ??
        (stockPal + stockDes);
    final backorders = (json['backorders_pendientes'] as num?)?.toInt() ?? 0;
    final demSem = (json['demanda_predicha_semanal'] as num?)?.toDouble() ?? 0.0;
    final dem4Sem =
        (json['demanda_predicha_mensual_4sem'] as num?)?.toDouble() ?? 0.0;
    final reqSem =
        (json['requerimiento_total'] as num?)?.toInt() ??
        (demSem.ceil() + backorders);
    final req4Sem =
        (json['requerimiento_total_mensual_4sem'] as num?)?.toInt() ??
        (dem4Sem.ceil() + backorders);
    final balSem =
        (json['balance_unidades'] as num?)?.toInt() ??
        (stockVitrina - reqSem);
    final bal4Sem =
        (json['balance_unidades_mensual_4sem'] as num?)?.toInt() ??
        (stockVitrina - req4Sem);
    final respaldo = stockVitrina + stockProceso;
    final defSem =
        (json['deficit_neto_compra'] as num?)?.toInt() ??
        (reqSem > respaldo ? reqSem - respaldo : 0);
    final def4Sem =
        (json['deficit_neto_compra_mensual_4sem'] as num?)?.toInt() ??
        (req4Sem > respaldo ? req4Sem - respaldo : 0);
    final estadoSem =
        json['estado_alerta']?.toString() ?? 'Cobertura Óptima';
    final estado4Sem =
        json['estado_alerta_mensual_4sem']?.toString() ??
        (bal4Sem >= 0
            ? 'Cobertura Óptima'
            : (respaldo >= req4Sem
                ? 'Atención / En Proceso'
                : 'Déficit Crítico'));

    return CoberturaStockCriticoItemModel(
      idCategoria: (json['id_categoria'] as num?)?.toInt() ?? 0,
      categoria: json['categoria']?.toString() ?? '',
      stockDisponibleTasado: stockVitrina,
      stockPaletizadoSinTasar: stockPal,
      stockEnDesarme: stockDes,
      stockEnProcesoInterno: stockProceso,
      stockTotalDisponible:
          (json['stock_total_disponible'] as num?)?.toInt() ?? 0,
      stockVinaDelMar: (json['stock_vina_del_mar'] as num?)?.toInt() ?? 0,
      stockLimache: (json['stock_limache'] as num?)?.toInt() ?? 0,
      stockDisponibleVina:
          (json['stock_disponible_vina'] as num?)?.toInt() ?? 0,
      stockDisponibleLimache:
          (json['stock_disponible_limache'] as num?)?.toInt() ?? 0,
      stockProcesoVina: (json['stock_proceso_vina'] as num?)?.toInt() ?? 0,
      stockProcesoLimache:
          (json['stock_proceso_limache'] as num?)?.toInt() ?? 0,
      paletizadoVina: (json['paletizado_vina'] as num?)?.toInt() ?? 0,
      paletizadoLimache: (json['paletizado_limache'] as num?)?.toInt() ?? 0,
      desarmeVina: (json['desarme_vina'] as num?)?.toInt() ?? 0,
      desarmeLimache: (json['desarme_limache'] as num?)?.toInt() ?? 0,
      backordersPendientes: backorders,
      demandaPredichaSemanal: demSem,
      demandaPredichaMensual4Sem: dem4Sem,
      requerimientoTotal: reqSem,
      balanceUnidades: balSem,
      deficitNetoCompra: defSem,
      semanasCobertura: (json['semanas_cobertura'] as num?)?.toDouble() ?? 0.0,
      estadoAlerta: estadoSem,
      recomendacionAccionable:
          json['recomendacion_accionable']?.toString() ?? '',
      requerimientoTotalMensual4Sem: req4Sem,
      balanceUnidadesMensual4Sem: bal4Sem,
      deficitNetoCompraMensual4Sem: def4Sem,
      estadoAlertaMensual4Sem: estado4Sem,
      recomendacionAccionableMensual4Sem:
          json['recomendacion_accionable_mensual_4sem']?.toString() ?? '',
      precioReferenciaPromedio:
          (json['precio_referencia_promedio'] as num?)?.toInt() ?? 0,
      precioReferenciaMin:
          (json['precio_referencia_min'] as num?)?.toInt() ?? 0,
      precioReferenciaMax:
          (json['precio_referencia_max'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_categoria': idCategoria,
      'categoria': categoria,
      'stock_disponible_tasado': stockDisponibleTasado,
      'stock_paletizado_sin_tasar': stockPaletizadoSinTasar,
      'stock_en_desarme': stockEnDesarme,
      'stock_en_proceso_interno': stockEnProcesoInterno,
      'stock_total_disponible': stockTotalDisponible,
      'stock_vina_del_mar': stockVinaDelMar,
      'stock_limache': stockLimache,
      'stock_disponible_vina': stockDisponibleVina,
      'stock_disponible_limache': stockDisponibleLimache,
      'stock_proceso_vina': stockProcesoVina,
      'stock_proceso_limache': stockProcesoLimache,
      'paletizado_vina': paletizadoVina,
      'paletizado_limache': paletizadoLimache,
      'desarme_vina': desarmeVina,
      'desarme_limache': desarmeLimache,
      'backorders_pendientes': backordersPendientes,
      'demanda_predicha_semanal': demandaPredichaSemanal,
      'demanda_predicha_mensual_4sem': demandaPredichaMensual4Sem,
      'requerimiento_total': requerimientoTotal,
      'balance_unidades': balanceUnidades,
      'deficit_neto_compra': deficitNetoCompra,
      'semanas_cobertura': semanasCobertura,
      'estado_alerta': estadoAlerta,
      'recomendacion_accionable': recomendacionAccionable,
      'requerimiento_total_mensual_4sem': requerimientoTotalMensual4Sem,
      'balance_unidades_mensual_4sem': balanceUnidadesMensual4Sem,
      'deficit_neto_compra_mensual_4sem': deficitNetoCompraMensual4Sem,
      'estado_alerta_mensual_4sem': estadoAlertaMensual4Sem,
      'recomendacion_accionable_mensual_4sem':
          recomendacionAccionableMensual4Sem,
      'precio_referencia_promedio': precioReferenciaPromedio,
      'precio_referencia_min': precioReferenciaMin,
      'precio_referencia_max': precioReferenciaMax,
    };
  }
}

class DesgloseDemandaCategoriaModel {
  final int idCategoria;
  final String categoria;
  final int unidadesStockFisico;
  final int unidadesBackorder;
  final int unidadesTotalesMes;

  const DesgloseDemandaCategoriaModel({
    required this.idCategoria,
    required this.categoria,
    required this.unidadesStockFisico,
    required this.unidadesBackorder,
    required this.unidadesTotalesMes,
  });

  double get porcentajeStockFisico {
    if (unidadesTotalesMes <= 0) return 0.0;
    return (unidadesStockFisico / unidadesTotalesMes) * 100.0;
  }

  double get porcentajeBackorder {
    if (unidadesTotalesMes <= 0) return 0.0;
    return (unidadesBackorder / unidadesTotalesMes) * 100.0;
  }

  factory DesgloseDemandaCategoriaModel.fromJson(Map<String, dynamic> json) {
    final fisico = (json['unidades_stock_fisico'] as num?)?.toInt() ?? 0;
    final backorder = (json['unidades_backorder'] as num?)?.toInt() ?? 0;
    final total =
        (json['unidades_totales_mes'] as num?)?.toInt() ?? (fisico + backorder);

    return DesgloseDemandaCategoriaModel(
      idCategoria: (json['id_categoria'] as num?)?.toInt() ?? 0,
      categoria: json['categoria']?.toString() ?? '',
      unidadesStockFisico: fisico,
      unidadesBackorder: backorder,
      unidadesTotalesMes: total,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_categoria': idCategoria,
      'categoria': categoria,
      'unidades_stock_fisico': unidadesStockFisico,
      'unidades_backorder': unidadesBackorder,
      'unidades_totales_mes': unidadesTotalesMes,
    };
  }
}

class HistorialSemanalItemModel {
  final String semanaInicio;
  final double unidadesMotor;
  final int montoMotorClp;
  final double unidadesCaja;
  final int montoCajaClp;
  final double unidadesAccesorio;
  final int montoAccesorioClp;
  final int ventaTotalClp;

  const HistorialSemanalItemModel({
    required this.semanaInicio,
    required this.unidadesMotor,
    required this.montoMotorClp,
    required this.unidadesCaja,
    required this.montoCajaClp,
    required this.unidadesAccesorio,
    required this.montoAccesorioClp,
    required this.ventaTotalClp,
  });

  factory HistorialSemanalItemModel.fromJson(Map<String, dynamic> json) {
    final motorClp = (json['monto_motor_clp'] as num?)?.toInt() ?? 0;
    final cajaClp = (json['monto_caja_clp'] as num?)?.toInt() ?? 0;
    final accClp = (json['monto_accesorio_clp'] as num?)?.toInt() ?? 0;

    return HistorialSemanalItemModel(
      semanaInicio: json['semana_inicio']?.toString() ?? '',
      unidadesMotor: (json['unidades_motor'] as num?)?.toDouble() ?? 0.0,
      montoMotorClp: motorClp,
      unidadesCaja: (json['unidades_caja'] as num?)?.toDouble() ?? 0.0,
      montoCajaClp: cajaClp,
      unidadesAccesorio:
          (json['unidades_accesorio'] as num?)?.toDouble() ?? 0.0,
      montoAccesorioClp: accClp,
      ventaTotalClp:
          (json['venta_total_clp'] as num?)?.toInt() ??
          (motorClp + cajaClp + accClp),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'semana_inicio': semanaInicio,
      'unidades_motor': unidadesMotor,
      'monto_motor_clp': montoMotorClp,
      'unidades_caja': unidadesCaja,
      'monto_caja_clp': montoCajaClp,
      'unidades_accesorio': unidadesAccesorio,
      'monto_accesorio_clp': montoAccesorioClp,
      'venta_total_clp': ventaTotalClp,
    };
  }
}

class PredictionDashboardModel {
  final MetadataModeloModel metadataModelo;
  final PrediccionSemanalT1Model prediccionSemanalT1;
  final ProyeccionMensual4SemanasModel proyeccionMensual4Semanas;
  final MixPorcentualVentasModel mixPorcentualVentas;
  final List<CoberturaStockCriticoItemModel> coberturaStockCritico;
  final List<HistorialSemanalItemModel> historialReciente8Semanas;
  final List<DesgloseDemandaCategoriaModel> desgloseDemandaUltimoMes;

  const PredictionDashboardModel({
    required this.metadataModelo,
    required this.prediccionSemanalT1,
    required this.proyeccionMensual4Semanas,
    required this.mixPorcentualVentas,
    required this.coberturaStockCritico,
    required this.historialReciente8Semanas,
    this.desgloseDemandaUltimoMes = const [],
  });

  factory PredictionDashboardModel.fromJson(Map<String, dynamic> json) {
    final rawCob = json['cobertura_stock_critico'] as List<dynamic>? ?? [];
    final rawHist =
        json['historial_reciente_8_semanas'] as List<dynamic>? ?? [];
    final rawDesglose =
        json['desglose_demanda_ultimo_mes'] as List<dynamic>? ?? [];

    return PredictionDashboardModel(
      metadataModelo: MetadataModeloModel.fromJson(
        (json['metadata_modelo'] as Map<String, dynamic>?) ?? const {},
      ),
      prediccionSemanalT1: PrediccionSemanalT1Model.fromJson(
        (json['prediccion_semanal_t1'] as Map<String, dynamic>?) ?? const {},
      ),
      proyeccionMensual4Semanas: ProyeccionMensual4SemanasModel.fromJson(
        (json['proyeccion_mensual_4_semanas'] as Map<String, dynamic>?) ??
            const {},
      ),
      mixPorcentualVentas: MixPorcentualVentasModel.fromJson(
        (json['mix_porcentual_ventas'] as Map<String, dynamic>?) ?? const {},
      ),
      coberturaStockCritico: rawCob
          .map(
            (e) => CoberturaStockCriticoItemModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      historialReciente8Semanas: rawHist
          .map(
            (e) =>
                HistorialSemanalItemModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      desgloseDemandaUltimoMes: rawDesglose
          .map(
            (e) => DesgloseDemandaCategoriaModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metadata_modelo': metadataModelo.toJson(),
      'prediccion_semanal_t1': prediccionSemanalT1.toJson(),
      'proyeccion_mensual_4_semanas': proyeccionMensual4Semanas.toJson(),
      'mix_porcentual_ventas': mixPorcentualVentas.toJson(),
      'cobertura_stock_critico': coberturaStockCritico
          .map((e) => e.toJson())
          .toList(),
      'historial_reciente_8_semanas': historialReciente8Semanas
          .map((e) => e.toJson())
          .toList(),
      'desglose_demanda_ultimo_mes': desgloseDemandaUltimoMes
          .map((e) => e.toJson())
          .toList(),
    };
  }
}

