import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/ticket_model.dart';

/// Modal BottomSheet que despliega el detalle completo de un ticket de soporte,
/// incluyendo la descripción detallada, metadatos, referencias y resolución.
class TicketDetailSheet extends StatelessWidget {
  final TicketModel ticket;

  const TicketDetailSheet({
    super.key,
    required this.ticket,
  });

  /// Método de invocación estática
  static Future<void> mostrar(BuildContext context, TicketModel ticket) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) => TicketDetailSheet(ticket: ticket),
    );
  }

  static Color _colorForEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'abierto':
        return AppPalette.secondary;
      case 'en proceso':
        return AppPalette.primary;
      case 'resuelto':
        return AppPalette.success;
      case 'cerrado':
        return AppPalette.neutral;
      default:
        return AppPalette.neutral;
    }
  }

  static Color _colorForPrioridad(String prioridad) {
    switch (prioridad.toLowerCase()) {
      case 'urgente':
        return AppPalette.error;
      case 'alta':
        return const Color(0xFFFF7043);
      case 'media':
        return AppPalette.secondary;
      case 'baja':
        return AppPalette.success;
      default:
        return AppPalette.neutral;
    }
  }

  static String _formatFecha(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final String formattedIso = isoDate.contains('Z')
          ? isoDate
          : '${isoDate.replaceAll(' ', 'T')}Z';
      final dt = DateTime.parse(formattedIso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = _colorForEstado(ticket.estadoTicket);
    final prioridadColor = _colorForPrioridad(ticket.prioridad);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          decoration: const BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle / Pill central ─────────────────────────────────────
              Center(
                child: Container(
                  width: 44.0,
                  height: 4.0,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: AppPalette.neutral.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // ── Header: Tipo de Ticket + Badge de Estado ────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: AppPalette.background,
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            ticket.tipoTicket.toUpperCase(),
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: estadoColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(color: estadoColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8.0,
                                height: 8.0,
                                decoration: BoxDecoration(
                                  color: estadoColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                ticket.estadoTicket.toUpperCase(),
                                style: AppTypography.small.copyWith(
                                  color: estadoColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14.0),

                    // ── Asunto / Título del Ticket ──────────────────────────
                    Text(
                      ticket.asunto,
                      style: AppTypography.headline.copyWith(
                        color: AppPalette.textPrimary,
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // ── Ficha de Metadatos (Prioridad, Fecha, ID) ───────────
                    Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.flag_rounded, color: prioridadColor, size: 18.0),
                              const SizedBox(width: 8.0),
                              Text('Prioridad:', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                              const Spacer(),
                              Text(
                                ticket.prioridad,
                                style: AppTypography.body.copyWith(
                                  color: prioridadColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 16.0),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, color: AppPalette.textSecondary, size: 16.0),
                              const SizedBox(width: 8.0),
                              Text('Fecha de Creación:', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                              const Spacer(),
                              Text(
                                _formatFecha(ticket.fechaCreacion),
                                style: AppTypography.body.copyWith(
                                  color: AppPalette.textPrimary,
                                  fontSize: 13.0,
                                ),
                              ),
                            ],
                          ),
                          if (ticket.tablaReferencia != null && ticket.tablaReferencia!.isNotEmpty) ...[
                            const Divider(color: Colors.white10, height: 16.0),
                            Row(
                              children: [
                                const Icon(Icons.link_rounded, color: AppPalette.primary, size: 16.0),
                                const SizedBox(width: 8.0),
                                Text('Referencia:', style: AppTypography.small.copyWith(color: AppPalette.textSecondary)),
                                const Spacer(),
                                Text(
                                  ticket.tablaReferencia!,
                                  style: AppTypography.small.copyWith(
                                    color: AppPalette.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20.0),

                    // ── Sección: Descripción Detallada ──────────────────────
                    Row(
                      children: [
                        const Icon(Icons.notes_rounded, color: AppPalette.primary, size: 18.0),
                        const SizedBox(width: 8.0),
                        Text(
                          'DESCRIPCIÓN DETALLADA',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        ticket.descripcion,
                        style: AppTypography.body.copyWith(
                          color: AppPalette.textPrimary,
                          fontSize: 14.5,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // ── Sección: Respuesta / Resolución de Cierre ───────────
                    if (ticket.observacionCierre != null && ticket.observacionCierre!.trim().isNotEmpty) ...[
                      const SizedBox(height: 20.0),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppPalette.success, size: 18.0),
                          const SizedBox(width: 8.0),
                          Text(
                            'RESOLUCIÓN TÉCNICA / CIERRE',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.success,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: AppPalette.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: AppPalette.success.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.observacionCierre!,
                              style: AppTypography.body.copyWith(
                                color: AppPalette.textPrimary,
                                fontSize: 14.0,
                                height: 1.4,
                              ),
                            ),
                            if (ticket.fechaCierre != null) ...[
                              const SizedBox(height: 8.0),
                              Text(
                                'Cerrado el: ${_formatFecha(ticket.fechaCierre)}',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.success,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24.0),
                  ],
                ),
              ),

              // ── Botón de Cerrar Modal ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.surface,
                    foregroundColor: AppPalette.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CERRAR DETALLE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
