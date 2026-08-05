// lib/features/paletizado/presentation/screens/etiqueta_preview_screen.dart

import 'package:flutter/material.dart';
import '../../domain/models/etiqueta_data.dart';
import '../widgets/etiqueta_termica_widget.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/widgets/bluetooth_error_dialog.dart';
import '../../services/print_service.dart';

class EtiquetaPreviewScreen extends StatefulWidget {
  const EtiquetaPreviewScreen({super.key});

  @override
  State<EtiquetaPreviewScreen> createState() => _EtiquetaPreviewScreenState();
}

class _EtiquetaPreviewScreenState extends State<EtiquetaPreviewScreen> {
  bool _isImprimiendo = false;

  // (Nota: Las funciones de _cargarImpresoraGuardada y selector Bluetooth
  // se omiten en esta versión simulada para enfocarnos en la validación visual y de log.
  // Cuando conectes el paquete real flutter_blue_plus, reactivaremos el selector de MAC).

  Future<void> _iniciarImpresion(EtiquetaData data) async {
    debugPrint(
      '📌 [PREVIEW_SCREEN] 🔘 Botón de impresión presionado para SKU: ${data.skuQrFisico}',
    );
    setState(() => _isImprimiendo = true);

    try {
      // Llamada al PrintService (que por ahora es el Stub que ajustamos antes)
      final exito = await PrintService.imprimirEtiqueta(data);

      if (!mounted) return;

      if (exito) {
        debugPrint(
          '📌 [PREVIEW_SCREEN] ✅ Impresión exitosa. (FUTURO: Llamar a PATCH confirmar-impresion)',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Etiqueta impresa. SKU: ${data.skuQrFisico}'),
            backgroundColor: AppPalette.success,
          ),
        );
      } else {
        debugPrint(
          '📌 [PREVIEW_SCREEN] ❌ Fallo en la impresión reportado por el servicio.',
        );
        await BluetoothErrorDialog.show(
          context,
          mensaje: 'Error de conexión con la impresora.',
        );
      }
    } catch (e) {
      debugPrint('📌 [PREVIEW_SCREEN] ❌ Excepción no controlada: $e');
    } finally {
      if (mounted) setState(() => _isImprimiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ModalRoute.of(context)?.settings.arguments as EtiquetaData?;

    if (data == null) {
      debugPrint(
        '📌 [PREVIEW_SCREEN] ⚠️ Pantalla iniciada sin EtiquetaData (Arguments Null)',
      );
      return Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text(
            'Error: No se recibieron datos.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    debugPrint(
      '📌 [PREVIEW_SCREEN] 📄 Renderizando vista previa para Folio: ${data.numeroIngreso}',
    );

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        elevation: 0,
        title: const Text('Vista Previa', style: AppTypography.title),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // ── Contenedor responsivo para visualizar la etiqueta ──
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: EtiquetaTermicaWidget(data: data),
                ),
              ),
            ),
          ),

          // ── Botón de Impresión ──
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImprimiendo
                    ? null
                    : () => _iniciarImpresion(data),
                icon: _isImprimiendo
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
                  _isImprimiendo ? 'ENVIANDO...' : 'CONFIRMAR E IMPRIMIR',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
