import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contribution_repository.dart';
import '../data/user_repository.dart';
import '../models/contribution_info.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'contribute_settings_page.dart';

/// Aba "Contribua" (21/08/2026, sem equivalente no nativo): versículo fixo,
/// nome da igreja + CNPJ, uma ou mais chaves PIX (com QR Code) e uma ou mais
/// contas bancárias, todos cadastrados pelo admin em `ContributeSettingsPage`
/// (engrenagem na barra). Visível pra visitante sem login também, a pedido
/// do usuário — exceção de leitura pública só pra este documento
/// (`settings/contribution`), ver `firestore.rules`/`storage.rules` do repo
/// nativo.
class ContributePage extends ConsumerWidget {
  const ContributePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(contributionInfoProvider);
    final isAdmin = ref.watch(currentUserProfileProvider).asData?.value?.isAdmin ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Contribua'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (isAdmin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ContributeSettingsPage(initial: infoAsync.asData?.value ?? ContributionInfo.empty),
                          ),
                        ),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('Configurar'),
                      ),
                    ),
                  const SizedBox(height: 4),
                  const _VerseCard(),
                  const SizedBox(height: 16),
                  infoAsync.when(
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    )),
                    error: (error, _) => Center(
                      child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
                    ),
                    data: (info) => _ContributionContent(info: info, isAdmin: isAdmin),
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

/// Espelha o versículo pedido pelo usuário (21/08/2026) — sempre visível,
/// antes de qualquer dado da igreja, mesmo enquanto carrega ou se nada foi
/// cadastrado ainda.
class _VerseCard extends StatelessWidget {
  const _VerseCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SibValColors.navyBlueLight, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '"Cada um contribua conforme determinou no coração, não com pesar nem '
            'por obrigação, pois Deus ama a quem dá com alegria."',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          const Text(
            '2 Coríntios 9:7',
            textAlign: TextAlign.center,
            style: TextStyle(color: SibValColors.goldAccent, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ContributionContent extends StatelessWidget {
  const _ContributionContent({required this.info, required this.isAdmin});

  final ContributionInfo info;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    if (info.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          isAdmin
              ? 'Nenhuma informação cadastrada ainda. Toque na engrenagem para configurar.'
              : 'Informações de contribuição em breve.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textSecondary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.churchName.isNotEmpty)
          Text(
            info.churchName,
            style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        if (info.cnpj.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('CNPJ: ${info.cnpj}', style: TextStyle(color: context.textSecondary, fontSize: 13)),
        ],
        for (final pix in info.pixEntries) ...[
          const SizedBox(height: 16),
          _PixCard(pix: pix),
        ],
        for (final bank in info.bankAccounts) ...[
          const SizedBox(height: 12),
          _BankCard(bank: bank),
        ],
      ],
    );
  }
}

class _PixCard extends StatelessWidget {
  const _PixCard({required this.pix});

  final PixEntry pix;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: pix.label.isNotEmpty ? 'PIX — ${pix.label}' : 'PIX',
      icon: Icons.qr_code_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pix.key.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _copyToClipboard(context, pix.key, 'Chave PIX copiada.'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chave', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                          Text(pix.key, style: TextStyle(color: context.textPrimary, fontSize: 15)),
                        ],
                      ),
                    ),
                    Icon(Icons.copy_outlined, size: 18, color: context.textSecondary),
                  ],
                ),
              ),
            ),
          if (pix.qrCodeUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(pix.qrCodeUrl, fit: BoxFit.contain),
            ),
          ],
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.bank});

  final BankAccountEntry bank;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: bank.label.isNotEmpty ? 'Conta Bancária — ${bank.label}' : 'Conta Bancária',
      icon: Icons.account_balance_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bank.bankName.isNotEmpty) _InfoRow(label: 'Banco', value: bank.bankName),
          if (bank.agency.isNotEmpty) _InfoRow(label: 'Agência', value: bank.agency),
          if (bank.account.isNotEmpty) _InfoRow(label: 'Conta', value: bank.account),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: context.textPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: context.textSecondary, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: TextStyle(color: context.textPrimary, fontSize: 15))),
        ],
      ),
    );
  }
}
