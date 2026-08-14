// lib/features/paletizado/presentation/screens/etiqueta_preview_screen.dart

import 'package:flutter/material.dart';
import '../../domain/exceptions/printer_exceptions.dart';
import '../../domain/models/etiqueta_data.dart';
import '../widgets/etiqueta_termica_widget.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/print_service.dart';
import '../../services/paletizado_service.dart';

class EtiquetaPreviewScreen extends StatefulWidget {
  const EtiquetaPreviewScreen({super.key});

  @override
  State<EtiquetaPreviewScreen> createState() => _EtiquetaPreviewScreenState();
}

class _EtiquetaPreviewScreenState extends State<EtiquetaPreviewScreen> {
  bool _isImprimiendo = false;
  final PaletizadoService _paletizadoService = PaletizadoService();

  Future<void> _iniciarImpresion(EtiquetaData data) async {
    debugPrint(
      '📌 [PREVIEW_SCREEN] 🔘 Botón de impresión presionado para SKU: ${data.skuQrFisico}',
    );
    setState(() => _isImprimiendo = true);

    try {
      // =======================================================================
      // ⚠️ MODO SIMULADOR EN CASA / PRUEBAS LOCALES (TEMPORAL)
      // Para restaurar en producción: descomentar la llamada a PrintService y borrar el forzado a true.
      // =======================================================================
      // final exitoImpresion = await PrintService.imprimirEtiqueta(data);
      final exitoImpresion = true;
      // =======================================================================

      if (!mounted) return;

      if (exitoImpresion) {
        // Fase 4: Confirmar en backend (PATCH qr_impreso = true)
        debugPrint(
          '📌 [PREVIEW_SCREEN] 📡 Impresión física exitosa. Confirmando en backend...',
        );
        final exitoPatch = await _paletizadoService.confirmarQrImpreso(data.idActivo);

        if (!mounted) return;

        if (exitoPatch) {
          debugPrint(
            '📌 [PREVIEW_SCREEN] ✅ Ciclo completo: etiqueta impresa y registrada en BD.',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Etiqueta impresa y registrada. SKU: ${data.skuQrFisico}',
              ),
              backgroundColor: AppPalette.success,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          // Impresión exitosa pero PATCH falló (problema de red/backend)
          debugPrint(
            '📌 [PREVIEW_SCREEN] ⚠️ Etiqueta impresa pero no se pudo confirmar en backend.',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Etiqueta impresa. No se pudo confirmar en el sistema (sin conexión).',
              ),
              backgroundColor: AppPalette.secondary,
              duration: Duration(seconds: 4),
            ),
          );
        }

        // pop(true): indica a la pantalla anterior que debe actualizar su UI
        Navigator.of(context).pop(true);
      }
    } on PrinterException catch (e) {
      debugPrint('📌 [PREVIEW_SCREEN] ❌ Error de dominio de impresora: ${e.mensaje}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.mensaje}'),
          backgroundColor: AppPalette.secondary,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('📌 [PREVIEW_SCREEN] ❌ Excepción no controlada: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error inesperado de conexión con la impresora.'),
          backgroundColor: AppPalette.secondary,
        ),
      );
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
