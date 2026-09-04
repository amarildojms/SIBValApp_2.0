import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/basket_donation_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_donation_success_page.dart';
import 'basket_widgets.dart';

/// "Confirmar doação" (04/09/2026) — última etapa antes de registrar a
/// intenção de doação no Firestore ([BasketDonationRepository.create]).
class BasketDonationConfirmPage extends ConsumerStatefulWidget {
  const BasketDonationConfirmPage({super.key, required this.items});

  final List<BasketDonationItem> items;

  @override
  ConsumerState<BasketDonationConfirmPage> createState() =>
      _BasketDonationConfirmPageState();
}

class _BasketDonationConfirmPageState
    extends ConsumerState<BasketDonationConfirmPage> {
  bool _saving = false;

  Future<void> _confirm() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    setState(() => _saving = true);
    try {
      final donation = await ref
          .read(basketDonationRepositoryProvider)
          .create(uid: uid, userName: profile?.name ?? '', items: widget.items);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BasketDonationSuccessPage(donation: donation),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao registrar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign =
        ref.watch(basketCampaignProvider).asData?.value ??
        BasketCampaignSettings.empty;
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Confirmar doação'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    'Confira os itens que você pretende doar.',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sua doação',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(height: 20),
                          for (final item in widget.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.itemName,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                      ),
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SibValColors.navyBlueLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: SibValColors.goldAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Esta é apenas uma intenção de doação. Ao entregar os alimentos na igreja, '
                            'nossa equipe fará o registro do recebimento.',
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
                  const SizedBox(height: 16),
                  BasketDeliveryInfoCard(deliveryInfo: campaign.deliveryInfo),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            color: SibValColors.goldAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prazo da intenção',
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sua intenção ficará válida por 7 dias. Após este prazo, ela será cancelada '
                                  'automaticamente.',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _confirm,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar que vou doar'),
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
