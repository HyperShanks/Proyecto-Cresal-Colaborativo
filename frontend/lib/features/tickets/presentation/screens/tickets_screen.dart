import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import 'crear_ticket_screen.dart';
import 'tickets_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TICKETS SCREEN — Vista raíz del módulo de Tickets (HU-2.7)
// Integra "Crear Ticket" y "Mis Tickets" con un DefaultTabController.
// Protegida: el Drawer de HomeScreen ya garantiza que solo usuarios
// autenticados llegan aquí.
// ─────────────────────────────────────────────────────────────────────────────
class TicketsScreen extends StatelessWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppPalette.background,
        appBar: _buildAppBar(context),
        body: const TabBarView(
          children: [
            CrearTicketScreen(),
            TicketsListScreen(),
          ],
        ),
      ),
    );
  }

  // ── AppBar con pestañas ────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppPalette.surface,
      foregroundColor: AppPalette.textPrimary,
      elevation: 0,
      title: Text(
        'Soporte Técnico',
        style: AppTypography.title.copyWith(fontSize: 17),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppPalette.textPrimary),
        tooltip: 'Volver',
        onPressed: () => Navigator.of(context).pop(),
      ),
      bottom: TabBar(
        indicatorColor: AppPalette.primary,
        indicatorWeight: 3,
        labelColor: AppPalette.primary,
        unselectedLabelColor: AppPalette.textSecondary,
        labelStyle: AppTypography.button.copyWith(fontSize: 13),
        unselectedLabelStyle: AppTypography.small.copyWith(fontSize: 13),
        tabs: const [
          Tab(
            icon: Icon(Icons.add_circle_outline, size: 20),
            text: 'CREAR TICKET',
          ),
          Tab(
            icon: Icon(Icons.list_alt_outlined, size: 20),
            text: 'MIS TICKETS',
          ),
        ],
      ),
    );
  }
}
