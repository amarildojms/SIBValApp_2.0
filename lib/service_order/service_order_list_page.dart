import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../admin/manage_service_order_moments_page.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/service_order_repository.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';
import '../models/service_order.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'leader_schedule_list_page.dart';
import 'service_order_form_page.dart';
import 'service_order_navigation.dart';
import 'service_order_preview_page.dart';

/// Sem equivalente no app nativo — feature nova (27-28/08/2026, pedido do
/// usuário). Tela que abre ao tocar em "Ordem de Culto" no menu Mais — antes
/// ia direto pro cadastro (`ServiceOrderFormPage`); agora mostra primeiro as
/// ordens já cadastradas (`serviceOrdersProvider`), com um botão "Nova
/// Ordem" pra iniciar o cadastro. Tile agora incondicional (28/08/2026 — ver
/// `main_shell.dart`), aberto pra qualquer usuário, logado ou em acesso
/// convidado: toque simples despacha por dono/papel via `openServiceOrder`
/// (`service_order_navigation.dart`) — **revisão de 28/08/2026**: só o dono
/// da ordem vai pro Precheck (contagem regressiva + "Iniciar Culto"); os
/// demais (Dirigentes/admin não-dono incluso) vão pras visões
/// somente-leitura — Louvor pra `ServiceOrderPraiseViewPage`, qualquer outro
/// pra `ServiceOrderMemberViewPage` (travada num timer até o dono iniciar).
/// Toque e segure abre um menu Editar/Excluir/Visualizar/
/// Alterar proprietário (`_showActions`) — **revisão de 28/08/2026, pedido do
/// usuário**: Editar/Excluir/Iniciar Culto/marcar momento são exclusivos do
/// dono da ordem (`ownerUid`), nem mesmo admin escapa dessa regra (ver
/// `firestore.rules` nativo — `update`/`delete` checam `resource.data.
/// ownerUid == request.auth.uid`, sem exceção pra `isAdmin()` nesses casos);
/// o único privilégio exclusivo do admin é "Alterar proprietário"
/// (`_showTransferOwnerSheet`/`_TransferOwnerSheet` — bottom sheet direto
/// nesta tela, não uma página própria, pedido do usuário numa revisão
/// seguinte), sempre disponível independente de quem é o dono atual — é
/// assim que o admin manipula uma ordem indiretamente, transferindo-a pra si
/// mesmo primeiro. "Visualizar" (prévia, sempre
/// disponível a quem abre o menu) usa o mesmo menu por conveniência. O ícone
/// de engrenagem, ao lado do título (28/08/2026 — antes ficava na app bar,
/// movido pra cá a pedido do usuário, mesmo padrão de "Contribua" +
/// "Configurar" em `contribute_page.dart`), abre
/// `ManageServiceOrderMomentsPage` (momentos do culto + momentos especiais).
/// Menu ☰ (28/08/2026, mesmo padrão de `PraiseMinistryPage`) com "Escala de
/// Dirigentes" (`LeaderScheduleListPage`) — visível a quem tem
/// `canViewLeaderSchedule` (Pastor/Dirigentes/admin).
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
    final canViewLeaderSchedule = profile?.canViewLeaderSchedule ?? false;

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
                  if (canViewLeaderSchedule)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.menu, color: context.textPrimary),
                      onSelected: (value) {
                        if (value == 'leader_schedule') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LeaderScheduleListPage(),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'leader_schedule',
                          child: Row(
                            children: [
                              Icon(Icons.event_note_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Escala de Dirigentes'),
                            ],
                          ),
                        ),
                      ],
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
                      final isOwner = order.ownerUid == uid;
                      final isAdmin = profile?.isAdmin ?? false;
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
                          onTap: () => openServiceOrder(context, order.id),
                          onLongPress: (isOwner || isAdmin)
                              ? () => _showActions(
                                  context,
                                  ref,
                                  order,
                                  isOwner: isOwner,
                                  isAdmin: isAdmin,
                                )
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

  void _showActions(
    BuildContext context,
    WidgetRef ref,
    ServiceOrder order, {
    required bool isOwner,
    required bool isAdmin,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Visualizar" (28/08/2026, pedido do usuário: "uma maneira do
            // dirigente acessar uma prévia do culto") — sempre disponível,
            // sem trava de horário, mesmo menu de conveniência de quem já
            // pode abrir este menu (dono ou admin).
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Visualizar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ServiceOrderPreviewPage(order: order),
                  ),
                );
              },
            ),
            // Editar/Excluir — exclusivos do dono (28/08/2026, pedido do
            // usuário: "Nem mesmo admin poderá fazer estas ações").
            if (isOwner) ...[
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
            // "Alterar proprietário" — exclusivo do admin, independente de
            // quem é o dono atual (28/08/2026, pedido do usuário: "o admin
            // poderá alterar o proprietário daquela ordem, podendo alterar
            // inclusive para ele próprio"). Fica na própria Ordem de Culto —
            // não é uma tela nova (pedido do usuário na revisão seguinte), só
            // outro bottom sheet, empilhado sobre este assim que ele fecha.
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Alterar proprietário'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showTransferOwnerSheet(context, ref, order);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet de transferência de propriedade (28/08/2026, pedido do
  /// usuário: "não deve ser uma nova tela") — busca + lista de candidatos
  /// (usuários aprovados com papel Dirigentes ou admin, mesmo critério de
  /// `isDirigentes()` no `firestore.rules` nativo, já que só quem passa
  /// nessa checagem consegue de fato editar a ordem depois de virar dono),
  /// toque confirma e chama `ServiceOrderRepository.transferOwner` — tudo
  /// sem sair de `ServiceOrderListPage`.
  void _showTransferOwnerSheet(BuildContext context, WidgetRef ref, ServiceOrder order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransferOwnerSheet(order: order),
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

/// Conteúdo do bottom sheet "Alterar proprietário" (28/08/2026, pedido do
/// usuário) — antes era uma página própria (`ServiceOrderTransferOwnerPage`,
/// removida), virou este sheet direto na Ordem de Culto.
class _TransferOwnerSheet extends ConsumerStatefulWidget {
  const _TransferOwnerSheet({required this.order});

  final ServiceOrder order;

  @override
  ConsumerState<_TransferOwnerSheet> createState() => _TransferOwnerSheetState();
}

class _TransferOwnerSheetState extends ConsumerState<_TransferOwnerSheet> {
  String _query = '';
  bool _transferring = false;

  Future<void> _confirmAndTransfer(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transferir propriedade'),
        content: Text(
          'Transferir esta ordem de culto para ${user.name}? '
          'A partir daí, só ${user.name} (ou outra transferência do admin) '
          'poderá editar, excluir, iniciar o culto ou marcar os momentos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _transferring = true);
    try {
      await ref
          .read(serviceOrderRepositoryProvider)
          .transferOwner(widget.order.id, user.uid, user.name);
      ref.invalidate(serviceOrdersProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao transferir: $e')));
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alterar proprietário',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.order.ownerName.isEmpty
                    ? 'Selecione o novo dirigente responsável por esta ordem.'
                    : 'Atual: ${widget.order.ownerName}. Selecione o novo dirigente responsável.',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              if (_transferring) const LinearProgressIndicator(),
              Expanded(
                child: usersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      'Falha ao carregar: $error',
                      style: TextStyle(color: context.textPrimary),
                    ),
                  ),
                  data: (users) {
                    final candidates =
                        users
                            .where(
                              (u) =>
                                  u.status == UserStatus.approved &&
                                  (u.isAdmin || u.roles.contains('dirigentes')),
                            )
                            .toList()
                          ..sort((a, b) => a.name.compareTo(b.name));
                    final query = _query.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? candidates
                        : candidates
                              .where((u) => u.name.toLowerCase().contains(query))
                              .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'Nenhum usuário encontrado.',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        final isCurrent = user.uid == widget.order.ownerUid;
                        return ListTile(
                          title: Text(
                            user.name,
                            style: TextStyle(color: context.textPrimary),
                          ),
                          subtitle: isCurrent ? const Text('Dono atual') : null,
                          trailing: isCurrent
                              ? const Icon(Icons.check, color: SibValColors.goldAccent)
                              : null,
                          onTap: (_transferring || isCurrent)
                              ? null
                              : () => _confirmAndTransfer(user),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
