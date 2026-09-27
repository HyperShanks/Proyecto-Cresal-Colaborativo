import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

/// Representa un periodo mensual agrupado (Año / Mes) para filtros de historial.
class PeriodoMesModel {
  final int year;
  final int month;
  final String key; // e.g. "2026-09"
  final String label; // e.g. "Septiembre 2026"

  const PeriodoMesModel({
    required this.year,
    required this.month,
    required this.key,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodoMesModel &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;
}

/// Panel lateral derecho (EndDrawer) para el filtrado avanzado de órdenes de venta (HU-3.5).
/// Implementa Flat Design estricto, sin sombras y con touch targets >= 48x48.
class HistorialFiltrosDrawer extends StatelessWidget {
  final bool verTodas;
  final String? filtroEstado;
  final String? periodoMes;
  final List<PeriodoMesModel>? periodosDisponibles;
  final ValueChanged<bool> onPeriodoChanged;
  final ValueChanged<String?> onEstadoChanged;
  final ValueChanged<String?>? onPeriodoMesChanged;
  final VoidCallback onAplicar;
  final VoidCallback onLimpiar;

  const HistorialFiltrosDrawer({
    super.key,
    required this.verTodas,
    required this.filtroEstado,
    this.periodoMes,
    this.periodosDisponibles,
    required this.onPeriodoChanged,
    required this.onEstadoChanged,
    this.onPeriodoMesChanged,
    required this.onAplicar,
    required this.onLimpiar,
  });

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.small.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: const Color(0xFFCBD5E1),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!isSelected),
        borderRadius: BorderRadius.circular(8.0),
        splashColor: selectedColor.withValues(alpha: 0.25),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : AppPalette.background,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isSelected ? selectedColor : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodoDropdown(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: periodoMes != null ? AppPalette.primary : Colors.white12,
          width: 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: const Key('dropdown_mes_historial'),
          value: periodoMes,
          isExpanded: true,
          dropdownColor: AppPalette.surface,
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontFamily: AppTypography.fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppPalette.textSecondary),
          hint: const Text(
            'Todo el Historial (Todos los meses)',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13.5,
            ),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todo el Historial (Todos los meses)'),
            ),
            if (periodosDisponibles != null)
              ...periodosDisponibles!.map(
                (p) => DropdownMenuItem<String?>(
                  value: p.key,
                  child: Text(p.label),
                ),
              ),
          ],
          onChanged: (val) {
            onPeriodoMesChanged?.call(val);
            if (val != null) {
              onPeriodoChanged(true);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomOffset = bottomPadding > 0 ? bottomPadding + 8.0 : 16.0;

    return Drawer(
      backgroundColor: AppPalette.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
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
                        isSelected: !verTodas && periodoMes == null,
                        onSelected: (selected) {
                          if (selected) {
                            onPeriodoChanged(false);
                            onPeriodoMesChanged?.call(null);
                          }
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Historial Completo',
                        isSelected: verTodas && periodoMes == null,
                        onSelected: (selected) {
                          if (selected) {
                            onPeriodoChanged(true);
                            onPeriodoMesChanged?.call(null);
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14.0),
                  _buildSectionTitle('MES DEL HISTORIAL'),
                  const SizedBox(height: 8.0),
                  _buildPeriodoDropdown(context),

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
                        label: 'Abonados',
                        isSelected: filtroEstado == 'Abonado',
                        activeColor: AppPalette.warning,
                        onSelected: (selected) {
                          onEstadoChanged(selected ? 'Abonado' : null);
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
                        label: 'Completadas',
                        isSelected: filtroEstado == 'Completada',
                        activeColor: AppPalette.primary,
                        onSelected: (selected) {
                          onEstadoChanged(selected ? 'Completada' : null);
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
              padding: EdgeInsets.fromLTRB(16.0, 14.0, 16.0, bottomOffset),
              decoration: const BoxDecoration(
                color: AppPalette.background,
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48.0,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.error,
                          disabledForegroundColor: AppPalette.error.withValues(alpha: 0.38),
                          side: BorderSide(color: AppPalette.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: () {
                          onLimpiar();
                          Navigator.of(context).pop();
                        },
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Limpiar',
                            maxLines: 1,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 48.0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onPressed: () {
                          onAplicar();
                          Navigator.of(context).pop();
                        },
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Aplicar Filtros',
                            maxLines: 1,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
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
