import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/basket_donation_repository.dart';
import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Histórico de doações já resolvidas — entregues (alimento) ou confirmadas
/// (Pix) (04/09/2026, pedido do usuário: "cada card de doação criado deve
/// guardar dentro dele o histórico de doações que recebeu, visível ao
/// diácono e tesoureiro" + "nas doações pendentes deve também guardar o
/// histórico... com todas as informações, inclusive mês e ano"). Agrupado
/// por mês/ano de resolução ([BasketDonation.deliveredAt]).
///
/// Reaproveitada em dois pontos: [campaignId] preenchido (a partir de
/// `BasketCampaignSettingsPage`, "dentro" da campanha) mostra só as doações
/// daquela campanha; `null` (a partir de `BasketDiaconiaDashboardPage`)
/// mostra de todas, com o nome da campanha em cada linha
/// ([campaignNames]).
class BasketDonationHistoryPage extends ConsumerWidget {
  const BasketDonationHistoryPage({
    super.key,
    this.campaignId,
    this.campaignNames = const {},
  });

  final String? campaignId;
  final Map<String, String> campaignNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(basketDonationHistoryProvider(campaignId));
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Histórico de Doações'),
            Expanded(
              child: historyAsync.when(
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
                        'Nenhuma doação recebida ainda.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  final rows = _groupByMonth(donations);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is _MonthHeaderRow) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                          child: Text(
                            row.label,
                            style: TextStyle(
                              color: SibValColors.goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }
                      final donation = (row as _DonationRow).donation;
                      return _HistoryCard(
                        donation: donation,
                        campaignName: campaignId == null
                            ? campaignNames[donation.campaignId] ?? ''
                            : '',
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_HistoryRow> _groupByMonth(List<BasketDonation> donations) {
    final rows = <_HistoryRow>[];
    final monthYearFormat = DateFormat('MMMM yyyy', 'pt_BR');
    String? lastLabel;
    for (final donation in donations) {
      final date = donation.deliveredAt ?? donation.createdAt;
      final label = _capitalize(monthYearFormat.format(date));
      if (label != lastLabel) {
        rows.add(_MonthHeaderRow(label));
        lastLabel = label;
      }
      rows.add(_DonationRow(donation));
    }
    return rows;
  }

  String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

sealed class _HistoryRow {}

class _MonthHeaderRow extends _HistoryRow {
  _MonthHeaderRow(this.label);
  final String label;
}

class _DonationRow extends _HistoryRow {
  _DonationRow(this.donation);
  final BasketDonation donation;
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.donation, required this.campaignName});

  final BasketDonation donation;
  final String campaignName;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final resolvedAt = donation.deliveredAt ?? donation.createdAt;
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    donation.type == BasketDonationType.pix ? 'Confirmada' : 'Entregue',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (campaignName.isNotEmpty)
              Text(
                campaignName,
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            Text(
              _dateFormat.format(resolvedAt),
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 6),
            if (donation.type == BasketDonationType.pix)
              Text(
                'R\$ ${donation.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
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
          ],
        ),
      ),
    );
  }
}
