// frontend/lib/features/gerencia/models/backorder_gerencia_models.dart
// Modelos de datos para el Visor Centralizado de Supervisión de Backorders (HU-5.4).

class BackorderItemModel {
  final String idReserva;
  final String folio;
  final String fechaCreacion;
  final String fechaCreacionIso;
  final String idCliente;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteRut;
  final String idVendedor;
  final String vendedorNombre;
  final int idSucursal;
  final String sucursalNombre;
  final int idCategoriaRequerida;
  final String categoriaNombre;
  final String marcaRequerida;
  final String modeloRequerido;
  final int? anioRequerido;
  final String? cilindradaRequerida;
  final String? combustibleRequerido;
  final String? transmisionRequerida;
  final String? notasPreparacion;
  final int precioAcordado;
  final int descuento;
  final int montoAbonado;
  final int saldoPendiente;
  final String estadoReserva;
  final String? idActivoAsignado;
  final String? activoAsignadoSku;
  final String? idOrden;
  final String? ordenFolio;
  final String? estadoOrden;

  const BackorderItemModel({
    required this.idReserva,
    required this.folio,
    required this.fechaCreacion,
    required this.fechaCreacionIso,
    required this.idCliente,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteRut,
    required this.idVendedor,
    required this.vendedorNombre,
    required this.idSucursal,
    required this.sucursalNombre,
    required this.idCategoriaRequerida,
    required this.categoriaNombre,
    required this.marcaRequerida,
    required this.modeloRequerido,
    this.anioRequerido,
    this.cilindradaRequerida,
    this.combustibleRequerido,
    this.transmisionRequerida,
    this.notasPreparacion,
    required this.precioAcordado,
    this.descuento = 0,
    required this.montoAbonado,
    required this.saldoPendiente,
    required this.estadoReserva,
    this.idActivoAsignado,
    this.activoAsignadoSku,
    this.idOrden,
    this.ordenFolio,
    this.estadoOrden,
  });

  factory BackorderItemModel.fromJson(Map<String, dynamic> json) {
    return BackorderItemModel(
      idReserva: json['id_reserva']?.toString() ?? '',
      folio: json['folio']?.toString() ?? '',
      fechaCreacion: json['fecha_creacion']?.toString() ?? '',
      fechaCreacionIso: json['fecha_creacion_iso']?.toString() ?? '',
      idCliente: json['id_cliente']?.toString() ?? '',
      clienteNombre: json['cliente_nombre']?.toString() ?? 'Cliente',
      clienteTelefono: json['cliente_telefono']?.toString(),
      clienteRut: json['cliente_rut']?.toString(),
      idVendedor: json['id_vendedor']?.toString() ?? '',
      vendedorNombre: json['vendedor_nombre']?.toString() ?? 'Vendedor',
      idSucursal: (json['id_sucursal'] as num?)?.toInt() ?? 0,
      sucursalNombre: json['sucursal_nombre']?.toString() ?? 'Sucursal',
      idCategoriaRequerida: (json['id_categoria_requerida'] as num?)?.toInt() ?? 1,
      categoriaNombre: json['categoria_nombre']?.toString() ?? 'Pieza',
      marcaRequerida: json['marca_requerida']?.toString() ?? '',
      modeloRequerido: json['modelo_requerido']?.toString() ?? '',
      anioRequerido: (json['anio_requerido'] as num?)?.toInt(),
      cilindradaRequerida: json['cilindrada_requerida']?.toString(),
      combustibleRequerido: json['combustible_requerido']?.toString(),
      transmisionRequerida: json['transmision_requerida']?.toString(),
      notasPreparacion: json['notas_preparacion']?.toString(),
      precioAcordado: (json['precio_acordado'] as num?)?.toInt() ?? 0,
      descuento: (json['descuento'] as num?)?.toInt() ?? 0,
      montoAbonado: (json['monto_abonado'] as num?)?.toInt() ?? 0,
      saldoPendiente: (json['saldo_pendiente'] as num?)?.toInt() ?? 0,
      estadoReserva: json['estado_reserva']?.toString() ?? 'Pendiente',
      idActivoAsignado: json['id_activo_asignado']?.toString(),
      activoAsignadoSku: json['activo_asignado_sku']?.toString(),
      idOrden: json['id_orden']?.toString(),
      ordenFolio: json['orden_folio']?.toString(),
      estadoOrden: json['estado_orden']?.toString(),
    );
  }
}

class BackordersKpisModel {
  final int totalActivos;
  final int capitalRetenido;
  final int listosParaLiquidar;
  final int totalRegistrados;
  final int totalRecaudadoSenas;

  const BackordersKpisModel({
    required this.totalActivos,
    required this.capitalRetenido,
    required this.listosParaLiquidar,
    required this.totalRegistrados,
    required this.totalRecaudadoSenas,
  });

  factory BackordersKpisModel.fromJson(Map<String, dynamic> json) {
    return BackordersKpisModel(
      totalActivos: (json['total_activos'] as num?)?.toInt() ?? 0,
      capitalRetenido: (json['capital_retenido'] as num?)?.toInt() ?? 0,
      listosParaLiquidar: (json['listos_para_liquidar'] as num?)?.toInt() ?? 0,
      totalRegistrados: (json['total_registrados'] as num?)?.toInt() ?? 0,
      totalRecaudadoSenas: (json['total_recaudado_senas'] as num?)?.toInt() ?? 0,
    );
  }

  factory BackordersKpisModel.empty() {
    return const BackordersKpisModel(
      totalActivos: 0,
      capitalRetenido: 0,
      listosParaLiquidar: 0,
      totalRegistrados: 0,
      totalRecaudadoSenas: 0,
    );
  }
}

class PaginatedBackordersResponse {
  final List<BackorderItemModel> items;
  final int totalCount;
  final int totalRecaudadoSenas;

  const PaginatedBackordersResponse({
    required this.items,
    required this.totalCount,
    required this.totalRecaudadoSenas,
  });

  factory PaginatedBackordersResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] as List<dynamic>? ?? [];
    return PaginatedBackordersResponse(
      items: rawList
          .map((e) => BackorderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      totalRecaudadoSenas: (json['total_recaudado_senas'] as num?)?.toInt() ?? 0,
    );
  }
}

class BackorderMovimientoModel {
  final String hora;
  final String evento;

  const BackorderMovimientoModel({
    required this.hora,
    required this.evento,
  });

  factory BackorderMovimientoModel.fromJson(Map<String, dynamic> json) {
    return BackorderMovimientoModel(
      hora: json['hora']?.toString() ?? '',
      evento: json['evento']?.toString() ?? '',
    );
  }
}

class BackorderPagoDetalleModel {
  final String? idTransaccion;
  final String metodoPago;
  final int monto;
  final String? fechaPago;
  final String? cajeroNombre;

  const BackorderPagoDetalleModel({
    this.idTransaccion,
    required this.metodoPago,
    required this.monto,
    this.fechaPago,
    this.cajeroNombre,
  });

  factory BackorderPagoDetalleModel.fromJson(Map<String, dynamic> json) {
    return BackorderPagoDetalleModel(
      idTransaccion: json['id_transaccion']?.toString(),
      metodoPago: json['metodo_pago']?.toString() ?? 'Efectivo',
      monto: (json['monto'] as num?)?.toInt() ?? 0,
      fechaPago: json['fecha_pago']?.toString(),
      cajeroNombre: json['cajero_nombre']?.toString(),
    );
  }
}

class BackorderAuditoriaModel {
  final String idReserva;
  final String folio;
  final String fechaCreacion;
  final String fechaCreacionIso;
  final String estadoReserva;

  final String? idOrden;
  final String? ordenFolio;
  final String? estadoOrden;

  final String idCliente;
  final String clienteNombre;
  final String? clienteRut;
  final String? clienteTelefono;
  final String? clienteCorreo;

  final String idVendedor;
  final String vendedorNombre;
  final int idSucursal;
  final String sucursalNombre;

  final int idCategoriaRequerida;
  final String categoriaNombre;
  final String marcaRequerida;
  final String modeloRequerido;
  final int? anioRequerido;
  final String? cilindradaRequerida;
  final String? combustibleRequerido;
  final String? transmisionRequerida;
  final String? notasPreparacion;

  final int precioAcordado;
  final int descuento;
  final int montoAbonado;
  final int saldoPendiente;

  final String? idActivoAsignado;
  final String? activoAsignadoSku;
  final String? vehiculoDonanteIngreso;
  final String? vehiculoDonantePatente;
  final String? vehiculoDonanteDescripcion;

  final List<BackorderPagoDetalleModel> desglosePagos;
  final List<BackorderMovimientoModel> movimientos;

  const BackorderAuditoriaModel({
    required this.idReserva,
    required this.folio,
    required this.fechaCreacion,
    required this.fechaCreacionIso,
    required this.estadoReserva,
    this.idOrden,
    this.ordenFolio,
    this.estadoOrden,
    required this.idCliente,
    required this.clienteNombre,
    this.clienteRut,
    this.clienteTelefono,
    this.clienteCorreo,
    required this.idVendedor,
    required this.vendedorNombre,
    required this.idSucursal,
    required this.sucursalNombre,
    required this.idCategoriaRequerida,
    required this.categoriaNombre,
    required this.marcaRequerida,
    required this.modeloRequerido,
    this.anioRequerido,
    this.cilindradaRequerida,
    this.combustibleRequerido,
    this.transmisionRequerida,
    this.notasPreparacion,
    required this.precioAcordado,
    this.descuento = 0,
    required this.montoAbonado,
    required this.saldoPendiente,
    this.idActivoAsignado,
    this.activoAsignadoSku,
    this.vehiculoDonanteIngreso,
    this.vehiculoDonantePatente,
    this.vehiculoDonanteDescripcion,
    this.desglosePagos = const [],
    this.movimientos = const [],
  });

  factory BackorderAuditoriaModel.fromJson(Map<String, dynamic> json) {
    final rawPagos = json['desglose_pagos'] as List<dynamic>? ?? [];
    final rawMovs = json['movimientos'] as List<dynamic>? ?? [];

    return BackorderAuditoriaModel(
      idReserva: json['id_reserva']?.toString() ?? '',
      folio: json['folio']?.toString() ?? '',
      fechaCreacion: json['fecha_creacion']?.toString() ?? '',
      fechaCreacionIso: json['fecha_creacion_iso']?.toString() ?? '',
      estadoReserva: json['estado_reserva']?.toString() ?? 'Pendiente',
      idOrden: json['id_orden']?.toString(),
      ordenFolio: json['orden_folio']?.toString(),
      estadoOrden: json['estado_orden']?.toString(),
      idCliente: json['id_cliente']?.toString() ?? '',
      clienteNombre: json['cliente_nombre']?.toString() ?? 'Cliente',
      clienteRut: json['cliente_rut']?.toString(),
      clienteTelefono: json['cliente_telefono']?.toString(),
      clienteCorreo: json['cliente_correo']?.toString(),
      idVendedor: json['id_vendedor']?.toString() ?? '',
      vendedorNombre: json['vendedor_nombre']?.toString() ?? 'Vendedor',
      idSucursal: (json['id_sucursal'] as num?)?.toInt() ?? 0,
      sucursalNombre: json['sucursal_nombre']?.toString() ?? 'Sucursal',
      idCategoriaRequerida: (json['id_categoria_requerida'] as num?)?.toInt() ?? 1,
      categoriaNombre: json['categoria_nombre']?.toString() ?? 'Repuesto',
      marcaRequerida: json['marca_requerida']?.toString() ?? '',
      modeloRequerido: json['modelo_requerido']?.toString() ?? '',
      anioRequerido: (json['anio_requerido'] as num?)?.toInt(),
      cilindradaRequerida: json['cilindrada_requerida']?.toString(),
      combustibleRequerido: json['combustible_requerido']?.toString(),
      transmisionRequerida: json['transmision_requerida']?.toString(),
      notasPreparacion: json['notas_preparacion']?.toString(),
      precioAcordado: (json['precio_acordado'] as num?)?.toInt() ?? 0,
      descuento: (json['descuento'] as num?)?.toInt() ?? 0,
      montoAbonado: (json['monto_abonado'] as num?)?.toInt() ?? 0,
      saldoPendiente: (json['saldo_pendiente'] as num?)?.toInt() ?? 0,
      idActivoAsignado: json['id_activo_asignado']?.toString(),
      activoAsignadoSku: json['activo_asignado_sku']?.toString(),
      vehiculoDonanteIngreso: json['vehiculo_donante_ingreso']?.toString(),
      vehiculoDonantePatente: json['vehiculo_donante_patente']?.toString(),
      vehiculoDonanteDescripcion: json['vehiculo_donante_descripcion']?.toString(),
      desglosePagos: rawPagos
          .map((p) => BackorderPagoDetalleModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      movimientos: rawMovs
          .map((m) => BackorderMovimientoModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

