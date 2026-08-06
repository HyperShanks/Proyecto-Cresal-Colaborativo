import 'package:flutter/material.dart';
import '../../models/tarea_alerta.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

import '../screens/auditoria_salida_screen.dart';

class TaskCard extends StatelessWidget {
  final TareaAlerta tarea;

  const TaskCard({Key? key, required this.tarea}) : super(key: key);

  // Método para desplegar el Modal de Acción
  void _mostrarDetalleModal(
    BuildContext context,
    Color accentColor,
    Color buttonColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de arrastre (pill)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    // CORRECCIÓN: Usamos withValues(alpha:) en lugar del obsoleto withOpacity
                    color: AppPalette.neutral.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Text(
                tarea.ordenRef ?? 'TAREA OPERATIVA',
                style: AppTypography.small.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(tarea.tituloPieza, style: AppTypography.headline),
              const SizedBox(height: 20),

              // Recuadro de Ubicación
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppPalette.neutral.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UBICACIÓN EXACTA',
                      style: AppTypography.small.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tarea.ubicacion,
                      style: AppTypography.title.copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),

              // RECUADRO DE INSTRUCCIONES DEL VENDEDOR (Destacado)
              if (tarea.notaEspecial != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppPalette.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppPalette.secondary, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppPalette.secondary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INSTRUCCIONES DE PREPARACIÓN',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tarea.notaEspecial!,
                              style: AppTypography.body.copyWith(
                                color: AppPalette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Botón de Ejecución Final
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // 1. Siempre cerramos el modal primero para que no quede estorbando abajo
                    Navigator.pop(context);

                    // 2. Evaluamos el tipo de alerta
                    if (tarea.tipoAlerta == 'LIBERADA') {
                      // Si está liberada, navegamos a la Barrera de Salida
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuditoriaSalidaScreen(),
                        ),
                      );
                    } else {
                      // Aquí irá la petición POST para Completar Impresión en el futuro
                    }
                  },
                  icon: Icon(
                    tarea.tipoAlerta == 'IMPRESION'
                        ? Icons.print
                        : Icons.check_circle_outline,
                    color: buttonColor == AppPalette.surface
                        ? AppPalette.textSecondary
                        : AppPalette.textPrimary,
                  ),
                  label: Text(
                    tarea.accionRequerida,
                    style: AppTypography.button.copyWith(
                      color: buttonColor == AppPalette.surface
                          ? AppPalette.textSecondary
                          : AppPalette.textPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16), // Espaciado extra para el notch
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    Color buttonColor;

    switch (tarea.tipoAlerta) {
      case 'IMPRESION':
        accentColor = AppPalette.error;
        buttonColor = AppPalette.error;
        break;
      case 'PREPARACION':
        accentColor = AppPalette.secondary;
        buttonColor = AppPalette.surface;
        break;
      case 'LIBERADA':
        accentColor = AppPalette.success;
        buttonColor = AppPalette.success;
        break;
      default:
        accentColor = AppPalette.neutral;
        buttonColor = AppPalette.neutral;
    }

    return GestureDetector(
      onTap: () => _mostrarDetalleModal(context, accentColor, buttonColor),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppPalette.surface,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    // CORRECCIÓN: Evita el subrayado azul de VSCode
                    color: buttonColor.withValues(alpha: 0.2),
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
            Text(tarea.tituloPieza, style: AppTypography.title),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.background,
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
                  onPressed: () {
                    if (tarea.tipoAlerta == 'LIBERADA') {
                      // Navegación directa saltándose el modal
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuditoriaSalidaScreen(),
                        ),
                      );
                    } else {
                      // Para el resto (ej. Impresión), abre el modal para confirmar
                      _mostrarDetalleModal(context, accentColor, buttonColor);
                    }
                  },
                  icon: Icon(
                    tarea.tipoAlerta == 'IMPRESION'
                        ? Icons.print
                        : Icons.qr_code_scanner,
                    color: AppPalette.textPrimary,
                    size: 20,
                  ),
                  label: Text(
                    tarea.accionRequerida,
                    style: AppTypography.button,
                  ),
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
      ),
    ); // <-- AQUÍ ESTÁ EL CIERRE DEL GESTURE DETECTOR QUE FALTABA
  }
}
