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

/// "Doar alimentos" (04/09/2026) — lista os itens que a campanha mais
/// precisa (`basketFoodItemsProvider(campaignId)`) e, se o usuário já tem uma
/// intenção de doação pendente ([BasketDonation.isPending]), mostra o resumo
/// dela com os atalhos "Editar"/"Cancelar" em vez do botão de iniciar uma
/// nova.
///
/// **04/09/2026, revisão do usuário**: quem marca a doação como entregue
/// deixou de ser o próprio doador — agora é a Diaconia, no painel
/// `BasketDiaconiaDashboardPage` (ver `BasketDonationRepository.markFoodDelivered`).
/// O doador só edita os itens ou cancela, sempre que a doação ainda estiver
/// pendente — editar não reinicia o prazo de 7 dias
/// (`BasketDonationRepository.updateItems`).
class BasketDonateFoodPage extends ConsumerWidget {
  const BasketDonateFoodPage({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(basketFoodItemsProvider(campaignId));
    final campaign =
        ref.watch(donationCampaignProvider(campaignId)).asData?.value;
    final uid = ref.watch(currentUidProvider);
    final pendingDonation = uid == null
        ? null
        : (ref.watch(myBasketDonationsProvider(uid)).asData?.value ??
                  const <BasketDonation>[])
              .where((d) => d.campaignId == campaignId && d.type == BasketDonationType.food && d.isPending)
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
                              _NeededItemTile(
                                item: items[i],
                                goalCount: campaign?.goalCount ?? 0,
                              ),
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
                      _PendingDonationCard(donation: pendingDonation, catalog: items)
                    else if (items.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BasketDonationFormPage(
                              campaignId: campaignId,
                              catalog: items,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Quero informar os itens que vou doar',
                        ),
                      ),
                    const SizedBox(height: 16),
                    BasketDeliveryInfoCard(deliveryInfo: campaign?.deliveryInfo ?? ''),
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
  const _NeededItemTile({required this.item, required this.goalCount});

  final BasketFoodItem item;
  final int goalCount;

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
      trailing: item.quantityPerBasket > 0
          ? Text(
              'Precisamos de\n${item.remainingNeeded(goalCount)} ${item.unit}',
              textAlign: TextAlign.right,
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            )
          : null,
    );
  }
}

class _PendingDonationCard extends ConsumerStatefulWidget {
  const _PendingDonationCard({required this.donation, required this.catalog});

  final BasketDonation donation;
  final List<BasketFoodItem> catalog;

  @override
  ConsumerState<_PendingDonationCard> createState() =>
      _PendingDonationCardState();
}

class _PendingDonationCardState extends ConsumerState<_PendingDonationCard> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar doação'),
        content: const Text('Tem certeza que deseja cancelar esta doação?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancelar doação'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancelling = true);
    try {
      await ref
          .read(basketDonationRepositoryProvider)
          .cancel(widget.donation.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao cancelar: $e')));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BasketDonationFormPage(
                          campaignId: widget.donation.campaignId,
                          catalog: widget.catalog,
                          editing: widget.donation,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancel,
                    icon: _cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close),
                    label: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
