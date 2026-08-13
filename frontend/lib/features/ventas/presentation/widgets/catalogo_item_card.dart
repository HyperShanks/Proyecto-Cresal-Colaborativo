// lib/features/ventas/presentation/widgets/catalogo_item_card.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/catalogo_model.dart';

/// Tarjeta de repuesto en Flat Design estricto (sin sombras).
/// Muestra información técnica, precio y el distintivo (badge) del Radar de Stock.
class CatalogoItemCard extends StatelessWidget {
  final CatalogoItem item;
  final int? vendedorSucursalId;
  final VoidCallback? onAddToCart;
  final VoidCallback? onTap;

  const CatalogoItemCard({
    super.key,
    required this.item,
    this.vendedorSucursalId,
    this.onAddToCart,
    this.onTap,
  });

  bool get _esMismaSucursal =>
      vendedorSucursalId != null && item.idSucursalActual == vendedorSucursalId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: _esMismaSucursal
              ? AppPalette.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
          width: 1.0,
        ),
        // REGLA SystemDesignCresal: Cero uso de sombras (Flat Design)
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fila Superior: Badge Sucursal + SKU ───────────────────────
                Row(
                  children: [
                    _buildSucursalBadge(),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        'SKU: ${item.skuQrFisico}',
                        style: AppTypography.small.copyWith(
                          fontSize: 12,
                          color: AppPalette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Título del Repuesto ──────────────────────────────────────
                Text(
                  item.tituloRepuesto,
                  style: AppTypography.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // ── Fila de Especificaciones Técnicas ────────────────────────
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: [
                    if (item.cilindrada != null && item.cilindrada!.isNotEmpty)
                      _buildTechChip(item.cilindrada!, Icons.speed),
                    if (item.combustible != null && item.combustible!.isNotEmpty)
                      _buildTechChip(item.combustible!, Icons.local_gas_station),
                    if (item.transmisionTipo != null && item.transmisionTipo!.isNotEmpty)
                      _buildTechChip(item.transmisionTipo!, Icons.settings),
                    if (item.traccion != null && item.traccion!.isNotEmpty)
                      _buildTechChip(item.traccion!, Icons.all_inclusive),
                    _buildTechChip(
                      'Ubicación: ${item.ubicacionFormateada}',
                      Icons.place_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Fila Inferior: Precio + Botón de Carrito (Touch Target 48x48) ─
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Precio de Referencia
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRECIO REFERENCIA',
                            style: AppTypography.small.copyWith(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.precioFormateado,
                            style: AppTypography.headline.copyWith(
                              color: AppPalette.secondary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Botón de Carrito con Touch Target de 48x48
                    _buildCartButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Distintivo de Sucursal según algoritmo Radar de Stock
  Widget _buildSucursalBadge() {
    if (_esMismaSucursal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: AppPalette.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: AppPalette.primary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.my_location,
              size: 14,
              color: AppPalette.primary,
            ),
            const SizedBox(width: 5),
            Text(
              'En tu sucursal (${item.nombreSucursal})',
              style: AppTypography.small.copyWith(
                fontSize: 12,
                color: AppPalette.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 14,
            color: AppPalette.neutral,
          ),
          const SizedBox(width: 5),
          Text(
            item.nombreSucursal,
            style: AppTypography.small.copyWith(
              fontSize: 12,
              color: AppPalette.neutral,
            ),
          ),
        ],
      ),
    );
  }

  /// Chip compacto para especificaciones técnicas
  Widget _buildTechChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppPalette.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.small.copyWith(
              fontSize: 11,
              color: AppPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Botón de Carrito con área interactiva mínima de 48x48 px
  Widget _buildCartButton() {
    return SizedBox(
      width: 48.0,
      height: 48.0,
      child: Material(
        color: AppPalette.primary,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: onAddToCart,
          child: const Center(
            child: Icon(
              Icons.add_shopping_cart,
              color: AppPalette.textPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
