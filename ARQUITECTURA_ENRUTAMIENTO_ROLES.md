# Arquitectura de Enrutamiento y Navegación por Roles (SSOT)
**Proyecto:** Cresal-SaaS (Frontend Flutter + Backend FastAPI)  
**Estándar:** Single Source of Truth (SSOT) & Role-Based Access Control (RBAC)  
**Audiencia:** Desarrolladores, Arquitectos de Software y Mantenedores del Sistema  

---

## 1. Contexto y Propósito

Este documento describe la arquitectura unificada para la resolución de rutas de inicio (*landing pages*) y control de acceso según el rol del usuario en la aplicación cliente de Cresal-SaaS.

El objetivo de este diseño es:
1. **Evitar la dispersión de lógica:** Que no existan múltiples árboles de decisión condicionales (`if-else`) repartidos en distintos controladores o vistas.
2. **Garantizar la previsibilidad:** Que el inicio de sesión, el desbloqueo por PIN y la recarga de página (`F5`) siempre conduzcan al usuario al panel exacto que le corresponde.
3. **Facilitar la extensibilidad futura:** Permitir la incorporación de nuevos perfiles o módulos modificando un único archivo centralizado.

---

## 2. El Problema Anterior (Deuda Técnica y Hardcoding)

En las etapas tempranas de desarrollo, la redirección posterior al inicio de sesión se construyó de manera fragmentada:

* **Controlador de Login (`login_controller.dart`)** evaluaba si el usuario era de Caja (`/caja`) o de Ventas (`/ventas_main`), y cualquier otro rol caía en un bloque `else` que navegaba a `/home` (Terminal de Bodega).
* **Pantalla de Carga (`splash_screen.dart`)** duplicaba exactamente el mismo bloque `if-else` al restaurar la sesión desde el token guardado.
* **Pantalla de Inicio (`home_screen.dart`)** tenía una guarda interna que solo expulsaba a usuarios de Caja y Ventas, pero dejaba pasar a Gerentes, rotulándolos estáticamente con el texto quemado *"Operador de Bodega"*.
* **Arranque (`main.dart`)** definía un mapa de rutas local que no incluía la ruta `/gerencia`, pese a que la vista ya estaba desarrollada.

### Consecuencia:
Cuando el **Gerente (Roberto, `id_rol = 4`)** ingresaba al sistema, caía forzosamente en la vista de Bodega, viendo tareas de paletizado y recepción en lugar de su Dashboard Ejecutivo.

---

## 3. El Nuevo Paradigma: Fuente Única de Verdad (SSOT)

Para resolver esto de raíz y con estándar senior, se desacopló la decisión de navegación de las pantallas y se centralizó en `AppRoutes` (`frontend/lib/routes/app_routes.dart`):

```
                      [Inicio de Sesión / Recarga Web]
                                     │
                                     ▼
                      AuthService.getIdRol() (Ej: 4)
                                     │
                                     ▼
                 ┌───────────────────────────────────────┐
                 │    AppRoutes.getHomeRouteForRole()    │  <-- ÚNICA FUENTE DE VERDAD
                 └───────────────────┬───────────────────┘
                                     │
       ┌──────────────┬──────────────┼──────────────┬──────────────┐
       ▼              ▼              ▼              ▼              ▼
     Rol 4          Rol 3      Roles 2, 6, 7      Rol 5          Rol 1
   (Gerente)        (Caja)        (Ventas)       (Admin)       (Bodega)
       │              │              │              │              │
       ▼              ▼              ▼              ▼              ▼
  '/gerencia'      '/caja'     '/ventas_main'    '/home'        '/home'
```

### Componentes de la Arquitectura:

1. **`AppRoutes.getHomeRouteForRole(int? idRol)`**:
   Es el **único método** en todo el frontend autorizado para responder: *"¿A qué pantalla principal pertenece este rol?"*.
2. **`AppRoutes.isRouteAllowedForRole(int? idRol, String route)`**:
   Es el **único método** que valida si un rol tiene permiso para ingresar a una sub-ruta específica (Guarda RBAC).
3. **`AppRoutes.getRoutes()`**:
   Es el registro maestro de todas las pantallas de la aplicación. `main.dart` (`frontend/lib/main.dart`) simplemente consume `routes: AppRoutes.getRoutes()`, eliminando diccionarios de rutas duplicados.

---

## 4. Matriz Actual de Roles y Aterrizaje

| ID Rol | Nombre del Perfil | Destino Inicial | Propósito y Naturaleza del Acceso |
| :---: | :--- | :---: | :--- |
| **1** | **Bodeguero** | `/home` | Operaciones físicas de almacén: recepción vehicular OCR, paletizado, búsqueda física y despacho en barrera digital. |
| **2** | **Vendedor (Mesón)** | `/ventas_main` | Búsqueda multicriterio en catálogo, radar de stock inter-sucursal, carrito temporal y checkout CRM. |
| **3** | **Caja** | `/caja` | Terminal desktop optimizada para teclado numérico: cobros de mesón, split-payments y emisión de QR de salida. |
| **4** | **Gerente** | `/gerencia` | **Dashboard Ejecutivo**: KPIs de facturación hoy/mes, desglose por métodos de pago, alertas operativas y auditoría general. |
| **5** | **Administrador Técnico** | `/home` | **Cuenta técnica para el equipo de desarrollo**: Aterriza en el panel base operativo y cuenta con permisos globales irrestrictos para configuración y administración de usuarios (`POST /api/auth/register`). |
| **6** | **Jefe de Ventas** | `/ventas_main` | Módulo de ventas con acceso adicional a la Bandeja de Tasación de Precios (`/bandeja_precios`). |
| **7** | **Vendedor Online** | `/ventas_main` | Ventas remotas con acceso directo a la coordinación de envíos a regiones (`/entregas-envios`). |

---

## 5. El Rol "Administrador" vs "Gerente" en Cresal

Es importante clarificar la distinción de negocio entre ambos roles:

* **En la estructura real de Cresal, la máxima autoridad de negocio es el Gerente (`id_rol = 4`)**.  
  El Gerente no opera grúas horquilla ni pistolas de escaneo; requiere una vista panorámica con métricas financieras consolidadas, tiempos de respuesta de sucursales y flujo de ingresos. Por esta razón, su pantalla de bienvenida obligatoria es `/gerencia`.
* **El rol Administrador (`id_rol = 5`) no es un cargo operativo de la empresa**, sino una **cuenta técnica reservada para los desarrolladores y soporte de infraestructura**.  
  Como los desarrolladores necesitamos probar la recepción, verificar el escaneo de piezas y auditar el sistema desde la raíz operativa, su aterrizaje se mantiene en `/home`, pero conservando autorización irrestricta para navegar a cualquier pantalla privada del sistema.

---

## 6. Guía Práctica: Cómo Añadir un Nuevo Rol en el Futuro

Gracias a este diseño desacoplado, agregar un nuevo perfil (por ejemplo: un rol *"Auditor Externo"* o *"Chofer de Reparto"*) no requiere modificar múltiples controladores ni pantallas. El procedimiento consta de **3 pasos claros**:

### Paso 1: Definir el ID y Nombre del Rol en Backend
En la base de datos (o script de seed), registrar el nuevo rol:
```sql
INSERT INTO "Rol" (id_rol, nombre_rol) VALUES (8, 'Chofer Reparto');
```

### Paso 2: Declarar la Ruta de Inicio en `app_routes.dart`
Abrir `frontend/lib/routes/app_routes.dart` y agregar una línea en `getHomeRouteForRole`:
```dart
static String getHomeRouteForRole(int? idRol) {
  if (idRol == 4) return gerencia;
  if (idRol == 3) return caja;
  if (idRol == 2 || idRol == 6 || idRol == 7) return ventasMain;
  if (idRol == 8) return entregasEnvios; // 👈 Nuevo rol redirigido a su panel
  return home;
}
```

### Paso 3: Configurar los Permisos RBAC en `app_routes.dart`
En la misma clase, definir las rutas a las que tiene acceso:
```dart
static const List<String> _choferRoutes = [
  entregasEnvios,
  buscador,
];

static bool isRouteAllowedForRole(int? idRol, String route) {
  // ...
  if (idRol == 8) return _choferRoutes.contains(route);
  // ...
}
```

### ¿Qué NO debes hacer?
* **NO agregues condicionales `if (idRol == X)` en `login_controller.dart`.**
* **NO agregues condicionales `if (idRol == X)` en `splash_screen.dart`.**
* **NO agregues condicionales `if (idRol == X)` en `home_screen.dart`.**

Todos estos componentes delegan automáticamente en `AppRoutes.getHomeRouteForRole(idRol)`. Al actualizar esa única función, todo el sistema responde de forma armónica e inmediata.
