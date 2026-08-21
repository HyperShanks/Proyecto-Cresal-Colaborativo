// lib/features/paletizado/services/zpl_builder.dart
//
// Módulo de Ensamblaje ZPL II para Impresora Térmica Industrial Honeywell PC42E-T (203 DPI).
//
// Genera plantillas dinámicas en código ZPL puro, calibradas para etiquetas térmicas
// estándar de 4x2 pulgadas (812 x 406 dots), con soporte UTF-8 (^CI28) y diferenciación
// de diseño entre Motores y Cajas de Cambio.

import '../domain/models/etiqueta_data.dart';

/// Constructor de tramas ZPL (Zebra Programming Language) para activos automotrices.
class ZplBuilder {
  /// Limpia y sanitiza cadenas de texto para evitar inyecciones o colisiones con comandos ZPL.
  static String _sanitize(String? input, {String defaultValue = 'N/A'}) {
    if (input == null || input.trim().isEmpty) {
      return defaultValue;
    }
    // Reemplaza caracteres de control ZPL (^ y ~) por espacios o guiones
    return input.replaceAll('^', '').replaceAll('~', '').trim();
  }

  /// Construye la trama ZPL final para el activo [data].
  ///
  /// Detecta si el activo es un Motor (SKU inicia con "MOT") o Caja de Cambio
  /// para renderizar los campos técnicos específicos correspondientes.
  static String buildEtiquetaActivo(EtiquetaData data) {
    final bool isMotor = data.skuQrFisico.toUpperCase().startsWith('MOT');
    final String badgeTexto = isMotor ? 'MOTOR' : 'CAJAS DE CAMBIO';

    final sb = StringBuffer();

    // ── 1. Inicialización y Configuración de Etiqueta ──
    sb.writeln('^XA'); // Inicio del formato ZPL
    sb.writeln('^CI28'); // Codificación UTF-8 para caracteres en español (tildes, ñ)
    sb.writeln('^PW812'); // Ancho de impresión: 812 dots (4 pulgadas @ 203 DPI)
    sb.writeln('^LL406'); // Alto de etiqueta: 406 dots (2 pulgadas @ 203 DPI)
    sb.writeln('^LH0,0'); // Origen en la esquina superior izquierda

    // ── 2. Marco Exterior y Líneas de Estructura ──
    sb.writeln('^FO20,15^GB772,376,3^FS'); // Borde exterior rectangular
    sb.writeln('^FO20,80^GB772,0,2^FS'); // Línea separadora de Header
    sb.writeln('^FO20,320^GB772,0,2^FS'); // Línea separadora de Footer
    sb.writeln('^FO340,80^GB0,240,2^FS'); // Línea vertical separadora (QR / Datos)

    // ── 3. Header: Logo CRESAL y Badge del Tipo de Activo ──
    sb.writeln('^FO40,28^A0N,28,28^FDCRESAL^FS');
    sb.writeln('^FO40,58^A0N,16,16^FDDesarme . Vehiculos . Repuestos^FS');

    // Badge con fondo negro y texto en negativo (blanco)
    sb.writeln('^FO530,25^GB240,42,42^FS');
    sb.writeln('^FO530,36^A0N,22,22^FR^FB240,1,0,C^FD$badgeTexto^FS');

    // ── 4. Bloque Izquierdo: Código QR, SKU y Ubicación ──
    // Código QR (Modelo 2, Factor de magnificación 4, Corrección de error M)
    final skuLimpio = _sanitize(data.skuQrFisico);
    sb.writeln('^FO65,95^BQN,2,4^FDQA,$skuLimpio^FS');

    // Texto SKU debajo del QR
    sb.writeln('^FO35,222^A0N,26,26^FB295,1,0,C^FD$skuLimpio^FS');

    // Pastilla negra de Ubicación
    sb.writeln('^FO35,260^GB295,44,44^FS');
    final ubicacion = 'UBICACION: G${data.galpon} - P${data.pasillo} - Pa${data.pallet}';
    sb.writeln('^FO35,274^A0N,18,18^FR^FB295,1,0,C^FD$ubicacion^FS');

    // ── 5. Bloque Derecho: Datos Técnicos Dinámicos ──
    final marca = _sanitize(data.marca);
    final modelo = _sanitize(data.modelo);
    final anio = data.anio > 0 ? data.anio.toString() : 'N/A';
    final transmision = _sanitize(data.transmision);

    if (isMotor) {
      // ── Campos Específicos para Motores ──
      final cilindrada = _sanitize(data.cilindrada);
      final combustible = _sanitize(data.combustible);

      sb.writeln('^FO360,95^A0N,20,20^FDMARCA/MOD: $marca $modelo^FS');
      sb.writeln('^FO360,135^A0N,20,20^FDANIO: $anio^FS');
      sb.writeln('^FO360,175^A0N,20,20^FDCILINDRADA: $cilindrada^FS');
      sb.writeln('^FO360,215^A0N,20,20^FDCOMBUSTIBLE: $combustible^FS');
      sb.writeln('^FO360,255^A0N,20,20^FDTRANSMISION: $transmision^FS');
    } else {
      // ── Campos Específicos para Cajas de Cambio ──
      sb.writeln('^FO360,105^A0N,22,22^FDMARCA: $marca^FS');
      sb.writeln('^FO360,150^A0N,22,22^FDMODELO: $modelo^FS');
      sb.writeln('^FO360,195^A0N,22,22^FDTIPO CAJA: $transmision^FS');
      sb.writeln('^FO360,240^A0N,22,22^FDANIO: $anio^FS');
    }

    // ── 6. Footer: Número de Motor y Número de Ingreso (Folio) ──
    final folio = _sanitize(data.numeroIngreso);

    if (isMotor) {
      final nroMotor = _sanitize(data.numeroMotor);
      sb.writeln('^FO40,345^A0N,22,22^FDNRO MOTOR: $nroMotor^FS');
      sb.writeln('^FO500,340^A0N,30,30^FDFOLIO: $folio^FS');
    } else {
      sb.writeln('^FO40,340^A0N,30,30^FDFOLIO INGRESO: $folio^FS');
    }

    // ── 7. Cierre e Impresión ──
    sb.writeln('^XZ'); // Fin de la etiqueta / Disparo al buffer de impresión

    return sb.toString();
  }
}
