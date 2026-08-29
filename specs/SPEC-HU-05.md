# SPEC-HU-05: Flujo de Carrito por Pasos (Wizard) e Integración de Reservas por Encargo (Reservas_Backorder)

## 1. Contexto y Archivos Afectados
- **Objetivo**: Refactorizar el proceso de Checkout en el Mesón de Ventas para utilizar un formato Wizard (por pasos secuenciales), e integrar la funcionalidad de "Reservas por Encargo" o "Compras en Verde" para artículos sin stock inmediato, reflejando su abono en la Caja.
- **Archivos a crear**:
  - Frontend: `lib/features/ventas/presentation/screens/checkout_wizard_screen.dart` (Contenedor del Wizard y Stepper).
  - Frontend: `lib/features/ventas/presentation/widgets/wizard_steps/*.dart` (Vistas modulares para cada uno de los 5 pasos).
  - Frontend: `lib/features/ventas/presentation/widgets/modal_backorder_form.dart` (Formulario para definir características técnicas y comerciales de la reserva).
- **Archivos a modificar**:
  - Backend: `backend/schemas.py` (Añadir `CheckoutWizardRequest`, `ReservaBackorderDTO`, etc.).
  - Backend: `backend/routers/ordenes.py` (Implementar endpoint `POST /api/v1/ordenes-venta/checkout-wizard`).
  - Frontend: `lib/features/ventas/services/ventas_service.dart` (Endpoint consolidado de checkout).
  - Frontend: `lib/features/ventas/controllers/checkout_controller.dart` (Manejo de estado persistente entre pasos).

## 2. Contratos de Datos y Firmas de API
- **Modelos Backend (Pydantic V2)**:
  ```python
  from pydantic import BaseModel, ConfigDict
  from typing import List, Optional
  from uuid import UUID

  class ReservaBackorderDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      id_categoria_requerida: int
      marca_requerida: str
      modelo_requerido: str
      anio_requerido: Optional[int] = None
      cilindrada_requerida: Optional[str] = None
      combustible_requerido: Optional[str] = None
      transmision_requerida: Optional[str] = None
      notas_preparacion: Optional[str] = None
      precio_acordado: int
      monto_abonado: int

  class DespachoDTO(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      direccion_envio: str
      receptor_nombres: str
      receptor_rut: str
      receptor_telefono: str
      id_comuna_destino: int
      empresa_transporte: Optional[str] = None

  class CheckoutWizardRequest(BaseModel):
      model_config = ConfigDict(from_attributes=True)
      id_cliente: UUID
      tipo_entrega: str  # 'Retiro' o 'Despacho Domicilio'
      total_venta: int
      monto_pendiente: int
      items_inventariados: List[UUID]  # IDs de Activo_Inventariado
      items_manuales: List[dict]       # Ventas rápidas
      reservas: Optional[List[ReservaBackorderDTO]] = None
      datos_despacho: Optional[DespachoDTO] = None
  ```

- **Endpoints Backend**:
  - `POST /api/v1/ordenes-venta/checkout-wizard`:
    - **Headers**: Autorización JWT Bearer.
    - **Payload JSON**: `CheckoutWizardRequest`
    - **Respuesta 200**: `{"id_orden": "uuid...", "estado": "Reservada", "msg": "Orden generada exitosamente."}`
    - **Respuesta 400**: Error de validación o incompatibilidad de datos logísticos/comerciales.

- **Modelos Frontend (Dart)**:
  - Manejo de clases DTO análogas (`CheckoutWizardRequest`, `ReservaBackorderDTO`, `DespachoDTO`) estructuradas con `json_serializable`.
  - Método en servicio: `Future<CheckoutResult> processCheckout(CheckoutWizardRequest request)`

## 3. Reglas de Negocio, Casos de Borde y Seguridad
- **Zero Trust & RBAC**: El endpoint de checkout verifica el `id_rol` asegurando que solo Vendedores (`id_rol == 2, 7`) o Jefaturas puedan emitir órdenes de venta.
- **Flujo de Transacciones ACID**: En el endpoint `checkout-wizard`, se debe utilizar un bloque `try ... db.commit() ... except: db.rollback()` para insertar atómicamente:
  1. `Orden_Venta` con `estado_orden = 'Reservada'`.
  2. Múltiples `Detalle_Orden` y actualizacion de `Activo_Inventariado`.
  3. Múltiples registros en `Reservas_Backorder` si los hay (asociando el `id_orden` generado, cliente y vendedor).
  4. Un registro en `Despacho` si `tipo_entrega == 'Despacho Domicilio'`.
- **Validaciones UI (Wizard)**:
  - Paso 2: Imposible avanzar al Paso 3 sin seleccionar o crear un Cliente.
  - Paso 3: Si `tipo_entrega` es Despacho, los campos de dirección, nombre de receptor y comuna son obligatorios.
  - El estado del Wizard (datos ya ingresados) se guarda en la instancia del controlador (Provider/Bloc/Riverpod), no se pierden si el usuario retrocede al Paso 1.
- **Impacto en Caja**: Al generarse la orden, su `monto_pendiente` reflejará el total menos cualquier abono inicial (si aplica flujo de abono en caja). La `Orden_Venta` resultante aparecerá en el módulo de Caja para su cobro.
- **Lifecycle Guards (Frontend)**: Cualquier operación de *Next Step* que implique llamadas asíncronas de validación (e.g. buscar RUT) o el envío final `processCheckout()`, debe incluir `if (!mounted) return;` antes de alterar el estado de navegación.
- **Manejo de Zona Horaria**: El `server_default=text("now()")` de Postgres es suficiente, pero si el ORM inyecta fechas manuales (ej: `fecha_preparacion`), usar `datetime.now(timezone.utc)`.

## 4. Checklist de Tareas de Implementación (TDD)
- [ ] **Tarea 1 (Backend - Schemas & Modelos)**: Construir `CheckoutWizardRequest`, `ReservaBackorderDTO`, `DespachoDTO` en Pydantic V2 (`ConfigDict(from_attributes=True)`).
- [ ] **Tarea 2 (Backend - Endpoints & Transacciones ACID)**: Codificar `/checkout-wizard` usando `try/commit/rollback` para asegurar persistencia atómica en `Orden_Venta`, `Detalle_Orden`, `Reservas_Backorder` y `Despacho`.
- [ ] **Tarea 3 (Backend - Pruebas Pytest)**: Implementar tests `test_checkout_wizard.py` comprobando la creación exitosa de órdenes combinadas (inventario + reservas + despacho) y el rollback frente a validaciones rotas.
- [ ] **Tarea 4 (Frontend - Servicio & Modelos Dart)**: Declarar modelos `CheckoutWizardRequest` y crear `processCheckout` en el `ventas_service.dart`.
- [ ] **Tarea 5 (Frontend - UI, Controladores & Mounted Guards)**: 
  - Codificar `CheckoutWizardController` reactivo.
  - Armar el layout de pasos (Paso 1 a 5) y el formulario `modal_backorder_form`.
  - Aplicar `if (!mounted) return;` en cada transición asíncrona.
- [ ] **Tarea 6 (Frontend - Pruebas Widget/Unitarias Flutter)**: Escribir tests verificando que no se pueda avanzar de paso sin data válida y comprobando que retroceder no borra el input.

## 5. Criterios de Validación Automatizada
- Backend Tests: Ejecutar `pytest tests/test_checkout_wizard.py -v`.
- Backend Linter: Ejecutar `flake8 backend/routers/ordenes.py backend/schemas.py`.
- Frontend Tests: Ejecutar `flutter test test/features/ventas/checkout_wizard_test.dart`.
- Frontend Linter: Ejecutar `flutter analyze lib/features/ventas/`.
