import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/pin_login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/recepcion/presentation/screens/recepcion_vehiculo_screen.dart';
import 'features/tickets/presentation/screens/tickets_screen.dart';
import 'features/paletizado/presentation/screens/paletizado_screen.dart'; // Importa la pantalla de paletizado
import 'features/paletizado/presentation/screens/etiqueta_preview_screen.dart'; // HU-2.4: Previsualización de etiqueta térmica
import 'features/alertas/presentation/screens/alertas_screen.dart'; // Importa la pantalla de alertas
import 'features/inventario/presentation/screens/buscador_screen.dart'; // Importa la pantalla de buscador
import 'features/ventas/presentation/screens/catalogo_screen.dart'; // HU-3.2: Catálogo Dinámico de Ventas
import 'features/ventas/presentation/screens/ventas_main_screen.dart'; // HU-3.2: Layout Principal Vendedor

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cresal Capstone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Oscuro por defecto industrial
      // Pantalla inicial: Splash que decide la ruta según sesión
      home: const SplashScreen(),

      // Rutas nombradas de la aplicación
      routes: {
        '/login': (context) => const PinLoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/ventas_main': (context) => const VentasMainScreen(),
        '/recepcion': (context) => const RecepcionVehiculoScreen(),
        '/tickets': (context) => const TicketsScreen(),
        '/paletizado': (context) =>
            const PaletizadoScreen(), // Nueva ruta para el módulo de paletizado
        // HU-2.4: Pantalla de previsualización de etiqueta térmica con QR
        '/etiqueta-preview': (context) => const EtiquetaPreviewScreen(),
        '/alertas': (context) =>
            const AlertasScreen(), // Nueva ruta para el módulo de alertas
        '/buscador': (context) =>
            const BuscadorScreen(), // Nueva ruta para el módulo de buscador
        '/catalogo': (context) =>
            const CatalogoScreen(), // HU-3.2: Catálogo Dinámico con Radar de Stock
      },
    );
  }
}
