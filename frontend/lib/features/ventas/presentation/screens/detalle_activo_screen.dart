// lib/features/ventas/presentation/screens/detalle_activo_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../controllers/cart_controller.dart';
import '../../models/catalogo_model.dart';

/// Pantalla Completa de Detalle del Repuesto (HU-3.2 / Fase 3 Mesón de Ventas).
/// Incluye carrusel de imágenes en gran formato con indicador interactivo,
/// ficha técnica detallada y barra inferior fija con acción de 'Agregar al Carrito'.
class DetalleActivoScreen extends StatefulWidget {
  final CatalogoItem item;
  final int? vendedorSucursalId;

  const DetalleActivoScreen({
    super.key,
    required this.item,
    this.vendedorSucursalId,
  });

  @override
  State<DetalleActivoScreen> createState() => _DetalleActivoScreenState();
}

class _DetalleActivoScreenState extends State<DetalleActivoScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  bool get _esMismaSucursal =>
      widget.vendedorSucursalId != null &&
      widget.item.idSucursalActual == widget.vendedorSucursalId;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onAddToCart() {
    final agregado = CartController.instance.agregarInventariado(widget.item);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppPalette.surface,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              agregado ? Icons.check_circle : Icons.info_outline,
              color: agregado ? AppPalette.primary : AppPalette.secondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                agregado
                    ? '${widget.item.tituloRepuesto} agregado al carrito'
                    : 'Este activo ya está en el carrito',
                style: AppTypography.small.copyWith(color: AppPalette.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (agregado && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> imagenes = widget.item.imagenes;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppPalette.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Volver',
        ),
        title: Text(
          'Detalle del Repuesto',
          style: AppTypography.title.copyWith(fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: _buildDisponibilidadBadge(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Carrusel / Galería de Fotos en Gran Formato ───────
                    _buildImageGallery(imagenes),
                    const SizedBox(height: 24),

                    // ── 2. Radar de Stock & SKU ──────────────────────────────
                    Row(
                      children: [
                        Flexible(child: _buildSucursalBadge()),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 5.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.surface,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            'SKU: ${widget.item.skuQrFisico}',
                            style: AppTypography.small.copyWith(
                              fontSize: 13,
                              color: AppPalette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── 3. Título Principal ──────────────────────────────────
                    Text(
                      widget.item.tituloRepuesto,
                      style: AppTypography.headline.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Categoría chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        widget.item.nombreCategoria.toUpperCase(),
                        style: AppTypography.small.copyWith(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── 4. Ficha Técnica Completa ────────────────────────────
                    _buildFichaTecnica(),
                    const SizedBox(height: 24),

                    // ── 5. Ubicación en Bodega ───────────────────────────────
                    _buildUbicacionCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Barra Fija Inferior (Bottom Action Bar) ─────────────────────
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  /// Visor / Carrusel de Imágenes
  Widget _buildImageGallery(List<String> imagenes) {
    final totalSlides = imagenes.isEmpty ? 1 : imagenes.length;

    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: totalSlides,
              onPageChanged: (idx) {
                setState(() => _currentImageIndex = idx);
              },
              itemBuilder: (context, index) {
                if (imagenes.isNotEmpty) {
                  return Image.network(
                    imagenes[index],
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _buildPlaceholderImage(),
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppPalette.primary,
                          ),
                        ),
                      );
                    },
                  );
                }
                return _buildPlaceholderImage();
              },
            ),

            // Indicador de Puntos / Páginas si hay más de 1
            if (totalSlides > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    totalSlides,
                    (idx) => Container(
                      width: _currentImageIndex == idx ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _currentImageIndex == idx
                            ? AppPalette.primary
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
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

  Widget _buildPlaceholderImage() {
    final bool esMotor = widget.item.nombreCategoria.toLowerCase().contains('motor');
    final IconData icono = esMotor ? Icons.engineering : Icons.settings;

    return Container(
      color: AppPalette.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icono,
                size: 54,
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Fotografía Técnica de Inventario',
              style: AppTypography.small.copyWith(
                color: AppPalette.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Badge de Disponibilidad
  Widget _buildDisponibilidadBadge() {
    final estado = widget.item.estadoActivo ?? 'Disponible';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppPalette.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppPalette.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppPalette.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            estado.toUpperCase(),
            style: AppTypography.small.copyWith(
              color: AppPalette.success,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge de Radar de Stock
  Widget _buildSucursalBadge() {
    if (_esMismaSucursal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: AppPalette.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: AppPalette.primary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.my_location, size: 16, color: AppPalette.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'En tu sucursal (${widget.item.nombreSucursal})',
                style: AppTypography.small.copyWith(
                  fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 16, color: AppPalette.neutral),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              widget.item.nombreSucursal,
              style: AppTypography.small.copyWith(
                fontSize: 13,
                color: AppPalette.neutral,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Ficha Técnica Completa
  Widget _buildFichaTecnica() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 20, color: AppPalette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ESPECIFICACIONES TÉCNICAS',
                  style: AppTypography.title.copyWith(
                    fontSize: 15,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          _buildSpecRow('Marca', widget.item.marca ?? 'N/A'),
          _buildSpecRow('Modelo', widget.item.modelo ?? 'N/A'),
          _buildSpecRow('Año', widget.item.anio?.toString() ?? 'N/A'),
          if (widget.item.idCategoria == 1 && widget.item.numeroMotor != null && widget.item.numeroMotor!.isNotEmpty)
            _buildSpecRow('Número de Motor', widget.item.numeroMotor!),
          if (widget.item.cilindrada != null && widget.item.cilindrada!.isNotEmpty)
            _buildSpecRow('Cilindrada', widget.item.cilindrada!),
          if (widget.item.transmisionTipo != null && widget.item.transmisionTipo!.isNotEmpty)
            _buildSpecRow('Transmisión', widget.item.transmisionTipo!),
          if (widget.item.combustible != null && widget.item.combustible!.isNotEmpty)
            _buildSpecRow('Combustible', widget.item.combustible!),
          if (widget.item.traccion != null && widget.item.traccion!.isNotEmpty)
            _buildSpecRow('Tracción', widget.item.traccion!),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.small.copyWith(
                color: AppPalette.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ubicación en Bodega
  Widget _buildUbicacionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 20, color: AppPalette.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'UBICACIÓN FÍSICA EN BODEGA',
                  style: AppTypography.title.copyWith(
                    fontSize: 15,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              Expanded(
                child: _buildLocationTile(
                  'Galpón',
                  (widget.item.ubicacionGalpon != null && widget.item.ubicacionGalpon!.trim().isNotEmpty)
                      ? widget.item.ubicacionGalpon!.trim()
                      : 'S/G',
                  Icons.warehouse_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLocationTile(
                  'Pasillo',
                  (widget.item.ubicacionPasillo != null && widget.item.ubicacionPasillo!.trim().isNotEmpty)
                      ? widget.item.ubicacionPasillo!.trim()
                      : 'S/P',
                  Icons.view_column_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLocationTile(
                  'Pallet',
                  (widget.item.ubicacionPallet != null && widget.item.ubicacionPallet!.trim().isNotEmpty)
                      ? widget.item.ubicacionPallet!.trim()
                      : 'S/P',
                  Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppPalette.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.small.copyWith(
                    fontSize: 11,
                    color: AppPalette.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Barra Fija Inferior con Precio y Botón Agregar
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Precio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PRECIO SUGERIDO',
                  style: AppTypography.small.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.0,
                    color: AppPalette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item.precioSugeridoFormateado,
                  style: AppTypography.headline.copyWith(
                    color: AppPalette.secondary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.item.precioMinimo != null && widget.item.precioMaximo != null && widget.item.precioMinimo != widget.item.precioMaximo) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Rango: ${widget.item.rangoPrecioFormateado}',
                    style: AppTypography.small.copyWith(
                      fontSize: 11,
                      color: AppPalette.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Botón Agregar
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              key: const Key('btn_agregar_carrito_detalle'),
              onPressed: _onAddToCart,
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text(
                'Agregar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: AppPalette.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
