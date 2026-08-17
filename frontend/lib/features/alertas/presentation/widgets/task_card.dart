import 'package:flutter/material.dart';
import '../../models/tarea_alerta.dart';
import '../../services/logistica_service.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../screens/auditoria_salida_screen.dart';

class TaskCard extends StatefulWidget {
  final TareaAlerta tarea;
  final VoidCallback? onActualizar;

  const TaskCard({Key? key, required this.tarea, this.onActualizar}) : super(key: key);

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isProcessingListo = false;

  Future<void> _marcarListo(BuildContext context) async {
    if (widget.tarea.idDetalle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el ID de detalle para marcar como listo.'),
          backgroundColor: AppPalette.error,
        ),
      );
      return;
    }

    setState(() => _isProcessingListo = true);

    try {
      final exito = await LogisticaService.completarPreentrega(widget.tarea.idDetalle!);
      if (!mounted) return;

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Preparación de ${widget.tarea.tituloPieza} marcada como LISTO.',
            ),
            backgroundColor: AppPalette.success,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onActualizar?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al completar preparación: $e'),
          backgroundColor: AppPalette.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingListo = false);
    }
  }

  // Método para desplegar el Modal de Acción
  void _mostrarDetalleModal(
    BuildContext context,
    Color accentColor,
    Color buttonColor,
  ) {
    final tarea = widget.tarea;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
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
                    color: AppPalette.neutral.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tarea.ordenRef ?? 'TAREA OPERATIVA',
                    style: AppTypography.small.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (tarea.esTraslado || tarea.tipoAlerta == 'TRASLADO')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppPalette.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppPalette.secondary),
                      ),
                      child: Text(
                        'TRASLADO INTER-SUCURSAL',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                ],
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

              const SizedBox(height: 24),

              // Botón Prominente 'Listo' para tareas de preparación / pre-entrega
              if (tarea.idDetalle != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingListo
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _marcarListo(context);
                          },
                    icon: _isProcessingListo
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      'MARCAR COMO LISTO',
                      style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Botón de Ejecución Alternativo (Barrera o Impresión)
              if (tarea.tipoAlerta == 'LIBERADA') ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final resultado = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AuditoriaSalidaScreen(tarea: tarea),
                        ),
                      );
                      if (resultado == true) {
                        widget.onActualizar?.call();
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner, color: AppPalette.textPrimary),
                    label: Text(
                      'ESCANEAR EN BARRERA',
                      style: AppTypography.button.copyWith(color: AppPalette.textPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ] else if (tarea.tipoAlerta == 'IMPRESION') ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (tarea.etiquetaData != null) {
                        final resultado = await Navigator.pushNamed(
                          context,
                          '/etiqueta-preview',
                          arguments: tarea.etiquetaData,
                        );
                        if (resultado == true) {
                          widget.onActualizar?.call();
                        }
                      }
                    },
                    icon: const Icon(Icons.print, color: AppPalette.textPrimary),
                    label: Text(
                      'GENERAR ETIQUETA QR',
                      style: AppTypography.button.copyWith(color: AppPalette.textPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tarea = widget.tarea;
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
      case 'TRASLADO':
        accentColor = AppPalette.secondary;
        buttonColor = AppPalette.secondary;
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
          border: Border(left: BorderSide(color: accentColor, width: 4.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la tarjeta: Título de tarea / Orden
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tarea.ordenRef ?? 'TAREA BODEGA',
                    style: AppTypography.cardTitle.copyWith(color: accentColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tarea.esTraslado || tarea.tipoAlerta == 'TRASLADO')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppPalette.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'TRASLADO',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8.0),

            // Título de la pieza
            Text(
              tarea.tituloPieza,
              style: AppTypography.title.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8.0),

            // Ubicación en Rack
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppPalette.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 4.0),
                Text(tarea.ubicacion, style: AppTypography.body),
              ],
            ),

            // Instrucciones especiales (si existen)
            if (tarea.notaEspecial != null) ...[
              const SizedBox(height: 8.0),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: AppPalette.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: AppPalette.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppPalette.secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Text(
                        tarea.notaEspecial!,
                        style: AppTypography.small.copyWith(
                          color: AppPalette.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Indicador de bloqueo (si existe)
            if (tarea.estadoBloqueo != null) ...[
              const SizedBox(height: 12.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: AppPalette.background,
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.3)),
                ),
                child: Row(
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

            // ── BOTONES DE ACCIÓN EN TARJETA ──
            if (tarea.estadoBloqueo == null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  // Botón 'Listo' prominente para tareas asociadas a una orden (pre-entrega)
                  if (tarea.idDetalle != null) ...[
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 45,
                        child: ElevatedButton.icon(
                          key: Key('btn_listo_${tarea.idTarea}'),
                          onPressed: _isProcessingListo ? null : () => _marcarListo(context),
                          icon: _isProcessingListo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                          label: Text(
                            'LISTO',
                            style: AppTypography.button.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.success,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Botón Secundario / Directo (Barrera o Impresión o Detalles)
                  Expanded(
                    flex: tarea.idDetalle != null ? 2 : 5,
                    child: SizedBox(
                      height: 45,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (tarea.tipoAlerta == 'LIBERADA') {
                            final resultado = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AuditoriaSalidaScreen(tarea: tarea),
                              ),
                            );
                            if (resultado == true) {
                              widget.onActualizar?.call();
                            }
                          } else if (tarea.tipoAlerta == 'IMPRESION') {
                            if (tarea.etiquetaData != null) {
                              final resultado = await Navigator.pushNamed(
                                context,
                                '/etiqueta-preview',
                                arguments: tarea.etiquetaData,
                              );
                              if (resultado == true) {
                                widget.onActualizar?.call();
                              }
                            }
                          } else {
                            _mostrarDetalleModal(context, accentColor, buttonColor);
                          }
                        },
                        icon: Icon(
                          tarea.tipoAlerta == 'IMPRESION'
                              ? Icons.print
                              : (tarea.tipoAlerta == 'LIBERADA' ? Icons.qr_code_scanner : Icons.visibility_outlined),
                          color: AppPalette.textPrimary,
                          size: 18,
                        ),
                        label: Text(
                          tarea.tipoAlerta == 'IMPRESION'
                              ? 'IMPRIMIR'
                              : (tarea.tipoAlerta == 'LIBERADA' ? 'BARRERA' : 'DETALLES'),
                          style: AppTypography.button.copyWith(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
