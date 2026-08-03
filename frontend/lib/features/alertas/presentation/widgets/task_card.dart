import 'package:flutter/material.dart';
import '../../models/tarea_alerta.dart';

// Importamos tus tokens exactos
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

class TaskCard extends StatelessWidget {
  final TareaAlerta tarea;

  const TaskCard({Key? key, required this.tarea}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    Color buttonColor;

    // Lógica estricta conectada a tus Tokens (AppPalette)
    switch (tarea.tipoAlerta) {
      case 'IMPRESION':
        accentColor = AppPalette.error; // Color Rojo de tus tokens
        buttonColor = AppPalette.error;
        break;
      case 'PREPARACION':
        accentColor = AppPalette.secondary; // Color Ámbar de tus tokens
        buttonColor = AppPalette.surface; // Botón apagado (fondo)
        break;
      case 'LIBERADA':
        accentColor = AppPalette.success; // Color Verde de tus tokens
        buttonColor = AppPalette.success;
        break;
      default:
        accentColor = AppPalette.neutral;
        buttonColor = AppPalette.neutral;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppPalette.surface, // Fondo tarjeta de tus tokens
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tarea.ordenRef ?? 'PENDIENTE: IMPRESIÓN',
                style: AppTypography.small.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: buttonColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tarea.accionRequerida,
                  style: AppTypography.small.copyWith(
                    color: buttonColor == AppPalette.surface
                        ? AppPalette.textSecondary
                        : buttonColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            tarea.tituloPieza,
            style: AppTypography.title, // Título de tus tokens
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.background, // Contenedor más oscuro
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UBICACIÓN DE RETIRO',
                  style: AppTypography.small.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  tarea.ubicacion,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          if (tarea.notaEspecial != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppPalette.secondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tarea.notaEspecial!,
                    style: AppTypography.small.copyWith(
                      color: AppPalette.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (tarea.estadoBloqueo != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: AppPalette.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tarea.estadoBloqueo!,
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (tarea.estadoBloqueo == null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(
                  tarea.tipoAlerta == 'IMPRESION'
                      ? Icons.print
                      : Icons.qr_code_scanner,
                  color: AppPalette.textPrimary,
                  size: 20,
                ),
                label: Text(tarea.accionRequerida, style: AppTypography.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
