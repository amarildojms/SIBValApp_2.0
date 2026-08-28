import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/manage_service_order_moments_page.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/service_order_repository.dart';
import '../data/user_repository.dart';
import '../models/service_order.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'service_order_form_page.dart';
import 'service_order_praise_view_page.dart';
import 'service_order_precheck_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Tela que abre ao tocar em "Ordem de Culto" no menu Mais — antes
/// ia direto pro cadastro (`ServiceOrderFormPage`); agora mostra primeiro as
/// ordens já cadastradas (`serviceOrdersProvider`), com um botão "Nova
/// Ordem" pra iniciar o cadastro. Toque simples abre
/// `ServiceOrderPrecheckPage` (contagem regressiva + "Iniciar Culto");
/// toque e segure abre um menu Editar/Excluir (`_showActions`), só pra quem
/// é dono da ordem ou admin (mesma regra de `firestore.rules`). O ícone de
/// engrenagem, ao lado do título (28/08/2026 — antes ficava na app bar,
/// movido pra cá a pedido do usuário, mesmo padrão de "Contribua" +
/// "Configurar" em `contribute_page.dart`), abre
/// `ManageServiceOrderMomentsPage` (momentos do culto + momentos especiais).
class ServiceOrderListPage extends ConsumerWidget {
  const ServiceOrderListPage({super.key});

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(serviceOrdersProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final uid = ref.watch(currentUidProvider);
    // Só Dirigentes/admin gerencia (cadastra/edita/configura) — Louvor só
    // enxerga (28/08/2026, papel novo, ver CurrentUserProfile.canViewPraiseOrder).
    final canManageOrders = profile?.canManageServiceOrders ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canManageOrders
          ? FloatingActionButton.extended(
              heroTag: 'service_order_new_fab',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ServiceOrderFormPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nova Ordem'),
            )
          : null,
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
                  const Expanded(
                    child: Text(
                      'Ordem de Culto',
                      style: TextStyle(
                        color: SibValColors.goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  if (canManageOrders)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ManageServiceOrderMomentsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Configurar'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (orders) {
                  if (orders.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhuma ordem de culto cadastrada ainda.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final canManage =
                          (profile?.isAdmin ?? false) || order.ownerUid == uid;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            order.isFinalized
                                ? Icons.check_circle
                                : Icons.church_outlined,
                            color: order.isFinalized ? SibValColors.goldAccent : null,
                          ),
                          title: Row(
                            children: [
                              Text(
                                _dateFormat.format(order.dateTime),
                                style: TextStyle(color: context.textPrimary),
                              ),
                              if (order.isFinalized) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SibValColors.goldAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Finalizada',
                                    style: TextStyle(
                                      color: SibValColors.goldAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: order.ownerName.isEmpty
                              ? null
                              : Text(
                                  'Dirigente: ${order.ownerName}',
                                  style: TextStyle(color: context.textSecondary),
                                ),
                          onTap: () => canManageOrders
                              ? Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ServiceOrderPrecheckPage(order: order),
                                  ),
                                )
                              : _openPraiseView(context, order),
                          onLongPress: canManage
                              ? () => _showActions(context, ref, order)
                              : null,
                        ),
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

  /// Quem não gerencia Ordem de Culto (Louvor puro) cai aqui — a própria
  /// `ServiceOrderPraiseViewPage` decide se mostra a ordem ou "ainda não
  /// disponível" (liberada 1h antes do culto).
  void _openPraiseView(BuildContext context, ServiceOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceOrderPraiseViewPage(orderId: order.id),
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, ServiceOrder order) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ServiceOrderFormPage(editing: order),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Excluir'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref, order);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ServiceOrder order) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir ordem de culto'),
        content: Text(
          'Tem certeza que deseja excluir a ordem de ${_dateFormat.format(order.dateTime)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(serviceOrderRepositoryProvider).delete(order.id);
              ref.invalidate(serviceOrdersProvider);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
