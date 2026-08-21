import 'dart:convert';

import 'package:http/http.dart' as http;

/// Busca a razão social a partir do CNPJ na BrasilAPI
/// (https://brasilapi.com.br) — pública, gratuita, sem autenticação. `null`
/// se o CNPJ não tiver 14 dígitos, não existir, ou a busca falhar (sem
/// internet, timeout); quem chama trata como "preenche manualmente".
Future<String?> lookupCnpj(String cnpj) async {
  final digits = cnpj.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 14) return null;
  try {
    final response =
        await http.get(Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$digits')).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['razao_social'] as String?;
  } catch (_) {
    return null;
  }
}
