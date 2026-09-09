// frontend/lib/core/utils/currency_formatter.dart

/// Utilidad estándar para formateo de moneda chilena (CLP).
class CurrencyFormatter {
  /// Formatea un valor numérico entero o decimal a Pesos Chilenos (CLP).
  /// Ejemplo: 1250000 -> "$ 1.250.000"
  static String formatCLP(num? valor) {
    if (valor == null) return '\$ 0';
    final intVal = valor.toInt();
    final isNegative = intVal < 0;
    final s = intVal.abs().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
    }

    final signo = isNegative ? '-' : '';
    return '$signo\$ $buffer';
  }
}
