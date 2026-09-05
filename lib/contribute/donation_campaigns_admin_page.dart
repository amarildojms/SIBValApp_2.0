import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/basket_donation_repository.dart';
import '../models/basket_donation.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'basket_campaign_settings_page.dart';

/// Gerenciamento das campanhas de doação de alimentos (04/09/2026,
/// generalização de "Doe para Cestas Básicas") — só quem tem
/// `canCreateDonationCampaigns` (admin) chega aqui: criar uma campanha nova é
/// uma decisão estrutural, distinta de configurar uma já existente
/// (`BasketCampaignSettingsPage`, aberta pra Diaconia também). Toque numa
/// campanha existente leva direto pra sua configuração.
class DonationCampaignsAdminPage extends ConsumerWidget {
  const DonationCampaignsAdminPage({super.key});

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nova campanha'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome (ex.: Cestas Básicas, Cristolândia)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(donationCampaignRepositoryProvider)
        .create(DonationCampaign(id: '', name: name));
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, DonationCampaign campaign) async {
    final controller = TextEditingController(text: campaign.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear campanha'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(donationCampaignRepositoryProvider)
        .update(campaign.copyWith(name: name));
  }

  /// "Finalizar campanha" (04/09/2026, pedido do usuário) — diferente do
  /// toggle Ativa/Inativa (pausa reversível), finalizar é permanente: a
  /// campanha nunca mais volta a aparecer na Contribua, mesmo que `active`
  /// seja marcado de novo (`DonationCampaign.finalized`,
  /// `activeDonationCampaignsProvider` já filtra por isso). Só o
  /// histórico/config continuam acessíveis depois. Admin-only, mesmo gate
  /// de criar uma campanha nova — decisão estrutural sobre o ciclo de vida.
  Future<void> _confirmFinalize(BuildContext context, WidgetRef ref, DonationCampaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar campanha'),
        content: Text(
          'Finalizar "${campaign.name}"? Ela some da Contribua em definitivo — diferente de desativar, não é possível reverter. O histórico de doações continua acessível.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(donationCampaignRepositoryProvider)
          .update(campaign.copyWith(finalized: true, active: false));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, DonationCampaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir campanha'),
        content: Text(
          'Tem certeza que deseja excluir "${campaign.name}"? Os itens e doações já registrados continuam no banco, mas a campanha some da Contribua.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(donationCampaignRepositoryProvider).delete(campaign.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignsAsync = ref.watch(donationCampaignsProvider);
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Campanhas de Doação'),
            Expanded(
              child: campaignsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (campaigns) {
                  if (campaigns.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhuma campanha cadastrada ainda.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      for (final campaign in campaigns)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BasketCampaignSettingsPage(initial: campaign),
                              ),
                            ),
                            title: Text(
                              campaign.name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              campaign.finalized
                                  ? 'Finalizada'
                                  : (campaign.active ? 'Ativa' : 'Inativa'),
                              style: TextStyle(
                                color: campaign.finalized
                                    ? context.textSecondary
                                    : (campaign.active
                                        ? Colors.green
                                        : context.textSecondary),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) {
                                switch (action) {
                                  case 'rename':
                                    _rename(context, ref, campaign);
                                  case 'toggle':
                                    ref
                                        .read(donationCampaignRepositoryProvider)
                                        .update(campaign.copyWith(active: !campaign.active));
                                  case 'finalize':
                                    _confirmFinalize(context, ref, campaign);
                                  case 'delete':
                                    _confirmDelete(context, ref, campaign);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Renomear'),
                                ),
                                if (!campaign.finalized) ...[
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(campaign.active ? 'Desativar' : 'Ativar'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'finalize',
                                    child: Text('Finalizar campanha'),
                                  ),
                                ],
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Excluir'),
                                ),
                              ],
                            ),
                          ),
                        ),
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
