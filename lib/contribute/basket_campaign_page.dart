import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/basket_donation_repository.dart';
import '../data/contribution_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/contribution_info.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_campaign_settings_page.dart';
import 'basket_donate_food_page.dart';
import 'pix_offer_page.dart';

/// "Doação de Cestas Básicas" (04/09/2026, sem equivalente no nativo) —
/// aberta a partir de um dos cards "Doe para..." na Contribua
/// (`contribute_page.dart`, um por campanha ativa desde a generalização
/// multi-campanha). Duas formas de contribuir: Pix (reaproveita
/// `PixOfferPage`, mesmo mecanismo dos demais cards da Contribua, com a
/// chave cadastrada em `DonationCampaign.pixKey` — ao gerar o código, já
/// registra a intenção de doação visível à Diaconia/Tesouraria) ou alimentos
/// (`BasketDonateFoodPage`).
class BasketCampaignPage extends ConsumerWidget {
  const BasketCampaignPage({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignAsync = ref.watch(donationCampaignProvider(campaignId));
    final infoAsync = ref.watch(contributionInfoProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    // Configurar a campanha (engrenagem) é admin OU Diaconia
    // (`canConfigureDonationCampaigns`) — diferente de
    // `canManageBasketDonations` (só Diaconia, sem admin), que é exclusivo
    // de receber/confirmar doação (04/09/2026, pedido do usuário).
    final canManage = profile?.canConfigureDonationCampaigns ?? false;
    final campaign = campaignAsync.asData?.value;
    final info = infoAsync.asData?.value ?? ContributionInfo.empty;
    if (campaign == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                  Expanded(
                    child: Text(
                      'Doação de ${campaign.name}',
                      style: const TextStyle(
                        color: SibValColors.goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Configurar',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              BasketCampaignSettingsPage(initial: campaign),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: SibValColors.navyBlueLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.volunteer_activism,
                          color: SibValColors.goldAccent,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doe para ${campaign.name}',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ajude famílias em nossa cidade com alimentos ou com uma contribuição via Pix.',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Como você deseja contribuir?',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const Divider(height: 20),
                          _OptionTile(
                            icon: Icons.pix,
                            title: 'Doar via Pix',
                            subtitle: 'Contribua com qualquer valor e ajude a montarmos as cestas.',
                            enabled: campaign.pixKey.isNotEmpty,
                            disabledMessage: 'Chave Pix ainda não configurada.',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PixOfferPage(
                                  description: 'Doação para ${campaign.name}',
                                  churchName: info.churchName,
                                  city: info.city,
                                  pixKey: campaign.pixKey,
                                  onGenerated: (amount) {
                                    final uid = ref.read(currentUidProvider);
                                    if (uid == null) return;
                                    ref
                                        .read(basketDonationRepositoryProvider)
                                        .createPix(
                                          campaignId: campaignId,
                                          uid: uid,
                                          userName: profile?.name ?? '',
                                          amount: amount,
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Doação registrada — será contabilizada assim que o Pix for confirmado.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 20),
                          _OptionTile(
                            icon: Icons.shopping_basket_outlined,
                            title: 'Doar alimentos',
                            subtitle:
                                'Doe alimentos e ajude famílias diretamente.',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BasketDonateFoodPage(campaignId: campaignId),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SibValColors.navyBlueLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          color: SibValColors.goldAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sua ajuda transforma vidas!',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Cada gesto de amor faz a diferença.',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (campaign.hasProgress) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acompanhamento da campanha',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.groups_outlined,
                                  color: SibValColors.goldAccent,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 15,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              '${campaign.collectedCount} de ${campaign.goalCount} cestas ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: 'arrecadadas este mês',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value:
                                    (campaign.collectedCount /
                                            campaign.goalCount)
                                        .clamp(0, 1)
                                        .toDouble(),
                                minHeight: 8,
                                backgroundColor: context.textSecondary
                                    .withValues(alpha: 0.15),
                                color: SibValColors.goldAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Meta do mês: ${campaign.goalCount} cestas básicas',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.disabledMessage,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final String? disabledMessage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled
          ? onTap
          : () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(disabledMessage ?? 'Indisponível no momento.'),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? SibValColors.goldAccent : context.textSecondary,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: enabled
                          ? context.textPrimary
                          : context.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textSecondary),
          ],
        ),
      ),
    );
  }
}
