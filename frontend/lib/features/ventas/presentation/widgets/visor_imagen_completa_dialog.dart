// lib/features/ventas/presentation/widgets/visor_imagen_completa_dialog.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

/// Modal a pantalla completa para visualizar con zoom las fotografías del activo
/// sin perder el estado o monto digitado en la tasación.
class VisorImagenCompletaDialog extends StatefulWidget {
  final List<String> fotografias;
  final int initialIndex;

  const VisorImagenCompletaDialog({
    super.key,
    required this.fotografias,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> fotografias,
    int initialIndex = 0,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => VisorImagenCompletaDialog(
        fotografias: fotografias,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<VisorImagenCompletaDialog> createState() =>
      _VisorImagenCompletaDialogState();
}

class _VisorImagenCompletaDialogState extends State<VisorImagenCompletaDialog> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, int> _retryCounters = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.fotografias.isEmpty ? 0 : widget.fotografias.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _irAAnterior() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _irASiguiente() {
    if (_currentIndex < widget.fotografias.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _reintentarCarga(int index) {
    setState(() {
      _retryCounters[index] = (_retryCounters[index] ?? 0) + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fotografias.isEmpty) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 48, color: Colors.white54),
              const SizedBox(height: 12),
              Text(
                'Activo sin fotografías registradas.',
                style: AppTypography.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    }

    final totalFotos = widget.fotografias.length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Carrusel interactivo a pantalla completa
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: totalFotos,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final url = widget.fotografias[index];
              final retryKey = ValueKey('$url-${_retryCounters[index] ?? 0}');

              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    url,
                    key: retryKey,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      final total = loadingProgress.expectedTotalBytes;
                      final loaded = loadingProgress.cumulativeBytesLoaded;
                      return Center(
                        child: CircularProgressIndicator(
                          value: total != null ? loaded / total : null,
                          color: AppPalette.primary,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amberAccent,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Error al cargar la imagen. Presione para reintentar.',
                                textAlign: TextAlign.center,
                                style: AppTypography.small.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.primary,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Reintentar'),
                                onPressed: () => _reintentarCarga(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // Barra Superior: Botón de cierre y pill "Foto X de Y"
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (totalFotos > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'Foto ${_currentIndex + 1} de $totalFotos',
                      style: AppTypography.small.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                IconButton(
                  tooltip: 'Cerrar visor',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Botones de Navegación Lateral (si hay más de 1 imagen)
          if (totalFotos > 1 && _currentIndex > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                  onPressed: _irAAnterior,
                ),
              ),
            ),
          if (totalFotos > 1 && _currentIndex < totalFotos - 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                  onPressed: _irASiguiente,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
