/// DTOs tipados para la Bandeja de Órdenes Pendientes y Cobros de Caja (SPEC-HU-4.2 / CRES-214).
library;

class ArticuloResumenModel {
  final int cantidad;
  final String tipo; // 'INVENTARIADO' | 'DESARME'
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

  factory ArticuloResumenModel.fromJson(Map<String, dynamic> json) =>
      ArticuloResumenModel(
        cantidad: json['cantidad'] as int? ?? 1,
        tipo: json['tipo'] as String? ?? 'DESARME',
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

  factory BackorderEspecificacionesModel.fromJson(Map<String, dynamic> json) =>
      BackorderEspecificacionesModel(
        marca: json['marca'] as String? ?? '',
        modelo: json['modelo'] as String? ?? '',
        anio: json['anio'] as int?,
        categoria: json['categoria'] as String? ?? '',
        cilindrada: json['cilindrada'] as String?,
        combustible: json['combustible'] as String?,
        transito: json['transito'] as String? ?? 'En Tránsito',
      );

  Map<String, dynamic> toJson() => {
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
        'categoria': categoria,
        'cilindrada': cilindrada,
        'combustible': combustible,
        'transito': transito,
      };
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

  factory CobroPendienteModel.fromJson(Map<String, dynamic> json) =>
      CobroPendienteModel(
        idReferencia: json['id_referencia']?.toString() ?? '',
        folioDocumento: json['folio_documento'] as String? ?? '',
        tipoOperacion: (json['tipo_operacion'] as String? ?? 'VENTA').toUpperCase(),
        estadoDocumento: json['estado_documento'] as String? ?? 'Pendiente',
        clienteNombre: json['cliente_nombre'] as String? ?? 'Cliente',
        clienteRut: json['cliente_rut'] as String? ?? '',
        vendedorNombre: json['vendedor_nombre'] as String? ?? 'Vendedor',
        fechaEmision: json['fecha_emision'] != null
            ? DateTime.tryParse(json['fecha_emision'] as String) ?? DateTime.now()
            : DateTime.now(),
        fechaEmisionFormateada: json['fecha_emision_formateada'] as String? ?? '',
        horaEmisionFormateada: json['hora_emision_formateada'] as String? ?? '',
        totalOperacion: json['total_operacion'] as int? ?? 0,
        abonoPrevio: json['abono_previo'] as int? ?? 0,
        montoACobrar: json['monto_a_cobrar'] as int? ?? 0,
        articulos: (json['articulos'] as List<dynamic>?)
                ?.map((e) =>
                    ArticuloResumenModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        especificacionesBackorder: json['especificaciones_backorder'] != null
            ? BackorderEspecificacionesModel.fromJson(
                json['especificaciones_backorder'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id_referencia': idReferencia,
        'folio_documento': folioDocumento,
        'tipo_operacion': tipoOperacion,
        'estado_documento': estadoDocumento,
        'cliente_nombre': clienteNombre,
        'cliente_rut': clienteRut,
        'vendedor_nombre': vendedorNombre,
        'fecha_emision': fechaEmision.toIso8601String(),
        'fecha_emision_formateada': fechaEmisionFormateada,
        'hora_emision_formateada': horaEmisionFormateada,
        'total_operacion': totalOperacion,
        'abono_previo': abonoPrevio,
        'monto_a_cobrar': montoACobrar,
        'articulos': articulos.map((e) => e.toJson()).toList(),
        'especificaciones_backorder': especificacionesBackorder?.toJson(),
      };
}
