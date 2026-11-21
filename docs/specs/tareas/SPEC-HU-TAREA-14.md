# SPEC-HU-TAREA-14: Acceso Directo por Número de Ingreso al Flujo de Paletizado y Enriquecimiento

## 1. Contexto y Archivos Afectados
- **Objetivo**: Optimizar la experiencia del bodeguero sustituyendo la lista general de activos por paletizar con un input directo de número de ingreso en la pantalla principal (Home), agilizando el flujo de trabajo en terminales físicas.
- **Archivos a modificar**:
  - Frontend: `lib/features/home/presentation/screens/home_screen.dart` (Añadir input predictivo y reemplazar la tarjeta de redirección plana).
  - Frontend: `lib/features/recepcion/presentation/screens/paletizado_screen.dart` (Eliminar/Bypassear la lista intermedia y consumir el ID recibido por parámetro).
  - Backend: `backend/routers/bodega.py` o `inventario.py` (Asegurar que el endpoint `GET` de búsqueda de activo por número de ingreso responda de forma rápida y exacta).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend**: Se reutiliza el DTO de consulta de vehículo/activo por número de ingreso.
- **Endpoints**: `GET /api/v1/inventario/ingreso/{numero_ingreso}`.
- **Modelos Frontend**: Inyección del `numero_ingreso` ingresado en el `TextField` directo hacia el servicio de búsqueda.

## 3. Reglas de Negocio, Casos de Borde y Seguridad (Matriz de Errores)
- **Ingreso Directo**: El input en el Home debe disparar el teclado numérico (`TextInputType.number`). El Enter (Submit) debe activar la búsqueda.
- **Validación Vacía**: Si el campo está vacío, no se realiza ninguna petición HTTP.

**Mensajería Intuitiva Exigida y Control de Excepciones**:
1. **Frontend: Activo No Encontrado**:
   - *Error Backend*: `404 Not Found`.
   - *Mensaje UI*: `"Número de ingreso no encontrado en la base de datos."` (Mantener foco en input para corrección rápida).
2. **Frontend: Activo Ya Paletizado/Procesado**:
   - *Error Backend*: `400 Bad Request` o chequeo local de estado `id_estado != 1`.
   - *Mensaje UI*: `"El activo asociado a este número ya fue paletizado previamente o no requiere este flujo."`
3. **Frontend: Fallo de Red**:
   - *Mensaje UI*: `"Error de conexión. Reintentando la búsqueda..."`

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Endpoint Auditoría)**: Validar o crear el endpoint de búsqueda directa por `numero_ingreso` que devuelva si está pendiente de paletizado.
- [ ] **Tarea 2 (Frontend - Home UI)**: Reemplazar el botón genérico de "Paletizado" por un componente con un `TextField` (teclado numérico) y botón de lupa.
- [ ] **Tarea 3 (Frontend - Navegación Directa)**: Implementar la redirección inmediata a la vista del formulario de paletizado (`/paletizado/detalle/{id}`) saltando la lista.
- [ ] **Tarea 4 (Frontend - Eliminación de Lista Previa)**: Desacoplar y remover la pantalla que antes cargaba la lista masiva de activos por paletizar, dejando únicamente el modo directo.
- [ ] **Tarea 5 (Frontend - Manejo de Errores)**: Implementar las validaciones visuales (Snackbar) detalladas en la Sección 3 para búsquedas inválidas, sin colapsar el Home.
- [ ] **Tarea 6 (Frontend - Pruebas Widget)**: Testear el input con un ID inválido para comprobar que no redirige y muestra el error.
- [ ] **Tarea 7 (Documentación)**: Agregar los errores de búsqueda al `DICCIONARIO_ERRORES.md`.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_inventario_busqueda.py -v`.
- Frontend Tests: Ejecutar `flutter test test/features/home/home_paletizado_input_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/home/`.
