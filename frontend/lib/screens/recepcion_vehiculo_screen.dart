import 'package:flutter/material.dart';
import '../core/widgets/gradient_button.dart';
import '../core/theme/tokens/app_palette.dart';

class RecepcionVehiculoScreen extends StatefulWidget {
  const RecepcionVehiculoScreen({super.key});

  @override
  State<RecepcionVehiculoScreen> createState() =>
      _RecepcionVehiculoScreenState();
}

class _RecepcionVehiculoScreenState extends State<RecepcionVehiculoScreen> {
  // Variables de Estado
  String numeroIngreso = "----";

  // Variables para los selectores obligatorios
  String? traccionSeleccionada;
  String? transmisionSeleccionada;
  String? combustibleSeleccionado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recepción de Vehículo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TARJETA DEL FOLIO (CORRELATIVO)
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    children: [
                      Text(
                        'NÚMERO DE INGRESO',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        numeroIngreso,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'Datos Técnicos del Vehículo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // 2. FORMULARIO COMPLETO
            const TextField(
              decoration: InputDecoration(
                labelText: 'Patente',
                hintText: 'Ej: XXYY11',
                prefixIcon: Icon(Icons.directions_car),
                suffixIcon: Icon(Icons.search), // Futuro botón de scraping
              ),
            ),
            const SizedBox(height: 16),

            const Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Marca'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Modelo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Año'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Cilindrada'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const TextField(
              decoration: InputDecoration(labelText: 'Nro. de Motor'),
            ),
            const SizedBox(height: 16),

            // 3. SELECTORES OBLIGATORIOS (CRITERIO DE JIRA)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Tracción'),
              value: traccionSeleccionada,
              items: ['4x2', '4x4', 'AWD'].map((String valor) {
                return DropdownMenuItem<String>(
                  value: valor,
                  child: Text(valor),
                );
              }).toList(),
              onChanged: (nuevoValor) =>
                  setState(() => traccionSeleccionada = nuevoValor),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Transmisión'),
              value: transmisionSeleccionada,
              items: ['Mecánica', 'Automática'].map((String valor) {
                return DropdownMenuItem<String>(
                  value: valor,
                  child: Text(valor),
                );
              }).toList(),
              onChanged: (nuevoValor) =>
                  setState(() => transmisionSeleccionada = nuevoValor),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Combustible'),
              value: combustibleSeleccionado,
              items: ['Gasolina', 'Diésel', 'Eléctrico', 'Híbrido'].map((
                String valor,
              ) {
                return DropdownMenuItem<String>(
                  value: valor,
                  child: Text(valor),
                );
              }).toList(),
              onChanged: (nuevoValor) =>
                  setState(() => combustibleSeleccionado = nuevoValor),
            ),

            const SizedBox(height: 32),
            Text(
              'Poka-Yoke: Validación Física',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // 4. ZONA DE CÁMARA PARA OCR
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppPalette.primary,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.camera_alt,
                    size: 48,
                    color: AppPalette.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tomar foto a la puerta',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'El OCR validará el código Posca',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 5. EL BOTÓN GUARDAR
            GradientButton(
              onPressed: () {
                // Aquí irá el POST
              },
              gradient: const LinearGradient(
                colors: [AppPalette.primary, AppPalette.secondary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              child: const Text(
                'GUARDAR INGRESO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(
              height: 40,
            ), // Espacio extra al final para scrollear cómodo
          ],
        ),
      ),
    );
  }
}
