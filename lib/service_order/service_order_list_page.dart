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
/// Alterar proprietário (`_showActions`) — **revisão de 29/08/2026, pedido
/// do usuário**: admin recuperou Editar/Excluir de qualquer ordem, dono ou
/// não (era exclusivo do dono desde a 15ª rodada de 28/08/2026); só
/// "manipular durante o culto" (`markStarted`/`updateProgress`/`finalize` —
/// Iniciar Culto e marcar cada momento como concluído, em
/// `ServiceOrderLivePage`) continua exclusivo de quem é dono da ordem
/// (`ownerUid`) — ver `firestore.rules` nativo, `update` de `serviceOrders`:
/// admin passa contanto que o diff não toque
/// `startedAt`/`completedMomentKeys`/`isFinalized`/`finalizedAt`.
/// "Alterar proprietário" (`_showTransferOwnerSheet`/`_TransferOwnerSheet` —
/// bottom sheet direto nesta tela, não uma página própria) continua exclusivo
/// do admin, sempre disponível independente de quem é o dono atual.
/// "Visualizar" (prévia, sempre
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
                    // Só a engrenagem, sem o rótulo "Configurar" (28/08/2026,
                    // pedido do usuário).
                    IconButton(
                      tooltip: 'Configurar',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ManageServiceOrderMomentsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
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
                  final isAdmin = profile?.isAdmin ?? false;
                  // Compactadas por mês, mesmo padrão de
                  // `ArchivedVisitorsPage._DayGroup` (28/08/2026, pedido do
                  // usuário) — só o mês corrente fica solto no topo da lista;
                  // os demais (o passado, na prática, já que `orders` vem
                  // descendente) viram grupos recolhidos por mês.
                  final now = DateTime.now();
                  final currentMonthOrders = <ServiceOrder>[];
                  final otherMonths = <DateTime, List<ServiceOrder>>{};
                  for (final order in orders) {
                    final d = order.dateTime;
                    if (d.year == now.year && d.month == now.month) {
                      currentMonthOrders.add(order);
                    } else {
                      otherMonths.putIfAbsent(DateTime(d.year, d.month), () => []).add(order);
                    }
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    children: [
                      for (final order in currentMonthOrders)
                        _OrderTile(order: order, uid: uid, isAdmin: isAdmin),
                      for (final entry in otherMonths.entries)
                        _MonthGroup(
                          header: _monthHeader(entry.key),
                          count: entry.value.length,
                          children: [
                            for (final order in entry.value)
                              _OrderTile(order: order, uid: uid, isAdmin: isAdmin),
                          ],
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

final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
final _monthFormat = DateFormat("MMMM 'de' yyyy", 'pt_BR');

/// Cabeçalho do grupo de mês (28/08/2026) — mesma capitalização manual de
/// `ArchivedVisitorsPage._dayHeader` (`DateFormat` em pt_BR não capitaliza
/// nome de mês sozinho).
String _monthHeader(DateTime month) {
  final label = _monthFormat.format(month);
  return label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
}

/// Um card de ordem de culto na lista — extraído (28/08/2026) pra ser
/// reaproveitado tanto solto (mês corrente) quanto dentro de um `_MonthGroup`
/// (meses anteriores, compactados).
class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order, required this.uid, required this.isAdmin});

  final ServiceOrder order;
  final String? uid;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = order.ownerUid == uid;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          order.isFinalized ? Icons.check_circle : Icons.church_outlined,
          color: order.isFinalized ? SibValColors.goldAccent : null,
        ),
        title: Row(
          children: [
            Text(
              _dateTimeFormat.format(order.dateTime),
              style: TextStyle(color: context.textPrimary),
            ),
            if (order.isFinalized) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            ? () => _showActions(context, ref, order, isOwner: isOwner, isAdmin: isAdmin)
            : null,
      ),
    );
  }
}

/// Grupo recolhido de um mês inteiro de ordens de culto (28/08/2026, pedido
/// do usuário: "compactadas dentro do mês como é feito com os visitantes") —
/// mesmo padrão visual de `ArchivedVisitorsPage._DayGroup`, só que agrupando
/// por mês em vez de por dia. Fechado por padrão.
class _MonthGroup extends StatelessWidget {
  const _MonthGroup({required this.header, required this.count, required this.children});

  final String header;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(header, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
          subtitle: Text(
            count == 1 ? '1 ordem de culto' : '$count ordens de culto',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: children,
        ),
      ),
    );
  }
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
          // Editar/Excluir — dono ou admin (29/08/2026, pedido do usuário:
          // admin recuperou a capacidade de editar/excluir qualquer ordem de
          // culto, revendo a exclusividade do dono da 15ª rodada — só
          // "manipular durante o culto" continua exclusivo do dono, ver
          // `firestore.rules`/`serviceOrders`).
          if (isOwner || isAdmin) ...[
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
        'Tem certeza que deseja excluir a ordem de ${_dateTimeFormat.format(order.dateTime)}?',
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
          'poderá iniciar o culto ou marcar os momentos.',
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
