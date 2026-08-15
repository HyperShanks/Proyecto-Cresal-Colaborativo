import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/ticket_model.dart';
import '../../services/ticket_service.dart';
import '../widgets/ticket_card.dart';
import '../widgets/ticket_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TICKETS LIST SCREEN (HU-2.7) — Historial de tickets del operario autenticado
// ─────────────────────────────────────────────────────────────────────────────
class TicketsListScreen extends StatefulWidget {
  const TicketsListScreen({super.key});

  @override
  State<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends State<TicketsListScreen> {
  // ── Estado de carga ────────────────────────────────────────────────────────
  late Future<List<TicketModel>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _cargarTickets();
  }

  void _cargarTickets() {
    setState(() {
      _ticketsFuture = TicketService.obtenerMisTickets();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TicketModel>>(
      future: _ticketsFuture,
      builder: (context, snapshot) {
        // ── Cargando ─────────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoader();
        }

        // ── Error de red / API ────────────────────────────────────────────────
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final tickets = snapshot.data ?? [];

        // ── Sin tickets ───────────────────────────────────────────────────────
        if (tickets.isEmpty) {
          return _buildEmptyState();
        }

        // ── Lista de tickets ──────────────────────────────────────────────────
        return RefreshIndicator(
          color: AppPalette.primary,
          backgroundColor: AppPalette.surface,
          onRefresh: () async => _cargarTickets(),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return TicketCard(
                ticket: ticket,
                onTap: () => TicketDetailSheet.mostrar(context, ticket),
              );
            },
          ),
        );
      },
    );
  }

  // ── Shimmer / loader placeholder ──────────────────────────────────────────
  Widget _buildShimmerLoader() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }

  // ── Estado vacío ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 64,
            color: AppPalette.neutral.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin tickets creados',
            style: AppTypography.title.copyWith(color: AppPalette.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los tickets que crees aparecerán aquí.',
            style: AppTypography.small,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _cargarTickets,
            icon: const Icon(Icons.refresh, color: AppPalette.primary),
            label: Text(
              'Actualizar',
              style: AppTypography.button.copyWith(color: AppPalette.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Estado de error ───────────────────────────────────────────────────────
  Widget _buildErrorState(String error) {
    final mensaje = error.replaceFirst('Exception: ', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_outlined,
              size: 56,
              color: AppPalette.error,
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudieron cargar los tickets',
              style: AppTypography.title.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              style: AppTypography.small,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargarTickets,
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER CARD — Placeholder animado mientras cargan los tickets
// Implementación pura sin dependencia de paquetes externos.
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final shimmerColor =
            AppPalette.surface.withValues(alpha: _animation.value + 0.3);
        return Container(
          height: 96,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: AppPalette.neutral.withValues(alpha: _animation.value),
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerLine(
                width: 100,
                height: 12,
                color: AppPalette.neutral.withValues(alpha: _animation.value),
              ),
              const SizedBox(height: 8),
              _ShimmerLine(
                width: double.infinity,
                height: 14,
                color: AppPalette.neutral.withValues(alpha: _animation.value),
              ),
              const SizedBox(height: 8),
              _ShimmerLine(
                width: 160,
                height: 11,
                color: AppPalette.neutral.withValues(alpha: _animation.value * 0.7),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _ShimmerLine({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
