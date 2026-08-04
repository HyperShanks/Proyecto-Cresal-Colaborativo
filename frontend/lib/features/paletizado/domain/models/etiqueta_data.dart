// lib/features/paletizado/domain/models/etiqueta_data.dart
//
// HU-2.4 — Modelo de dominio para la etiqueta térmica.
//
// Responsabilidad única: transportar los datos necesarios para renderizar
// el widget EtiquetaTermicaWidget y enviarlos al servicio de impresión.
//
// Regla de negocio: todos los campos que puedan ser nulos (ej. cilindrada)
// se exponen como String? y el widget los convierte a "N/A" en la UI.

import 'package:flutter/foundation.dart';

/// Modelo inmutable con todos los datos de una etiqueta de activo inventariado.
class EtiquetaData {
  // ── Identificación del vehículo origen ──────────────────────────────────
  final String numeroIngreso;
  final String marca;
  final String modelo;
  final int anio;

  // ── Detalles técnicos del activo (null → se muestra "N/A") ──────────────
  final String? cilindrada;
  final String? combustible;
  final String? transmision;
  final String? numeroMotor;

  // ── Ubicación física en el almacén ───────────────────────────────────────
  final String galpon;
  final String pasillo;
  final String pallet;

  // ── Identidad digital (HU-2.4) ───────────────────────────────────────────
  /// Contenido del código QR. Ejemplo: "MOT-8A2F"
  final String skuQrFisico;

  const EtiquetaData({
    required this.numeroIngreso,
    required this.marca,
    required this.modelo,
    required this.anio,
    this.cilindrada,
    this.combustible,
    this.transmision,
    this.numeroMotor,
    required this.galpon,
    required this.pasillo,
    required this.pallet,
    required this.skuQrFisico,
  });

  /// Convierte el Map JSON de la respuesta del backend a un EtiquetaData.
  /// Los campos técnicos opcionales se mapean a null si vienen ausentes o nulos.
  factory EtiquetaData.fromJson(Map<String, dynamic> json) {
    debugPrint("📥 Recibiendo payload para EtiquetaData: $json");

    // Defensa: Si la respuesta viene envuelta en un nodo "data" o similar, lo desestructuramos
    final Map<String, dynamic> data = json.containsKey('numero_ingreso')
        ? json
        : (json['data'] as Map<String, dynamic>? ?? json);
    return EtiquetaData(
      numeroIngreso: data['numero_ingreso']?.toString() ?? '',
      marca: data['marca']?.toString() ?? '',
      modelo: data['modelo']?.toString() ?? '',
      anio: (data['anio'] as num?)?.toInt() ?? 0,
      cilindrada: data['cilindrada']?.toString(),
      combustible: data['combustible']?.toString(),
      transmision: (data['transmision'] ?? data['transmision_tipo'])?.toString(),
      numeroMotor: data['numero_motor']?.toString(),
      galpon: data['galpon']?.toString() ?? '',
      pasillo: data['pasillo']?.toString() ?? '',
      pallet: data['pallet']?.toString() ?? '',
      skuQrFisico: data['sku_qr_fisico']?.toString() ?? '',
    );
  }

  /// Helper: devuelve el valor o "N/A" si el campo es nulo o vacío.
  /// Conveniente para la capa de presentación.
  static String naIfNull(String? value) =>
      (value == null || value.trim().isEmpty) ? 'N/A' : value;
}
