import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Catálogo de apps de banco/pagamento comuns no Brasil, usado pela Contribua
/// (01/09/2026, pedido do usuário: "copiar a chave PIX e já encaminhar para
/// o app do banco") — sem equivalente no nativo. Não existe deep link
/// universal de Pix no Android (cada banco usa um esquema próprio,
/// não-documentado, que não aceita a chave como parâmetro por segurança), então
/// a abordagem escolhida foi: copiar a chave pro clipboard e oferecer uma
/// lista dos apps de banco já instalados no aparelho, abrindo o escolhido na
/// tela inicial dele (não numa tela de Pix específica) para o usuário colar.
///
/// Nomes de pacote (`packageName`) conferidos via busca na Google Play Store
/// em 01/09/2026 e, pra Itaú/Bradesco/Banco do Brasil/CAIXA/Mercado
/// Pago/Sicoob, confirmados de verdade via `adb shell pm list packages` no
/// celular de teste do usuário depois de um primeiro bug (ver canal nativo em
/// `MainActivity.kt`) — um nome desatualizado só faz aquele item nunca
/// aparecer como instalado, sem quebrar o restante da lista.
///
/// A checagem/abertura passa por um `MethodChannel` nativo
/// (`sibval.app/bank_apps`, implementado em `MainActivity.kt`) em vez do
/// pacote `android_intent_plus` — este usava
/// `PackageManager.resolveActivity(intent, MATCH_DEFAULT_ONLY)`, que exige a
/// categoria `DEFAULT` no launcher do app-alvo além de `LAUNCHER`; a maioria
/// dos bancos só declara `LAUNCHER` (padrão do Android), então ficavam
/// invisíveis mesmo instalados — bug real encontrado no primeiro teste do
/// usuário (só Santander/C6 Bank/PicPay apareciam). `getLaunchIntentForPackage`
/// (usado no canal nativo) não tem essa exigência.
const MethodChannel _channel = MethodChannel('sibval.app/bank_apps');

class BankApp {
  const BankApp({required this.name, required this.packageName});

  final String name;
  final String packageName;
}

const List<BankApp> bankApps = [
  BankApp(name: 'Nubank', packageName: 'com.nu.production'),
  BankApp(name: 'Banco Itaú', packageName: 'com.itau'),
  BankApp(name: 'Bradesco', packageName: 'com.bradesco'),
  BankApp(name: 'Banco do Brasil', packageName: 'br.com.bb.android'),
  BankApp(name: 'CAIXA', packageName: 'br.com.gabba.Caixa'),
  BankApp(name: 'Santander', packageName: 'com.santander.app'),
  BankApp(name: 'Banco Inter', packageName: 'br.com.intermedium'),
  BankApp(name: 'C6 Bank', packageName: 'com.c6bank.app'),
  BankApp(name: 'PicPay', packageName: 'com.picpay'),
  BankApp(name: 'Mercado Pago', packageName: 'com.mercadopago.wallet'),
  BankApp(name: 'Sicoob', packageName: 'br.com.sicoobnet'),
  BankApp(name: 'Sicredi', packageName: 'br.com.sicredi.app'),
];

/// `true` só no Android — nas outras plataformas não há como detectar/abrir
/// um app por nome de pacote (a busca de bancos instalados fica restrita a
/// esta plataforma).
bool get canPickBankApp => Platform.isAndroid;

/// Verifica, um a um, quais [bankApps] estão instalados no aparelho —
/// requer os `<package>` correspondentes declarados em `<queries>` no
/// `AndroidManifest.xml` (regra de visibilidade de pacotes do Android 11+).
Future<List<BankApp>> installedBankApps() async {
  if (!Platform.isAndroid) return const [];
  final results = await Future.wait(bankApps.map((bank) async {
    final installed = await _channel.invokeMethod<bool>('isInstalled', {'packageName': bank.packageName});
    return installed == true ? bank : null;
  }));
  return results.whereType<BankApp>().toList();
}

/// Abre o app do banco na tela inicial dele (não há como pular direto pra
/// tela de Pix — ver doc comment da classe).
Future<void> launchBankApp(BankApp bank) async {
  if (!Platform.isAndroid) return;
  await _channel.invokeMethod<bool>('launch', {'packageName': bank.packageName});
}

/// Copia [text] pro clipboard e, no Android, oferece o seletor de apps de
/// banco instalados pra abrir e colar — usado tanto pela chave PIX simples
/// (`_PixCard` em `contribute_page.dart`) quanto pelo código Pix com valor
/// gerado em `MissionOfferPage` (01/09/2026).
Future<void> copyAndOfferBankApp(BuildContext context, String text, {String copiedMessage = 'Copiado.'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  if (!canPickBankApp) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$copiedMessage Abra o app do seu banco e cole no Pix.')),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(copiedMessage), duration: const Duration(seconds: 2)),
  );
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const BankAppPickerSheet(),
  );
}

/// Bottom sheet com os apps de banco/pagamento já instalados no aparelho. A
/// chave/código já foi copiado antes de abrir este sheet — escolher um app
/// aqui só o leva pra tela inicial dele (não há como pular direto pra tela de
/// Pix), o usuário cola lá.
class BankAppPickerSheet extends StatefulWidget {
  const BankAppPickerSheet({super.key});

  @override
  State<BankAppPickerSheet> createState() => _BankAppPickerSheetState();
}

class _BankAppPickerSheetState extends State<BankAppPickerSheet> {
  late final Future<List<BankApp>> _future = installedBankApps();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Abrir no app do banco',
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              'Já foi copiado — escolha o app e cole no Pix.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<BankApp>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final apps = snapshot.data ?? const [];
                if (apps.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhum app de banco compatível foi encontrado neste celular. '
                      'Já está copiado — abra o app do seu banco manualmente.',
                      style: TextStyle(color: context.textSecondary),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final bank in apps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.account_balance_outlined),
                        title: Text(bank.name, style: TextStyle(color: context.textPrimary)),
                        onTap: () {
                          Navigator.of(context).pop();
                          launchBankApp(bank);
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
