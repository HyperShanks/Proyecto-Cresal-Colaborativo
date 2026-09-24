// lib/features/ventas/presentation/widgets/catalogo_item_card.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/catalogo_model.dart';
import '../screens/detalle_activo_screen.dart';
import 'visor_imagen_completa_dialog.dart';
import 'cart_fly_animation.dart';

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
                // ── 1. Fila Superior: Miniatura + Título del Activo ──────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Miniatura / Thumbnail interactiva
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10.0),
                        onTap: item.imagenes.isNotEmpty
                            ? () {
                                VisorImagenCompletaDialog.show(
                                  context,
                                  fotografias: item.imagenes,
                                  initialIndex: 0,
                                  titulo: item.tituloRepuesto,
                                  sku: item.skuQrFisico,
                                );
                              }
                            : null,
                        child: Container(
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
                                    cacheWidth: 200,
                                    cacheHeight: 200,
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
                          if (item.observacionEstado != null &&
                              item.observacionEstado!.trim().isNotEmpty &&
                              item.observacionEstado!.trim().toLowerCase() != 'null' &&
                              item.observacionEstado!.trim() != 'Sin observaciones registradas.') ...[
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppPalette.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppPalette.secondary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.sticky_note_2_outlined,
                                    size: 13,
                                    color: AppPalette.secondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Obs: ${item.observacionEstado!.trim()}',
                                      style: AppTypography.small.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppPalette.secondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 2. Fila Intermedia: Badge Sucursal + Chip Estado Disponible ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildSucursalBadge(),
                    const SizedBox(width: 8.0),
                    _buildDisponibilidadChip(),
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
                            'PRECIO SUGERIDO',
                            style: AppTypography.small.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.0,
                              color: AppPalette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.precioSugeridoFormateado,
                            style: AppTypography.headline.copyWith(
                              color: AppPalette.secondary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.precioMinimo != null && item.precioMaximo != null && item.precioMinimo != item.precioMaximo) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Rango: ${item.rangoPrecioFormateado}',
                              style: AppTypography.small.copyWith(
                                fontSize: 11,
                                color: AppPalette.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
    final bool esReservado = item.esReservado;
    final estado = esReservado ? 'RESERVADO' : (item.estadoActivo ?? 'Disponible');
    final bool esDisponible = !esReservado && estado.toLowerCase() == 'disponible';
    final colorChip = esDisponible
        ? AppPalette.success
        : (esReservado ? const Color(0xFFF59E0B) : AppPalette.secondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: colorChip.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: colorChip.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Text(
        estado.toUpperCase(),
        style: AppTypography.small.copyWith(
          fontSize: 11,
          color: colorChip,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Formatea el nombre de la sucursal de manera concisa: 'Viña' o 'Limache'.
  String _formatearNombreSucursal(String nombre) {
    final lower = nombre.toLowerCase();
    if (lower.contains('viña') || lower.contains('vina')) {
      return 'Viña';
    }
    if (lower.contains('limache')) {
      return 'Limache';
    }
    return nombre.isNotEmpty ? nombre : 'Sucursal';
  }

  /// Distintivo de Sucursal con visibilidad completa y limpia
  Widget _buildSucursalBadge() {
    final nombreBase = item.nombreSucursal.isNotEmpty ? item.nombreSucursal : 'Sucursal';
    final nombreSuc = _formatearNombreSucursal(nombreBase);

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
            const SizedBox(width: 6),
            Text(
              nombreSuc,
              style: AppTypography.small.copyWith(
                fontSize: 12,
                color: AppPalette.primary,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 14,
            color: AppPalette.neutral,
          ),
          const SizedBox(width: 6),
          Text(
            nombreSuc,
            style: AppTypography.small.copyWith(
              fontSize: 12,
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Botón de Carrito con área interactiva mínima de 48x48 px.
  /// Se desactiva visualmente si el activo se encuentra bloqueado/reservado.
  Widget _buildCartButton() {
    final bool bloqueado = item.esReservado;

    return Builder(
      builder: (btnContext) {
        return Tooltip(
          message: bloqueado
              ? 'Repuesto reservado temporalmente'
              : 'Agregar al carrito',
          child: SizedBox(
            width: 48.0,
            height: 48.0,
            child: Material(
              color: bloqueado
                  ? AppPalette.neutral.withValues(alpha: 0.25)
                  : AppPalette.primary,
              borderRadius: BorderRadius.circular(10.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(10.0),
                onTap: bloqueado
                    ? null
                    : () {
                        CartFlyAnimation.run(context: btnContext);
                        onAddToCart?.call();
                      },
                child: Center(
                  child: Icon(
                    bloqueado
                        ? Icons.lock_clock_outlined
                        : Icons.add_shopping_cart,
                    color: bloqueado
                        ? AppPalette.textSecondary
                        : AppPalette.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
