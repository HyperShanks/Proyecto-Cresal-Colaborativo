// frontend/lib/features/gerencia/presentation/widgets/panel_filtros_avanzados.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

/// Barra de filtros multidimensionales de alta densidad para el visor de órdenes (HU-5.2).
/// Diseñé este widget inspirándome en la barra unificada de `prototipo_gerencia_v1.html`,
/// permitiendo filtrar simultáneamente por término libre, rango temporal predeterminado,
/// estado oficial de la orden y método de pago con botón de limpieza inmediata.
class PanelFiltrosAvanzados extends StatelessWidget {
  final TextEditingController busquedaController;
  final ValueChanged<String> onBusquedaChanged;
  final String periodoSeleccionado;
  final ValueChanged<String> onPeriodoChanged;
  final String estadoSeleccionado;
  final ValueChanged<String> onEstadoChanged;
  final String metodoPagoSeleccionado;
  final ValueChanged<String> onMetodoPagoChanged;
  final VoidCallback onLimpiar;

  const PanelFiltrosAvanzados({
    super.key,
    required this.busquedaController,
    required this.onBusquedaChanged,
    required this.periodoSeleccionado,
    required this.onPeriodoChanged,
    required this.estadoSeleccionado,
    required this.onEstadoChanged,
    required this.metodoPagoSeleccionado,
    required this.onMetodoPagoChanged,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;

          final widgets = [
            // 1. Buscador Predictivo (Folio, Cliente, RUT o Vendedor)
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 240,
                maxWidth: isWide ? 340 : double.infinity,
              ),
              child: TextField(
                controller: busquedaController,
                onChanged: onBusquedaChanged,
                style: AppTypography.small.copyWith(
                  fontSize: 13,
                  color: AppPalette.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar por Folio, Cliente, RUT o Vendedor...',
                  hintStyle: AppTypography.small.copyWith(
                    color: AppPalette.textSecondaryLight.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppPalette.textSecondaryLight,
                  ),
                  suffixIcon: busquedaController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          color: AppPalette.textSecondaryLight,
                          onPressed: () {
                            busquedaController.clear();
                            onBusquedaChanged('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppPalette.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppPalette.neutral.withValues(alpha: 0.25),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppPalette.neutral.withValues(alpha: 0.25),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppPalette.tertiary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Segmented Buttons para Período Temporal Oficial
            _buildSegmentedPeriodo(),

            // 3. Dropdown de Estado Oficial (5 estados)
            _buildDropdownEstado(),

            // 4. Dropdown de Método de Pago
            _buildDropdownMetodoPago(),

            // 5. Botón Limpiar Filtros
            _buildBotonLimpiar(),
          ];

          if (isWide) {
            return Row(
              children: [
                Expanded(child: widgets[0]),
                const SizedBox(width: 12),
                widgets[1],
                const SizedBox(width: 12),
                widgets[2],
                const SizedBox(width: 12),
                widgets[3],
                const SizedBox(width: 12),
                widgets[4],
              ],
            );
          } else {
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: widgets,
            );
          }
        },
      ),
    );
  }

  Widget _buildSegmentedPeriodo() {
    final periodos = [
      {'id': 'hoy', 'label': 'Hoy'},
      {'id': '7d', 'label': 'Esta Semana'},
      {'id': '30d', 'label': 'Este Mes'},
      {'id': 'todos', 'label': 'Todo'},
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: periodos.map((p) {
          final isSelected = periodoSeleccionado == p['id'];
          return InkWell(
            onTap: () => onPeriodoChanged(p['id']!),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppPalette.surfaceLight : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                p['label']!,
                style: AppTypography.small.copyWith(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppPalette.tertiary
                      : AppPalette.textSecondaryLight,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdownEstado() {
    final estados = [
      {'value': 'todos', 'label': 'Estado: Todos'},
      {'value': 'Reservada', 'label': 'Reservada'},
      {'value': 'Pagada', 'label': 'Pagada'},
      {'value': 'Completada', 'label': 'Completada'},
      {'value': 'Despachada', 'label': 'Despachada'},
      {'value': 'Anulada', 'label': 'Anulada'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.25),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: estadoSeleccionado,
          isDense: true,
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppPalette.tertiary,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppPalette.tertiary,
          ),
          items: estados.map((e) {
            return DropdownMenuItem<String>(
              value: e['value'],
              child: Text(e['label']!),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onEstadoChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildDropdownMetodoPago() {
    final metodos = [
      {'value': 'todos', 'label': 'Método: Todos'},
      {'value': 'Transferencia', 'label': 'Transferencia'},
      {'value': 'Débito', 'label': 'Tarjeta Débito'},
      {'value': 'Crédito', 'label': 'Tarjeta Crédito'},
      {'value': 'Efectivo', 'label': 'Efectivo'},
      {'value': 'Cheque', 'label': 'Cheque'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.25),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: metodoPagoSeleccionado,
          isDense: true,
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppPalette.tertiary,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppPalette.tertiary,
          ),
          items: metodos.map((m) {
            return DropdownMenuItem<String>(
              value: m['value'],
              child: Text(m['label']!),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onMetodoPagoChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildBotonLimpiar() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(
          color: AppPalette.neutral.withValues(alpha: 0.3),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: const Icon(
        Icons.filter_alt_off_rounded,
        size: 16,
        color: AppPalette.textSecondaryLight,
      ),
      label: Text(
        'Limpiar',
        style: AppTypography.button.copyWith(
          color: AppPalette.textSecondaryLight,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      onPressed: onLimpiar,
    );
  }
}
