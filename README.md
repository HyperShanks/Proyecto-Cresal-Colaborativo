# Cresal-SaaS — ERP Automotriz e Inventario Transaccional

> Plataforma integral de gestión de desarme, inventario, ventas (mesón/caja), logística en bodega (PDA) y reportería ejecutiva para la empresa automotriz **Cresal**.

---

## 🛠️ Stack Tecnológico

- **Backend:** Python 3.12+ / FastAPI / SQLAlchemy ORM / Pydantic V2.
- **Base de Datos:** PostgreSQL en la nube vía **Supabase** (Persistencia ACID, control de concurrencia optimista).
- **Frontend:** Flutter 3.3x Multiplataforma (Desktop PC para Caja/Gerencia, All-in-One Touch para Mesón de Ventas, PDA Industrial Android para Bodega).
- **Control de Calidad:** Pytest, Flake8, Flutter Test, Flutter Analyze (Estándar TDD estricto).

---

## ⚖️ Reglas de Desarrollo y Gobernanza

Cualquier desarrollo, refactorización o cambio realizado por desarrolladores o agentes autónomos se rige obligatoriamente por el documento:

* 📄 **[RULES.md](RULES.md)**: Directrices inquebrantables de Seguridad Zero Trust, Persistencia Transaccional ACID, Manejo de Zonas Horarias (`America/Santiago` a UTC) y Criterios de Parada TDD.

---

## 📚 Mapa Central de Documentación (`/docs`)

Toda la documentación técnica del repositorio se encuentra clasificada bajo la estructura modular [`docs/`](docs/):

### 1. Arquitectura y Diseño del Sistema ([`docs/arquitectura/`](docs/arquitectura/))
* **[ARQUITECTURA_BACKORDER_WIZARD.md](docs/arquitectura/ARQUITECTURA_BACKORDER_WIZARD.md)**: Flujo de Checkout Wizard de 5 pasos y compras en verde/reservas.
* **[ARQUITECTURA_BODEGA_PDA_HU06.md](docs/arquitectura/ARQUITECTURA_BODEGA_PDA_HU06.md)**: Interfaz y flujo operativo para dispositivos PDA de bodega.
* **[ARQUITECTURA_ENRUTAMIENTO_ROLES.md](docs/arquitectura/ARQUITECTURA_ENRUTAMIENTO_ROLES.md)**: Matriz de enrutamiento y guardas de navegación por rol de usuario.
* **[ARQUITECTURA_IMPRESION_BODEGA.md](docs/arquitectura/ARQUITECTURA_IMPRESION_BODEGA.md)**: Integración con impresoras térmicas e industriales (ZPL / Bluetooth / Red).
* **[ARQUITECTURA_JWT_JORNADAS_Y_SESION.md](docs/arquitectura/ARQUITECTURA_JWT_JORNADAS_Y_SESION.md)**: Ciclo de vida de sesión, tokens JWT, apertura y cierre de jornadas operativas.
* **[ARQUITECTURA_SINCRONIA_Y_ESTADOS_FLUTTER.md](docs/arquitectura/ARQUITECTURA_SINCRONIA_Y_ESTADOS_FLUTTER.md)**: Patrones de gestión de estado, reactividad y manejo asíncrono en Flutter.
* **[PATRONES_LAYOUT_Y_RESPONSIVIDAD.md](docs/arquitectura/PATRONES_LAYOUT_Y_RESPONSIVIDAD.md)**: Guía de adaptabilidad visual, constraints y prevención de desbordamientos (`RenderFlex overflowed`).

### 2. Operaciones y Credenciales ([`docs/operaciones/`](docs/operaciones/))
* **[USUARIOS_ROLES.md](docs/operaciones/USUARIOS_ROLES.md)**: Matriz de usuarios de prueba, roles en Supabase, credenciales y PINs operativos.
* **[DICCIONARIO_ERRORES.md](docs/operaciones/DICCIONARIO_ERRORES.md)**: Matriz global de errores HTTP, códigos internos y mensajes estandarizados Zero Technical Leaks.
* **[DICCIONARIO_ERRORES_TAREA12.md](docs/operaciones/DICCIONARIO_ERRORES_TAREA12.md)**: Matriz de excepciones y validaciones matemáticas Módulo 11 para RUTs.

### 3. Requerimientos y Especificaciones ([`docs/specs/`](docs/specs/))
* **[Historias de Usuario (`docs/specs/historias_usuario/`)](docs/specs/historias_usuario/)**: Requerimientos funcionales de alto nivel:
  * `SPEC-HU-01.md` al `SPEC-HU-07.md` (Caja, Venta Mesón, Inventario, Reportes, Checkout, Bodega, etc.).
  * Submódulos `SPEC-HU-4.2.md`, `SPEC-HU-4.5.md`, `SPEC-HU-5.1.md` al `SPEC-HU-5.4.md`.
  * Casos transversales: `SPEC-HU-EDICION-PAGOS-AUDITORIA.md`, `SPEC-JWT-INTERCEPCION-401-Y-TELEMETRIA.md`, `SISTEMA-DE-REFRESCOS-POR-ROL.md`.
* **[Tareas de Ingeniería (`docs/specs/tareas/`)](docs/specs/tareas/)**:
  * Especificaciones técnicas detalladas: `SPEC-HU-TAREA-1.md` a `SPEC-HU-TAREA-24-*.md`.

### 4. Entregables y Cierre Técnico ([`docs/entregas/`](docs/entregas/))
* Documentación post-implementación de módulos críticos:
  * `DOCUMENTACION_HU_5.1_DASHBOARD_EJECUTIVO.md`
  * `DOCUMENTACION_HU_5.2_VISOR_ORDENES.md`
  * `DOCUMENTACION_RESILIENCIA_RED_Y_HANDSHAKE.md`
  * `DOCUMENTACION_TAREA_22_RECEPCION_VEHICULAR.md`
  * `DOCUMENTACION_TAREA_23_ALERTAS_TELEGRAM_Y_AUDITORIA.md`
  * `DOCUMENTACION_TAREA_24_VENTA_REFERIDA_LIMACHE.md`

### 5. Auditorías y Aseguramiento de Calidad ([`docs/auditorias_y_qa/`](docs/auditorias_y_qa/))
* **[AUDIT-SPRINTS-1-TO-3.md](docs/auditorias_y_qa/AUDIT-SPRINTS-1-TO-3.md)**: Informe exhaustivo de auditoría estática y dinámica de los Sprints 0 al 3.
* **[DOCUMENTACION_PRUEBAS_TAREAS_9_Y_10.md](docs/auditorias_y_qa/DOCUMENTACION_PRUEBAS_TAREAS_9_Y_10.md)**: Resultados de auditoría de seguridad y pruebas de carga/concurrencia.

---

## 🚀 Comandos Rápidos de Ejecución y Pruebas

### Backend (FastAPI)
```bash
cd backend

# Crear entorno virtual (solo la primera vez)
python -m venv venv

# Activar entorno virtual (Windows)
venv\Scripts\activate

# Instalar dependencias del entorno
pip install -r requirements.txt

# Ejecutar análisis estático y suite de pruebas
flake8 . --count --select=E9,F63,F7,F82 --exclude=venv,__pycache__
pytest -v

# Ejecutar servidor de desarrollo
uvicorn main:app --reload --port 8000
```

### Frontend (Flutter)
```bash
cd frontend

# Obtener dependencias
flutter pub get

# Ejecutar análisis estático y pruebas
flutter analyze
flutter test

# Ejecutar aplicación (seleccionar dispositivo o escritorio Windows)
flutter run -d windows
```
