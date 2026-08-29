import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/privacy_policy_page.dart';
import '../auth/terms_of_use_page.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (29/08/2026, pedido do
/// usuário). Tela "Sobre", aberta pelo rodapé da aba Mais (`main_shell.dart`,
/// `_MaisPage`) — abaixo do bloco Entrar/Sair, visível a qualquer usuário,
/// logado ou em acesso convidado (não é uma configuração admin, é informação
/// do próprio app). Mostra ícone/nome/versão (`package_info_plus`, mesmo
/// pacote já usado em `update_gate.dart`) e atalhos pras duas páginas legais
/// que já existiam soltas dentro do fluxo de cadastro
/// (`PrivacyPolicyPage`/`TermsOfUsePage`, `lib/auth/`).
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const ScreenTitle('Sobre'),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/icon_sibval.png',
                      width: 88,
                      height: 88,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SIBVal Connect',
                    style: TextStyle(
                      color: SibValColors.goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      return Text(
                        info == null
                            ? ' '
                            : 'Versão ${info.version} (build ${info.buildNumber})',
                        style: TextStyle(color: context.textSecondary, fontSize: 13),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'O SIBVal Connect é o aplicativo oficial da Segunda Igreja '
              'Batista em Valparaíso — eventos, devocionais, Bíblia, '
              'hinários, avisos e comunicação da igreja em um só lugar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Política de Privacidade'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Termos de Uso'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
