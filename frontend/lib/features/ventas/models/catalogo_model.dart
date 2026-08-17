// lib/features/ventas/models/catalogo_model.dart

class CatalogoItem {
  final String idActivo;
  final String skuQrFisico;
  final int? precioReferencia;
  final int idCategoria;
  final String nombreCategoria;
  final int idSucursalActual;
  final String nombreSucursal;
  final String? idVehiculo;
  final String? marca;
  final String? modelo;
  final int? anio;
  final String? traccion;
  final String? cilindrada;
  final String? combustible;
  final String? transmisionTipo;
  final String? ubicacionPasillo;
  final String? ubicacionPallet;
  final String? estadoActivo;
  final List<String> imagenes;

  const CatalogoItem({
    required this.idActivo,
    required this.skuQrFisico,
    this.precioReferencia,
    required this.idCategoria,
    required this.nombreCategoria,
    required this.idSucursalActual,
    required this.nombreSucursal,
    this.idVehiculo,
    this.marca,
    this.modelo,
    this.anio,
    this.traccion,
    this.cilindrada,
    this.combustible,
    this.transmisionTipo,
    this.ubicacionPasillo,
    this.ubicacionPallet,
    this.estadoActivo,
    this.imagenes = const [],
  });

  factory CatalogoItem.fromJson(Map<String, dynamic> json) {
    return CatalogoItem(
      idActivo: json['id_activo']?.toString() ?? '',
      skuQrFisico: json['sku_qr_fisico']?.toString() ?? '',
      precioReferencia: json['precio_referencia'] as int?,
      idCategoria: json['id_categoria'] as int? ?? 0,
      nombreCategoria: json['nombre_categoria']?.toString() ?? 'Sin categoría',
      idSucursalActual: json['id_sucursal_actual'] as int? ?? 0,
      nombreSucursal: json['nombre_sucursal']?.toString() ?? 'Sucursal no especificada',
      idVehiculo: json['id_vehiculo']?.toString(),
      marca: json['marca']?.toString(),
      modelo: json['modelo']?.toString(),
      anio: json['anio'] as int?,
      traccion: json['traccion']?.toString(),
      cilindrada: json['cilindrada']?.toString(),
      combustible: json['combustible']?.toString(),
      transmisionTipo: json['transmision_tipo']?.toString(),
      ubicacionPasillo: json['ubicacion_pasillo']?.toString(),
      ubicacionPallet: json['ubicacion_pallet']?.toString(),
      estadoActivo: json['estado_activo']?.toString(),
      imagenes: (json['imagenes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_activo': idActivo,
      'sku_qr_fisico': skuQrFisico,
      'precio_referencia': precioReferencia,
      'id_categoria': idCategoria,
      'nombre_categoria': nombreCategoria,
      'id_sucursal_actual': idSucursalActual,
      'nombre_sucursal': nombreSucursal,
      'id_vehiculo': idVehiculo,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'traccion': traccion,
      'cilindrada': cilindrada,
      'combustible': combustible,
      'transmision_tipo': transmisionTipo,
      'ubicacion_pasillo': ubicacionPasillo,
      'ubicacion_pallet': ubicacionPallet,
      'estado_activo': estadoActivo,
      'imagenes': imagenes,
    };
  }

  /// Título compuesto para la tarjeta de producto (ej: "Motor - Toyota Yaris 2018")
  String get tituloRepuesto {
    final vehiculoParts = <String>[];
    if (marca != null && marca!.isNotEmpty) vehiculoParts.add(marca!);
    if (modelo != null && modelo!.isNotEmpty) vehiculoParts.add(modelo!);
    if (anio != null) vehiculoParts.add(anio.toString());

    if (vehiculoParts.isNotEmpty) {
      return '$nombreCategoria - ${vehiculoParts.join(' ')}';
    }
    return nombreCategoria;
  }

  /// Ubicación física en bodega
  String get ubicacionFormateada {
    final pasillo = ubicacionPasillo ?? 'S/P';
    final pallet = ubicacionPallet ?? 'S/P';
    return '$pasillo - $pallet';
  }

  /// Formato de moneda chilena (CLP) con separadores de miles
  String get precioFormateado {
    if (precioReferencia == null) return 'Consultar precio';
    final valor = precioReferencia.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '\$$valor';
  }
}

class PaginatedCatalogoResponse {
  final List<CatalogoItem> items;
  final int totalCount;
  final int limit;
  final int offset;

  const PaginatedCatalogoResponse({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  factory PaginatedCatalogoResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((item) => CatalogoItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return PaginatedCatalogoResponse(
      items: items,
      totalCount: json['total_count'] as int? ?? 0,
      limit: json['limit'] as int? ?? 15,
      offset: json['offset'] as int? ?? 0,
    );
  }
}
