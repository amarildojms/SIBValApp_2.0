import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/basket_donation_repository.dart';
import '../data/contribution_repository.dart';
import '../data/user_repository.dart';
import '../models/basket_donation.dart';
import '../models/contribution_info.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_campaign_page.dart';
import 'contribute_settings_page.dart';
import 'pix_offer_page.dart';

/// Aba "Contribua" (21/08/2026, sem equivalente no nativo): versículo fixo,
/// nome da igreja + CNPJ, um card "gerar oferta" por chave PIX cadastrada e
/// uma ou mais contas bancárias, todos configurados pelo admin em
/// `ContributeSettingsPage` (engrenagem na barra). Visível pra visitante sem
/// login também, a pedido do usuário — exceção de leitura pública só pra este
/// documento (`settings/contribution`), ver `firestore.rules`/`storage.rules`
/// do repo nativo.
///
/// **Reforma de 01/09/2026** (pedido do usuário): a página deixou de exibir
/// a chave PIX crua (texto + QR Code fixo) — cada [PixEntry] agora vira um
/// card ([_PixOfferCard]) que abre [PixOfferPage], onde o usuário informa um
/// valor e o app gera um código Pix (BR Code) com esse valor e a mensagem de
/// [PixEntry.description]. Deixa de existir um único caso especial pra
/// "Missões": qualquer chave com [PixEntry.displayTitle] preenchido vira um
/// card configurável (ex.: "Oferta para Missões", "Dízimo", "Obras").
class ContributePage extends ConsumerWidget {
  const ContributePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(contributionInfoProvider);
    final isAdmin =
        ref.watch(currentUserProfileProvider).asData?.value?.isAdmin ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Contribua',
                      style: TextStyle(
                        color: SibValColors.goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  if (isAdmin)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ContributeSettingsPage(
                            initial:
                                infoAsync.asData?.value ??
                                ContributionInfo.empty,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Configurar'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const _VerseCard(),
                  const SizedBox(height: 16),
                  infoAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => Center(
                      child: Text(
                        'Falha ao carregar: $error',
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ),
                    data: (info) =>
                        _ContributionContent(info: info, isAdmin: isAdmin),
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
      decoration: BoxDecoration(
        color: SibValColors.navyBlueLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '"Cada um contribua conforme determinou no coração, não com pesar nem '
            'por obrigação, pois Deus ama a quem dá com alegria."',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '2 Coríntios 9:7',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SibValColors.goldAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Copia o CNPJ como chave Pix — só os dígitos, sem pontos/barra/traço
/// (01/09/2026, pedido do usuário: "ao tocar o cnpj deve ser copiado como
/// chave pix"). Muitas chaves Pix do tipo CNPJ são cadastradas nos bancos só
/// com os números, então essa é a forma mais provável de colar direto num
/// campo "chave Pix" sem precisar editar.
void _copyCnpjAsPixKey(BuildContext context, String cnpj) {
  final digitsOnly = cnpj.replaceAll(RegExp(r'\D'), '');
  Clipboard.setData(ClipboardData(text: digitsOnly));
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Chave Pix (CNPJ) copiada.')));
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (info.cnpj.isNotEmpty) ...[
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _copyCnpjAsPixKey(context, info.cnpj),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CNPJ: ${info.cnpj}',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.copy_outlined,
                    size: 15,
                    color: context.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
        for (final pix in info.pixEntries)
          if (pix.key.isNotEmpty && pix.displayTitle.isNotEmpty) ...[
            const SizedBox(height: 16),
            _PixOfferCard(info: info, pix: pix),
          ],
        const SizedBox(height: 16),
        const _BasketCampaignCard(),
        for (final bank in info.bankAccounts) ...[
          const SizedBox(height: 12),
          _BankCard(bank: bank),
        ],
      ],
    );
  }
}

/// Card de "gerar oferta" a partir de uma [PixEntry] (01/09/2026) — cada
/// chave PIX cadastrada com [PixEntry.displayTitle] preenchido vira um destes,
/// abrindo [PixOfferPage] pra informar o valor e gerar o código Pix.
class _PixOfferCard extends StatelessWidget {
  const _PixOfferCard({required this.info, required this.pix});

  final ContributionInfo info;
  final PixEntry pix;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: SibValColors.navyBlueLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PixOfferPage(
              description: pix.displayTitle,
              churchName: info.churchName,
              city: info.city,
              pixKey: pix.key,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.volunteer_activism_outlined,
                color: SibValColors.goldAccent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pix.displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Informe o valor e gere o Pix na hora',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card "Doe para Cestas Básicas" (04/09/2026) — abre [BasketCampaignPage].
/// Ao contrário dos `_PixOfferCard` (um por [PixEntry] cadastrada), este
/// tile é fixo — sempre aparece na Contribua, independente de configuração
/// prévia (a própria `BasketCampaignPage` trata o caso "nada configurado
/// ainda").
/// Destacado dos demais `_PixOfferCard` (04/09/2026, pedido do usuário) —
/// borda dourada + fundo com leve tingimento dourado (`Color.alphaBlend`
/// sobre `navyBlueLight`, mesmo mecanismo de `_momentBox` da Ordem de Culto)
/// e o ícone em círculo dourado com cor invertida (navy sobre dourado, em
/// vez de dourado sobre navy) — chama mais atenção sem sair da paleta da
/// marca.
///
/// Ganhou o resumo do "Acompanhamento da campanha" (04/09/2026, pedido do
/// usuário — já existia dentro de `BasketCampaignPage`, aqui é a mesma
/// informação, mais compacta, pra dar pra ver sem precisar abrir a tela)
/// direto no card fixo da Contribua, quando a meta do mês está configurada
/// (`BasketCampaignSettings.hasProgress`).
class _BasketCampaignCard extends ConsumerWidget {
  const _BasketCampaignCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign =
        ref.watch(basketCampaignProvider).asData?.value ??
        BasketCampaignSettings.empty;
    return Card(
      color: Color.alphaBlend(
        SibValColors.goldAccent.withValues(alpha: 0.16),
        SibValColors.navyBlueLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: SibValColors.goldAccent, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BasketCampaignPage())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: SibValColors.goldAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_basket_outlined,
                      color: SibValColors.navyBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Doe para Cestas Básicas',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Contribua via Pix ou doe alimentos',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: SibValColors.goldAccent,
                  ),
                ],
              ),
              if (campaign.hasProgress) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Colors.white24),
                ),
                Text(
                  '${campaign.collectedCount} de ${campaign.goalCount} cestas arrecadadas este mês',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (campaign.collectedCount / campaign.goalCount)
                        .clamp(0, 1)
                        .toDouble(),
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    color: SibValColors.goldAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.bank});

  final BankAccountEntry bank;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: bank.label.isNotEmpty
          ? 'Conta Bancária — ${bank.label}'
          : 'Conta Bancária',
      icon: Icons.account_balance_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bank.bankName.isNotEmpty)
            _InfoRow(label: 'Banco', value: bank.bankName),
          if (bank.agency.isNotEmpty)
            _InfoRow(label: 'Agência', value: bank.agency),
          if (bank.operation.isNotEmpty)
            _InfoRow(label: 'Operação', value: bank.operation),
          if (bank.account.isNotEmpty)
            _InfoRow(label: 'Conta', value: bank.account),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

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
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
            child: Text(
              label,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: context.textPrimary, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
