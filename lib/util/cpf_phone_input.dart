import 'package:flutter/services.dart';

import 'masked_input.dart';

/// Só dígitos, formata como ###.###.###-## enquanto digita — usado tanto no
/// cadastro por e-mail (`register_page.dart`) quanto no de completar perfil
/// via Google (`complete_google_profile_page.dart`), daí ser compartilhado
/// aqui em vez de ficar privado a um dos dois arquivos.
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = digitsAfterEdit(oldValue, newValue);
    final trimmed = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      buffer.write(trimmed[i]);
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('-');
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

/// Só dígitos, formata como (##) #####-#### (ou #### para fixo) enquanto digita.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = digitsAfterEdit(oldValue, newValue);
    final trimmed = digits.length > 11 ? digits.substring(0, 11) : digits;
    final hyphenIndex = trimmed.length <= 10 ? 5 : 6;
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i == 0) buffer.write('(');
      buffer.write(trimmed[i]);
      if (i == 1) buffer.write(') ');
      if (i == hyphenIndex) buffer.write('-');
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

/// Validação padrão de CPF (dígitos verificadores), sem dependência externa —
/// mesmo algoritmo usado pela Receita Federal.
abstract final class CpfValidator {
  static bool isValid(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;

    final firstNine = digits.substring(0, 9);
    final firstTen = firstNine + _calcDigit(firstNine).toString();
    final eleventh = _calcDigit(firstTen).toString();
    return digits == firstTen + eleventh;
  }

  static int _calcDigit(String base) {
    var sum = 0;
    var weight = base.length + 1;
    for (final char in base.split('')) {
      sum += int.parse(char) * weight;
      weight--;
    }
    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }
}
