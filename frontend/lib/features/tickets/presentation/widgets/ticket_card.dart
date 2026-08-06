import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/ticket_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TICKET CARD — Widget local del módulo de tickets
// Muestra el resumen de un ticket en el historial.
// Touch target ≥ 48dp (W3C) garantizado por el InkWell wrapping.
// ─────────────────────────────────────────────────────────────────────────────
class TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.ticket, this.onTap});

  // ── Colores y etiquetas de estado ─────────────────────────────────────────

  static Color _colorForEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'abierto':
        return AppPalette.secondary; // Ámbar
      case 'en proceso':
        return AppPalette.primary; // Azul
      case 'resuelto':
        return AppPalette.success; // Verde
      case 'cerrado':
        return AppPalette.neutral; // Gris
      default:
        return AppPalette.neutral;
    }
  }

  static Color _colorForPrioridad(String prioridad) {
    switch (prioridad.toLowerCase()) {
      case 'urgente':
        return AppPalette.error;
      case 'alta':
        return const Color(0xFFFF7043); // Naranja industrial
      case 'media':
        return AppPalette.secondary;
      case 'baja':
        return AppPalette.success;
      default:
        return AppPalette.neutral;
    }
  }

  // ── Formateo de fecha ─────────────────────────────────────────────────────

  static String _formatFecha(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final String formattedIso = isoDate.contains('Z') 
          ? isoDate 
          : '${isoDate.replaceAll(' ', 'T')}Z';
      final dt = DateTime.parse(formattedIso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
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

    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // ── Borde izquierdo de color según prioridad (patrón del HomeScreen) ─
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: prioridadColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila superior: tipo + badge de estado ────────────────────
              Row(
                children: [
                  Text(
                    ticket.tipoTicket.toUpperCase(),
                    style: AppTypography.cardTitle.copyWith(
                      color: AppPalette.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  _EstadoBadge(
                    label: ticket.estadoTicket,
                    color: estadoColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Asunto ───────────────────────────────────────────────────
              Text(
                ticket.asunto,
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // ── Fila inferior: prioridad + fecha ─────────────────────────
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 14, color: prioridadColor),
                  const SizedBox(width: 4),
                  Text(
                    ticket.prioridad,
                    style: AppTypography.small.copyWith(color: prioridadColor),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time_outlined,
                    size: 14,
                    color: AppPalette.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatFecha(ticket.fechaCreacion),
                      style: AppTypography.small,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE de estado — Pill con color semántico
// ─────────────────────────────────────────────────────────────────────────────
class _EstadoBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _EstadoBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: AppTypography.small.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
