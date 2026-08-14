// lib/features/paletizado/domain/exceptions/printer_exceptions.dart
//
// Excepciones de dominio para el subsistema de impresión industrial (Honeywell PC42E-T).

/// Clase base para todas las excepciones del dominio de impresión térmica.
abstract class PrinterException implements Exception {
  final String mensaje;
  final dynamic originalError;

  const PrinterException(this.mensaje, [this.originalError]);

  @override
  String toString() =>
      '$runtimeType: $mensaje${originalError != null ? " (Causa: $originalError)" : ""}';
}

/// Lanzada cuando el dispositivo móvil (Sunmi L3) no cuenta con conexión a la red local (Wi-Fi).
class PrinterNetworkException extends PrinterException {
  const PrinterNetworkException([
    super.mensaje = 'El dispositivo no cuenta con conexión a la red Wi-Fi local.',
    super.originalError,
  ]);
}

/// Lanzada cuando la impresora no responde dentro del tiempo límite (timeout 3s),
/// indicando que está apagada, fuera de red o con una IP estática inalcanzable.
class PrinterTimeoutException extends PrinterException {
  final String ip;
  final int port;

  const PrinterTimeoutException(
    this.ip,
    this.port, [
    super.mensaje = 'Tiempo de espera agotado al conectar con la impresora térmica.',
    super.originalError,
  ]);

  @override
  String toString() =>
      '$runtimeType: $mensaje [$ip:$port]${originalError != null ? " (Causa: $originalError)" : ""}';
}

/// Lanzada cuando el chequeo de estado físico (~HS) indica falta de papel o cabezal/tapa abierta.
class PrinterPaperOutException extends PrinterException {
  const PrinterPaperOutException([
    super.mensaje = 'La impresora no tiene papel térmico o la tapa/cabezal se encuentra abierta.',
    super.originalError,
  ]);
}

/// Lanzada ante cualquier error general de socket TCP o fallo en la transmisión de datos.
class PrinterCommunicationException extends PrinterException {
  const PrinterCommunicationException(
    super.mensaje, [
    super.originalError,
  ]);
}
