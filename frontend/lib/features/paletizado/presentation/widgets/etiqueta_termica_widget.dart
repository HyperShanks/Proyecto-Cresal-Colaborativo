// lib/features/paletizado/presentation/widgets/etiqueta_termica_widget.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../domain/models/etiqueta_data.dart';

class EtiquetaTermicaWidget extends StatelessWidget {
  final EtiquetaData data;

  const EtiquetaTermicaWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isMotor = data.skuQrFisico.toUpperCase().startsWith('MOT');

    // Proporción exacta 100x70 mm (10:7 -> 600x420 px)
    return Container(
      width: 600,
      height: 420,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // ── HEADER ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoCresal(),
              _buildBadgeInsignia(isMotor ? 'MOTOR' : 'CAJAS DE CAMBIO'),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.black, thickness: 3, height: 12),

          // ── CUERPO PRINCIPAL ──
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── IZQUIERDA: Código QR y Ubicación ──
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: data.skuQrFisico,
                          version: QrVersions.auto,
                          size: 140, // <- QR Factor 8 proporcional y centrado
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        // <- Magia: encoge el texto si es muy largo
                        fit: BoxFit.scaleDown,
                        child: Text(
                          data.skuQrFisico,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'UBICACIÓN: G${data.galpon} - P${data.pasillo} - Pa${data.pallet}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── SEPARADOR VERTICAL ──
                Container(
                  width: 3,
                  color: Colors.black,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),

                // ── DERECHA: Filas de datos técnicos ──
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _buildCamposTecnicos(),
                  ),
                ),
              ],
            ),
          ),

          // ── FOOTER: Números de Identificación ──
          const Divider(color: Colors.black, thickness: 3, height: 12),
          SizedBox(
            height: 50, // Fijamos el alto del footer para que no moleste arriba
            child: Row(
              children: [
                Expanded(
                  child: isMotor
                      ? _buildFooterBox(
                          Icons.settings_input_component,
                          'NRO MOTOR',
                          data.numeroMotor ?? 'N/A',
                        )
                      : const SizedBox.shrink(),
                ),
                if (isMotor) Container(width: 3, color: Colors.black),
                Expanded(
                  child: _buildFooterBox(
                    Icons.assignment,
                    'NRO INGRESO',
                    data.numeroIngreso,
                    isGiant: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGETS CONSTRUCTORES INTERNOS
  // ===========================================================================

  Widget _buildLogoCresal() {
    return const Row(
      children: [
        Icon(Icons.settings, size: 40, color: Colors.black),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CRESAL®',
              style: TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            Text(
              'Desarme • Vehículos • Repuestos',
              style: TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgeInsignia(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  List<Widget> _buildCamposTecnicos() {
    return [
      _buildFilaDato(Icons.directions_car, 'MARCA', data.marca),
      _buildFilaDato(Icons.directions_car_filled, 'MODELO', data.modelo),
      _buildFilaDato(
        Icons.calendar_month,
        'AÑO',
        data.anio > 0 ? data.anio.toString() : 'N/A',
      ),
      _buildFilaDato(Icons.settings, 'CILINDRADA', data.cilindrada ?? 'N/A'),
      _buildFilaDato(
        Icons.local_gas_station,
        'COMBUSTIBLE',
        data.combustible ?? 'N/A',
      ),
      _buildFilaDato(
        Icons.account_tree,
        'TRANSMISIÓN',
        data.transmision ?? 'N/A',
      ),
      _buildFilaDato(
        Icons.all_inclusive,
        'TRACCIÓN',
        data.traccion ?? 'N/A',
      ),
    ];
  }

  Widget _buildFilaDato(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          width: 35,
          height: 30,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(4),
              right: Radius.circular(12),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
              Container(
                height: 1.5,
                color: Colors.black87,
                margin: const EdgeInsets.only(top: 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterBox(
    IconData icon,
    String title,
    String value, {
    bool isGiant = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 28, color: Colors.black),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value.toUpperCase(),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: isGiant ? 32 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
