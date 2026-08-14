import 'package:flutter/material.dart';
import '../../models/tarea_alerta.dart';
import '../../services/logistica_service.dart';
import '../widgets/task_card.dart';

// Importamos tus tokens exactos
import '../../../../core/theme/tokens/app_palette.dart';
import '../../../../core/theme/tokens/app_typography.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({Key? key}) : super(key: key);

  @override
  _AlertasScreenState createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  late Future<List<TareaAlerta>> futureAlertas;

  @override
  void initState() {
    super.initState();
    futureAlertas = LogisticaService.obtenerAlertas();
  }

  Future<void> _refreshAlertas() async {
    setState(() {
      futureAlertas = LogisticaService.obtenerAlertas();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos los tokens exactos de tu AppPalette
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(
          'ALERTAS TAREAS',
          // Usamos AppTypography.headline de tus tokens
          style: AppTypography.headline.copyWith(
            color: AppPalette.textPrimary,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: AppPalette.surface,
        iconTheme: const IconThemeData(color: AppPalette.primary),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAlertas,
        color: AppPalette.primary,
        backgroundColor: AppPalette.surface,
        child: FutureBuilder<List<TareaAlerta>>(
          future: futureAlertas,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppPalette.primary),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: AppPalette.error),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No hay alertas operativas.',
                  style: TextStyle(color: AppPalette.textSecondary),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return TaskCard(
                  tarea: snapshot.data![index],
                  onActualizar: _refreshAlertas,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
