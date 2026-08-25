import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../data/visitor_repository.dart';
import '../models/notification.dart';
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import '../util/cpf_phone_input.dart';
import '../util/scroll_to_save.dart';
import '../widgets/sibval_app_bar.dart';
import 'archived_visitors_page.dart';
import 'visitor_tiles.dart';

/// Sem equivalente no app nativo — feature nova (24/08/2026, unificada numa
/// só tela em 25/08/2026 a pedido do usuário). Área única "Recepção" — o que
/// cada um vê dentro dela depende do papel (ver
/// `CurrentUserProfile.canRegisterVisitors`/`canViewVisitorSummaries`/
/// `canViewVisitorDetails`, `lib/data/user_repository.dart`):
/// - Recepção: formulário de cadastro + lista completa do que ela mesma
///   cadastrou, com exclusão.
/// - Pastor: lista completa (`visitors`, telefone incluso como link de
///   WhatsApp), só leitura.
/// - Dirigentes (sem Recepção nem Pastor): lista resumida
///   (`visitorSummaries`, nome/igreja/primeira visita, sem telefone), só
///   leitura — é a única que de fato só tem acesso a essa coleção
///   (`firestore.rules`: `visitors` só libera `read` pra Recepção/Pastor).
/// As duas listas só mostram visitantes de hoje — ver `Visitor.isFromToday`/
/// `VisitorRepository.watchAll`/`watchSummaries` (25/08/2026, pedido do
/// usuário: cadastros de dias anteriores "arquivam", saindo da lista sem
/// serem apagados — ver `ArchivedVisitorsPage`, agrupada por data). Ver doc
/// comment de `Visitor`/`VisitorSummary` (`lib/models/visitor.dart`) para o
/// desenho completo de coleções. Cards/selo compartilhados com
/// `ArchivedVisitorsPage` em `visitor_tiles.dart`.
class ReceptionPage extends ConsumerStatefulWidget {
  const ReceptionPage({super.key});

  @override
  ConsumerState<ReceptionPage> createState() => _ReceptionPageState();
}

class _ReceptionPageState extends ConsumerState<ReceptionPage> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _phoneController = TextEditingController();
  final _churchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _firstVisit = true;
  bool _sending = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    syncNotificationsForScreen(ref, type: NotificationType.visitor);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _phoneController.dispose();
    _churchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Informe o nome do visitante.');
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _sending = true;
      _nameError = null;
    });
    _scrollController.scrollToSaveButton();
    try {
      await ref.read(visitorRepositoryProvider).registerVisitor(
            name: name,
            phone: _phoneController.text.trim(),
            church: _churchController.text.trim(),
            firstVisit: _firstVisit,
            createdByUid: uid,
          );
      _nameController.clear();
      _phoneController.clear();
      _churchController.clear();
      setState(() => _firstVisit = true);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Visitante cadastrado'),
            content: const Text('O cadastro foi realizado com sucesso.'),
            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
          ),
        );
      }
      // Pedido do usuário (25/08/2026): depois de cadastrar, o cursor volta
      // pro campo Nome pra agilizar o próximo cadastro em sequência.
      if (mounted) _nameFocusNode.requestFocus();
    } catch (error) {
      // Antes, um erro aqui (ex.: falta de permissão no Firestore) era
      // engolido silenciosamente — o botão parecia simplesmente não fazer
      // nada. Agora mostra o motivo real pro usuário (25/08/2026).
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Não foi possível cadastrar'),
            content: Text('Ocorreu um erro ao cadastrar o visitante:\n$error'),
            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir visitante'),
        content: const Text('Tem certeza que deseja excluir este cadastro?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(visitorRepositoryProvider).deleteVisitor(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canRegister = profile?.canRegisterVisitors ?? false;
    final canViewDetails = profile?.canViewVisitorDetails ?? false;
    final canViewSummaries = profile?.canViewVisitorSummaries ?? false;
    // Recepção e Pastor leem a mesma coleção completa (`visitors`) — só quem
    // tem exclusivamente o papel Dirigentes cai na coleção resumida sem
    // telefone, ver doc comment da classe.
    final canReadFull = canRegister || canViewDetails;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Recepção'),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (canRegister) ...[
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        errorText: _nameError,
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Telefone (opcional)',
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _churchController,
                      decoration: InputDecoration(
                        labelText: 'Igreja (opcional)',
                        hintText: 'Deixe em branco se não frequenta nenhuma',
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Primeira visita', style: TextStyle(color: context.textPrimary)),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                        color: Theme.of(context).cardColor,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              value: _firstVisit,
                              onChanged: (_) => setState(() => _firstVisit = true),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text('Sim', style: TextStyle(color: context.textPrimary)),
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              value: !_firstVisit,
                              onChanged: (_) => setState(() => _firstVisit = false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text('Não', style: TextStyle(color: context.textPrimary)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Cadastrar visitante'),
                    ),
                    const SizedBox(height: 24),
                    Divider(color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(height: 8),
                  ],
                  if (canReadFull || canViewSummaries) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Visitantes de hoje',
                          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchivedVisitorsPage())),
                          icon: const Icon(Icons.archive_outlined, size: 18),
                          label: const Text('Arquivados'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (canReadFull) _FullVisitorList(canDelete: canRegister, onDelete: _delete) else const _SummaryVisitorList(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullVisitorList extends ConsumerWidget {
  const _FullVisitorList({required this.canDelete, required this.onDelete});

  final bool canDelete;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitorsAsync = ref.watch(visitorsProvider);

    return visitorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
      data: (visitors) {
        if (visitors.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Nenhum visitante hoje.', style: TextStyle(color: context.textSecondary)),
            ),
          );
        }
        return Column(
          children: [
            for (final visitor in visitors) VisitorFullTile(visitor: visitor, onDelete: canDelete ? onDelete : null),
          ],
        );
      },
    );
  }
}

class _SummaryVisitorList extends ConsumerWidget {
  const _SummaryVisitorList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(visitorSummariesProvider);

    return summariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
      data: (summaries) {
        if (summaries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Nenhum visitante hoje.', style: TextStyle(color: context.textSecondary)),
            ),
          );
        }
        return Column(
          children: [
            for (final summary in summaries) VisitorSummaryTile(summary: summary),
          ],
        );
      },
    );
  }
}
