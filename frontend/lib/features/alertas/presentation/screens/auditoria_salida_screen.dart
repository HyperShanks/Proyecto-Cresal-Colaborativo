import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

class AuditoriaSalidaScreen extends StatelessWidget {
  const AuditoriaSalidaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(
          'AUDITORÍA DE SALIDA',
          style: AppTypography.headline.copyWith(
            color: AppPalette.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: AppPalette.surface,
        iconTheme: const IconThemeData(color: AppPalette.primary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header de advertencia
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.neutral.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: AppPalette.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verificación de doble factor requerida.',
                      style: AppTypography.button,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tarjeta 1: Escaneo de Pieza
            _buildScanCard(
              title: '1. Escanee QR de la Pieza',
              subtitle: '(Motor/Caja)',
              isActive: false, // Simula que ya fue escaneado en tu mock visual
              isCompleted: true,
            ),
            const SizedBox(height: 16),

            // Tarjeta 2: Escaneo de Vendedor
            _buildScanCard(
              title: '2. Escanee QR de la Tablet del Vendedor',
              subtitle: 'ESPERANDO LECTURA...',
              isActive: true, // Simula que está esperando escaneo
              isCompleted: false,
            ),

            const Spacer(),

            // Botón Gigante de Match Exitoso (Deshabilitado por ahora en el mock)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppPalette.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.success, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppPalette.success,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'MATCH EXITOSO',
                        style: AppTypography.headline.copyWith(
                          color: AppPalette.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Ref: MT-8820-A1 / ID: VD-9912',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Botón de Ejecución Final
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.inventory_2,
                  color: AppPalette.textPrimary,
                ),
                label: Text(
                  'DESCONTAR INVENTARIO Y ENTREGAR',
                  style: AppTypography.button,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary, // Azul Cresal
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppPalette.primary
              : (isCompleted
                    ? AppPalette.success
                    : AppPalette.neutral.withOpacity(0.3)),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppPalette.primary.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 40,
                color: isActive ? AppPalette.primary : AppPalette.textSecondary,
              ),
              if (isCompleted) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle,
                  color: AppPalette.success,
                  size: 24,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.title.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? AppPalette.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subtitle,
              style: AppTypography.small.copyWith(
                color: isActive ? AppPalette.primary : AppPalette.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
