import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/service_order_repository.dart';
import '../models/service_order.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). 2ª etapa do cadastro/edição de Ordem de Culto: [draft] chega
/// pronto de `ServiceOrderFormPage` (todos os campos já preenchidos e
/// validados, `momentOrder` só com os momentos extras escolhidos lá) —
/// aqui o dirigente arrasta pra reordenar os momentos do culto
/// (`ReorderableListView`, toque longo no ícone antes de arrastar —
/// `ReorderableDelayedDragStartListener`, pedido do usuário pra evitar
/// arraste acidental) e só então confirma o salvamento. Só esta tela grava
/// de fato no Firestore (`create` ou `update`, conforme [editingOrder]).
///
/// O botão "Adicionar momento" (catálogo de momentos especiais) saiu desta
/// tela em 28/08/2026 — pedido do usuário foi que ficasse na 1ª etapa
/// (`ServiceOrderFormPage`). Aqui só resta remover (X) um momento extra já
/// escolhido, se o dirigente mudar de ideia durante o arraste.
class ServiceOrderReorderPage extends ConsumerStatefulWidget {
  const ServiceOrderReorderPage({
    super.key,
    required this.draft,
    this.editingOrder,
    this.defaultMomentOrder = const [],
  });

  final ServiceOrder draft;

  /// Ordem original sendo editada — `null` no cadastro de uma ordem nova.
  /// Quando presente, a ordem inicial dos momentos (`_buildInitialOrder`)
  /// preserva o arranjo já salvo em vez de partir do zero.
  final ServiceOrder? editingOrder;

  /// Sequência padrão dos "Momentos do Culto" (28/08/2026, configurável em
  /// `ManageServiceOrderMomentsPage` — mistura fixos + especiais marcados
  /// "padrão"), buscada por `ServiceOrderFormPage` antes de empurrar pra cá.
  /// Só usada no modo cadastro (`editingOrder == null`); no modo edição a
  /// ordem inicial parte do arranjo já salvo, não deste padrão.
  final List<ServiceOrderItem> defaultMomentOrder;

  @override
  ConsumerState<ServiceOrderReorderPage> createState() =>
      _ServiceOrderReorderPageState();
}

class _ServiceOrderReorderPageState
    extends ConsumerState<ServiceOrderReorderPage> {
  late final List<ServiceOrderItem> _order = _buildInitialOrder();
  bool _saving = false;

  bool get _isEditing => widget.editingOrder != null;

  /// Parte de uma "base" (a sequência padrão configurada, no cadastro, ou o
  /// arranjo já salvo, na edição) e reconcilia: remove momentos fixos que
  /// ficaram vazios com os dados atuais, remove momentos extras que não
  /// estão mais marcados como padrão (cadastro) ou não foram mantidos na
  /// seção "Momentos Especiais" da 1ª etapa (edição), acrescenta no fim
  /// qualquer momento fixo que passou a valer mas não estava na base, e
  /// qualquer momento extra escolhido na 1ª etapa que ainda não apareceu —
  /// preserva a ordem manual (seja a configurada como padrão, seja a que o
  /// dirigente já tinha escolhido antes numa edição), só ajusta o que mudou.
  List<ServiceOrderItem> _buildInitialOrder() {
    final draft = widget.draft;
    final existing = widget.editingOrder;
    final isEditing = existing != null;
    final base = existing?.momentOrder ?? widget.defaultMomentOrder;
    final chosenExtraIds = draft.momentOrder.map((e) => e.extraMomentId).toSet();

    final result = <ServiceOrderItem>[];
    for (final item in base) {
      if (item.type != null) {
        if (!_isEmptyMoment(item.type!, draft)) result.add(item);
      } else if (isEditing) {
        // Bug corrigido (28/08/2026, relatado pelo usuário: "Ceia do Senhor
        // não está atualizando quando editamos, removi o momento e
        // adicionei novamente com novo texto") — antes acrescentava o
        // `item` antigo de `base` (o arranjo já salvo, com os dados de
        // ANTES da edição); como o `extraMomentId` já batia, o item novo
        // vindo de `draft.momentOrder` (com o texto/nomes atualizados da 1ª
        // etapa) nunca chegava a entrar (o loop de baixo pula quem já tem o
        // mesmo `extraMomentId` em `result`). Agora busca o item
        // correspondente em `draft.momentOrder` — mantém a POSIÇÃO
        // reconciliada a partir de `base`, mas com os DADOS atuais.
        if (chosenExtraIds.contains(item.extraMomentId)) {
          final fresh = draft.momentOrder.firstWhere(
            (e) => e.extraMomentId == item.extraMomentId,
            orElse: () => item,
          );
          result.add(fresh);
        }
      } else {
        // Cadastro: todo extra na base já é um momento marcado "padrão" —
        // sempre entra, sem depender de `draft.momentOrder` (que só carrega
        // os extras escolhidos avulso na 1ª etapa, não os padrão).
        result.add(item);
      }
    }
    for (final type in ServiceOrderMomentType.values) {
      if (_isEmptyMoment(type, draft)) continue;
      if (result.any((i) => i.type == type)) continue;
      result.add(ServiceOrderItem.fixed(type));
    }
    for (final extra in draft.momentOrder) {
      if (result.any((i) => i.extraMomentId == extra.extraMomentId)) continue;
      result.add(extra);
    }
    return result;
  }

  bool _isEmptyMoment(ServiceOrderMomentType type, ServiceOrder draft) {
    switch (type) {
      case ServiceOrderMomentType.prelude:
        return draft.preludeStyle == PreludeStyle.naoHavera;
      case ServiceOrderMomentType.participation:
        return draft.participation.trim().isEmpty;
      case ServiceOrderMomentType.missionMoment:
        return draft.missionMoment == MissionMoment.naoHavera;
      default:
        return false;
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
  }

  void _removeItem(ServiceOrderItem item) {
    setState(() => _order.remove(item));
  }

  /// Prelúdio precisa ser o primeiro momento (quando presente — pode estar
  /// ausente se "Não haverá") e Poslúdio precisa ser o último (28/08/2026,
  /// pedido do usuário) — `null` se a ordem está válida.
  String? _validateOrder() {
    final preludeIndex = _order.indexWhere((i) => i.type == ServiceOrderMomentType.prelude);
    if (preludeIndex > 0) {
      return 'O Prelúdio precisa ficar no início da ordem — nada pode vir antes dele.';
    }
    final postludeIndex = _order.indexWhere((i) => i.type == ServiceOrderMomentType.postlude);
    if (postludeIndex != -1 && postludeIndex != _order.length - 1) {
      return 'O Poslúdio precisa ficar no fim da ordem — nada pode vir depois dele.';
    }
    return null;
  }

  Future<void> _save() async {
    final validationError = _validateOrder();
    if (validationError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    setState(() => _saving = true);
    try {
      final order = widget.draft.copyWith(momentOrder: _order);
      final repo = ref.read(serviceOrderRepositoryProvider);
      final existing = widget.editingOrder;
      if (existing != null) {
        await repo.update(existing.id, order);
      } else {
        await repo.create(order);
      }
      ref.invalidate(serviceOrdersProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(_isEditing ? 'Ordem de culto atualizada!' : 'Ordem de culto salva!'),
          content: Text(
            _isEditing
                ? 'As alterações foram salvas com sucesso.'
                : 'A ordem de culto foi cadastrada com sucesso.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Organizar momentos'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Toque e segure o ícone para arrastar e reordenar os momentos do culto.',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                buildDefaultDragHandles: false,
                itemCount: _order.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final item = _order[index];
                  final summary = item.summary(widget.draft);
                  return Card(
                    key: ValueKey(item.instanceId),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(item.label),
                      subtitle: summary != null ? Text(summary) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.isExtra)
                            IconButton(
                              tooltip: 'Remover momento',
                              icon: const Icon(Icons.close),
                              onPressed: () => _removeItem(item),
                            ),
                          ReorderableDelayedDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Voltar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
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
