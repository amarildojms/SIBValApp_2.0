import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/basket_donation_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_donation_form_page.dart';

/// "Ver minhas doações" (04/09/2026) — lista as intenções de doação (alimento
/// ou Pix) do próprio usuário logado, mais recente primeiro.
///
/// **04/09/2026, revisão do usuário**: marcar como entregue/confirmada
/// deixou de ser uma ação do doador — agora é a Diaconia/Tesouraria (ver
/// `BasketDiaconiaDashboardPage`). O doador só edita os itens (só doações de
/// alimento, só pendentes) ou cancela (alimento ou Pix, só pendentes).
class BasketMyDonationsPage extends ConsumerWidget {
  const BasketMyDonationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final donationsAsync = uid == null
        ? const AsyncValue<List<BasketDonation>>.data(<BasketDonation>[])
        : ref.watch(myBasketDonationsProvider(uid));

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Minhas Doações'),
            Expanded(
              child: donationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (donations) {
                  if (donations.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhuma doação registrada ainda.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: donations.length,
                    itemBuilder: (context, index) =>
                        _DonationCard(donation: donations[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonationCard extends ConsumerStatefulWidget {
  const _DonationCard({required this.donation});

  final BasketDonation donation;

  @override
  ConsumerState<_DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends ConsumerState<_DonationCard> {
  bool _cancelling = false;
  static final _dateFormat = DateFormat('dd/MM/yyyy');

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

  (String, Color) get _status {
    final d = widget.donation;
    if (d.cancelled) return ('Cancelada', Colors.grey);
    if (d.delivered) {
      return d.type == BasketDonationType.pix
          ? ('Confirmada', Colors.green)
          : ('Entregue', Colors.green);
    }
    if (d.isExpired) return ('Expirada', Colors.grey);
    return ('Pendente', Colors.orange);
  }

  @override
  Widget build(BuildContext context) {
    final donation = widget.donation;
    final (statusLabel, statusColor) = _status;
    final itemsAsync = ref.watch(basketFoodItemsProvider(donation.campaignId));
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Enviada em ${_dateFormat.format(donation.createdAt)}',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (donation.type == BasketDonationType.pix)
              Text(
                'R\$ ${donation.amount.toStringAsFixed(2).replaceAll('.', ',')} via Pix',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              for (final item in donation.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: TextStyle(color: context.textSecondary),
                        ),
                      ),
                      Text(
                        '${item.quantity} ${item.unit}',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
            if (donation.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (donation.type == BasketDonationType.food)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final catalog =
                              itemsAsync.asData?.value ?? const <BasketFoodItem>[];
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BasketDonationFormPage(
                                campaignId: donation.campaignId,
                                catalog: catalog,
                                editing: donation,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                    ),
                  if (donation.type == BasketDonationType.food)
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
          ],
        ),
      ),
    );
  }
}
