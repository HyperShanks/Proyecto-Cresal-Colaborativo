import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';
import '../../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN — Punto de entrada de la app
// Lee el token guardado y decide hacia dónde navegar:
//   • Token presente → /home
//   • Sin token      → /login
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de fade-in del logo
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Verificar sesión después del fade
    _checkSession();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    // Mínimo de tiempo de splash para que el logo sea visible
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final token = await AuthService.getToken();

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      final rol = await AuthService.getRol();
      if (!mounted) return;
      if (rol?.toLowerCase() == 'vendedor') {
        Navigator.of(context).pushReplacementNamed('/ventas_main');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo corporativo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.45),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'C',
                    style: AppTypography.headline.copyWith(fontSize: 52),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'CRESAL',
                style: AppTypography.headline.copyWith(fontSize: 30, letterSpacing: 8),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistema Industrial de Operaciones',
                style: AppTypography.small,
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppPalette.primary,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
