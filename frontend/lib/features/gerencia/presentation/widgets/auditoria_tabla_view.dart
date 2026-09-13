// frontend/lib/features/gerencia/presentation/widgets/auditoria_tabla_view.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../caja/models/historial_caja_model.dart';
import '../../../caja/presentation/widgets/cobro_pendiente_card.dart';

/// Tabla de alta fidelidad para el Visor Histórico de Órdenes y Auditoría de Ventas (HU-5.2).
/// Diseñé este widget replicando exactamente las 10 columnas del mockup oficial:
/// 1. FOLIO
/// 2. FECHA / HORA
/// 3. CLIENTE / RUT
/// 4. SUCURSAL
/// 5. VENDEDOR / CAJERA
/// 6. MÉTODO DE PAGO
/// 7. TOTAL VENTA
/// 8. PENDIENTE (columna dedicada con '—' o monto en ámbar/naranja si hay saldo)
/// 9. ESTADO OFICIAL (pills ovaladas con borde y tono pastel)
/// 10. ACCIONES (ícono de ojo Icons.visibility_outlined y etiqueta "Auditar")
class AuditoriaTablaView extends StatelessWidget {
  final List<HistorialOrdenItemModel> items;
  final int paginaActual;
  final int totalPaginas;
  final int totalRegistros;
  final int totalConsolidado;
  final ValueChanged<int> onCambiarPagina;
  final ValueChanged<HistorialOrdenItemModel> onVerDetalle;

  const AuditoriaTablaView({
    super.key,
    required this.items,
    required this.paginaActual,
    required this.totalPaginas,
    required this.totalRegistros,
    required this.totalConsolidado,
    required this.onCambiarPagina,
    required this.onVerDetalle,
  });

  /// Determina los colores pastel para los estados oficiales según el mockup
  static ({Color bg, Color border, Color text}) _getEstadoStyle(String estado) {
    switch (estado.toLowerCase()) {
      case 'completada':
        return (
          bg: const Color(0xFFECFDF5),
          border: const Color(0xFFA7F3D0),
          text: const Color(0xFF059669),
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
          bg: const Color(0xFFF0F9FF),
          border: const Color(0xFFBAE6FD),
          text: const Color(0xFF0284C7),
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

  /// Estilo de pill por método de pago según el mockup
  static ({Color bg, Color border, Color text}) _getMetodoStyle(String metodo) {
    final m = metodo.toLowerCase();
    if (m.contains('transf')) {
      return (
        bg: const Color(0xFFE0F2FE),
        border: const Color(0xFFBAE6FD),
        text: const Color(0xFF0284C7),
      );
    } else if (m.contains('débito') || m.contains('debito')) {
      return (
        bg: const Color(0xFFECFDF5),
        border: const Color(0xFFA7F3D0),
        text: const Color(0xFF059669),
      );
    } else if (m.contains('crédito') || m.contains('credito')) {
      return (
        bg: const Color(0xFFEEF2FF),
        border: const Color(0xFFC7D2FE),
        text: const Color(0xFF4F46E5),
      );
    } else if (m.contains('efectivo')) {
      return (
        bg: const Color(0xFFF0FDFA),
        border: const Color(0xFF99F6E4),
        text: const Color(0xFF0D9488),
      );
    } else if (m.contains('cheque')) {
      return (
        bg: const Color(0xFFFAF5FF),
        border: const Color(0xFFE9D5FF),
        text: const Color(0xFF9333EA),
      );
    } else {
      return (
        bg: const Color(0xFFF1F5F9),
        border: const Color(0xFFCBD5E1),
        text: const Color(0xFF475569),
      );
    }
  }

  /// Formatea la fecha en estilo "Hoy HH:mm" o "dd/MM HH:mm" como en el mockup
  String _formatearFechaHora(HistorialOrdenItemModel item) {
    try {
      final now = DateTime.now();
      final dt = DateTime.parse(item.fechaIso).toLocal();
      final esHoy =
          dt.year == now.year && dt.month == now.month && dt.day == now.day;
      if (esHoy) {
        return 'Hoy ${item.hora}';
      }
      final dia = dt.day.toString().padLeft(2, '0');
      final mes = dt.month.toString().padLeft(2, '0');
      return '$dia/$mes ${item.hora}';
    } catch (_) {
      return item.fechaHoraFormateada.isNotEmpty
          ? item.fechaHoraFormateada
          : 'Hoy ${item.hora}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppPalette.neutral.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── CABECERA DE LA TABLA (10 COLUMNAS EXACTAS) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppPalette.backgroundLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppPalette.neutral.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell('FOLIO', flex: 12),
                _buildHeaderCell('FECHA / HORA', flex: 10),
                _buildHeaderCell('CLIENTE / RUT', flex: 19),
                _buildHeaderCell('SUCURSAL', flex: 15),
                _buildHeaderCell('VENDEDOR / CAJERA', flex: 15),
                _buildHeaderCell('MÉTODO DE PAGO', flex: 20),
                _buildHeaderCell('TOTAL VENTA', flex: 13),
                _buildHeaderCell('PENDIENTE', flex: 12),
                _buildHeaderCell('ESTADO OFICIAL', flex: 13),
                _buildHeaderCell('ACCIONES',
                    flex: 12, alignment: Alignment.center),
              ],
            ),
          ),

          // ── CUERPO CON FILAS DE DATOS O ESTADO VACÍO ──
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No se encontraron órdenes',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Prueba ajustando los filtros de período, sucursal, estado o búsqueda.',
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AppPalette.neutral.withValues(alpha: 0.1),
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildRowItem(context, item);
                    },
                  ),
          ),

          // ── FOOTER UNIFICADO: CONTEO, PAGINACIÓN Y TOTAL CONSOLIDADO ──
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildRowItem(BuildContext context, HistorialOrdenItemModel item) {
    final estadoStyle = _getEstadoStyle(item.estadoOrden);

    return InkWell(
      onTap: () => onVerDetalle(item),
      hoverColor: AppPalette.primary.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // 1. FOLIO
            Expanded(
              flex: 12,
              child: Text(
                item.folio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  fontSize: 14,
                ),
              ),
            ),

            // 2. FECHA / HORA
            Expanded(
              flex: 10,
              child: Text(
                _formatearFechaHora(item),
                style: AppTypography.small.copyWith(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // 3. CLIENTE / RUT (2 líneas)
            Expanded(
              flex: 19,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.clienteNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      fontSize: 14,
                    ),
                  ),
                  if (item.clienteRut != null && item.clienteRut!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'RUT: ${item.clienteRut}',
                        style: AppTypography.small.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 4. SUCURSAL
            Expanded(
              flex: 15,
              child: Text(
                item.sucursalNombre.isNotEmpty
                    ? item.sucursalNombre
                    : 'Casa Matriz (Viña)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),

            // 5. VENDEDOR / CAJERA (2 líneas)
            Expanded(
              flex: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.vendedorNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.small.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Caja: ${item.cajeraNombre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.small.copyWith(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 6. MÉTODO DE PAGO (Pill + Monto)
            Expanded(
              flex: 20,
              child: _buildMetodoPagoCell(item),
            ),

            // 7. TOTAL VENTA
            Expanded(
              flex: 13,
              child: Text(
                CobroPendienteCard.formatClp(
                  item.totalVenta > 0 ? item.totalVenta : item.totalLiquidado,
                ),
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: item.esAnulada
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF0F172A),
                ),
              ),
            ),

            // 8. PENDIENTE (Columna dedicada: '—' si 0, $XXX.XXX en naranja si > 0)
            Expanded(
              flex: 12,
              child: item.montoPendiente > 0
                  ? Text(
                      CobroPendienteCard.formatClp(item.montoPendiente),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: const Color(0xFFC2410C), // Ámbar / Naranja alerta
                      ),
                    )
                  : Text(
                      '—',
                      style: AppTypography.body.copyWith(
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),

            // 9. ESTADO OFICIAL (Pill con borde y fondo suave)
            Expanded(
              flex: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: estadoStyle.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: estadoStyle.border,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    item.estadoOrden,
                    style: AppTypography.small.copyWith(
                      color: estadoStyle.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

            // 10. ACCIONES (Pastilla estilizada interactiva con hover pulido)
            Expanded(
              flex: 12,
              child: Align(
                alignment: Alignment.center,
                child: OutlinedButton.icon(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return const Color(0xFFE0F2FE); // Azul cielo suave al pasar el mouse
                      }
                      return const Color(0xFFF0F9FF); // Fondo claro sutil
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return const Color(0xFF0369A1); // Azul más vivo en hover
                      }
                      return const Color(0xFF0284C7);
                    }),
                    side: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return const BorderSide(color: Color(0xFF0284C7), width: 1.2);
                      }
                      return const BorderSide(color: Color(0xFFBAE6FD), width: 1.0);
                    }),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    ),
                    minimumSize: WidgetStateProperty.all(const Size(86, 30)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: WidgetStateProperty.all(0),
                  ),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 15,
                  ),
                  label: Text(
                    'Auditar',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () => onVerDetalle(item),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye la celda de método de pago con la pastilla coloreada y el monto
  Widget _buildMetodoPagoCell(HistorialOrdenItemModel item) {
    if (item.desglosePagos.isNotEmpty) {
      final primerPago = item.desglosePagos.first;
      final estilo = _getMetodoStyle(primerPago.metodoPago);
      final tieneMultiples = item.desglosePagos.length > 1;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: estilo.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: estilo.border, width: 0.8),
              ),
              child: Text(
                primerPago.metodoPago,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small.copyWith(
                  color: estilo.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            CobroPendienteCard.formatClp(primerPago.monto),
            maxLines: 1,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
              fontSize: 12,
            ),
          ),
          if (tieneMultiples) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '+${item.desglosePagos.length - 1}',
                style: AppTypography.small.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Fallback con texto de metodosResumen
    return Text(
      item.metodosResumen.isNotEmpty ? item.metodosResumen : 'Sin pagos',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.small.copyWith(
        color: const Color(0xFF64748B),
        fontSize: 12.5,
      ),
    );
  }

  /// Construye el pie de tabla según el mockup:
  /// Izquierda: "Mostrando X órdenes registradas"
  /// Centro: Controles de paginación
  /// Derecha: "Total Consolidado en Vista: $X.XXX.XXX"
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(11),
          bottomRight: Radius.circular(11),
        ),
        border: Border(
          top: BorderSide(
            color: AppPalette.neutral.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Conteo a la izquierda
          Text.rich(
            TextSpan(
              text: 'Mostrando ',
              style: AppTypography.small.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 12.5,
              ),
              children: [
                TextSpan(
                  text: '$totalRegistros órdenes',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const TextSpan(text: ' registradas'),
              ],
            ),
          ),

          // Paginador central (si hay más de 1 página)
          if (totalPaginas > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: paginaActual > 1
                      ? () => onCambiarPagina(paginaActual - 1)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'Página $paginaActual de $totalPaginas',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: paginaActual < totalPaginas
                      ? () => onCambiarPagina(paginaActual + 1)
                      : null,
                ),
              ],
            ),

          // Total consolidado a la derecha con tooltip explicativo
          Tooltip(
            message: 'Monto efectivamente recaudado en órdenes procesadas y abonos de reservas (excluye anuladas y saldos pendientes)',
            child: Text.rich(
              TextSpan(
                text: 'Total Consolidado en Vista: ',
                style: AppTypography.small.copyWith(
                  color: const Color(0xFF64748B),
                  fontSize: 12.5,
                ),
                children: [
                  TextSpan(
                    text: CobroPendienteCard.formatClp(totalConsolidado),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF004C89), // AppPalette.tertiary
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String label, {
    required int flex,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          label,
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF64748B),
            fontSize: 11.5,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
