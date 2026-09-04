import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/basket_donation_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// "Ver minhas doações" (04/09/2026) — lista as intenções de doação de
/// alimentos do próprio usuário logado, mais recente primeiro, com o atalho
/// "Já entreguei minha doação" nas que ainda estão pendentes.
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
  bool _saving = false;

  Future<void> _markDelivered() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(basketDonationRepositoryProvider)
          .markDelivered(widget.donation.id);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao registrar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  (String, Color) get _status {
    final d = widget.donation;
    if (d.delivered) return ('Entregue', Colors.green);
    if (d.isExpired) return ('Expirada', Colors.grey);
    return ('Pendente', Colors.orange);
  }

  @override
  Widget build(BuildContext context) {
    final donation = widget.donation;
    final (statusLabel, statusColor) = _status;
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
                    'Enviada em ${DateFormat('dd/MM/yyyy').format(donation.createdAt)}',
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
              OutlinedButton.icon(
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
          ],
        ),
      ),
    );
  }
}
