import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/basket_donation_repository.dart';
import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_my_donations_page.dart';
import 'basket_widgets.dart';

/// "Doação registrada" (04/09/2026) — tela final do fluxo, mostrada depois
/// que [BasketDonationRepository.create] tem sucesso.
class BasketDonationSuccessPage extends ConsumerWidget {
  const BasketDonationSuccessPage({super.key, required this.donation});

  final BasketDonation donation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaign =
        ref.watch(basketCampaignProvider).asData?.value ??
        BasketCampaignSettings.empty;
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: SibValColors.navyBlueLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: SibValColors.goldAccent,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Obrigado por contribuir!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SibValColors.goldAccent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Registramos sua intenção de doação. Agora é só entregar os alimentos na igreja.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumo da sua doação',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(height: 20),
                    for (final item in donation.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.itemName,
                                style: TextStyle(color: context.textPrimary),
                              ),
                            ),
                            Text(
                              '${item.quantity} ${item.unit}',
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            BasketDeliveryInfoCard(deliveryInfo: campaign.deliveryInfo),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Intenção válida até ${DateFormat('dd/MM/yyyy').format(donation.expiresAt)}. Após esta data, '
                      'sua intenção será cancelada automaticamente.',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BasketMyDonationsPage(),
                ),
              ),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Ver minhas doações'),
            ),
          ],
        ),
      ),
    );
  }
}
