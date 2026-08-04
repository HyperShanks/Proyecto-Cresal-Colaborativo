// lib/features/paletizado/presentation/widgets/etiqueta_termica_widget.dart
//
// HU-2.4 — Widget reutilizable que simula una etiqueta térmica 4×6.
//
// Propósito: Renderizar todos los datos de un activo inventariado en un
// formato de tarjeta imprimible. El QR se genera desde `sku_qr_fisico`.
//
// Este widget es PURO (sin lógica de negocio): solo recibe un EtiquetaData
// y lo presenta. No realiza llamadas HTTP ni accede a servicios.

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../domain/models/etiqueta_data.dart';
import '../../../../core/theme/tokens/app_palette.dart';

/// Widget que simula una etiqueta térmica de proporción 4×6 (landscape).
///
/// Uso:
/// ```dart
/// EtiquetaTermicaWidget(data: miEtiquetaData)
/// ```
class EtiquetaTermicaWidget extends StatelessWidget {
  final EtiquetaData data;

  const EtiquetaTermicaWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      // ── Proporciones 4×6 (landscape) ─────────────────────────────────────
      width: 420,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white, // Fondo blanco simula papel térmico
        border: Border.all(color: Colors.black, width: 3), // Borde negro limpio simulando etiqueta
      ),
      child: Row(
        children: [
          // ── COLUMNA IZQUIERDA: Datos del activo ──────────────────────────
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado: N° Ingreso en grande (dato estrella)
                  _buildHeader(),
                  const Divider(color: Colors.black, height: 12, thickness: 1.5),

                  // Datos del vehículo origen
                  _buildVehicleRow(),
                  const SizedBox(height: 6),

                  // Datos técnicos del activo
                  _buildTechData(),
                  const Spacer(),

                  // Ubicación física
                  _buildUbicacion(),
                ],
              ),
            ),
          ),

          // Separador vertical
          Container(width: 2, color: Colors.black),

          // ── COLUMNA DERECHA: QR + SKU ─────────────────────────────────────
          SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Código QR generado desde sku_qr_fisico
                QrImageView(
                  data: data.skuQrFisico,
                  version: QrVersions.auto,
                  size: 96,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
                const SizedBox(height: 8),
                // Texto del SKU justo debajo del QR, reemplazando "CRESAL"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    data.skuQrFisico,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets privados de construcción ──────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black, // Estilo industrial
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'N° ${data.numeroIngreso}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28, // Tamaño extra grande
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${data.marca} ${data.modelo}',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleRow() {
    final String anioTexto = (data.anio <= 0) ? 'N/A' : data.anio.toString();
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      children: [
        _chip('Año', anioTexto),
        _chip('Comb.', EtiquetaData.naIfNull(data.combustible)),
        _chip('Trans.', EtiquetaData.naIfNull(data.transmision)),
      ],
    );
  }

  Widget _buildTechData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dataRow(
          Icons.settings_outlined,
          'Cilindrada',
          EtiquetaData.naIfNull(data.cilindrada),
        ),
        _dataRow(
          Icons.confirmation_number_outlined,
          'N° Motor',
          EtiquetaData.naIfNull(data.numeroMotor),
        ),
      ],
    );
  }

  Widget _buildUbicacion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 14, color: Colors.black),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'G: ${data.galpon} | P: ${data.pasillo} | Pa: ${data.pallet}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Chip de dato clave-valor compacto.
  Widget _chip(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black54, fontSize: 9),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  /// Fila de dato con ícono, etiqueta y valor.
  Widget _dataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 10, color: AppPalette.primary),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.black54, fontSize: 9),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
