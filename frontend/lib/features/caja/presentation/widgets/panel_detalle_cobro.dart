import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/cobro_pendiente_model.dart';
import '../../models/cobro_model.dart';
import '../providers/caja_provider.dart';
import 'cobro_pendiente_card.dart';
import 'resultado_cobro_dialog.dart';

/// Panel de Detalle de Cobro con soporte para Pago Único o Dividido (Split Payment).
/// Cumple con la especificación SPEC-HU-03 / CRES-214 (Master-Detail alimentado en memoria).
class PanelDetalleCobro extends StatefulWidget {
  final CajaProvider provider;

  const PanelDetalleCobro({
    super.key,
    required this.provider,
  });

  @override
  State<PanelDetalleCobro> createState() => _PanelDetalleCobroState();
}

class _PanelDetalleCobroState extends State<PanelDetalleCobro> {
  final TextEditingController _abonoCustomController = TextEditingController();
  final TextEditingController _skuActivoController = TextEditingController();
  final List<TextEditingController> _montoControllers = [];
  String? _lastIdReferencia;
  int? _lastPagosCount;
  int _intentosFallidosSku = 0;

  @override
  void initState() {
    super.initState();
    _sincronizarControllers();
  }

  @override
  void didUpdateWidget(covariant PanelDetalleCobro oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sincronizarControllers();
  }

  @override
  void dispose() {
    _abonoCustomController.dispose();
    _skuActivoController.dispose();
    for (final c in _montoControllers) {
      c.dispose();
    }
    _montoControllers.clear();
    super.dispose();
  }

  void _sincronizarControllers() {
    final orden = widget.provider.ordenSeleccionada;
    final pagos = widget.provider.pagosDivididos;

    if (orden == null) {
      _lastIdReferencia = null;
      _lastPagosCount = 0;
      return;
    }

    final ordenCambio = _lastIdReferencia != orden.idReferencia;
    final countCambio = _lastPagosCount != pagos.length;

    if (ordenCambio || countCambio) {
      _lastIdReferencia = orden.idReferencia;
      _lastPagosCount = pagos.length;

      // Limpiar controladores existentes
      for (final c in _montoControllers) {
        c.dispose();
      }
      _montoControllers.clear();

      for (int i = 0; i < pagos.length; i++) {
        final ctrl = TextEditingController(
          text: pagos[i].monto > 0 ? pagos[i].monto.toString() : '',
        );
        _montoControllers.add(ctrl);
      }

      _abonoCustomController.text =
          widget.provider.montoDeclarado > 0 ? widget.provider.montoDeclarado.toString() : '';
          
      _skuActivoController.clear();
      _intentosFallidosSku = 0;
    } else {
      // Actualizar valores de controladores si difieren del provider
      for (int i = 0; i < pagos.length && i < _montoControllers.length; i++) {
        final currentTextVal = int.tryParse(_montoControllers[i].text) ?? 0;
        if (currentTextVal != pagos[i].monto) {
          _montoControllers[i].text =
              pagos[i].monto > 0 ? pagos[i].monto.toString() : '';
        }
      }
    }
  }

  IconData _getIconoMetodo(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'efectivo':
        return Icons.payments_rounded;
      case 'debito':
      case 'débito':
      case 'credito':
      case 'crédito':
        return Icons.credit_card_rounded;
      case 'transferencia':
        return Icons.swap_horiz_rounded;
      case 'cheque':
        return Symbols.checkbook_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Future<void> _handleProcesarCobro() async {
    final orden = widget.provider.ordenSeleccionada;
    if (orden == null) return;

    try {
      final res = await widget.provider.procesarCobro();
      if (!mounted) return;

      if (res != null && res.success) {
        final resumenMetodos = widget.provider.pagosDivididos
            .where((p) => p.monto > 0)
            .map((p) => '${p.metodo}: ${CobroPendienteCard.formatClp(p.monto)}')
            .join(' + ');

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => ResultadoCobroDialog(
            orden: orden,
            resultado: res,
            metodosResumen: resumenMetodos,
            onSiguienteOrden: () {
              Navigator.of(dialogCtx).pop();
              widget.provider.removerOrdenProcesada(orden.idReferencia);
            },
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppPalette.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.toString().replaceAll('Exception: ', ''),
                  style: AppTypography.body.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final orden = widget.provider.ordenSeleccionada;
        if (orden == null) {
          return _buildEmptyState();
        }
        return _buildPanelContent(context, orden);
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: AppPalette.backgroundLight,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppPalette.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppPalette.neutral.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 48,
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Seleccione una orden para procesar el cobro',
              style: AppTypography.title.copyWith(
                color: AppPalette.textPrimaryLight,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Haga clic en cualquiera de las tarjetas de la bandeja izquierda para ver los detalles.',
              style: AppTypography.body.copyWith(
                color: AppPalette.textSecondaryLight,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(BuildContext context, CobroPendienteModel orden) {
    final isVenta = orden.esVenta;
    final esAbono = widget.provider.modalidad == 'ABONO';
    final requiereAtribucion = !isVenta && !esAbono;

    return Container(
      color: AppPalette.backgroundLight,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── 1. ENCABEZADO DE LA ORDEN / FOLIO (ST-F02) ──
          _buildHeaderCard(orden, isVenta),

          const SizedBox(height: 16),

          // ── 2. TARJETA FINANCIERA DESTACADA (AZUL CRESAL ST-F02) ──
          _buildFinancialCard(orden),

          const SizedBox(height: 16),

          // ── 3. DESGLOSE ADAPTATIVO (REPUESTOS O BACKORDER) (CA-01) ──
          _buildDesgloseCard(orden, isVenta),

          const SizedBox(height: 16),

          // ── 4. SELECTOR DE MODALIDAD Y BANNER ÁMBAR (ST-F03 / CA-02) ──
          _buildModalidadSection(orden, esAbono),

          const SizedBox(height: 16),

          // ── 4.5 SECCIÓN ATRIBUCIÓN DE ACTIVO (BACKORDER FULL PAYMENT) ──
          if (requiereAtribucion) ...[
             _buildBackorderAttributionSection(context, orden),
             const SizedBox(height: 16),
          ],

          // ── 5. PASARELA DE MÉTODOS DE PAGO (PAGO ÚNICO / SPLIT) (ST-F04 / CA-04) ──
          _buildMetodosPagoSection(),

          const SizedBox(height: 16),

          // ── 6. INDICADOR DE CUADRATURA Y BOTÓN PROCESAR (ST-F05 / CA-05) ──
          _buildCuadraturaYAccion(context, orden),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(CobroPendienteModel orden, bool isVenta) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Folio y Tipo
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      orden.folioDocumento,
                      style: AppTypography.headline.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppPalette.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isVenta ? AppPalette.secondary : AppPalette.tertiary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isVenta ? AppPalette.secondary : AppPalette.tertiary)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVenta ? Icons.storefront_rounded : Icons.directions_boat_filled_outlined,
                            size: 14,
                            color: isVenta ? AppPalette.warningText : AppPalette.tertiary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isVenta ? 'Venta en Tienda' : 'Ventas en Verde',
                            style: AppTypography.small.copyWith(
                              color: isVenta ? AppPalette.warningText : AppPalette.tertiary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Botón Limpiar Selección
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppPalette.textSecondaryLight,
                tooltip: 'Cerrar detalle',
                onPressed: () {
                  widget.provider.seleccionarOrden(null);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_rounded, size: 18, color: AppPalette.textSecondaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${orden.clienteNombre}  •  RUT: ${orden.clienteRut}',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimaryLight,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.badge_rounded, size: 18, color: AppPalette.textSecondaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vendedor: ${orden.vendedorNombre}  •  Emitida el ${orden.fechaEmisionFormateada} a las ${orden.horaEmisionFormateada}',
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondaryLight,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(CobroPendienteModel orden) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppPalette.tertiary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppPalette.tertiary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Operación
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orden.esVenta ? 'TOTAL VENTA' : 'PRECIO ACORDADO',
                  style: AppTypography.small.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CobroPendienteCard.formatClp(orden.totalOperacion),
                  style: AppTypography.title.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          // Abonos Previos (Rojo / Error ST-F02)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ABONOS PREVIOS',
                    style: AppTypography.small.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CobroPendienteCard.formatClp(orden.abonoPrevio),
                    style: AppTypography.title.copyWith(
                      color: orden.abonoPrevio > 0 ? AppPalette.secondary : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          // Saldo Pendiente Actual
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SALDO A COBRAR',
                    style: AppTypography.small.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CobroPendienteCard.formatClp(orden.montoACobrar),
                    style: AppTypography.title.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
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

  Widget _buildDesgloseCard(CobroPendienteModel orden, bool isVenta) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVenta ? Icons.assignment_rounded : Icons.info_outline_rounded,
                size: 18,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isVenta
                    ? 'DETALLE DE REPUESTOS Y ARTÍCULOS'
                    : 'ESPECIFICACIONES DE VENTA EN VERDE',
                style: AppTypography.title.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textSecondaryLight,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isVenta)
            _buildArticulosList(orden.articulos)
          else
            _buildBackorderGrid(orden.especificacionesBackorder),
        ],
      ),
    );
  }

  Widget _buildArticulosList(List<ArticuloResumenModel> articulos) {
    if (articulos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Sin artículos asociados a la orden.'),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: articulos.length,
      separatorBuilder: (context, index) => Divider(
        color: AppPalette.borderLight,
        height: 14,
      ),
      itemBuilder: (context, idx) {
        final art = articulos[idx];
        final tieneSku = art.sku != null && art.sku!.isNotEmpty;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppPalette.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.borderLight),
              ),
              alignment: Alignment.center,
              child: Text(
                '${art.cantidad}x',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppPalette.primary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    art.nombreDisplay,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimaryLight,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (tieneSku)
                    Text(
                      'SKU: ${art.sku}',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: art.tipo == 'RESERVA'
                            ? AppPalette.warning.withValues(alpha: 0.12)
                            : AppPalette.neutral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        art.tipo == 'RESERVA' ? 'Venta en Verde' : 'Misceláneo',
                        style: AppTypography.small.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: art.tipo == 'RESERVA'
                              ? AppPalette.warningText
                              : AppPalette.textSecondaryLight,
                        ),
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
                color: AppPalette.textPrimaryLight,
                fontSize: 14,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackorderGrid(BackorderEspecificacionesModel? bo) {
    if (bo == null) {
      return const Text('Sin especificaciones de venta en verde disponibles.');
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSpecTile('Marca Requerida', bo.marca)),
            const SizedBox(width: 12),
            Expanded(child: _buildSpecTile('Modelo Requerido', bo.modelo)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildSpecTile('Categoría', bo.categoria)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSpecTile(
                'Año Requerido',
                bo.anio != null ? bo.anio.toString() : 'No especificado',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSpecTile(
                'Motor / Combustible',
                '${bo.cilindrada ?? "-"} • ${bo.combustible ?? "-"}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildSpecTile('Estado de Tránsito', bo.transito)),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.small.copyWith(
              color: AppPalette.textSecondaryLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.body.copyWith(
              color: AppPalette.textPrimaryLight,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModalidadSection(CobroPendienteModel orden, bool esAbono) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MODALIDAD DE COBRO',
            style: AppTypography.title.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppPalette.textSecondaryLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Botón Liquidación Total
              Expanded(
                child: InkWell(
                  onTap: () {
                    widget.provider.setModalidad('LIQUIDACION');
                    _sincronizarControllers();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: !esAbono
                          ? AppPalette.tertiary.withValues(alpha: 0.08)
                          : AppPalette.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !esAbono ? AppPalette.tertiary : AppPalette.borderLight,
                        width: !esAbono ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: !esAbono ? AppPalette.tertiary : AppPalette.textSecondaryLight,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Liquidación Total',
                          style: AppTypography.button.copyWith(
                            color: !esAbono ? AppPalette.tertiary : AppPalette.textSecondaryLight,
                            fontWeight: !esAbono ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Botón Abono Personalizado
              Expanded(
                child: InkWell(
                  onTap: () {
                    widget.provider.setModalidad('ABONO');
                    _sincronizarControllers();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: esAbono
                          ? AppPalette.tertiary.withValues(alpha: 0.08)
                          : AppPalette.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: esAbono ? AppPalette.tertiary : AppPalette.borderLight,
                        width: esAbono ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 20,
                          color: esAbono ? AppPalette.tertiary : AppPalette.textSecondaryLight,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Abono Personalizado',
                          style: AppTypography.button.copyWith(
                            color: esAbono ? AppPalette.tertiary : AppPalette.textSecondaryLight,
                            fontWeight: esAbono ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Banner Ámbar de Advertencia si es Abono (CA-02 / ST-F03)
          if (esAbono) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppPalette.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.warningBorder, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppPalette.warningText,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este pago registrará un abono y mantendrá la orden retenida sin emitir código QR de salida.',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.warningText,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monto Acordado a Abonar (\$ CLP):',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.textPrimaryLight,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Máx permitido: ${CobroPendienteCard.formatClp(orden.montoACobrar)}',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: (widget.provider.montoDeclarado > orden.montoACobrar || widget.provider.montoDeclarado <= 0)
                        ? AppPalette.error
                        : AppPalette.primary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Atajos rápidos de porcentaje sobre el saldo pendiente
            Row(
              children: [
                _buildPresetChip(
                  label: '25%',
                  seleccionado: widget.provider.montoDeclarado == (orden.montoACobrar * 0.25).round(),
                  onTap: () {
                    final v = (orden.montoACobrar * 0.25).round();
                    _abonoCustomController.text = v.toString();
                    widget.provider.setMontoDeclarado(v);
                    _sincronizarControllers();
                  },
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: '50%',
                  seleccionado: widget.provider.montoDeclarado == (orden.montoACobrar * 0.50).round(),
                  onTap: () {
                    final v = (orden.montoACobrar * 0.50).round();
                    _abonoCustomController.text = v.toString();
                    widget.provider.setMontoDeclarado(v);
                    _sincronizarControllers();
                  },
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: '75%',
                  seleccionado: widget.provider.montoDeclarado == (orden.montoACobrar * 0.75).round(),
                  onTap: () {
                    final v = (orden.montoACobrar * 0.75).round();
                    _abonoCustomController.text = v.toString();
                    widget.provider.setMontoDeclarado(v);
                    _sincronizarControllers();
                  },
                ),
                const SizedBox(width: 6),
                _buildPresetChip(
                  label: 'Saldo Total',
                  seleccionado: widget.provider.montoDeclarado == orden.montoACobrar,
                  onTap: () {
                    final v = orden.montoACobrar;
                    _abonoCustomController.text = v.toString();
                    widget.provider.setMontoDeclarado(v);
                    _sincronizarControllers();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _abonoCustomController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              style: AppTypography.body.copyWith(
                color: (widget.provider.montoDeclarado > orden.montoACobrar || widget.provider.montoDeclarado <= 0)
                    ? AppPalette.error
                    : AppPalette.textPrimaryLight,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: AppTypography.body.copyWith(
                  color: (widget.provider.montoDeclarado > orden.montoACobrar || widget.provider.montoDeclarado <= 0)
                      ? AppPalette.error
                      : AppPalette.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                hintText: 'Ej: ${(orden.montoACobrar * 0.5).round()}',
                hintStyle: AppTypography.body.copyWith(
                  color: AppPalette.textSecondaryLight.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: (widget.provider.montoDeclarado > orden.montoACobrar || widget.provider.montoDeclarado <= 0)
                    ? AppPalette.errorBg
                    : AppPalette.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: (widget.provider.montoDeclarado > orden.montoACobrar || widget.provider.montoDeclarado <= 0)
                        ? AppPalette.errorBorder
                        : AppPalette.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: (widget.provider.montoDeclarado > orden.montoACobrar || widget.provider.montoDeclarado <= 0)
                        ? AppPalette.errorBorder
                        : AppPalette.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: (widget.provider.montoDeclarado > orden.montoACobrar || widget.provider.montoDeclarado <= 0)
                        ? AppPalette.error
                        : AppPalette.primary,
                    width: 2,
                  ),
                ),
                suffixIcon: widget.provider.montoDeclarado > orden.montoACobrar
                    ? TextButton(
                        onPressed: () {
                          _abonoCustomController.text = orden.montoACobrar.toString();
                          widget.provider.setMontoDeclarado(orden.montoACobrar);
                          _sincronizarControllers();
                        },
                        child: Text(
                          'Ajustar al máx',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      )
                    : null,
              ),
              onChanged: (val) {
                final nuevoMonto = int.tryParse(val) ?? 0;
                widget.provider.setMontoDeclarado(nuevoMonto);
                _sincronizarControllers();
              },
            ),

            if (widget.provider.montoDeclarado > orden.montoACobrar) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.errorBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppPalette.errorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppPalette.errorText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'El abono no puede superar el saldo pendiente de ${CobroPendienteCard.formatClp(orden.montoACobrar)}.',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.errorText,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (widget.provider.montoDeclarado <= 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.errorBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppPalette.errorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AppPalette.errorText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'El abono debe ser estrictamente mayor a \$0.',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.errorText,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monto mínimo: \$1',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondaryLight,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Saldo restante tras abono: ${CobroPendienteCard.formatClp(orden.montoACobrar - widget.provider.montoDeclarado > 0 ? orden.montoACobrar - widget.provider.montoDeclarado : 0)}',
                    style: AppTypography.small.copyWith(
                      color: AppPalette.textSecondaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetodosPagoSection() {
    final modalidadPago = widget.provider.modalidadPago;
    final isUnico = modalidadPago == 'UNICO';
    final pagos = widget.provider.pagosDivididos;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.payment_rounded, size: 18, color: AppPalette.primary),
                  const SizedBox(width: 8),
                  Text(
                    'MÉTODOS DE PAGO',
                    style: AppTypography.title.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textSecondaryLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  final nuevaMod = isUnico ? 'SPLIT' : 'UNICO';
                  widget.provider.setModalidadPago(nuevaMod);
                  _sincronizarControllers();
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isUnico ? Icons.call_split_rounded : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: AppPalette.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUnico ? 'Dividir Pago' : 'Pago Único (100%)',
                        style: AppTypography.small.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Título del selector de métodos (idéntico al prototipo)
          Text(
            'SELECCIONA EL MÉTODO',
            style: AppTypography.small.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppPalette.textSecondaryLight,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),

          // Grid de 5 Botones de Métodos (Borde constante de 1.5px y altura uniforme)
          _buildMetodosGrid(),
          const SizedBox(height: 14),

          // Detalle de distribución según modalidad
          if (isUnico)
            _buildPagoUnicoResumen(pagos)
          else
            _buildPagoDivididoInputs(pagos),
        ],
      ),
    );
  }

  Widget _buildMetodosGrid() {
    const metodosConfig = [
      {'nombre': 'Efectivo', 'label': 'EFECTIVO', 'icon': Icons.payments_rounded},
      {'nombre': 'Debito', 'label': 'DÉBITO', 'icon': Icons.credit_card_rounded},
      {'nombre': 'Credito', 'label': 'CRÉDITO', 'icon': Icons.credit_card_rounded},
      {'nombre': 'Transferencia', 'label': 'TRANSFERENCIA', 'icon': Icons.swap_horiz_rounded},
      {'nombre': 'Cheque', 'label': 'CHEQUE', 'icon': Symbols.checkbook_rounded},
    ];

    return Row(
      children: metodosConfig.map((cfg) {
        final nombre = cfg['nombre'] as String;
        final label = cfg['label'] as String;
        final icon = cfg['icon'] as IconData;
        final isActive = widget.provider.esMetodoActivo(nombre);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                widget.provider.toggleMetodoPago(nombre);
                _sincronizarControllers();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppPalette.tertiary : AppPalette.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? AppPalette.tertiary : AppPalette.borderLight,
                    width: 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppPalette.tertiary.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isActive ? Colors.white : AppPalette.textSecondaryLight,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: AppTypography.small.copyWith(
                        color: isActive ? Colors.white : AppPalette.textPrimaryLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPagoUnicoResumen(List<TransaccionPagoItemModel> pagos) {
    final metodoNombre = pagos.isNotEmpty ? pagos.first.metodo : 'Efectivo';
    final monto = widget.provider.montoDeclarado;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppPalette.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconoMetodo(metodoNombre),
                  size: 20,
                  color: AppPalette.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Canal Activo: $metodoNombre',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppPalette.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cubre el 100% del monto acordado',
                    style: AppTypography.small.copyWith(
                      fontSize: 11,
                      color: AppPalette.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            CobroPendienteCard.formatClp(monto),
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppPalette.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagoDivididoInputs(List<TransaccionPagoItemModel> pagos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DISTRIBUCIÓN DE MONTOS',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: AppPalette.textSecondaryLight,
                  letterSpacing: 0.5,
                ),
              ),
              if (widget.provider.diferenciaCuadratura > 0 && pagos.length > 1)
                InkWell(
                  onTap: () {
                    widget.provider.autoRellenarRestante(pagos.length - 1);
                    _sincronizarControllers();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.auto_fix_high_rounded, size: 14, color: AppPalette.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-rellenar restante',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.tertiary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Inputs dinámicos para los métodos seleccionados
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pagos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final pago = pagos[idx];
              final ctrl = idx < _montoControllers.length ? _montoControllers[idx] : null;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.borderLight),
                ),
                child: Row(
                  children: [
                    // Badge del método con ancho uniforme (140px) para alinear todos los inputs
                    Container(
                      width: 140,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppPalette.tertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getIconoMetodo(pago.metodo), size: 16, color: AppPalette.tertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pago.metodo,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppPalette.tertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Input de monto
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: AppTypography.body.copyWith(
                          color: AppPalette.textPrimaryLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: AppTypography.body.copyWith(
                            color: AppPalette.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          hintText: '0',
                          hintStyle: AppTypography.body.copyWith(
                            color: AppPalette.textSecondaryLight.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: AppPalette.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppPalette.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppPalette.tertiary, width: 2),
                          ),
                        ),
                        onChanged: (val) {
                          final valInt = int.tryParse(val) ?? 0;
                          widget.provider.actualizarMontoMetodo(idx, valInt);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Auto-rellenar
                    Tooltip(
                      message: 'Auto-rellenar este método',
                      child: IconButton(
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                        color: AppPalette.tertiary,
                        style: IconButton.styleFrom(
                          backgroundColor: AppPalette.tertiary.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.all(8),
                        ),
                        onPressed: () {
                          widget.provider.autoRellenarRestante(idx);
                          _sincronizarControllers();
                        },
                      ),
                    ),

                    // Botón Eliminar si hay > 1 método
                    if (pagos.length > 1) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Eliminar método',
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          color: AppPalette.error,
                          style: IconButton.styleFrom(
                            backgroundColor: AppPalette.error.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: () {
                            widget.provider.removerMetodoPago(idx);
                            _sincronizarControllers();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCuadraturaYAccion(BuildContext context, CobroPendienteModel orden) {
    final montoDeclarado = widget.provider.montoDeclarado;
    final totalIngresado = widget.provider.totalPagosIngresados;
    final diferencia = widget.provider.diferenciaCuadratura;
    final esValida = widget.provider.esCuadraturaValida;
    final isProcesando = widget.provider.isProcesandoCobro;
    
    final maxPermitido = orden.montoACobrar;
    final bool montoExcedido = montoDeclarado > maxPermitido;
    final bool montoInvalido = montoDeclarado <= 0;
    
    final requiereAtribucion = !orden.esVenta && widget.provider.modalidad != 'ABONO';
    final validacion = widget.provider.validacionActivo;
    final activoAtribuido = widget.provider.skuActivoAtribuido != null && (validacion?.coincide == true || widget.provider.forzarAtribucion);
    final validacionBloqueada = requiereAtribucion && !activoAtribuido;
    final puedeProcesar = esValida && !validacionBloqueada && !montoExcedido && !montoInvalido;

    final bool operacionValida = esValida && !montoExcedido && !montoInvalido;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: operacionValida ? AppPalette.successBorder : AppPalette.errorBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (operacionValida ? AppPalette.success : AppPalette.error).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila de Resumen de Cuadratura
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL A COBRAR',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CobroPendienteCard.formatClp(montoDeclarado),
                      style: AppTypography.title.copyWith(
                        color: montoExcedido ? AppPalette.error : AppPalette.textPrimaryLight,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL INGRESADO',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CobroPendienteCard.formatClp(totalIngresado),
                      style: AppTypography.title.copyWith(
                        color: AppPalette.textPrimaryLight,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIFERENCIA',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CobroPendienteCard.formatClp(diferencia.abs()),
                      style: AppTypography.title.copyWith(
                        color: diferencia == 0 ? AppPalette.success : AppPalette.error,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Banner de Cuadratura Dinámico (Verde/Rojo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: operacionValida ? AppPalette.successBg : AppPalette.errorBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: operacionValida ? AppPalette.successBorder : AppPalette.errorBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  operacionValida ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  size: 20,
                  color: operacionValida ? AppPalette.success : AppPalette.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    montoExcedido
                        ? 'Monto Excedido: El monto a cobrar (${CobroPendienteCard.formatClp(montoDeclarado)}) no puede superar el saldo pendiente (${CobroPendienteCard.formatClp(maxPermitido)}).'
                        : montoInvalido
                            ? 'Monto Inválido: El monto a cobrar debe ser estrictamente mayor a \$0.'
                            : esValida
                                ? 'Cuadratura Exacta: Los métodos de pago suman el 100% del monto acordado.'
                                : diferencia > 0
                                    ? 'Descuadre Financiero: Faltan ${CobroPendienteCard.formatClp(diferencia)} por asignar.'
                                    : 'Descuadre Financiero: Sobran ${CobroPendienteCard.formatClp(diferencia.abs())} en los métodos.',
                    style: AppTypography.small.copyWith(
                      color: operacionValida ? AppPalette.successText : AppPalette.errorText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Botón de Acción "Procesar Cobro" (ST-F05)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: operacionValida ? AppPalette.success : AppPalette.disabled,
                foregroundColor: operacionValida ? AppPalette.textPrimary : AppPalette.disabledText,
                disabledBackgroundColor: AppPalette.disabled,
                disabledForegroundColor: AppPalette.disabledText,
                elevation: operacionValida ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: isProcesando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      operacionValida ? Icons.check_circle_rounded : Icons.lock_rounded,
                      size: 22,
                    ),
              label: Text(
                isProcesando
                    ? 'PROCESANDO PAGO...'
                    : validacionBloqueada 
                        ? 'FALTA ATRIBUIR ACTIVO'
                        : montoExcedido
                            ? 'MONTO SUPERA EL SALDO PENDIENTE'
                            : montoInvalido
                                ? 'MONTO DE ABONO INVÁLIDO'
                                : operacionValida
                                    ? 'CONFIRMAR Y PROCESAR COBRO'
                                    : 'PAGO BLOQUEADO (DESCUADRE)',
                style: AppTypography.button.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: (puedeProcesar && !isProcesando)
                  ? () => _handleProcesarCobro()
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: seleccionado ? AppPalette.tertiary : AppPalette.backgroundLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: seleccionado ? AppPalette.tertiary : AppPalette.borderLight,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.small.copyWith(
            color: seleccionado ? Colors.white : AppPalette.textSecondaryLight,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildBackorderAttributionSection(BuildContext context, CobroPendienteModel orden) {
    final validacion = widget.provider.validacionActivo;
    final isRevisando = widget.provider.isRevisandoActivo;
    final atribuido = widget.provider.skuActivoAtribuido != null;
    final forzar = widget.provider.forzarAtribucion;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: validacion?.coincide == false ? AppPalette.errorBorder : AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 18, color: AppPalette.primary),
              const SizedBox(width: 8),
              Text(
                'ATRIBUCIÓN DE ACTIVO FÍSICO',
                style: AppTypography.title.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textSecondaryLight,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ingresa el SKU del repuesto físico que se entregará al cliente. Este paso es obligatorio para saldar un Backorder.',
            style: AppTypography.small.copyWith(
              color: AppPalette.textPrimaryLight,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skuActivoController,
                  enabled: !atribuido || (validacion?.coincide == false && !forzar),
                  style: AppTypography.body.copyWith(
                    color: AppPalette.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (isRevisando || (atribuido && validacion?.coincide == true) || forzar)
                      ? null
                      : (_) => _ejecutarValidacionSku(),
                  decoration: InputDecoration(
                    hintText: 'Ej: MOT-1020',
                    prefixIcon: const Icon(Icons.tag_rounded, size: 20, color: AppPalette.primary),
                    filled: true,
                    fillColor: AppPalette.backgroundLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppPalette.borderLight),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: isRevisando 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search_rounded, size: 18),
                label: Text('Validar', style: AppTypography.button.copyWith(fontSize: 13)),
                onPressed: isRevisando || (atribuido && validacion?.coincide == true) || forzar ? null : _ejecutarValidacionSku,
              ),
            ],
          ),
          
          if (validacion != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: validacion.coincide ? AppPalette.successBg : AppPalette.errorBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: validacion.coincide ? AppPalette.successBorder : AppPalette.errorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        validacion.coincide ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: validacion.coincide ? AppPalette.successText : AppPalette.errorText,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          validacion.mensaje,
                          style: AppTypography.body.copyWith(
                            color: validacion.coincide ? AppPalette.successText : AppPalette.errorText,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!validacion.coincide && validacion.discrepancias.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...validacion.discrepancias.map((d) => Padding(
                      padding: const EdgeInsets.only(left: 26, top: 2),
                      child: Text('• $d', style: AppTypography.small.copyWith(color: AppPalette.errorText, fontWeight: FontWeight.w600)),
                    )),
                  ],
                ],
              ),
            ),

            if (validacion.activoDetalle != null) ...[
              _buildDetalleActivoIngresado(validacion.activoDetalle!, orden.especificacionesBackorder),
            ],
          ],
          
          if (validacion != null && !validacion.coincide && _intentosFallidosSku >= 3 && !forzar) ...[
             const SizedBox(height: 14),
             SizedBox(
               width: double.infinity,
               child: OutlinedButton.icon(
                 style: OutlinedButton.styleFrom(
                   foregroundColor: AppPalette.error,
                   side: const BorderSide(color: AppPalette.error),
                   padding: const EdgeInsets.symmetric(vertical: 12),
                 ),
                 icon: const Icon(Icons.warning_amber_rounded, size: 18),
                 label: const Text('Ignorar advertencia y forzar atribución', style: TextStyle(fontWeight: FontWeight.bold)),
                 onPressed: () {
                   widget.provider.setForzarAtribucion(true);
                 },
               ),
             ),
          ],
          if (forzar) ...[
             const SizedBox(height: 14),
             Container(
               padding: const EdgeInsets.all(10),
               decoration: BoxDecoration(
                 color: AppPalette.warningBg,
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: AppPalette.warningBorder),
               ),
               child: Row(
                 children: [
                   const Icon(Icons.warning_amber_rounded, color: AppPalette.warningText, size: 18),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                       'Validación técnica ignorada manualmente. El activo será atribuido al backorder bajo responsabilidad de la caja.',
                       style: AppTypography.small.copyWith(color: AppPalette.warningText, fontWeight: FontWeight.w700),
                     ),
                   ),
                 ],
               ),
             ),
          ],
        ],
      ),
    );
  }

  Future<void> _ejecutarValidacionSku() async {
    final sku = _skuActivoController.text.trim();
    if (sku.isEmpty) return;
    await widget.provider.validarActivoBackorder(sku);
    final res = widget.provider.validacionActivo;
    if (res != null && !res.coincide) {
      setState(() {
        _intentosFallidosSku++;
      });
    }
  }

  Widget _buildDetalleActivoIngresado(
    ActivoDetalleBackorderModel detalle,
    BackorderEspecificacionesModel? bo,
  ) {
    final bool marcaCoincide = bo?.marca == null ||
        (detalle.marca != null && detalle.marca!.trim().toLowerCase() == bo!.marca.trim().toLowerCase());
    final bool modeloCoincide = bo?.modelo == null ||
        (detalle.modelo != null && detalle.modelo!.trim().toLowerCase() == bo!.modelo.trim().toLowerCase());

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_rounded, size: 20, color: AppPalette.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'REPUESTO FÍSICO EN BODEGA',
                          style: AppTypography.title.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppPalette.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            detalle.sku,
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppPalette.primary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ficha técnica del repuesto físico para cotejo contra la reserva.',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (detalle.estadoConservacion != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.successBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppPalette.successBorder),
                  ),
                  child: Text(
                    detalle.estadoConservacion!,
                    style: AppTypography.small.copyWith(
                      color: AppPalette.successText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppPalette.borderLight),
          const SizedBox(height: 14),

          // Grilla de detalles técnicos del activo
          Row(
            children: [
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.directions_car_rounded,
                  label: 'Vehículo Origen (Marca / Modelo)',
                  value: '${detalle.marca ?? "-"} ${detalle.modelo ?? "-"}',
                  badgeText: (marcaCoincide && modeloCoincide) ? 'Coincide' : 'Difiere',
                  isMatch: marcaCoincide && modeloCoincide,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Año / Categoría',
                  value: '${detalle.anio != null ? detalle.anio.toString() : "S/A"} • ${detalle.categoria ?? "Repuesto"}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.speed_rounded,
                  label: 'Motor / Combustible',
                  value: '${detalle.cilindrada ?? "-"} • ${detalle.combustible ?? "-"}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.settings_input_component_rounded,
                  label: 'Transmisión',
                  value: detalle.transmision ?? 'No especificada',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.warehouse_rounded,
                  label: 'Ubicación Física',
                  value: detalle.ubicacion ?? 'Sin ubicación registrada',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivoInfoItem(
                  icon: Icons.tag_rounded,
                  label: 'Patente / VIN',
                  value: '${detalle.patente ?? "S/P"} • ${detalle.vin ?? "S/V"}',
                ),
              ),
            ],
          ),
          if (detalle.precioReferencia != null && detalle.precioReferencia! > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActivoInfoItem(
                    icon: Icons.payments_outlined,
                    label: 'Precio de Referencia',
                    value: CobroPendienteCard.formatClp(detalle.precioReferencia!),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivoInfoItem({
    required IconData icon,
    required String label,
    required String value,
    String? badgeText,
    bool isMatch = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppPalette.textSecondaryLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isMatch ? AppPalette.successBg : AppPalette.errorBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isMatch ? AppPalette.successBorder : AppPalette.errorBorder),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isMatch ? AppPalette.successText : AppPalette.errorText,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppPalette.textPrimaryLight,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
