class TareaAlerta {
  final String idTarea;
  final String tipoAlerta; // 'IMPRESION', 'PREPARACION', 'LIBERADA'
  final String? ordenRef;
  final String tituloPieza;
  final String ubicacion;
  final String? notaEspecial;
  final String? estadoBloqueo;
  final String accionRequerida;

  TareaAlerta({
    required this.idTarea,
    required this.tipoAlerta,
    this.ordenRef,
    required this.tituloPieza,
    required this.ubicacion,
    this.notaEspecial,
    this.estadoBloqueo,
    required this.accionRequerida,
  });

  factory TareaAlerta.fromJson(Map<String, dynamic> json) {
    return TareaAlerta(
      idTarea: json['id_tarea'] ?? '',
      tipoAlerta: json['tipo_alerta'] ?? '',
      ordenRef: json['orden_ref'],
      tituloPieza: json['titulo_pieza'] ?? 'Pieza Desconocida',
      ubicacion: json['ubicacion'] ?? 'Ubicación Pendiente',
      notaEspecial: json['nota_especial'],
      estadoBloqueo: json['estado_bloqueo'],
      accionRequerida: json['accion_requerida'] ?? '',
    );
  }
}
