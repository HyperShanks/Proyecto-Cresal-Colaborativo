# SPEC-HU-TAREA-17: Visualización Compartida de Atributos Técnicos entre Motor y Caja de Cambios

## 1. Contexto y Archivos Afectados
- **Objetivo**: Estandarizar la visualización de los detalles técnicos de los activos en el catálogo de ventas y el inventario. Se debe asegurar que las Cajas de Cambios muestren las especificaciones del motor del vehículo donante (Cilindrada, Combustible, etc.) y la Tracción, compartiendo estos datos con la vista del Motor. El campo `numero_motor` será exclusivo para los repuestos de categoría Motor.
- **Archivos a modificar**:
  - Backend: `backend/routers/inventario.py` (Endpoints de búsqueda y detalle de activo).
  - Frontend: `lib/features/inventario/presentation/screens/detalle_activo_screen.dart` o `ticket_detail_dialog.dart` (Vistas de detalle de activos).
  - Frontend: `lib/features/ventas/presentation/widgets/catalogo_item_card.dart` (o donde se pre-visualicen especificaciones).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  El esquema `CatalogoItemResponse` ya contempla todos los campos (`traccion`, `cilindrada`, `combustible`, `transmision_tipo`, `numero_motor`). No es necesario modificar el DTO, pero **SÍ es obligatorio** modificar cómo se pueblan estos datos en SQLAlchemy.
- **Endpoints Afectados**:
  - `GET /api/v1/inventario/buscar` (Listado paginado)
  - `GET /api/v1/inventario/{id_activo}` (Detalle de un activo)
- **Modelos Frontend (Dart)**:
  - El modelo `CatalogoItemModel` ya soporta estos campos, la UI deberá mapearlos dinámicamente.

## 3. Reglas de Negocio, Casos de Borde y Seguridad
- **Herencia de Datos para Caja de Cambios**:
  - En la base de datos, `cilindrada` y `combustible` se almacenan físicamente en `Detalle_Motor` (asociado al `id_activo` del motor).
  - Cuando se solicite el detalle de una **Caja de Cambios** (`id_categoria == 2`), el backend debe rastrear el `id_vehiculo` (Vehículo Origen), buscar el activo Motor (`id_categoria == 1`) perteneciente a ese mismo vehículo, y extraer de ahí su `cilindrada` y `combustible` para rellenar el DTO de la Caja de Cambios.
- **Atributos Provenientes del Vehículo**:
  - La `traccion` pertenece directamente a la tabla `Vehiculo_Origen`. Tanto el Motor como la Caja deben inyectar este dato en el DTO extrayéndolo del vehículo padre.
- **Exclusividad del Número de Motor**:
  - La propiedad `numero_motor` **SÓLO** debe mostrarse en la Interfaz de Usuario si la pieza es un Motor (`id_categoria == 1`). Para la Caja de Cambios, debe ocultarse u omitirse en la pantalla (aunque el DTO lo envíe nulo).

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Lógica de Herencia en Detalle)**: Modificar `obtener_detalle_activo` en `routers/inventario.py`. Si el activo consultado es Caja (`id_categoria == 2`), realizar un query adicional (o JOIN) para buscar el `Detalle_Motor` del mismo `id_vehiculo` y poblar `cilindrada` y `combustible`.
- [ ] **Tarea 2 (Backend - Lógica de Herencia en Búsqueda)**: Replicar esta lógica de cruce en el endpoint `GET /api/v1/inventario/buscar` para asegurar que el catálogo principal muestre las cajas con la cilindrada correcta.
- [ ] **Tarea 3 (Backend - Pruebas Pytest)**: Escribir un test unitario creando un vehículo con motor y caja, consultando el endpoint de la caja y verificando que el JSON de respuesta incluya la `cilindrada` heredada del motor.
- [ ] **Tarea 4 (Frontend - UI Detalle Compartido)**: Refactorizar `detalle_activo_screen.dart` para que la sección de especificaciones itere y renderice dinámicamente `traccion`, `transmision_tipo`, `cilindrada` y `combustible` independientemente de si es Caja o Motor.
- [ ] **Tarea 5 (Frontend - UI Exclusividad de Motor)**: Envolver el renderizado visual de la etiqueta `Número de Motor` con un guardián tipo `if (activo.idCategoria == 1 && activo.numeroMotor != null)`.
- [ ] **Tarea 6 (Frontend - Pruebas Widget)**: Testear que al renderizar el widget con un mock de Caja de Cambios, el componente del "Número de Motor" no exista en el árbol de widgets.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_inventario_herencia_caja.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/inventario.py`.
- Frontend Tests: Ejecutar `flutter test test/features/inventario/detalle_activo_ui_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/inventario/`.
