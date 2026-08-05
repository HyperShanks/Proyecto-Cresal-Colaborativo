// lib/core/widgets/bluetooth_error_dialog.dart
//
// HU-2.4 Fase 4 — Diálogo de error de hardware Bluetooth.
//
// Se muestra cuando la impresora térmica está apagada, no emparejada
// o responde con un error durante el envío de la trama ESC/POS.
// Mantiene qr_impreso = False hasta que el operario confirme una nueva
// intento de impresión exitoso.
//
// Uso:
//   await BluetoothErrorDialog.show(context, mensaje: 'Impresora no disponible');

import 'package:flutter/material.dart';
import '../theme/tokens/app_palette.dart';
import '../theme/tokens/app_typography.dart';

/// Diálogo modal de error de Bluetooth/Hardware para la impresión de etiquetas.
///
/// Presenta el motivo del fallo de forma clara al operario industrial
/// y ofrece dos acciones: reintentar o cerrar (imprimir más tarde).
class BluetoothErrorDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final VoidCallback? onReintentar;

  const BluetoothErrorDialog({
    super.key,
    this.titulo = 'Error de Impresión',
    required this.mensaje,
    this.onReintentar,
  });

  /// Muestra el diálogo y retorna `true` si el operario eligió reintentar.
  static Future<bool> show(
    BuildContext context, {
    String titulo = 'Error de Impresión',
    required String mensaje,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BluetoothErrorDialog(
        titulo: titulo,
        mensaje: mensaje,
        onReintentar: () => Navigator.of(ctx).pop(true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Ícono de error ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0x22D32F2F), // Error con opacidad
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_disabled,
                color: AppPalette.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // ── Título ────────────────────────────────────────────────────
            Text(
              titulo,
              style: AppTypography.title.copyWith(color: AppPalette.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // ── Mensaje descriptivo ───────────────────────────────────────
            Text(
              mensaje,
              style: AppTypography.small.copyWith(
                color: AppPalette.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // ── Aviso sobre qr_impreso ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x22FFB800), // secondary con opacidad
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppPalette.secondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La etiqueta NO fue marcada como impresa en el sistema.',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Acciones ──────────────────────────────────────────────────
            if (onReintentar != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onReintentar,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Reintentar Impresión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Imprimir más tarde',
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
