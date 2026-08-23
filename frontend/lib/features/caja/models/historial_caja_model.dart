/// Modelos de datos para el Historial de Órdenes y Auditoría de Caja (SPEC-HU-4.5 / CRES-217).
library;

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

  Map<String, dynamic> toJson() => {
        'id_transaccion': idTransaccion,
        'metodo_pago': metodoPago,
        'monto': monto,
        'fecha_pago': fechaPago?.toIso8601String(),
      };
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

  Map<String, dynamic> toJson() => {
        'cantidad': cantidad,
        'tipo': tipo,
        'descripcion': descripcion,
        'sku': sku,
        'precio': precio,
        'subtotal': subtotal,
      };
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

  Map<String, dynamic> toJson() => {
        'hora': hora,
        'evento': evento,
      };
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

  Map<String, dynamic> toJson() => {
        'total_recaudado': totalRecaudado,
        'total_ordenes_pagadas': totalOrdenesPagadas,
        'total_efectivo': totalEfectivo,
        'total_pos': totalPos,
        'total_debito': totalDebito,
        'total_credito': totalCredito,
        'total_transferencia': totalTransferencia,
        'total_cheque': totalCheque,
      };
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

  bool get esPagada => estadoOrden == 'Pagada';
  bool get esDespachada => estadoOrden == 'Despachada';
  bool get esAnulada => estadoOrden == 'Anulada';
  bool get esSplit => modalidadPago.toLowerCase() == 'split';

  factory HistorialOrdenItemModel.fromJson(Map<String, dynamic> json) =>
      HistorialOrdenItemModel(
        idOrden: json['id_orden'] as String? ?? '',
        folio: json['folio'] as String? ?? '',
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

  Map<String, dynamic> toJson() => {
        'id_orden': idOrden,
        'folio': folio,
        'tipo_operacion': tipoOperacion,
        'emite_qr': emiteQr,
        'fecha_iso': fechaIso,
        'hora': hora,
        'fecha_hora_formateada': fechaHoraFormateada,
        'cliente_nombre': clienteNombre,
        'cliente_rut': clienteRut,
        'vendedor_nombre': vendedorNombre,
        'cajera_nombre': cajeraNombre,
        'estado_orden': estadoOrden,
        'modalidad_pago': modalidadPago,
        'metodos_resumen': metodosResumen,
        'total_venta': totalVenta,
        'abono_previo': abonoPrevio,
        'total_liquidado': totalLiquidado,
        'desglose_pagos': desglosePagos.map((e) => e.toJson()).toList(),
        'articulos': articulos.map((e) => e.toJson()).toList(),
        'historial_movimientos':
            historialMovimientos.map((e) => e.toJson()).toList(),
      };
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

  factory HistorialCajaResponseModel.empty() => HistorialCajaResponseModel(
        totalRegistros: 0,
        paginaActual: 1,
        limitePorPagina: 20,
        totalPaginas: 1,
        resumenCuadre: ResumenCuadreCajaModel.empty(),
        items: [],
      );

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

  Map<String, dynamic> toJson() => {
        'total_registros': totalRegistros,
        'pagina_actual': paginaActual,
        'limite_por_pagina': limitePorPagina,
        'total_paginas': totalPaginas,
        'resumen_cuadre': resumenCuadre.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
      };
}
