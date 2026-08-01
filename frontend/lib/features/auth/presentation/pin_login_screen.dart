import 'package:flutter/material.dart';
import '../../../core/theme/tokens/app_palette.dart';
import '../../../core/theme/tokens/app_typography.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA DE LOGIN POR PIN INDUSTRIAL
// Diseñada para operarios con guantes en patio de desarme.
// Cumple regla W3C: touch targets mínimos de 44px.
// ─────────────────────────────────────────────────────────────────────────────
class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;

  // Animación de sacudida para feedback de error
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ── Lógica de ingreso de dígitos ──────────────────────────────────────────

  void _onDigitPressed(String digit) {
    if (_isLoading || _pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == _pinLength) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onClear() {
    if (_isLoading) return;
    setState(() {
      _pin = '';
      _errorMessage = null;
    });
  }

  // ── Llamada al servicio de autenticación ──────────────────────────────────

  Future<void> _submitPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.loginConPin(_pin);

    if (!mounted) return;

    if (result.success) {
      // Navegar al HomeScreen y reemplazar la pantalla de login en el stack
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Camino triste: limpiar PIN, animar error y mostrar mensaje
      _shakeController.forward(from: 0);
      setState(() {
        _isLoading = false;
        _pin = '';
        _errorMessage = result.errorMessage;
      });
    }
  }

  // ── Construcción de la UI ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 48),
                _buildPinIndicators(),
                const SizedBox(height: 20),
                _buildErrorMessage(),
                const SizedBox(height: 40),
                _buildNumericKeypad(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Encabezado con logo y título ──────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Emblema de la empresa
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppPalette.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppPalette.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'C',
              style: AppTypography.headline.copyWith(fontSize: 42),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'CRESAL',
          style: AppTypography.headline.copyWith(fontSize: 28, letterSpacing: 6),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sistema Industrial de Operaciones',
          style: AppTypography.small,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        const Divider(color: AppPalette.surface, thickness: 1),
        const SizedBox(height: 20),
        const Text(
          'Ingrese su PIN de Operario',
          style: AppTypography.title,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Indicadores de dígitos (4 círculos) ──────────────────────────────────

  Widget _buildPinIndicators() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        // Efecto de sacudida horizontal en caso de error
        final offset = _shakeController.isAnimating
            ? 12 * (0.5 - _shakeAnimation.value).abs() * 2
            : 0.0;
        return Transform.translate(
          offset: Offset(offset * (_shakeAnimation.value < 0.5 ? 1 : -1), 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pinLength, (index) {
          final isFilled = index < _pin.length;
          final hasError = _errorMessage != null;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasError
                  ? AppPalette.error
                  : isFilled
                  ? AppPalette.primary
                  : AppPalette.surface,
              border: Border.all(
                color: hasError
                    ? AppPalette.error
                    : isFilled
                    ? AppPalette.primary
                    : AppPalette.neutral,
                width: 2,
              ),
              boxShadow: isFilled
                  ? [
                      BoxShadow(
                        color:
                            (hasError ? AppPalette.error : AppPalette.primary)
                                .withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  // ── Mensaje de error ──────────────────────────────────────────────────────

  Widget _buildErrorMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _errorMessage != null
          ? Container(
              key: ValueKey(_errorMessage),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppPalette.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppPalette.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.small.copyWith(
                        color: AppPalette.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(key: ValueKey('empty'), height: 0),
    );
  }

  // ── Teclado numérico industrial 3×4 ──────────────────────────────────────

  Widget _buildNumericKeypad() {
    const double keypadSpacing = 14;
    final List<String?> keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'C',
      '0',
      '⌫',
    ];

    if (_isLoading) {
      return SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(
            color: AppPalette.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int row = 0; row < 4; row++) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int col = 0; col < 3; col++) ...[
                _buildKeyButton(keys[row * 3 + col]),
                if (col < 2) const SizedBox(width: keypadSpacing),
              ],
            ],
          ),
          if (row < 3) const SizedBox(height: keypadSpacing),
        ],
      ],
    );
  }

  Widget _buildKeyButton(String? label) {
    const double buttonSize = 72; // Amplio para guantes industriales (>44px)

    final bool isDelete = label == '⌫';
    final bool isClear = label == 'C';
    final bool isSpecial = isDelete || isClear;

    Color bgColor = AppPalette.surface;
    Color fgColor = AppPalette.textPrimary;
    if (isDelete) {
      bgColor = AppPalette.neutral.withValues(alpha: 0.3);
      fgColor = AppPalette.textSecondary;
    } else if (isClear) {
      bgColor = AppPalette.error.withValues(alpha: 0.15);
      fgColor = AppPalette.error;
    }

    return GestureDetector(
      onTap: () {
        if (label == null) return;
        if (isDelete) {
          _onBackspace();
        } else if (isClear) {
          _onClear();
        } else {
          _onDigitPressed(label);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isDelete
              ? Icon(Icons.backspace_outlined, color: fgColor, size: 22)
              : Text(
                  label ?? '',
                  style: AppTypography.title.copyWith(
                    fontSize: isSpecial ? 16 : 24,
                    color: fgColor,
                  ),
                ),
        ),
      ),
    );
  }
}
