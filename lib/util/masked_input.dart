import 'package:flutter/services.dart';

/// Dígitos de [newValue] após um possível apagar — usado por todo
/// `TextInputFormatter` mascarado do app (CPF, telefone, CNPJ, CEP, data).
///
/// Sem isso, apagar o caractere de formatação (`.`, `/`, `-`) sozinho não
/// muda a contagem de dígitos, então a reformatação recoloca exatamente o
/// mesmo separador que acabou de ser apagado — o campo trava, dando a
/// impressão de que o backspace não funciona bem em cima de um separador
/// (22/08/2026, bug relatado pelo usuário no CNPJ, mas idêntico nos outros
/// campos mascarados). Quando isso acontece, também descarta o último
/// dígito, como se o backspace tivesse "passado direto" pelo separador.
String digitsAfterEdit(TextEditingValue oldValue, TextEditingValue newValue) {
  var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
  final isDeletion = newValue.text.length < oldValue.text.length;
  if (isDeletion) {
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == oldDigits.length && digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }
  }
  return digits;
}
