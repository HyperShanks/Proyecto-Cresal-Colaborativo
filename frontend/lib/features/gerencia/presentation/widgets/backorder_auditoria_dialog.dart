// frontend/lib/features/gerencia/presentation/widgets/backorder_auditoria_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../models/backorder_gerencia_models.dart';
import '../../services/gerencia_service.dart';

/// Modal Forense 360° de Auditoría de Venta en Verde (Backorder) para Gerencia.
/// Diseñado para cumplir estrictamente con los estándares corporativos de peritaje:
/// - 100% de solo lectura (sin botones de edición, cobranza ni reasignación).
/// - Cabecera con Folios asociados (RES-XXXX y ORD-XXXX), badge oficial y fecha.
/// - Ficha de Identificación del Cliente (Nombre, RUT, Teléfono, Email).
/// - Ficha Técnica del Repuesto (Categoría, Marca, Modelo, Año, Especificaciones).
/// - Desglose Financiero (Precio pactado, abonos, saldo pendiente).
/// - Match Donante (SKU físico, N° Ingreso y Patente si aplica).
/// - Línea de Tiempo Cronológica Forense (Hitos secuenciales con fecha, hora 24h y usuario).
class BackorderAuditoriaDialog extends StatefulWidget {
  final BackorderItemModel backorderItem;
  final BackorderAuditoriaModel? auditoriaInicial;

  const BackorderAuditoriaDialog({
    super.key,
    required this.backorderItem,
    this.auditoriaInicial,
  });

  static Future<void> show(
    BuildContext context,
    BackorderItemModel backorder, {
    BackorderAuditoriaModel? auditoriaInicial,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => BackorderAuditoriaDialog(
        backorderItem: backorder,
        auditoriaInicial: auditoriaInicial,
      ),
    );
  }

  @override
  State<BackorderAuditoriaDialog> createState() => _BackorderAuditoriaDialogState();
}

class _BackorderAuditoriaDialogState extends State<BackorderAuditoriaDialog> {
  BackorderAuditoriaModel? _auditoria;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.auditoriaInicial != null) {
      _auditoria = widget.auditoriaInicial;
      _isLoading = false;
    } else {
      _cargarAuditoria();
    }
  }


  Future<void> _cargarAuditoria() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await GerenciaService.obtenerAuditoriaBackorder(
        widget.backorderItem.idReserva,
      );
      if (!mounted) return;
      setState(() {
        _auditoria = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  static ({Color bg, Color border, Color text}) _getEstadoStyle(String estado) {
    switch (estado.toLowerCase()) {
      case 'completada':
        return (
          bg: const Color(0xFFECFDF5),
          border: const Color(0xFFA7F3D0),
          text: const Color(0xFF059669),
        );
      case 'confirmada':
        return (
          bg: const Color(0xFFD1FAE5),
          border: const Color(0xFFA7F3D0),
          text: const Color(0xFF065F46),
        );
      case 'pendiente':
        return (
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFDE68A),
          text: const Color(0xFFD97706),
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

  static String _formatoCLP(int monto) {
    final str = monto.abs().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return monto < 0 ? '-\$$str' : '\$$str';
  }

  @override
  Widget build(BuildContext context) {
    final estadoActual = _auditoria?.estadoReserva ?? widget.backorderItem.estadoReserva;
    final estadoStyle = _getEstadoStyle(estadoActual);
    final folioReserva = _auditoria?.folio ?? widget.backorderItem.folio;
    final folioOrden = _auditoria?.ordenFolio ?? widget.backorderItem.ordenFolio;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 620,
          maxHeight: 780,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. CABECERA: AUDITORÍA DE VENTA EN VERDE + BADGES + FOLIOS + CLOSE BUTTON ──
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
                              'AUDITORÍA DE VENTA EN VERDE',
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
                                estadoActual,
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
                              folioReserva,
                              style: AppTypography.headline.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0284C7),
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (folioOrden != null && folioOrden.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  folioOrden,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Registrada el ${_auditoria?.fechaCreacion ?? widget.backorderItem.fechaCreacion}',
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
                      // ── 2. FICHA DEL CLIENTE Y RESPONSABLES ──
                      _buildCardClienteResponsables(),

                      const SizedBox(height: 16),

                      // ── 3. FICHA TÉCNICA Y DONANTE ──
                      _buildCardFichaTecnica(),

                      const SizedBox(height: 16),

                      // ── 4. BALANCE FINANCIERO Y ABONOS ──
                      _buildCardFinanciera(),

                      const SizedBox(height: 16),

                      // ── 5. LÍNEA DE TIEMPO / TRAZABILIDAD CRONOLÓGICA ──
                      _buildSeccionTimeline(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── 6. BOTÓN INFERIOR: CERRAR (SOLO LECTURA) ──
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
                    style: AppTypography.small.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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

  /// Tarjeta de Ficha de Identificación del Cliente y Responsables
  Widget _buildCardClienteResponsables() {
    final clienteNombre = _auditoria?.clienteNombre ?? widget.backorderItem.clienteNombre;
    final clienteRut = _auditoria?.clienteRut ?? widget.backorderItem.clienteRut ?? 'S/RUT';
    final clienteTel = _auditoria?.clienteTelefono ?? widget.backorderItem.clienteTelefono ?? 'Sin teléfono';
    final clienteEmail = _auditoria?.clienteCorreo ?? 'Sin correo registrado';
    final vendedorNombre = _auditoria?.vendedorNombre ?? widget.backorderItem.vendedorNombre;
    final sucursalNombre = _auditoria?.sucursalNombre ?? widget.backorderItem.sucursalNombre;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Cliente
              Expanded(
                flex: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_pin_rounded,
                          size: 15,
                          color: Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'FICHA DEL CLIENTE',
                          style: AppTypography.small.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      clienteNombre,
                      style: AppTypography.small.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'RUT: $clienteRut',
                          style: AppTypography.small.copyWith(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          clienteTel,
                          style: AppTypography.small.copyWith(
                            color: const Color(0xFF64748B),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            clienteEmail,
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFF64748B),
                              fontSize: 11.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 90,
                color: const Color(0xFFE2E8F0),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),

              // Columna Responsables
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'EMISIÓN / SUCURSAL',
                            style: AppTypography.small.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sucursalNombre,
                      style: AppTypography.small.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vendedor a cargo:',
                      style: AppTypography.small.copyWith(
                        color: const Color(0xFF94A3B8),
                        fontSize: 10.5,
                      ),
                    ),
                    Text(
                      vendedorNombre,
                      style: AppTypography.small.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Ficha Técnica del Repuesto y Match Donante
  Widget _buildCardFichaTecnica() {
    final catNombre = _auditoria?.categoriaNombre ?? widget.backorderItem.categoriaNombre;
    final isMotor = catNombre.toLowerCase().contains('motor') ||
        widget.backorderItem.idCategoriaRequerida == 1;
    final marca = _auditoria?.marcaRequerida ?? widget.backorderItem.marcaRequerida;
    final modelo = _auditoria?.modeloRequerido ?? widget.backorderItem.modeloRequerido;
    final anio = _auditoria?.anioRequerido?.toString() ??
        widget.backorderItem.anioRequerido?.toString() ??
        'S/A';
    final comb = _auditoria?.combustibleRequerido ?? widget.backorderItem.combustibleRequerido ?? 'N/A';
    final transm = _auditoria?.transmisionRequerida ?? widget.backorderItem.transmisionRequerida ?? 'N/A';
    final notas = _auditoria?.notasPreparacion ?? widget.backorderItem.notasPreparacion;

    final sku = _auditoria?.activoAsignadoSku ?? widget.backorderItem.activoAsignadoSku;
    final donanteIngreso = _auditoria?.vehiculoDonanteIngreso;
    final donantePatente = _auditoria?.vehiculoDonantePatente;
    final donanteDesc = _auditoria?.vehiculoDonanteDescripcion;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.precision_manufacturing_outlined,
                    size: 15,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ESPECIFICACIÓN TÉCNICA DEL REPUESTO',
                    style: AppTypography.small.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isMotor ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isMotor ? 'Motor' : 'Caja de Cambios',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isMotor ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$marca $modelo ($anio)',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Combustible: $comb  •  Transmisión: $transm',
            style: AppTypography.small.copyWith(
              color: const Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (notas != null && notas.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Notas de mesón: $notas',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],

          // Sección de Donante Asignado (Match)
          if (sku != null && sku.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'MATCH DONANTE ASIGNADO: ',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF047857),
                              ),
                            ),
                            Text(
                              sku,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                        if (donanteIngreso != null || donantePatente != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Ingreso: ${donanteIngreso ?? 'N/A'}  |  Patente: ${donantePatente ?? 'S/P'}${donanteDesc != null ? ' ($donanteDesc)' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
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

  /// Desglose Financiero (Precio pactado, seña, saldo)
  Widget _buildCardFinanciera() {
    final precio = _auditoria?.precioAcordado ?? widget.backorderItem.precioAcordado;
    final descuento = _auditoria?.descuento ?? widget.backorderItem.descuento;
    final abono = _auditoria?.montoAbonado ?? widget.backorderItem.montoAbonado;
    final saldo = _auditoria?.saldoPendiente ?? widget.backorderItem.saldoPendiente;
    final pagos = _auditoria?.desglosePagos ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
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
                'DESGLOSE FINANCIERO DE LA OPERACIÓN',
                style: AppTypography.small.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Precio Comercial Pactado:',
                style: AppTypography.small.copyWith(
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              Text(
                _formatoCLP(precio),
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (descuento > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Descuento Comercial:',
                  style: AppTypography.small.copyWith(
                    color: const Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  '- ${_formatoCLP(descuento)}',
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFDC2626),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Abonos Recaudados (Seña/Caja):',
                style: AppTypography.small.copyWith(
                  color: const Color(0xFF047857),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              Text(
                _formatoCLP(abono),
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF047857),
                  fontSize: 13,
                ),
              ),
            ],
          ),

          // Si hay desglose de pagos detallado
          if (pagos.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...pagos.map((p) => Padding(
              padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '↳ ${p.metodoPago}${p.cajeroNombre != null ? ' (Cajero: ${p.cajeroNombre})' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    _formatoCLP(p.monto),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            )),
          ],

          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SALDO PENDIENTE:',
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _formatoCLP(saldo),
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w900,
                  color: saldo > 0 ? const Color(0xFFB45309) : const Color(0xFF059669),
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sección de Línea de Tiempo y Trazabilidad Cronológica Forense
  Widget _buildSeccionTimeline() {
    final movimientos = _auditoria?.movimientos ?? [];

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
              'LÍNEA DE TIEMPO / TRAZABILIDAD CRONOLÓGICA',
              style: AppTypography.small.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
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
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _errorMessage != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No fue posible cargar el historial detallado.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: _cargarAuditoria,
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    )
                  : movimientos.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: movimientos.map((mov) {
                            final isLast = mov == movimientos.last;
                            final horaDisplay = mov.hora.replaceAll('/2026', '/26');
                            return Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 13,
                                        color: Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        horaDisplay,
                                        style: AppTypography.small.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: Text(
                                      mov.evento,
                                      style: AppTypography.small.copyWith(
                                        color: const Color(0xFF475569),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      : Text(
                          'Sin eventos registrados en la bitácora.',
                          style: AppTypography.small.copyWith(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
        ),
      ],
    );
  }
}
