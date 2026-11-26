// frontend/lib/features/gerencia/presentation/widgets/auditoria_detalle_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../auth/services/auth_service.dart';
import '../../../caja/models/historial_caja_model.dart';
import '../../../caja/presentation/widgets/cobro_pendiente_card.dart';
import '../../../caja/presentation/widgets/editar_pago_dialog.dart';
import 'auditoria_tabla_view.dart';
import 'gestionar_orden_gerencia_dialog.dart';

/// Modal Forense 360° de Auditoría de Venta para Gerencia (HU-5.2 / TAREA-25).
/// Integra cabecera con folio y estado oficial, ficha cliente/responsables,
/// listado de artículos, desglose de pagos con corrección inline para Gerencia,
/// línea de tiempo completa (incluyendo preparación en bodega y doble escaneo en barrera)
/// y acceso directo a gestión administrativa de la orden.
class AuditoriaDetalleDialog extends StatelessWidget {
  final HistorialOrdenItemModel orden;
  final VoidCallback? onOrdenModificada;

  const AuditoriaDetalleDialog({
    super.key,
    required this.orden,
    this.onOrdenModificada,
  });

  static Future<void> show(
    BuildContext context,
    HistorialOrdenItemModel orden, {
    VoidCallback? onOrdenModificada,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => AuditoriaDetalleDialog(
        orden: orden,
        onOrdenModificada: onOrdenModificada,
      ),
    );
  }

  static ({Color bg, Color border, Color text}) _getEstadoStyle(String estado) {
    switch (estado.toLowerCase()) {
      case 'completada':
        return (
          bg: const Color(0xFF2596BE).withValues(alpha: 0.12),
          border: const Color(0xFF2596BE).withValues(alpha: 0.4),
          text: const Color(0xFF2596BE),
        );
      case 'reservada':
      case 'pendiente':
        return (
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFDE68A),
          text: const Color(0xFFD97706),
        );
      case 'despachada':
        return (
          bg: const Color(0xFFF5F3FF),
          border: const Color(0xFFDDD6FE),
          text: const Color(0xFF7C3AED),
        );
      case 'pagada':
        return (
          bg: const Color(0xFF2E7D32).withValues(alpha: 0.12),
          border: const Color(0xFF2E7D32).withValues(alpha: 0.4),
          text: const Color(0xFF2E7D32),
        );
      case 'anulada':
        return (
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFFECACA),
          text: const Color(0xFFDC2626),
        );
      default:
        return (
          bg: const Color(0xFFF8FAFC),
          border: const Color(0xFFE2E8F0),
          text: const Color(0xFF64748B),
        );
    }
  }

  String _formatearFechaRegistro() {
    try {
      final now = DateTime.now();
      final dt = DateTime.parse(orden.fechaIso).toLocal();
      final esHoy =
          dt.year == now.year && dt.month == now.month && dt.day == now.day;
      if (esHoy) {
        return 'Registrada el Hoy ${orden.hora}';
      }
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      final anio = dt.year.toString().substring(
        dt.year.toString().length >= 2 ? dt.year.toString().length - 2 : 0,
      );
      return 'Registrada el $dia/$mes/$anio ${orden.hora}';
    } catch (_) {
      return 'Registrada el ${orden.fechaHoraFormateada}'.replaceAll(
        '/2026',
        '/26',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoStyle = _getEstadoStyle(orden.estadoOrden);
    final bool puedeEditar = AuthService.cachedUser?.idRol != 8;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 560,
          maxHeight: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. CABECERA: AUDITORÍA DE VENTA + BADGE + FOLIO + CLOSE BUTTON ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'AUDITORÍA DE VENTA',
                              style: AppTypography.small.copyWith(
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: estadoStyle.bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: estadoStyle.border,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                orden.estadoOrden,
                                style: AppTypography.small.copyWith(
                                  color: estadoStyle.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              orden.folioDisplay,
                              style: AppTypography.headline.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0284C7),
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (AuditoriaTablaView.buildBadgesMotorCaja(
                                  orden,
                                  context: context,
                                ) !=
                                null) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: AuditoriaTablaView.buildBadgesMotorCaja(orden, context: context)!,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatearFechaRegistro(),
                          style: AppTypography.small.copyWith(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: Color(0xFF94A3B8),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── CONTENIDO SCROLLABLE ──
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 2. TARJETA: CLIENTE Y RESPONSABLES ──
                      _buildCardClienteResponsables(),

                      const SizedBox(height: 18),

                      // ── 3. SECCIÓN: ARTÍCULOS Y REPUESTOS ──
                      _buildSeccionArticulos(),

                      const SizedBox(height: 18),

                      // ── 4. SECCIÓN: DESGLOSE EXACTO DE PAGOS ──
                      _buildSeccionPagos(context, puedeEditar),

                      const SizedBox(height: 18),

                      // ── 5. SECCIÓN: LÍNEA DE TIEMPO / MOVIMIENTOS ──
                      _buildSeccionTimeline(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── 6. BOTONES INFERIORES: GESTIONAR / CERRAR ──
              if (puedeEditar)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.2),
                            backgroundColor: const Color(0xFFF0F9FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final modificado = await GestionarOrdenGerenciaDialog.show(
                              context,
                              orden,
                            );
                            if (modificado == true) {
                              onOrdenModificada?.call();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          },
                          icon: const Icon(Icons.edit_note_rounded, size: 19),
                          label: Text(
                            'Gestionar Orden',
                            style: AppTypography.button.copyWith(
                              color: const Color(0xFF0284C7),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Cerrar',
                            style: AppTypography.button.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cerrar',
                      style: AppTypography.button.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta con dos columnas: Cliente y Responsables
  Widget _buildCardClienteResponsables() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna Cliente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLIENTE',
                  style: AppTypography.small.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  orden.clienteNombre,
                  style: AppTypography.small.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (orden.clienteRut != null &&
                    orden.clienteRut!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'RUT: ${orden.clienteRut}',
                    style: AppTypography.small.copyWith(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Columna Responsables
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESPONSABLES',
                  style: AppTypography.small.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'Vendedor: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      fontSize: 11.5,
                    ),
                    children: [
                      TextSpan(
                        text: orden.vendedorNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: 'Cajera: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      fontSize: 11.5,
                    ),
                    children: [
                      TextSpan(
                        text: orden.cajeraNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
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

  /// Sección con lista de artículos y repuestos
  Widget _buildSeccionArticulos() {
    final articulos = orden.articulos;
    final totalItems = articulos.isNotEmpty ? articulos.length : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.widgets_outlined,
                  size: 15,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 6),
                Text(
                  'ARTÍCULOS Y REPUESTOS',
                  style: AppTypography.small.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            Text(
              '$totalItems items',
              style: AppTypography.small.copyWith(
                color: const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: articulos.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: articulos.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 16,
                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final art = articulos[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${art.cantidad}x',
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0284C7),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                art.descripcion,
                                style: AppTypography.small.copyWith(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 3,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (art.sku != null && art.sku!.isNotEmpty) ...[
                                      if (art.activoAuditado == null)
                                        Text(
                                          'SKU: ${art.sku}',
                                          style: AppTypography.small.copyWith(
                                            color: const Color(0xFF64748B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFA7F3D0),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Text(
                                          'Activo Físico',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (art.activoAuditado != null)
                                      AuditoriaTablaView.buildBadgeActivo(
                                        art.activoAuditado!,
                                        context: context,
                                      ),
                                    if (art.vehiculoOrigenDisplay != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.directions_car_rounded,
                                              size: 10,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              art.vehiculoOrigenDisplay!,
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CobroPendienteCard.formatClp(art.subtotal),
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  },
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '1x',
                        style: AppTypography.small.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0284C7),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Repuesto / Orden Consolidada',
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            'Folio: ${orden.folioDisplay}',
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CobroPendienteCard.formatClp(
                        orden.totalVenta > 0
                            ? orden.totalVenta
                            : orden.totalLiquidado,
                      ),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Sección con desglose exacto de pagos y Total Liquidado
  Widget _buildSeccionPagos(BuildContext context, bool puedeEditar) {
    final pagos = orden.desglosePagos;
    final total = orden.totalLiquidado > 0
        ? orden.totalLiquidado
        : ((orden.montoPendiente > 0 || orden.esAnulada)
            ? 0
            : (orden.totalVenta > 0 ? orden.totalVenta : 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 15,
              color: Color(0xFF059669),
            ),
            const SizedBox(width: 6),
            Text(
              'DESGLOSE EXACTO DE PAGOS',
              style: AppTypography.small.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            children: [
              if (pagos.isNotEmpty)
                ...pagos.map((pago) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pago.metodoPago,
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (puedeEditar &&
                            !orden.esAnulada &&
                            pago.idTransaccion != null) ...[
                          InkWell(
                            onTap: () async {
                              final actualizado = await EditarPagoDialog.show(
                                context: context,
                                orden: orden,
                                pago: pago,
                              );
                              if (actualizado == true) {
                                onOrdenModificada?.call();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: Color(0xFF475569),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Corregir',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          CobroPendienteCard.formatClp(pago.monto),
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                })
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        orden.metodosResumen.isNotEmpty
                            ? orden.metodosResumen
                            : 'Sin pagos registrados',
                        style: AppTypography.small.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        CobroPendienteCard.formatClp(total),
                        style: AppTypography.small.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              if (orden.descuento > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.confirmation_num_outlined,
                            size: 14,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Descuento a Favor',
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '- ${CobroPendienteCard.formatClp(orden.descuento)}',
                        style: AppTypography.small.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDC2626),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
              ),
              const SizedBox(height: 8),

              // Total Liquidado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL LIQUIDADO:',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    CobroPendienteCard.formatClp(total),
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0284C7),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              if (orden.montoPendiente > 0 && !orden.esAnulada) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SALDO PENDIENTE:',
                      style: AppTypography.small.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFC2410C),
                        fontSize: 11.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      CobroPendienteCard.formatClp(orden.montoPendiente),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFC2410C),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Determina el ícono y color distintivo de cada hito de la línea de tiempo
  static ({IconData icon, Color color}) _estiloMovimiento(String evento) {
    final ev = evento.toLowerCase();
    if (ev.contains('barrera') || ev.contains('doble escaneo')) {
      return (icon: Icons.verified_rounded, color: const Color(0xFF059669));
    }
    if (ev.contains('bodega') || ev.contains('pre-entrega')) {
      return (icon: Icons.inventory_2_outlined, color: const Color(0xFF4F46E5));
    }
    if (ev.contains('anulada') || ev.contains('reversado') || ev.contains('fallida')) {
      return (icon: Icons.cancel_outlined, color: const Color(0xFFDC2626));
    }
    if (ev.contains('corregido') || ev.contains('modificado') || ev.contains('ajustada')) {
      return (icon: Icons.history_edu_rounded, color: const Color(0xFFD97706));
    }
    if (ev.contains('pago') || ev.contains('abono') || ev.contains('liquidado')) {
      return (icon: Icons.payments_outlined, color: const Color(0xFF0284C7));
    }
    return (icon: Icons.access_time_rounded, color: const Color(0xFF64748B));
  }

  /// Sección de línea de tiempo con hitos y marcas de hora
  Widget _buildSeccionTimeline() {
    final movimientos = orden.historialMovimientos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 15,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              'LÍNEA DE TIEMPO / MOVIMIENTOS',
              style: AppTypography.small.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: movimientos.isNotEmpty
                ? movimientos.map((mov) {
                    final horaDisplay = mov.hora.replaceAll('/2026', '/26');
                    final isLast = mov == movimientos.last;
                    final estilo = _estiloMovimiento(mov.evento);
                    final esBarrera = mov.evento.toLowerCase().contains('doble escaneo') ||
                        mov.evento.toLowerCase().contains('barrera');
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                      child: Container(
                        width: double.infinity,
                        padding: esBarrera
                            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                            : EdgeInsets.zero,
                        decoration: esBarrera
                            ? BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                  width: 0.8,
                                ),
                              )
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  estilo.icon,
                                  size: 13.5,
                                  color: estilo.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  horaDisplay,
                                  style: AppTypography.small.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: esBarrera
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFF334155),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.only(left: 19),
                              child: Text(
                                mov.evento,
                                style: AppTypography.small.copyWith(
                                  color: esBarrera
                                      ? const Color(0xFF047857)
                                      : const Color(0xFF475569),
                                  fontSize: 11.5,
                                  fontWeight: esBarrera ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList()
                : [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              orden.hora,
                              style: AppTypography.small.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF334155),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: Text(
                            'Orden emitida en Mesón por ${orden.vendedorNombre}',
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFF475569),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              orden.hora,
                              style: AppTypography.small.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF334155),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: Text(
                            'Pago liquidado en ventanilla por ${orden.cajeraNombre}',
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFF475569),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
          ),
        ),
      ],
    );
  }
}
