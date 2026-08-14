import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

/// Panel lateral derecho (EndDrawer) para el filtrado avanzado de órdenes de venta (HU-3.5).
/// Implementa Flat Design estricto, sin sombras y con touch targets >= 48x48.
class HistorialFiltrosDrawer extends StatelessWidget {
  final bool verTodas;
  final String? filtroEstado;
  final ValueChanged<bool> onPeriodoChanged;
  final ValueChanged<String?> onEstadoChanged;
  final VoidCallback onAplicar;
  final VoidCallback onLimpiar;

  const HistorialFiltrosDrawer({
    super.key,
    required this.verTodas,
    required this.filtroEstado,
    required this.onPeriodoChanged,
    required this.onEstadoChanged,
    required this.onAplicar,
    required this.onLimpiar,
  });

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.small.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: AppPalette.textSecondary,
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    Color? activeColor,
  }) {
    final selectedColor = activeColor ?? AppPalette.primary;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppPalette.textPrimary : AppPalette.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: selectedColor,
      backgroundColor: AppPalette.background,
      elevation: 0,
      pressElevation: 0,
      side: BorderSide(
        color: isSelected
            ? selectedColor
            : Colors.white.withValues(alpha: 0.08),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayFiltrosActivos = verTodas || filtroEstado != null;

    return Drawer(
      backgroundColor: AppPalette.surface,
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            // ── Encabezado ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white10, width: 1.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6.0),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Icon(
                            Icons.tune,
                            size: 20.0,
                            color: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            'Filtros de Órdenes',
                            style: AppTypography.title.copyWith(fontSize: 18.0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppPalette.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar filtros',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ],
              ),
            ),

            // ── Contenido de Filtros ────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Sección 1: Período de Venta
                  _buildSectionTitle('PERÍODO DE VENTA'),
                  const SizedBox(height: 10.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildChoiceChip(
                        label: 'Ventas de Hoy',
                        isSelected: !verTodas,
                        onSelected: (selected) {
                          if (selected) onPeriodoChanged(false);
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Historial Completo',
                        isSelected: verTodas,
                        onSelected: (selected) {
                          if (selected) onPeriodoChanged(true);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24.0),
                  const Divider(color: Colors.white10, height: 1.0),
                  const SizedBox(height: 20.0),

                  // Sección 2: Estado de la Orden
                  _buildSectionTitle('ESTADO DE LA ORDEN'),
                  const SizedBox(height: 10.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildChoiceChip(
                        label: 'Todas',
                        isSelected: filtroEstado == null,
                        onSelected: (_) => onEstadoChanged(null),
                      ),
                      _buildChoiceChip(
                        label: 'Reservadas',
                        isSelected: filtroEstado == 'Reservada',
                        activeColor: AppPalette.secondary,
                        onSelected: (selected) {
                          onEstadoChanged(selected ? 'Reservada' : null);
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Pagadas',
                        isSelected: filtroEstado == 'Pagada',
                        activeColor: AppPalette.success,
                        onSelected: (selected) {
                          onEstadoChanged(selected ? 'Pagada' : null);
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Anuladas',
                        isSelected: filtroEstado == 'Anulada',
                        activeColor: AppPalette.error,
                        onSelected: (selected) {
                          onEstadoChanged(selected ? 'Anulada' : null);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Barra Inferior: Botones de Acción ───────────────────────
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: AppPalette.background,
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48.0,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.textSecondary,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: hayFiltrosActivos
                            ? () {
                                onLimpiar();
                                Navigator.of(context).pop();
                              }
                            : null,
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: AppPalette.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: () {
                          onAplicar();
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Aplicar Filtros',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
