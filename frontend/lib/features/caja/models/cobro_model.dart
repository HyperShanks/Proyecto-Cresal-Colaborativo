/// DTOs tipados para el registro y confirmación de cobros en Caja (SPEC-HU-03).
library;

class TransaccionPagoItemModel {
  final String metodo;
  final int monto;

  TransaccionPagoItemModel({
    required this.metodo,
    required this.monto,
  });

  factory TransaccionPagoItemModel.fromJson(Map<String, dynamic> json) =>
      TransaccionPagoItemModel(
        metodo: json['metodo'] as String? ?? 'Efectivo',
        monto: json['monto'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'metodo': metodo,
        'monto': monto,
      };

  TransaccionPagoItemModel copyWith({
    String? metodo,
    int? monto,
  }) {
    return TransaccionPagoItemModel(
      metodo: metodo ?? this.metodo,
      monto: monto ?? this.monto,
    );
  }
}

class RegistrarCobroRequestModel {
  final String tipoOperacion;
  final String idDocumento;
  final String modalidad;
  final int montoDeclarado;
  final List<TransaccionPagoItemModel> pagos;

  RegistrarCobroRequestModel({
    required this.tipoOperacion,
    required this.idDocumento,
    required this.modalidad,
    required this.montoDeclarado,
    required this.pagos,
  });

  Map<String, dynamic> toJson() => {
        'tipo_operacion': tipoOperacion,
        'id_documento': idDocumento,
        'modalidad': modalidad,
        'monto_declarado': montoDeclarado,
        'pagos': pagos.map((p) => p.toJson()).toList(),
      };
}

class RegistrarCobroResponseModel {
  final bool success;
  final String mensaje;
  final String folio;
  final int montoCobrado;
  final int nuevoSaldoPendiente;
  final String estadoActualizado;
  final List<String> transaccionesIds;

  RegistrarCobroResponseModel({
    required this.success,
    required this.mensaje,
    required this.folio,
    required this.montoCobrado,
    required this.nuevoSaldoPendiente,
    required this.estadoActualizado,
    required this.transaccionesIds,
  });

  factory RegistrarCobroResponseModel.fromJson(Map<String, dynamic> json) =>
      RegistrarCobroResponseModel(
        success: json['success'] as bool? ?? false,
        mensaje: json['mensaje'] as String? ?? '',
        folio: json['folio'] as String? ?? '',
        montoCobrado: json['monto_cobrado'] as int? ?? 0,
        nuevoSaldoPendiente: json['nuevo_saldo_pendiente'] as int? ?? 0,
        estadoActualizado: json['estado_actualizado'] as String? ?? '',
        transaccionesIds: (json['transacciones_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}
