# Resultados de Pruebas: Tareas 9 y 10

Este documento presenta los resultados de las pruebas de auditoría de seguridad (Tarea 9) y las pruebas de concurrencia y carga (Tarea 10), ejecutadas sobre el estado actual del repositorio `CresalRepoCapstone`.

---

## Tarea 9: Blindaje de Seguridad (Hardening) y Preparación para Producción

Se realizó una auditoría del código fuente y se ejecutaron scripts de prueba contra la API de FastAPI.

### 1. Almacenamiento Seguro y Protección de PIN
- **Almacenamiento Seguro:** Se verificó el uso extensivo de `flutter_secure_storage` en el frontend para el manejo de credenciales y tokens. (Cumple ✅)
- **Rate Limiting en `pin_acceso`:** Se ejecutó un script iterativo simulando ataques de fuerza bruta contra el endpoint `/api/auth/login-pin`. 
  - **Resultado:** El sistema permitió 6 o más intentos fallidos consecutivos sin aplicar bloqueos (retornando siempre 401 en lugar de 429).
  - **Sugerencia de Mejora:** Implementar un limitador de tasa (ej. usando la librería `slowapi` en FastAPI) o agregar un contador de intentos fallidos en la base de datos para bloquear el `id_usuario` temporalmente tras 5 intentos.

### 2. Validación de Roles en Backend (RBAC Middleware)
- **Resultado:** El backend cumple con el patrón *Zero Trust*. Dependencias como `verificar_rol_jefe_ventas` (en `core/security.py`) validan los permisos directamente a partir del ID de rol obtenido del token JWT decodificado, no de los parámetros de la petición. (Cumple ✅)

### 3. Sanitización de Respuestas y Manejo de Errores
- **Resultado:** El archivo `core/exceptions.py` define manejadores globales (`sqlalchemy_exception_handler`, etc.) que interceptan errores de base de datos (como `IntegrityError`), ocultando trazas SQL y devolviendo un formato estándar unificado (`ErrorResponseDTO`). (Cumple ✅)

### 4. Cero Credenciales Hardcoded y CORS
- **Cero Credenciales:** La conexión a la base de datos y la firma JWT se extraen correctamente de `.env`. Sin embargo, en `main.py` existe una ruta *hardcoded* hacia una llave JSON: `os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "vision-key.json"`.
  - **Sugerencia de Mejora:** Pasar el contenido del JSON a través de una variable de entorno segura o parametrizar la ruta de la llave.
- **Configuración CORS:** Se evaluó el middleware de CORS mediante peticiones `OPTIONS` simuladas.
  - **Resultado:** El servidor devolvió autorización para el origen `http://origen-malicioso.com`, debido a que `main.py` está configurado con `allow_origins=["*"]`.
  - **Sugerencia de Mejora:** Restringir el arreglo `allow_origins` explícitamente a los dominios o IPs de los terminales autorizados de Cresal.

---

## Tarea 10: Pruebas de Carga, Concurrencia y Resiliencia

Se desarrollaron y ejecutaron scripts asíncronos en Python utilizando `httpx` para estresar el backend de manera concurrente.

### 1. Prueba de Concurrencia y Resolución de Carreras (Stock Unitario)
Se simuló un escenario donde 3 vendedores (Admin, Vendedor 1 y Vendedor 2) intentaron enviar la petición de reserva (`POST /api/v1/carrito/reservar`) en el **mismo milisegundo**, apuntando al mismo `id_activo` y enviando el mismo `version_lock`.

- **Resultados:**
  - **Petición 1:** Código HTTP 200 OK (Reserva exitosa).
  - **Petición 2:** Código HTTP 409 Conflict ("¡Lo sentimos! Este repuesto acaba de ser reservado...").
  - **Petición 3:** Código HTTP 409 Conflict.
- **Conclusión:** El mecanismo de concurrencia optimista (`version_lock`) es robusto. El ACID de la base de datos previno la colisión, asignando el repuesto a un único vendedor. (Cumple ✅)

### 2. Prueba de Carga y Estrés (20 Usuarios Concurrentes)
Se lanzó un script simulando el tráfico de 20 usuarios consultando el catálogo completo de inventario (`GET /api/v1/inventario/buscar`) simultáneamente.

- **Métricas Obtenidas:**
  - **Tasa de Error:** 0.00% (El backend toleró la carga sin bloqueos ni caídas).
  - **Tiempo Promedio:** ~670 ms.
  - **Tiempo Percentil 95 (p95):** ~907 ms.
- **Conclusión:** La tasa de error (0%) es excelente, pero el p95 (907 ms) está por encima de los 500 ms esperados en los Criterios de Aceptación.
- **Sugerencia de Mejora:** Esta latencia alta es un síntoma de consultar una base de datos remota en la nube (Supabase) desde un entorno local, sumado a joins complejos en SQL. Para alcanzar la métrica de < 500 ms en producción, se recomienda:
  - Hospedar el backend de FastAPI en la misma región que la base de datos para reducir la latencia de red.
  - Implementar una capa de caché en memoria (como Redis) para las peticiones recurrentes de búsqueda de catálogo.
