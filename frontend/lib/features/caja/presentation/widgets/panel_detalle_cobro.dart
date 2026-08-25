import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/cobro_pendiente_model.dart';
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
  final List<TextEditingController> _montoControllers = [];
  String? _lastIdReferencia;
  int? _lastPagosCount;

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
        return Icons.receipt_long_rounded;
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

          // ── 5. PASARELA DE MÉTODOS DE PAGO / SPLIT (ST-F04 / CA-04) ──
          _buildSplitPaymentSection(),

          const SizedBox(height: 16),

          // ── 6. INDICADOR DE CUADRATURA Y BOTÓN PROCESAR (ST-F05 / CA-05) ──
          _buildCuadraturaYAccion(context),
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
                      child: Text(
                        isVenta ? 'Venta en Tienda' : 'Reserva Backorder',
                        style: AppTypography.small.copyWith(
                          color: isVenta ? AppPalette.warningText : AppPalette.tertiary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
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
                isVenta ? Icons.format_list_bulleted_rounded : Icons.info_outline_rounded,
                size: 18,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isVenta
                    ? 'DETALLE DE REPUESTOS Y ARTÍCULOS'
                    : 'ESPECIFICACIONES DE LA RESERVA BACKORDER',
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
        return Row(
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
                    art.descripcion,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimaryLight,
                      fontSize: 13,
                    ),
                  ),
                  if (art.sku != null && art.sku!.isNotEmpty)
                    Text(
                      'SKU: ${art.sku}',
                      style: AppTypography.small.copyWith(
                        color: AppPalette.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
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
      return const Text('Sin especificaciones de backorder disponibles.');
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
            const SizedBox(height: 12),
            // Input para monto de abono
            Text(
              'Monto Acordado a Abonar (\$ CLP):',
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.w700,
                color: AppPalette.textPrimaryLight,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _abonoCustomController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: 'Ej: 150000',
                filled: true,
                fillColor: AppPalette.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppPalette.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppPalette.primary, width: 2),
                ),
              ),
              onChanged: (val) {
                final nuevoMonto = int.tryParse(val) ?? 0;
                widget.provider.setMontoDeclarado(nuevoMonto);
                _sincronizarControllers();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSplitPaymentSection() {
    final pagos = widget.provider.pagosDivididos;
    const metodosDisponibles = ['Efectivo', 'Debito', 'Credito', 'Transferencia', 'Cheque'];

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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_rounded, size: 18, color: AppPalette.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CANALES DE PAGO (PAGO DIVIDIDO)',
                        style: AppTypography.title.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.textSecondaryLight,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  'Agregar Método',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onPressed: () {
                  widget.provider.agregarMetodoPago(metodo: 'Debito', monto: 0);
                  _sincronizarControllers();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lista dinámica de métodos de pago
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
                  color: AppPalette.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.borderLight),
                ),
                child: Row(
                  children: [
                    // Selector de Método
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppPalette.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppPalette.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: metodosDisponibles.contains(pago.metodo)
                              ? pago.metodo
                              : 'Efectivo',
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          items: metodosDisponibles.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Row(
                                children: [
                                  Icon(_getIconoMetodo(m), size: 16, color: AppPalette.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    m,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppPalette.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newMethod) {
                            if (newMethod != null) {
                              widget.provider.actualizarTipoMetodo(idx, newMethod);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Input de Monto
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          hintText: '0',
                          isDense: true,
                          filled: true,
                          fillColor: AppPalette.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppPalette.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppPalette.primary, width: 2),
                          ),
                        ),
                        onChanged: (val) {
                          final valInt = int.tryParse(val) ?? 0;
                          widget.provider.actualizarMontoMetodo(idx, valInt);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Auto-rellenar Restante (CA-04)
                    Tooltip(
                      message: 'Auto-rellenar restante',
                      child: IconButton(
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                        color: AppPalette.primary,
                        style: IconButton.styleFrom(
                          backgroundColor: AppPalette.primary.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          widget.provider.autoRellenarRestante(idx);
                          _sincronizarControllers();
                        },
                      ),
                    ),

                    // Botón Eliminar fila si > 1
                    if (pagos.length > 1) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Eliminar método',
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          color: AppPalette.error,
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

  Widget _buildCuadraturaYAccion(BuildContext context) {
    final montoDeclarado = widget.provider.montoDeclarado;
    final totalIngresado = widget.provider.totalPagosIngresados;
    final diferencia = widget.provider.diferenciaCuadratura;
    final esValida = widget.provider.esCuadraturaValida;
    final isProcesando = widget.provider.isProcesandoCobro;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esValida ? AppPalette.successBorder : AppPalette.errorBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (esValida ? AppPalette.success : AppPalette.error).withValues(alpha: 0.05),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimaryLight,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimaryLight,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: esValida ? AppPalette.success : AppPalette.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Indicador Visual de Estado (Verde / Rojo) (ST-F05)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: esValida ? AppPalette.successBg : AppPalette.errorBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: esValida ? AppPalette.successBorder : AppPalette.errorBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  esValida ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  size: 20,
                  color: esValida ? AppPalette.success : AppPalette.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    esValida
                        ? 'Cuadratura Exacta: Los métodos de pago suman el 100% del monto acordado.'
                        : diferencia > 0
                            ? 'Descuadre Financiero: Faltan ${CobroPendienteCard.formatClp(diferencia)} por asignar.'
                            : 'Descuadre Financiero: Sobran ${CobroPendienteCard.formatClp(diferencia.abs())} en los métodos.',
                    style: AppTypography.small.copyWith(
                      color: esValida ? AppPalette.successText : AppPalette.errorText,
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
                backgroundColor: esValida ? AppPalette.success : AppPalette.disabled,
                foregroundColor: esValida ? AppPalette.textPrimary : AppPalette.disabledText,
                disabledBackgroundColor: AppPalette.disabled,
                disabledForegroundColor: AppPalette.disabledText,
                elevation: esValida ? 2 : 0,
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
                      esValida ? Icons.check_circle_rounded : Icons.lock_rounded,
                      size: 22,
                    ),
              label: Text(
                isProcesando
                    ? 'PROCESANDO PAGO...'
                    : esValida
                        ? 'CONFIRMAR Y PROCESAR COBRO'
                        : 'PAGO BLOQUEADO (DESCUADRE)',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: (esValida && !isProcesando)
                  ? () => _handleProcesarCobro()
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
