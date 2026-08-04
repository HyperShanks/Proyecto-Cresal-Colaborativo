// lib/features/paletizado/presentation/screens/etiqueta_preview_screen.dart
//
// HU-2.4 — Pantalla de previsualización de la etiqueta térmica en grande.
//
// Recibe un [EtiquetaData] como argumento de navegación y muestra el widget
// EtiquetaTermicaWidget centrado y escalado para que el operario pueda
// verificar visualmente el contenido antes de imprimir.
//
// Navegación de entrada:
//   Navigator.pushNamed(
//     context,
//     '/etiqueta-preview',
//     arguments: miEtiquetaData,
//   );

import 'package:flutter/material.dart';
import '../../domain/models/etiqueta_data.dart';
import '../widgets/etiqueta_termica_widget.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/print_service.dart';

/// Pantalla de previsualización completa de la etiqueta térmica.
///
/// El operario puede verificar el QR y los datos antes de imprimir.
class EtiquetaPreviewScreen extends StatefulWidget {
  const EtiquetaPreviewScreen({super.key});

  @override
  State<EtiquetaPreviewScreen> createState() => _EtiquetaPreviewScreenState();
}

class _EtiquetaPreviewScreenState extends State<EtiquetaPreviewScreen> {
  bool _isConnecting = false;

  Future<void> _imprimirDesdePreview(EtiquetaData data) async {
    setState(() => _isConnecting = true);

    // FUTURO: PrintService.imprimirEtiqueta() invocará flutter_blue_plus.
    // Ver print_service.dart para el punto de inyección Bluetooth.
    await PrintService.imprimirEtiqueta(data);

    if (!mounted) return;
    setState(() => _isConnecting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🖨️ Orden de impresión enviada (Bluetooth stub).'),
        backgroundColor: AppPalette.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos el EtiquetaData desde los argumentos de navegación
    final data = ModalRoute.of(context)?.settings.arguments as EtiquetaData?;

    if (data == null) {
      return Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const Text('Previsualización', style: AppTypography.title),
          backgroundColor: AppPalette.background,
        ),
        body: const Center(
          child: Text(
            'Error: No se recibieron datos de la etiqueta.',
            style: TextStyle(color: AppPalette.error),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        elevation: 0,
        title: const Text('Vista Previa de Etiqueta', style: AppTypography.title),
        centerTitle: true,
        actions: [
          // Botón de impresión en el AppBar para acceso rápido
          IconButton(
            icon: _isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppPalette.primary,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.print, color: AppPalette.primary),
            tooltip: 'Imprimir etiqueta',
            onPressed: _isConnecting ? null : () => _imprimirDesdePreview(data),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Información contextual ──────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppPalette.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Etiqueta generada para el activo ${data.skuQrFisico} '
                    '— N° Ingreso ${data.numeroIngreso}',
                    style: AppTypography.small,
                  ),
                ),
              ],
            ),
          ),

          // ── Widget de etiqueta centrado ─────────────────────────────────
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Etiqueta térmica escalada al ancho de la pantalla
                    FittedBox(
                      fit: BoxFit.contain,
                      child: EtiquetaTermicaWidget(data: data),
                    ),

                    const SizedBox(height: 32),

                    // Botón de impresión inferior
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isConnecting ? null : () => _imprimirDesdePreview(data),
                        icon: _isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.print, color: Colors.white),
                        label: Text(
                          _isConnecting ? 'CONECTANDO...' : 'IMPRIMIR ETIQUETA',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
