// lib/features/ventas/presentation/widgets/filtros_drawer.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

/// Panel lateral de filtros interactivos para el Catálogo de Repuestos (HU-3.2).
/// Diseñado con Flat Design estricto, respetando SystemDesignCresal.
class FiltrosDrawer extends StatelessWidget {
  final int? idCategoria;
  final int? idSucursal;
  final String? marca;
  final int? anio;
  final String? cilindrada;
  final String? transmision;
  final ValueChanged<int?> onCategoriaChanged;
  final ValueChanged<int?> onSucursalChanged;
  final ValueChanged<String?> onMarcaChanged;
  final ValueChanged<int?> onAnioChanged;
  final ValueChanged<String?> onCilindradaChanged;
  final ValueChanged<String?> onTransmisionChanged;
  final VoidCallback onLimpiarFiltros;

  const FiltrosDrawer({
    super.key,
    required this.idCategoria,
    required this.idSucursal,
    required this.marca,
    required this.anio,
    this.cilindrada,
    this.transmision,
    required this.onCategoriaChanged,
    required this.onSucursalChanged,
    required this.onMarcaChanged,
    required this.onAnioChanged,
    required this.onCilindradaChanged,
    required this.onTransmisionChanged,
    required this.onLimpiarFiltros,
  });

  static const List<String> _marcasDisponibles = [
    'Toyota',
    'Chevrolet',
    'Hyundai',
    'Nissan',
    'Kia',
    'Ford',
    'Peugeot',
    'Suzuki',
    'Volkswagen',
    'Honda',
    'Mitsubishi',
  ];

  static const List<String> _cilindradasDisponibles = [
    '1.0',
    '1.2',
    '1.4',
    '1.5',
    '1.6',
    '1.8',
    '2.0',
    '2.2',
    '2.4',
    '2.5',
    '3.0',
    '3.5',
  ];

  static const List<int> _aniosDisponibles = [
    2024,
    2023,
    2022,
    2021,
    2020,
    2019,
    2018,
    2017,
    2016,
    2015,
    2014,
    2013,
    2012,
    2011,
    2010,
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppPalette.background,
      elevation: 0,
      child: SafeArea(
        child: Column(
          children: [
            // ── Cabecera: Título + Botón Ocultar ─────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppPalette.surface,
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filtros',
                      style: AppTypography.title,
                    ),
                  ),
                  // Botón "Ocultar" superior derecho
                  Material(
                    color: AppPalette.primary,
                    borderRadius: BorderRadius.circular(8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8.0),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 6.0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.close,
                              color: AppPalette.textPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ocultar',
                              style: AppTypography.button.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Cuerpo de Filtros ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Sección TIPO
                    _buildSectionHeader('TIPO'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildChoiceChip(
                          label: 'Todos',
                          isSelected: idCategoria == null,
                          onSelected: (selected) {
                            if (selected) onCategoriaChanged(null);
                          },
                        ),
                        _buildChoiceChip(
                          label: 'Motores',
                          isSelected: idCategoria == 1,
                          onSelected: (selected) {
                            onCategoriaChanged(selected ? 1 : null);
                          },
                        ),
                        _buildChoiceChip(
                          label: 'Cajas',
                          isSelected: idCategoria == 2,
                          onSelected: (selected) {
                            onCategoriaChanged(selected ? 2 : null);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 2. Sección SUCURSAL
                    _buildSectionHeader('SUCURSAL'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildChoiceChip(
                          label: 'Todas',
                          isSelected: idSucursal == null,
                          onSelected: (selected) {
                            if (selected) onSucursalChanged(null);
                          },
                        ),
                        _buildChoiceChip(
                          label: 'Viña del Mar',
                          isSelected: idSucursal == 1,
                          onSelected: (selected) {
                            onSucursalChanged(selected ? 1 : null);
                          },
                        ),
                        _buildChoiceChip(
                          label: 'Limache',
                          isSelected: idSucursal == 2,
                          onSelected: (selected) {
                            onSucursalChanged(selected ? 2 : null);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 3. Sección MARCA DEL VEHÍCULO
                    _buildSectionHeader('MARCA DEL VEHÍCULO'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: marca,
                      isExpanded: true,
                      dropdownColor: AppPalette.surface,
                      style: AppTypography.body,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppPalette.textSecondary,
                      ),
                      decoration: _buildInputDecoration(hintText: 'Seleccionar marca'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Todas',
                            style: AppTypography.body,
                          ),
                        ),
                        ..._marcasDisponibles.map(
                          (m) => DropdownMenuItem<String?>(
                            value: m,
                            child: Text(
                              m,
                              style: AppTypography.body,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onMarcaChanged,
                    ),
                    const SizedBox(height: 24),

                    // 4. Sección AÑO DEL MOTOR / VEHÍCULO
                    _buildSectionHeader('AÑO DEL MOTOR'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: anio,
                      isExpanded: true,
                      dropdownColor: AppPalette.surface,
                      style: AppTypography.body,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppPalette.textSecondary,
                      ),
                      decoration: _buildInputDecoration(hintText: 'Seleccionar año'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Todos',
                            style: AppTypography.body,
                          ),
                        ),
                        ..._aniosDisponibles.map(
                          (a) => DropdownMenuItem<int?>(
                            value: a,
                            child: Text(
                              a.toString(),
                              style: AppTypography.body,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onAnioChanged,
                    ),
                    const SizedBox(height: 24),

                    // 5. Sección CILINDRADA
                    _buildSectionHeader('CILINDRADA'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: cilindrada,
                      isExpanded: true,
                      dropdownColor: AppPalette.surface,
                      style: AppTypography.body,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppPalette.textSecondary,
                      ),
                      decoration: _buildInputDecoration(hintText: 'Seleccionar cilindrada'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Todas',
                            style: AppTypography.body,
                          ),
                        ),
                        ..._cilindradasDisponibles.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c,
                            child: Text(
                              '$c L',
                              style: AppTypography.body,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onCilindradaChanged,
                    ),
                    const SizedBox(height: 24),

                    // 6. Sección TIPO DE TRANSMISIÓN
                    _buildSectionHeader('TIPO DE TRANSMISIÓN'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildChoiceChip(
                          label: 'Todas',
                          isSelected: transmision == null,
                          onSelected: (selected) {
                            if (selected) onTransmisionChanged(null);
                          },
                        ),
                        _buildChoiceChip(
                          label: 'Automática',
                          isSelected: transmision == 'Automatica' || transmision == 'Automática',
                          onSelected: (selected) {
                            onTransmisionChanged(selected ? 'Automatica' : null);
                          },
                        ),
                        _buildChoiceChip(
                          label: 'Mecánica',
                          isSelected: transmision == 'Mecanica' || transmision == 'Mecánica' || transmision == 'Manual',
                          onSelected: (selected) {
                            onTransmisionChanged(selected ? 'Mecanica' : null);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Botón Inferior: Limpiar Filtros ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppPalette.surface,
                    width: 1.5,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onLimpiarFiltros,
                  icon: const Icon(
                    Icons.close,
                    color: AppPalette.error,
                    size: 20,
                  ),
                  label: Text(
                    'Limpiar filtros',
                    style: AppTypography.button.copyWith(
                      color: AppPalette.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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
  }) {
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
      selectedColor: AppPalette.primary,
      backgroundColor: AppPalette.surface,
      elevation: 0,
      pressElevation: 0,
      side: BorderSide(
        color: isSelected
            ? AppPalette.primary
            : Colors.white.withValues(alpha: 0.08),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    );
  }

  InputDecoration _buildInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.body.copyWith(
        color: AppPalette.textSecondary,
      ),
      filled: true,
      fillColor: AppPalette.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(
          color: AppPalette.primary,
          width: 1.5,
        ),
      ),
    );
  }
}
