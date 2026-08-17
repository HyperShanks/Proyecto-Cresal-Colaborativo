// lib/features/ventas/presentation/widgets/catalogo_item_card.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/catalogo_model.dart';
import '../screens/detalle_activo_screen.dart';

/// Tarjeta de repuesto en Flat Design para Mesón de Ventas / Catálogo (HU-3.2).
/// Contenido simplificado y tipografía aumentada para lectura rápida en tablets.
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

  void _abrirDetalle(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => DetalleActivoScreen(
          item: item,
          vendedorSucursalId: vendedorSucursalId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esMotor = item.nombreCategoria.toLowerCase().contains('motor');
    final IconData iconoPieza = esMotor ? Icons.engineering : Icons.settings;

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: _esMismaSucursal
              ? AppPalette.primary.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.0),
          onTap: onTap ?? () => _abrirDetalle(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Fila Superior: Badge Sucursal + SKU + Chip Estado ───
                Row(
                  children: [
                    Flexible(child: _buildSucursalBadge()),
                    const SizedBox(width: 8.0),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    _buildDisponibilidadChip(),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 2. Cuerpo Principal: Miniatura + Título Simplificado ────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Miniatura / Thumbnail
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: item.imagenes.isNotEmpty
                            ? Image.network(
                                item.imagenes.first,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Center(
                                  child: Icon(
                                    iconoPieza,
                                    size: 32,
                                    color: AppPalette.primary,
                                  ),
                                ),
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppPalette.primary,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Icon(
                                  iconoPieza,
                                  size: 32,
                                  color: AppPalette.primary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Título (Marca, Modelo, Año y Categoría)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.tituloRepuesto,
                            style: AppTypography.headline.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.nombreCategoria} • ${item.ubicacionFormateada}',
                            style: AppTypography.small.copyWith(
                              fontSize: 13,
                              color: AppPalette.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── 3. Fila Inferior: Precio Destacado + Botón de Carrito ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Precio de Referencia Destacado
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRECIO REFERENCIA',
                            style: AppTypography.small.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.0,
                              color: AppPalette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.precioFormateado,
                            style: AppTypography.headline.copyWith(
                              color: AppPalette.secondary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Botón de Carrito (Touch Target 48x48)
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

  /// Chip de Disponibilidad
  Widget _buildDisponibilidadChip() {
    final estado = item.estadoActivo ?? 'Disponible';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: AppPalette.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Text(
        estado.toUpperCase(),
        style: AppTypography.small.copyWith(
          fontSize: 11,
          color: AppPalette.success,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Distintivo de Sucursal según algoritmo Radar de Stock
  Widget _buildSucursalBadge() {
    if (_esMismaSucursal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
            Flexible(
              child: Text(
                'En tu sucursal (${item.nombreSucursal})',
                style: AppTypography.small.copyWith(
                  fontSize: 12,
                  color: AppPalette.primary,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          Flexible(
            child: Text(
              item.nombreSucursal,
              style: AppTypography.small.copyWith(
                fontSize: 12,
                color: AppPalette.neutral,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        borderRadius: BorderRadius.circular(10.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
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
