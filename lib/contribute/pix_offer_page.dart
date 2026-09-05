import 'package:brcode/brcode.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../util/bank_apps.dart';
import '../widgets/sibval_app_bar.dart';

/// Gera um código Pix "Copia e Cola" (BR Code / EMV) com valor e mensagem
/// pré-preenchidos a partir de uma `PixEntry` da Contribua (01/09/2026, sem
/// equivalente no nativo, pedido do usuário — inicialmente só pra "Oferta
/// para Missões", generalizado no mesmo dia pra qualquer chave PIX
/// cadastrada com uma [description]). Análise técnica feita antes de
/// implementar: isto NÃO é um Pix "Cobrança" via API bancária (que exigiria
/// integração com um PSP, credenciais e webhook de conciliação) — é um Pix
/// estático com valor, montado 100% no cliente a partir da própria chave PIX
/// já cadastrada, igual a qualquer "gerador de QR Code Pix". Por isso o app
/// não tem como saber se a oferta foi de fato paga, só gera o código pra
/// colar no app do banco. Usa o pacote `brcode` (TLV + CRC16 conforme o
/// Manual de Padrões para Iniciação do Pix do Bacen) e `qr_flutter` (desenho
/// do QR).
class PixOfferPage extends StatefulWidget {
  const PixOfferPage({
    super.key,
    required this.description,
    required this.churchName,
    required this.city,
    required this.pixKey,
    this.onGenerated,
  });

  /// Texto exibido no título da tela e usado como mensagem de referência do
  /// código Pix gerado — vem de `PixEntry.displayTitle` (campo "Descrição"
  /// configurado pelo admin em `ContributeSettingsPage`).
  final String description;
  final String churchName;
  final String city;
  final String pixKey;

  /// Chamado com o valor informado assim que o código é gerado com sucesso
  /// (04/09/2026, pedido do usuário) — `null` em todo call site que não
  /// precisa reagir a isso (default, sem mudança de comportamento). Usado
  /// por `BasketCampaignPage` pra registrar a "intenção de doação" Pix
  /// (`BasketDonation.type == pix`) visível à Diaconia/Tesouraria assim que
  /// o doador gera o código — não espera nenhuma confirmação de pagamento.
  final void Function(double amount)? onGenerated;

  @override
  State<PixOfferPage> createState() => _PixOfferPageState();
}

class _PixOfferPageState extends State<PixOfferPage> {
  final _amountController = TextEditingController(text: 'R\$ 0,00');
  int _cents = 0;
  String? _generatedCode;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => _cents / 100;

  void _onAmountChanged(String formatted) {
    final digits = formatted.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _cents = int.tryParse(digits) ?? 0;
      _generatedCode = null;
      _error = null;
    });
  }

  void _generate() {
    FocusScope.of(context).unfocus();
    if (_cents <= 0) {
      setState(() {
        _error = 'Informe um valor maior que zero.';
        _generatedCode = null;
      });
      return;
    }
    final city = widget.city.trim();
    final name = widget.churchName.trim();
    if (city.isEmpty || name.isEmpty) {
      setState(() {
        _error = 'A igreja ainda não configurou o nome/cidade para gerar o código Pix. Fale com a Secretaria.';
        _generatedCode = null;
      });
      return;
    }
    try {
      final code = BRCode(
        amount: _amount,
        pixKey: widget.pixKey,
        merchantName: name.length > 25 ? name.substring(0, 25) : name,
        merchantCity: city.length > 15 ? city.substring(0, 15) : city,
        txId: _txIdFor(widget.description),
      ).generate();
      setState(() {
        _generatedCode = code;
        _error = null;
      });
      widget.onGenerated?.call(_amount);
    } catch (e) {
      setState(() {
        _error = 'Não foi possível gerar o código: $e';
        _generatedCode = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _generatedCode;
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenTitle(widget.description),
              const SizedBox(height: 4),
              Text(
                'Informe o valor e gere o código Pix na hora.',
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, _CentsInputFormatter()],
                onChanged: _onAmountChanged,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: _generate,
                child: const Text('Gerar código Pix'),
              ),
              if (code != null) ...[
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: QrImageView(data: code, size: 220),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.description} — R\$ ${_amount.toStringAsFixed(2).replaceAll('.', ',')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => copyAndOfferBankApp(context, code, copiedMessage: 'Código Pix copiado.'),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Copiar e abrir no banco'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código Pix copiado.')));
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copiar código Pix'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Deriva o campo de referência do Pix (tag 62-05, até 25 caracteres
/// alfanuméricos) a partir da descrição livre cadastrada pelo admin — sem
/// espaço/acento/pontuação, que costumam confundir o parser de alguns bancos.
String _txIdFor(String description) {
  final upper = removeDiacritics(description).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (upper.isEmpty) return '***';
  return upper.length > 25 ? upper.substring(0, 25) : upper;
}

/// Máscara de valor monetário — cada dígito digitado empurra os centavos,
/// mesmo padrão usado em apps de pagamento (ex.: "1" -> "R$ 0,01", "150" ->
/// "R$ 1,50"). Sem pacote novo: é só formatação de texto.
class _CentsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.isEmpty) digits = '0';
    final cents = int.parse(digits);
    final reais = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    final formatted = 'R\$ $reais';
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
