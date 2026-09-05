import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/basket_donation_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/basket_donation.dart';
import '../notifications/notification_read_sync.dart';
import '../models/notification.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_donation_history_page.dart';

/// Painel de trabalho da Diaconia/Tesouraria (04/09/2026, sem equivalente no
/// nativo) — lista, de todas as campanhas de doação, as intenções ainda não
/// resolvidas (`BasketDonationRepository.watchPendingAll`). Seção "Alimentos"
/// só pra quem tem `canManageBasketDonations` (Diaconia); seção "Pix" pra
/// quem tem `canManageBasketDonations` OU `canConfirmBasketPix` (Tesouraria)
/// — confirmar é uma ação única que qualquer um dos dois papéis resolve
/// (confirmado com o usuário: não é uma aprovação em duas etapas
/// obrigatórias).
class BasketDiaconiaDashboardPage extends ConsumerStatefulWidget {
  const BasketDiaconiaDashboardPage({super.key});

  @override
  ConsumerState<BasketDiaconiaDashboardPage> createState() =>
      _BasketDiaconiaDashboardPageState();
}

class _BasketDiaconiaDashboardPageState
    extends ConsumerState<BasketDiaconiaDashboardPage> {
  @override
  void initState() {
    super.initState();
    syncNotificationsForScreen(ref, type: NotificationType.basketDonationPending);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canManage = profile?.canManageBasketDonations ?? false;
    final canConfirmPix = profile?.canConfirmBasketPix ?? false;
    final donationsAsync = ref.watch(pendingBasketDonationsProvider);
    final campaignsAsync = ref.watch(donationCampaignsProvider);
    final campaignNames = <String, String>{
      for (final c in campaignsAsync.asData?.value ?? const [])
        c.id: c.name,
    };

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: ScreenTitle('Doações Pendentes')),
                // "Nas doações pendentes deve também guardar o histórico de
                // doações recebidas" (04/09/2026, pedido do usuário) — de
                // todas as campanhas juntas, diferente do histórico "dentro"
                // de uma campanha específica (`BasketCampaignSettingsPage`).
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BasketDonationHistoryPage(
                        campaignNames: campaignNames,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Histórico'),
                ),
              ],
            ),
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
                  final food = canManage
                      ? donations
                            .where((d) => d.type == BasketDonationType.food)
                            .toList()
                      : const <BasketDonation>[];
                  final pix = (canManage || canConfirmPix)
                      ? donations
                            .where((d) => d.type == BasketDonationType.pix)
                            .toList()
                      : const <BasketDonation>[];
                  if (food.isEmpty && pix.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhuma doação pendente no momento.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (food.isNotEmpty) ...[
                        _SectionLabel('Alimentos (${food.length})'),
                        for (final d in food)
                          _FoodDonationCard(
                            donation: d,
                            campaignName: campaignNames[d.campaignId] ?? '',
                          ),
                      ],
                      if (pix.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SectionLabel('Pix (${pix.length})'),
                        for (final d in pix)
                          _PixDonationCard(
                            donation: d,
                            campaignName: campaignNames[d.campaignId] ?? '',
                          ),
                      ],
                    ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.textSecondary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FoodDonationCard extends ConsumerStatefulWidget {
  const _FoodDonationCard({required this.donation, required this.campaignName});

  final BasketDonation donation;
  final String campaignName;

  @override
  ConsumerState<_FoodDonationCard> createState() => _FoodDonationCardState();
}

class _FoodDonationCardState extends ConsumerState<_FoodDonationCard> {
  bool _saving = false;
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _markDelivered() async {
    final uid = ref.read(currentUidProvider) ?? '';
    setState(() => _saving = true);
    try {
      await ref
          .read(basketDonationRepositoryProvider)
          .markFoodDelivered(widget.donation.id, uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao registrar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final donation = widget.donation;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    donation.userName,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _dateFormat.format(donation.createdAt),
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                ),
              ],
            ),
            if (widget.campaignName.isNotEmpty)
              Text(
                widget.campaignName,
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            const SizedBox(height: 6),
            for (final item in donation.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _markDelivered,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Marcar como entregue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PixDonationCard extends ConsumerStatefulWidget {
  const _PixDonationCard({required this.donation, required this.campaignName});

  final BasketDonation donation;
  final String campaignName;

  @override
  ConsumerState<_PixDonationCard> createState() => _PixDonationCardState();
}

class _PixDonationCardState extends ConsumerState<_PixDonationCard> {
  bool _saving = false;
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Future<void> _confirm() async {
    final uid = ref.read(currentUidProvider) ?? '';
    setState(() => _saving = true);
    try {
      await ref
          .read(basketDonationRepositoryProvider)
          .confirmPix(widget.donation.id, uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao registrar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final donation = widget.donation;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    donation.userName,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _dateFormat.format(donation.createdAt),
                  style: TextStyle(color: context.textSecondary, fontSize: 11),
                ),
              ],
            ),
            if (widget.campaignName.isNotEmpty)
              Text(
                widget.campaignName,
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            const SizedBox(height: 6),
            Text(
              'R\$ ${donation.amount.toStringAsFixed(2).replaceAll('.', ',')}',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _confirm,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar recebimento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
