// lib/features/ventas/models/pendiente_precio_model.dart

/// Modelo de datos para un repuesto ingresado por bodega pendiente de asignación de precio (HU-3.8).
class ActivoPendientePrecioModel {
  final String idActivo;
  final String skuQrFisico;
  final int idCategoria;
  final String nombreCategoria;
  final int idSucursalActual;
  final String nombreSucursal;
  final String? ubicacionPasillo;
  final String? ubicacionPallet;
  final String? idVehiculo;
  final String? numeroIngreso;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? traccion;
  final String? cilindrada;
  final String? combustible;
  final String? transmisionTipo;
  final String tituloRepuesto;
  final String estadoActivo;
  final DateTime? fechaCreacion;

  const ActivoPendientePrecioModel({
    required this.idActivo,
    required this.skuQrFisico,
    required this.idCategoria,
    required this.nombreCategoria,
    required this.idSucursalActual,
    required this.nombreSucursal,
    this.ubicacionPasillo,
    this.ubicacionPallet,
    this.idVehiculo,
    this.numeroIngreso,
    this.marca,
    this.modelo,
    this.anio,
    this.traccion,
    this.cilindrada,
    this.combustible,
    this.transmisionTipo,
    required this.tituloRepuesto,
    required this.estadoActivo,
    this.fechaCreacion,
  });

  factory ActivoPendientePrecioModel.fromJson(Map<String, dynamic> json) {
    DateTime? fecha;
    if (json['fecha_creacion'] != null) {
      try {
        fecha = DateTime.parse(json['fecha_creacion'].toString());
      } catch (_) {}
    }

    return ActivoPendientePrecioModel(
      idActivo: json['id_activo']?.toString() ?? '',
      skuQrFisico: json['sku_qr_fisico']?.toString() ?? '',
      idCategoria: (json['id_categoria'] as num?)?.toInt() ?? 0,
      nombreCategoria: json['nombre_categoria']?.toString() ?? 'Repuesto',
      idSucursalActual: (json['id_sucursal_actual'] as num?)?.toInt() ?? 0,
      nombreSucursal: json['nombre_sucursal']?.toString() ?? 'Casa Matriz',
      ubicacionPasillo: json['ubicacion_pasillo']?.toString(),
      ubicacionPallet: json['ubicacion_pallet']?.toString(),
      idVehiculo: json['id_vehiculo']?.toString(),
      numeroIngreso: json['numero_ingreso']?.toString(),
      marca: json['marca']?.toString(),
      modelo: json['modelo']?.toString(),
      anio: (json['anio'] as num?)?.toInt(),
      traccion: json['traccion']?.toString(),
      cilindrada: json['cilindrada']?.toString(),
      combustible: json['combustible']?.toString(),
      transmisionTipo: json['transmision_tipo']?.toString(),
      tituloRepuesto: json['titulo_repuesto']?.toString() ?? 'Repuesto Sin Título',
      estadoActivo: json['estado_activo']?.toString() ?? 'En Desarme',
      fechaCreacion: fecha,
    );
  }

  // ── Getters Utilitarios para la UI ──────────────────────────────────────────

  /// Retorna la ubicación en pasillo y pallet formateada (ej. "P-03 • PL-10")
  String get ubicacionDisplay {
    final pasillo = (ubicacionPasillo != null && ubicacionPasillo!.isNotEmpty) ? ubicacionPasillo! : 'S/P';
    final pallet = (ubicacionPallet != null && ubicacionPallet!.isNotEmpty) ? ubicacionPallet! : 'S/P';
    return '$pasillo • $pallet';
  }

  /// Retorna la información del vehículo de origen formateada (ej. "Hyundai Accent 2020")
  String get fichaVehiculoDisplay {
    final parts = [marca, modelo, anio?.toString()].where((p) => p != null && p.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(' ') : 'Vehículo no especificado';
  }

  /// Retorna las especificaciones mecánicas del repuesto (ej. "1.4L • Gasolina • Manual")
  String get especificacionesDisplay {
    final specs = [cilindrada, combustible, transmisionTipo, traccion]
        .where((s) => s != null && s.isNotEmpty && s != 'N/A')
        .toList();
    return specs.isNotEmpty ? specs.join(' • ') : 'Sin especificaciones técnicas';
  }

  /// Retorna la fecha de ingreso formateada en formato "dd/MM/yyyy HH:mm"
  String get fechaCreacionFormateada {
    if (fechaCreacion == null) return 'Fecha no registrada';
    final dt = fechaCreacion!;
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    final anio = dt.year;
    final hora = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio $hora:$min';
  }
}

/// DTO de respuesta tras asignar precio de referencia a un activo.
class AsignarPrecioResponseModel {
  final String idActivo;
  final String skuQrFisico;
  final int precioReferencia;
  final String estadoActivo;
  final String mensaje;

  const AsignarPrecioResponseModel({
    required this.idActivo,
    required this.skuQrFisico,
    required this.precioReferencia,
    required this.estadoActivo,
    required this.mensaje,
  });

  factory AsignarPrecioResponseModel.fromJson(Map<String, dynamic> json) {
    return AsignarPrecioResponseModel(
      idActivo: json['id_activo']?.toString() ?? '',
      skuQrFisico: json['sku_qr_fisico']?.toString() ?? '',
      precioReferencia: (json['precio_referencia'] as num?)?.toInt() ?? 0,
      estadoActivo: json['estado_activo']?.toString() ?? 'Disponible',
      mensaje: json['mensaje']?.toString() ?? 'Precio asignado exitosamente.',
    );
  }

  String get precioFormateado => _formatearMonto(precioReferencia);

  static String _formatearMonto(int monto) {
    final str = monto.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return '\$${buffer.toString().split('').reversed.join('')}';
  }
}
