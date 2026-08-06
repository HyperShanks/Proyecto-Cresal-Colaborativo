import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../screens/detalle_activo_screen.dart';

class ResultadoCard extends StatelessWidget {
  final Map<String, dynamic> itemCompleto;
  final String marca;
  final String modelo;
  final String sku;
  final String ubicacion;
  final String estado;

  const ResultadoCard({
    Key? key,
    required this.itemCompleto,
    required this.marca,
    required this.modelo,
    required this.sku,
    required this.ubicacion,
    required this.estado,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lógica visual para el estado
    Color estadoColor;
    switch (estado.toUpperCase()) {
      case 'DISPONIBLE':
        estadoColor = AppPalette.success;
        break;
      case 'RESERVADO':
        estadoColor = AppPalette.secondary;
        break;
      case 'VENDIDO':
        estadoColor = AppPalette.error;
        break;
      default:
        estadoColor = AppPalette.neutral;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                // ⚠️ AHORA PASAMOS EL JSON COMPLETO INTACTO A LA FICHA
                builder: (context) => DetalleActivoScreen(activo: itemCompleto),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppPalette.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.settings_suggest,
                    color: AppPalette.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              // ⚠️ AHORA ES DINÁMICO
                              '${itemCompleto['categoria'] ?? 'Activo'} $marca $modelo',
                              style: AppTypography.title.copyWith(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: estadoColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: estadoColor, width: 1),
                            ),
                            child: Text(
                              estado.toUpperCase(),
                              style: AppTypography.small.copyWith(
                                color: estadoColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: $sku',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ubicacion,
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
