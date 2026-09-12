// lib/features/paletizado/services/zpl_builder.dart
//
// Módulo de Ensamblaje ZPL II para Impresora Térmica Industrial Honeywell PC42E-T (203 DPI).
//
// Formato físico: 100 mm de ancho x 70 mm de alto (800 x 560 dots @ 8 dpmm).
// Soporte UTF-8 (^CI28), QR con factor de magnificación 8 perfectamente centrado
// matemática y visualmente (86 dots a cada margen), rotulación "NRO INGRESO" alineada a
// la izquierda y conjunto unificado de 6 características técnicas para Motores y Cajas.

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
  /// Dimensiones: 100 mm de ancho x 70 mm de alto (800 x 560 dots a 203 DPI).
  /// Mantiene las mismas 6 características técnicas tanto para Motor como Caja de Cambio,
  /// diferenciándolos en el Badge superior y en el Número de Motor en el Footer.
  static String buildEtiquetaActivo(EtiquetaData data) {
    final bool isMotor = data.skuQrFisico.toUpperCase().startsWith('MOT');
    final String badgeTexto = isMotor ? 'MOTOR' : 'CAJAS DE CAMBIO';

    final sb = StringBuffer();

    // ── 1. Inicialización y Configuración de Etiqueta (100x70 mm @ 203 DPI) ──
    sb.writeln('^XA'); // Inicio del formato ZPL
    sb.writeln('^CI28'); // Codificación UTF-8 para caracteres en español (tildes, ñ)
    sb.writeln('^PW800'); // Ancho de impresión: 800 dots (100 mm @ 8 dpmm / 203 DPI)
    sb.writeln('^LL560'); // Alto de etiqueta: 560 dots (70 mm @ 8 dpmm / 203 DPI)
    sb.writeln('^LH0,0'); // Origen en la esquina superior izquierda

    // ── 2. Marco Exterior y Líneas de Estructura ──
    sb.writeln('^FO20,15^GB760,530,3^FS'); // Borde exterior rectangular
    sb.writeln('^FO20,95^GB760,0,3^FS'); // Línea separadora de Header
    sb.writeln('^FO20,455^GB760,0,3^FS'); // Línea separadora de Footer
    sb.writeln('^FO360,95^GB0,360,3^FS'); // Línea vertical separadora (QR / Datos)

    // ── 3. Header: Logo CRESAL y Badge del Tipo de Activo ──
    sb.writeln('^FO40,25^A0N,32,32^FDCRESAL^FS');
    sb.writeln('^FO40,62^A0N,20,20^FDDesarme . Vehiculos . Repuestos^FS');

    // Badge con fondo negro y texto en negativo (blanco)
    sb.writeln('^FO500,25^GB260,55,55^FS');
    sb.writeln('^FO500,40^A0N,28,28^FR^FB260,1,0,C^FD$badgeTexto^FS');

    // ── 4. Bloque Izquierdo: Código QR Factor 8 ──
    final skuLimpio = _sanitize(data.skuQrFisico);
    sb.writeln('^FO104,104^BQN,2,8^FDQA,$skuLimpio^FS');

    // Texto SKU debajo del QR (centrado)
    sb.writeln('^FO35,342^A0N,26,26^FB310,1,0,C^FD$skuLimpio^FS');

    // Pastilla negra de Ubicación (centrada)
    sb.writeln('^FO35,384^GB310,50,50^FS');
    final ubicacion = 'UBICACION: G${data.galpon} - P${data.pasillo} - Pa${data.pallet}';
    sb.writeln('^FO35,398^A0N,22,22^FR^FB310,1,0,C^FD$ubicacion^FS');

    // ── 5. Bloque Derecho: 7 Características Técnicas Compartidas ──
    final marca = _sanitize(data.marca);
    final modelo = _sanitize(data.modelo);
    final anio = data.anio > 0 ? data.anio.toString() : 'N/A';
    final cilindrada = _sanitize(data.cilindrada);
    final combustible = _sanitize(data.combustible);
    final transmision = _sanitize(data.transmision);
    final traccion = _sanitize(data.traccion);

    // Ambas tarjetas manejan exactamente las mismas 7 filas técnicas uniformes.
    // Todas las características usan tamaño tipográfico homogéneo ^A0N,25,25.
    sb.writeln('^FO385,118^A0N,25,25^FDMARCA: $marca^FS');
    sb.writeln('^FO385,164^A0N,25,25^FDMODELO: $modelo^FS');
    sb.writeln('^FO385,210^A0N,25,25^FDANIO: $anio^FS');
    sb.writeln('^FO385,256^A0N,25,25^FDCILINDRADA: $cilindrada^FS');
    sb.writeln('^FO385,302^A0N,25,25^FDCOMBUSTIBLE: $combustible^FS');
    sb.writeln('^FO385,348^A0N,25,25^FDTRANSMISION: $transmision^FS');
    sb.writeln('^FO385,394^A0N,25,25^FDTRACCION: $traccion^FS');

    // ── 6. Footer: NRO MOTOR y NRO INGRESO iniciando a la izquierda (Left) ──
    final nroIngreso = _sanitize(data.numeroIngreso);

    if (isMotor) {
      final nroMotor = _sanitize(data.numeroMotor);
      sb.writeln('^FO35,485^A0N,24,24^FDNRO MOTOR: $nroMotor^FS');
      sb.writeln('^FO430,485^A0N,24,24^FDNRO INGRESO: $nroIngreso^FS');
    } else {
      sb.writeln('^FO40,485^A0N,28,28^FDNRO INGRESO: $nroIngreso^FS');
    }

    // ── 7. Cierre e Impresión ──
    sb.writeln('^XZ'); // Fin de la etiqueta / Disparo al buffer de impresión

    return sb.toString();
  }
}
