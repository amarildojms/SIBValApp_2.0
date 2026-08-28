import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/service_order_extra_moment_repository.dart';
import '../data/service_order_moment_order_repository.dart';
import '../data/user_repository.dart';
import '../models/service_order.dart';
import '../models/service_order_extra_moment.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Botão "Configurar" em `ServiceOrderListPage` abre esta tela —
/// duas seções:
///
/// 1. **Momentos do Culto** — a sequência padrão usada ao criar uma ordem
///    de culto nova (`serviceOrderMomentTemplateProvider`): mistura os 16
///    momentos fixos (`ServiceOrderMomentType`, cada um com campo próprio
///    no cadastro — não são criáveis/excluíveis, só reordenáveis) com os
///    momentos adicionais marcados "padrão" (removíveis daqui, o que só
///    desmarca `isDefault` — a exclusão de verdade é na seção 2).
/// 2. **Momentos Adicionais** (renomeado de "Momentos Especiais" — pedido
///    do usuário) — catálogo administrável (Batismo, Ceia do Senhor, mais
///    um Louvor, mais uma Leitura bíblica etc.) — criar/editar/excluir, e o
///    switch "Incluir nos momentos do culto" (`isDefault`) que promove/
///    rebaixa o momento pra dentro/fora da seção 1. Cada momento pode
///    exigir um campo próprio ao ser escolhido pelo dirigente
///    (`ExtraMomentFieldKind` — nenhum/um nome/vários nomes/texto bíblico),
///    definido aqui na criação/edição.
///
/// Quem só é Dirigentes (não admin) enxerga as duas listas (leitura
/// liberada em `firestore.rules`) mas sem nenhum controle de
/// editar/excluir/reordenar/adicionar — escrita é admin-only nas duas
/// coleções, mesmo padrão de `ManageMinistriesPage`.
class ManageServiceOrderMomentsPage extends ConsumerWidget {
  const ManageServiceOrderMomentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canManage = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Configurar Ordem de Culto'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _SectionHeader(
                    title: 'Momentos do Culto',
                    subtitle: canManage
                        ? 'Toque e segure pra reordenar — essa é a sequência usada ao criar uma ordem de culto nova.'
                        : 'Sequência usada ao criar uma ordem de culto nova.',
                  ),
                  _MomentTemplateSection(canManage: canManage),
                  const Divider(height: 32),
                  _SectionHeader(
                    title: 'Momentos Adicionais',
                    subtitle: 'Momentos avulsos (Batismo, Ceia do Senhor etc.) — marque '
                        '"Incluir nos momentos do culto" pra entrar automaticamente em '
                        'toda ordem nova.',
                  ),
                  _ExtraMomentsSection(canManage: canManage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MomentTemplateSection extends ConsumerWidget {
  const _MomentTemplateSection({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateAsync = ref.watch(serviceOrderMomentTemplateProvider);
    return templateAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Falha ao carregar: $error',
          style: TextStyle(color: context.textPrimary),
        ),
      ),
      data: (template) => _MomentTemplateList(template: template, canManage: canManage),
    );
  }
}

class _MomentTemplateList extends ConsumerStatefulWidget {
  const _MomentTemplateList({required this.template, required this.canManage});

  final List<ServiceOrderItem> template;
  final bool canManage;

  @override
  ConsumerState<_MomentTemplateList> createState() => _MomentTemplateListState();
}

class _MomentTemplateListState extends ConsumerState<_MomentTemplateList> {
  late List<ServiceOrderItem> _order = widget.template;

  @override
  void didUpdateWidget(covariant _MomentTemplateList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _order = widget.template;
  }

  String _tokenFor(ServiceOrderItem item) =>
      item.type != null ? item.type!.name : 'extra:${item.extraMomentId}';

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    ref
        .read(serviceOrderMomentOrderRepositoryProvider)
        .saveTokens(_order.map(_tokenFor).toList());
  }

  Future<void> _removeExtra(ServiceOrderItem item) async {
    final id = item.extraMomentId;
    if (id == null) return;
    setState(() => _order.removeWhere((i) => i.extraMomentId == id));
    await ref.read(serviceOrderExtraMomentRepositoryProvider).setDefault(id, false);
    await ref
        .read(serviceOrderMomentOrderRepositoryProvider)
        .saveTokens(_order.map(_tokenFor).toList());
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      buildDefaultDragHandles: false,
      itemCount: _order.length,
      onReorder: widget.canManage ? _onReorder : (_, _) {},
      itemBuilder: (context, index) {
        final item = _order[index];
        return Card(
          key: ValueKey(_tokenFor(item)),
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
            title: Text(item.label),
            subtitle: item.isExtra
                ? Text('Adicional', style: TextStyle(color: context.textSecondary))
                : null,
            trailing: !widget.canManage
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.isExtra)
                        IconButton(
                          tooltip: 'Remover dos momentos do culto',
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeExtra(item),
                        ),
                      ReorderableDelayedDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ExtraMomentsSection extends ConsumerWidget {
  const _ExtraMomentsSection({required this.canManage});

  final bool canManage;

  Future<void> _setDefault(
    WidgetRef ref,
    ServiceOrderExtraMomentOption moment,
    bool isDefault,
  ) async {
    await ref
        .read(serviceOrderExtraMomentRepositoryProvider)
        .setDefault(moment.id, isDefault);
    final orderRepo = ref.read(serviceOrderMomentOrderRepositoryProvider);
    final tokens = await orderRepo.getTokens();
    final token = 'extra:${moment.id}';
    if (isDefault) {
      if (!tokens.contains(token)) await orderRepo.saveTokens([...tokens, token]);
    } else if (tokens.contains(token)) {
      await orderRepo.saveTokens(tokens.where((t) => t != token).toList());
    }
  }

  Future<void> _delete(WidgetRef ref, ServiceOrderExtraMomentOption moment) async {
    await ref.read(serviceOrderExtraMomentRepositoryProvider).delete(moment.id);
    final orderRepo = ref.read(serviceOrderMomentOrderRepositoryProvider);
    final tokens = await orderRepo.getTokens();
    final token = 'extra:${moment.id}';
    if (tokens.contains(token)) {
      await orderRepo.saveTokens(tokens.where((t) => t != token).toList());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentsAsync = ref.watch(serviceOrderExtraMomentsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        momentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Falha ao carregar: $error',
              style: TextStyle(color: context.textPrimary),
            ),
          ),
          data: (moments) {
            if (moments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Nenhum momento adicional cadastrado ainda.',
                  style: TextStyle(color: context.textSecondary),
                ),
              );
            }
            final sorted = [...moments]..sort((a, b) => a.name.compareTo(b.name));
            return Column(
              children: [
                for (final moment in sorted)
                  ListTile(
                    title: Text(
                      moment.name,
                      style: TextStyle(color: context.textPrimary),
                    ),
                    subtitle: Text(
                      moment.isDefault
                          ? 'Incluído nos momentos do culto'
                          : 'Avulso — adicionado manualmente pelo dirigente',
                      style: TextStyle(color: context.textSecondary, fontSize: 12),
                    ),
                    trailing: canManage
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: moment.isDefault,
                                onChanged: (value) => _setDefault(ref, moment, value),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Editar',
                                onPressed: () =>
                                    _showEditDialog(context, ref, moment: moment),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Excluir',
                                onPressed: () => _confirmDelete(context, ref, moment),
                              ),
                            ],
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        if (canManage)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: OutlinedButton.icon(
              onPressed: () => _showEditDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar momento adicional'),
            ),
          ),
      ],
    );
  }

  /// Diálogo único de criar/editar (28/08/2026, unificado nesta sessão pra
  /// incluir o seletor de `ExtraMomentFieldKind`) — `moment == null` cria um
  /// novo, senão edita o passado.
  void _showEditDialog(
    BuildContext context,
    WidgetRef ref, {
    ServiceOrderExtraMomentOption? moment,
  }) {
    final controller = TextEditingController(text: moment?.name ?? '');
    var fieldKind = moment?.fieldKind ?? ExtraMomentFieldKind.none;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(moment == null ? 'Adicionar momento adicional' : 'Editar momento'),
          content: SizedBox(
            // `isExpanded`/largura explícita (28/08/2026, corrige bug
            // relatado pelo usuário: "Right overflowed" ao abrir este
            // diálogo) — sem isso, o `DropdownButtonFormField` tentava
            // mostrar o rótulo comprido de `ExtraMomentFieldKind.label`
            // (ex. "Vários nomes (ex.: batizandos)") na largura estreita
            // padrão de um `AlertDialog`.
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nome do momento'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ExtraMomentFieldKind>(
                  initialValue: fieldKind,
                  isExpanded: true,
                  dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  decoration: const InputDecoration(labelText: 'Campo a preencher'),
                  items: [
                    for (final kind in ExtraMomentFieldKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => fieldKind = value ?? ExtraMomentFieldKind.none,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.of(dialogContext).pop();
                final repo = ref.read(serviceOrderExtraMomentRepositoryProvider);
                try {
                  if (moment == null) {
                    await repo.create(name, fieldKind);
                  } else {
                    await repo.update(moment.id, name, fieldKind);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ServiceOrderExtraMomentOption moment,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir momento'),
        content: Text('Tem certeza que deseja excluir "${moment.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _delete(ref, moment);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
