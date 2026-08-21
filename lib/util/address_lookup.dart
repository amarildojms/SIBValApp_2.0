import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/address.dart';
import 'masked_input.dart';

/// Só dígitos, formata como #####-### enquanto digita — usado por
/// `AddressFields` (`lib/widgets/address_fields.dart`) no campo de CEP.
class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = digitsAfterEdit(oldValue, newValue);
    final trimmed = digits.length > 8 ? digits.substring(0, 8) : digits;
    final formatted = trimmed.length > 5 ? '${trimmed.substring(0, 5)}-${trimmed.substring(5)}' : trimmed;
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

/// Busca rua/bairro/cidade/estado a partir do CEP na API pública do ViaCEP
/// (https://viacep.com.br) — sem autenticação, gratuita. `null` se o CEP não
/// tiver 8 dígitos, não existir, ou a busca falhar (sem internet, timeout);
/// quem chama trata como "preenche o resto manualmente".
Future<Address?> lookupCep(String cep) async {
  final digits = cep.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 8) return null;
  try {
    final response = await http.get(Uri.parse('https://viacep.com.br/ws/$digits/json/')).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['erro'] == true) return null;
    return Address(
      cep: digits.length == 8 ? '${digits.substring(0, 5)}-${digits.substring(5)}' : digits,
      street: data['logradouro'] as String? ?? '',
      neighborhood: data['bairro'] as String? ?? '',
      city: data['localidade'] as String? ?? '',
      state: data['uf'] as String? ?? '',
    );
  } catch (_) {
    return null;
  }
}
