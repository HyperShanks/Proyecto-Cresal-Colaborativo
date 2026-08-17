import 'package:flutter/material.dart';
import '../../models/tarea_alerta.dart';
import '../../services/logistica_service.dart';
import '../widgets/task_card.dart';

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
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Alertas Tareas',
          style: AppTypography.title.copyWith(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppPalette.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Volver',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppPalette.primary),
            onPressed: _refreshAlertas,
            tooltip: 'Actualizar tareas',
          ),
        ],
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
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppPalette.error, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Error al cargar tareas: ${snapshot.error}',
                        style: const TextStyle(color: AppPalette.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshAlertas,
                        style: ElevatedButton.styleFrom(backgroundColor: AppPalette.primary),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.task_alt, color: AppPalette.success, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      '¡Al día!',
                      style: AppTypography.title.copyWith(color: AppPalette.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'No hay tareas operativas pendientes.',
                      style: TextStyle(color: AppPalette.textSecondary),
                    ),
                  ],
                ),
              );
            }

            final tareas = snapshot.data!;
            final trasladosCount = tareas.where((t) => t.esTraslado || t.tipoAlerta == 'TRASLADO').length;

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: tareas.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppPalette.neutral.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tareas.length} ${tareas.length == 1 ? 'TAREA PENDIENTE' : 'TAREAS PENDIENTES'}',
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppPalette.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (trasladosCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppPalette.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppPalette.secondary),
                            ),
                            child: Text(
                              '$trasladosCount TRASLADO(S)',
                              style: AppTypography.small.copyWith(
                                color: AppPalette.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return TaskCard(
                  key: Key('task_card_${tareas[index - 1].idTarea}'),
                  tarea: tareas[index - 1],
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
