import 'package:flutter/services.dart';

import 'masked_input.dart';

/// Só dígitos, formata como ##.###.###/####-## enquanto digita — usado por
/// `ContributeSettingsPage`. Mesmo padrão de `cpf_phone_input.dart`.
class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = digitsAfterEdit(oldValue, newValue);
    final trimmed = digits.length > 14 ? digits.substring(0, 14) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      buffer.write(trimmed[i]);
      if (i == 1 || i == 4) buffer.write('.');
      if (i == 7) buffer.write('/');
      if (i == 11) buffer.write('-');
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}
