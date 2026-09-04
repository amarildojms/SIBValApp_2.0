import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/login_page.dart';
import '../data/basket_donation_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_donation_form_page.dart';
import 'basket_widgets.dart';

/// "Doar alimentos" (04/09/2026) — lista os itens que a igreja mais precisa
/// (`basketFoodItemsProvider`) e, se o usuário já tem uma intenção de
/// doação pendente ([BasketDonation.isPending]), mostra o resumo dela com o
/// atalho "Já entreguei minha doação" em vez do botão de iniciar uma nova.
class BasketDonateFoodPage extends ConsumerWidget {
  const BasketDonateFoodPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(basketFoodItemsProvider);
    final campaign =
        ref.watch(basketCampaignProvider).asData?.value ??
        BasketCampaignSettings.empty;
    final uid = ref.watch(currentUidProvider);
    final pendingDonation = uid == null
        ? null
        : (ref.watch(myBasketDonationsProvider(uid)).asData?.value ??
                  const <BasketDonation>[])
              .where((d) => d.isPending)
              .toList()
              .basketFirstOrNull;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Doar alimentos'),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (items) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      'Veja os itens que mais estamos precisando e compartilhe o que você pretende doar.',
                      style: TextStyle(color: context.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      Text(
                        'Nenhum item cadastrado no momento.',
                        style: TextStyle(color: context.textSecondary),
                      )
                    else ...[
                      Text(
                        'Itens que mais precisamos',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _NeededItemTile(item: items[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (uid == null)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text('Entrar para informar uma doação'),
                      )
                    else if (pendingDonation != null)
                      _PendingDonationCard(donation: pendingDonation)
                    else if (items.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BasketDonationFormPage(catalog: items),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Quero informar os itens que vou doar',
                        ),
                      ),
                    const SizedBox(height: 16),
                    BasketDeliveryInfoCard(deliveryInfo: campaign.deliveryInfo),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _BasketFirstOrNull<T> on List<T> {
  T? get basketFirstOrNull => isEmpty ? null : first;
}

class _NeededItemTile extends StatelessWidget {
  const _NeededItemTile({required this.item});

  final BasketFoodItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.shopping_basket_outlined,
        color: SibValColors.goldAccent,
      ),
      title: Text(
        item.name,
        style: TextStyle(
          color: context.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Align(
        alignment: Alignment.centerLeft,
        child: BasketPriorityBadge(priority: item.priority),
      ),
      trailing: Text(
        'Precisamos de\n${item.neededQuantity} ${item.unit}',
        textAlign: TextAlign.right,
        style: TextStyle(color: context.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _PendingDonationCard extends ConsumerStatefulWidget {
  const _PendingDonationCard({required this.donation});

  final BasketDonation donation;

  @override
  ConsumerState<_PendingDonationCard> createState() =>
      _PendingDonationCardState();
}

class _PendingDonationCardState extends ConsumerState<_PendingDonationCard> {
  bool _saving = false;

  Future<void> _markDelivered() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(basketDonationRepositoryProvider)
          .markDelivered(widget.donation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obrigado! Doação marcada como entregue.'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você já tem uma doação pendente',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in widget.donation.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
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
                      style: TextStyle(color: context.textSecondary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _saving ? null : _markDelivered,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Já entreguei minha doação'),
            ),
          ],
        ),
      ),
    );
  }
}
