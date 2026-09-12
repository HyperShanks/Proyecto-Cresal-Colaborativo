import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../../../core/widgets/custom_error_snackbar.dart';
import '../../models/tarea_alerta.dart';
import '../../services/logistica_service.dart';

/// Pantalla operativa para el Bodeguero: Escaneo y Handshake de Auditoría de Salida (HU-3.6).
/// Implementa la regla 'Cero-Clics' con enrutamiento inteligente de códigos (TX-QR- vs. SKU físico),
/// validación de Doble Llave (Dual-Scan) y respuesta háptica en entornos industriales.
class AuditoriaSalidaScreen extends StatefulWidget {
  final TareaAlerta? tarea;

  const AuditoriaSalidaScreen({super.key, this.tarea});

  @override
  State<AuditoriaSalidaScreen> createState() => _AuditoriaSalidaScreenState();
}

class _AuditoriaSalidaScreenState extends State<AuditoriaSalidaScreen>
    with SingleTickerProviderStateMixin {
  String? _qrTransaccionalSalida;
  final List<String> _skusEscaneados = [];
  bool _isProcessing = false;
  EscanearSalidaResponseModel? _resultadoExitoso;

  // Controlador de entrada manual / lector PDA
  final TextEditingController _simuladorController = TextEditingController();
  final FocusNode _simuladorFocus = FocusNode();

  // Animación del láser escáner industrial
  late AnimationController _laserAnimController;

  @override
  void initState() {
    super.initState();
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _simuladorController.dispose();
    _simuladorFocus.dispose();
    super.dispose();
  }

  /// Procesa cualquier código capturado por la cámara, escáner láser PDA o simulador
  void _procesarCodigoLeido(String rawCode) {
    final code = rawCode.trim();
    if (code.isEmpty || _isProcessing || _resultadoExitoso != null) return;

    if (code.toUpperCase().startsWith('TX-QR-')) {
      setState(() {
        _qrTransaccionalSalida = code;
        debugPrint(
          '📱 [AUDITORIA] QR Digital Vendedor capturado: $_qrTransaccionalSalida',
        );
      });
    } else {
      final sku = code.toUpperCase();
      if (_skusEscaneados.contains(sku)) {
        CustomErrorSnackbar.mostrar(
          context,
          mensaje: 'La pieza ya fue escaneada y registrada previamente.',
          codigoError: 'PIEZA_DUPLICADA',
        );
        return;
      }
      setState(() {
        _skusEscaneados.add(sku);
        debugPrint(
          '📦 [AUDITORIA] SKU Físico de pieza capturado: $sku (Total: ${_skusEscaneados.length})',
        );
      });
    }

    _simuladorController.clear();

    // ── REGLA CERO-CLICS (Auto-Trigger) ──────────────────────────────────────
    // En cuanto poseemos el token del vendedor y al menos un SKU físico, gatillamos el match
    if (_qrTransaccionalSalida != null && _skusEscaneados.isNotEmpty) {
      _ejecutarDualScanMatch();
    }
  }

  /// Ejecuta la llamada transaccional atómica al backend sin intervención manual
  Future<void> _ejecutarDualScanMatch() async {
    if (_isProcessing ||
        _qrTransaccionalSalida == null ||
        _skusEscaneados.isEmpty) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      debugPrint(
        '🚀 [AUDITORIA] Auto-Trigger Cero-Clics activado. Validando Dual-Scan en backend...',
      );

      final response = await LogisticaService.escanearSalida(
        qrTransaccionalSalida: _qrTransaccionalSalida!,
        skusEscaneados: _skusEscaneados,
      );

      if (!mounted) return;

      // Feedback háptico de éxito para entorno ruidoso de bodega
      HapticFeedback.heavyImpact();

      setState(() {
        _resultadoExitoso = response;
        _isProcessing = false;
      });

      // Retorno automático tras 5.0s para que el operario visualice la confirmación
      Future.delayed(const Duration(milliseconds: 5000), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      if (!mounted) return;

      // Feedback háptico de alerta
      HapticFeedback.mediumImpact();

      String rawError = e.toString().replaceFirst('Exception: ', '').trim();
      String mensajeSanitizado = rawError;
      String codigoError = 'BARRERA_ERROR';

      if (rawError.toLowerCase().contains('no encontrado') || rawError.toLowerCase().contains('404')) {
        mensajeSanitizado = 'El código escaneado no pertenece a ninguna orden activa.';
        codigoError = 'SCAN_NO_ENCONTRADO';
      } else if (rawError.toLowerCase().contains('no pertenecen a esta orden') || rawError.toLowerCase().contains('otra orden')) {
        mensajeSanitizado = 'Cuidado, la pieza escaneada pertenece a otra orden.';
        codigoError = 'ORDEN_MISMATCH';
      }

      debugPrint('❌ [AUDITORIA] Error en barrera: $mensajeSanitizado');

      setState(() => _isProcessing = false);

      CustomErrorSnackbar.mostrar(
        context,
        mensaje: mensajeSanitizado,
        codigoError: codigoError,
        onReintentar: () => _ejecutarDualScanMatch(),
      );
    }
  }

  void _limpiarEscaneos() {
    setState(() {
      _qrTransaccionalSalida = null;
      _skusEscaneados.clear();
      _resultadoExitoso = null;
      _isProcessing = false;
    });
    _simuladorController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tienePieza = _skusEscaneados.isNotEmpty;
    final tieneToken = _qrTransaccionalSalida != null;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(
          'AUDITORÍA DE SALIDA',
          style: AppTypography.headline.copyWith(
            color: AppPalette.textPrimary,
            fontSize: 18.0,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: AppPalette.surface,
        iconTheme: const IconThemeData(color: AppPalette.primary),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8.0,
                  height: 8.0,
                  decoration: const BoxDecoration(
                    color: AppPalette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6.0),
                Text(
                  'ESCÁNER ACTIVO',
                  style: AppTypography.small.copyWith(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Informativo ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppPalette.secondary,
                      size: 22.0,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        'Doble Llave de Salida: Escanee el QR de la pieza física y el Ticket Digital del vendedor.',
                        style: AppTypography.small.copyWith(
                          color: AppPalette.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16.0),

              // ── Tarjeta 1: Escaneo de Pieza Física ─────────────────────────
              _buildScanCard(
                titulo: '1. Escanee QR de la Pieza Física',
                subtitulo: tienePieza
                    ? '${_skusEscaneados.length} pieza(s) escaneada(s): ${_skusEscaneados.join(", ")}'
                    : 'Apunta a la etiqueta física (ej. MOT-TOY-...)',
                icono: Icons.precision_manufacturing_outlined,
                isCompleted: tienePieza,
                isActive: !tienePieza,
                chips: _skusEscaneados,
              ),

              const SizedBox(height: 12.0),

              // ── Tarjeta 2: Escaneo de Tablet Vendedor ──────────────────────
              _buildScanCard(
                titulo: '2. Escanee Ticket Digital (Tablet Vendedor)',
                subtitulo: tieneToken
                    ? 'Ticket validado: $_qrTransaccionalSalida'
                    : 'Apunta a la pantalla del vendedor (TX-QR-...)',
                icono: Icons.qr_code_2_rounded,
                isCompleted: tieneToken,
                isActive: tienePieza && !tieneToken,
                chips: tieneToken ? [_qrTransaccionalSalida!] : [],
              ),

              const SizedBox(height: 20.0),

              // ── Visor de Cámara y Retícula Láser Industrial ───────────────
              _buildViewfinder(),

              const SizedBox(height: 16.0),

              // ── Banner de Éxito / Feedback Dinámico ────────────────────────
              if (_resultadoExitoso != null) ...[
                _buildSuccessBanner(_resultadoExitoso!),
              ] else if (_isProcessing) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: AppPalette.primary),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20.0,
                        height: 20.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppPalette.primary,
                        ),
                      ),
                      SizedBox(width: 12.0),
                      Text(
                        'Verificando Handshake en Barrera...',
                        style: TextStyle(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16.0),

              // ── Simulador / Entrada de Escaneo Rápido (PDA / Emulador) ────
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Entrada de Escáner / Entrada Rápida',
                            style: AppTypography.small.copyWith(
                              color: AppPalette.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tienePieza || tieneToken) ...[
                          const SizedBox(width: 8.0),
                          InkWell(
                            onTap: _limpiarEscaneos,
                            borderRadius: BorderRadius.circular(4.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 2.0,
                              ),
                              child: Text(
                                'Limpiar escaneos',
                                style: AppTypography.small.copyWith(
                                  color: AppPalette.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _simuladorController,
                            focusNode: _simuladorFocus,
                            style: AppTypography.body.copyWith(fontSize: 13.0),
                            decoration: InputDecoration(
                              hintText:
                                  'Ingrese código o dispare escáner PDA...',
                              hintStyle: AppTypography.small.copyWith(
                                color: AppPalette.neutral,
                              ),
                              filled: true,
                              fillColor: AppPalette.background,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 10.0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (val) {
                              _procesarCodigoLeido(val);
                              _simuladorFocus.requestFocus();
                            },
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.primary,
                            foregroundColor: AppPalette.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 10.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppComponents.defaultBorderRadius,
                              ),
                            ),
                          ),
                          onPressed: () =>
                              _procesarCodigoLeido(_simuladorController.text),
                          child: const Text(
                            'Capturar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de estado de escaneo para cada una de las llaves
  Widget _buildScanCard({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required bool isCompleted,
    required bool isActive,
    List<String> chips = const [],
  }) {
    Color borderColor;
    Color iconColor;

    if (isCompleted) {
      borderColor = AppPalette.success;
      iconColor = AppPalette.success;
    } else if (isActive) {
      borderColor = AppPalette.primary;
      iconColor = AppPalette.primary;
    } else {
      borderColor = Colors.white10;
      iconColor = AppPalette.textSecondary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: borderColor,
          width: isCompleted || isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.15),
                  blurRadius: 10.0,
                  spreadRadius: 1.0,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : icono,
              color: iconColor,
              size: 22.0,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? AppPalette.success
                              : AppPalette.textPrimary,
                        ),
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.success.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'LISTO',
                          style: AppTypography.small.copyWith(
                            color: AppPalette.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.0,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitulo,
                  style: AppTypography.small.copyWith(
                    color: isCompleted
                        ? AppPalette.textPrimary
                        : AppPalette.textSecondary,
                    fontSize: 12.0,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: chips
                        .map(
                          (c) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 3.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.background,
                              borderRadius: BorderRadius.circular(6.0),
                              border: Border.all(
                                color: AppPalette.success.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Text(
                              c,
                              style: AppTypography.small.copyWith(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.success,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Visor animado con retícula láser de escáner industrial
  Widget _buildViewfinder() {
    return Container(
      width: double.infinity,
      height: 180.0,
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rejilla de fondo industrial
            CustomPaint(
              size: const Size(double.infinity, 180.0),
              painter: _GridBackgroundPainter(),
            ),

            // Marco central de enfoque
            Container(
              width: 140.0,
              height: 140.0,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppPalette.primary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 56.0,
                  color: Colors.white24,
                ),
              ),
            ),

            // Línea láser animada
            AnimatedBuilder(
              animation: _laserAnimController,
              builder: (context, child) {
                return Positioned(
                  top: 20.0 + (_laserAnimController.value * 140.0),
                  left: 30.0,
                  right: 30.0,
                  child: Container(
                    height: 2.0,
                    decoration: BoxDecoration(
                      color: AppPalette.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.primary.withValues(alpha: 0.8),
                          blurRadius: 8.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Etiqueta flotante inferior
            Positioned(
              bottom: 10.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  'Apunta a la pantalla o etiqueta',
                  style: AppTypography.small.copyWith(
                    color: AppPalette.textSecondary,
                    fontSize: 11.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner gigante de Match Exitoso en Barrera
  Widget _buildSuccessBanner(EscanearSalidaResponseModel res) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: AppPalette.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: AppPalette.success, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: AppPalette.success.withValues(alpha: 0.3),
            blurRadius: 16.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppPalette.success, size: 28.0),
              SizedBox(width: 10.0),
              Text(
                'MATCH EXITOSO EN BARRERA',
                style: TextStyle(
                  color: AppPalette.success,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            '${res.folio} • ${res.totalEntregados} repuesto(s) liberado(s)',
            style: AppTypography.body.copyWith(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            res.mensaje,
            textAlign: TextAlign.center,
            style: AppTypography.small.copyWith(
              color: AppPalette.textSecondary,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter decorativo para simular retícula de escáner industrial
class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
