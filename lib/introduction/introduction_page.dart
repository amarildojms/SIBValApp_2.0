import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/member_repository.dart' show membersProvider;
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../data/visitor_repository.dart';
import '../models/notification.dart';
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import '../util/cpf_phone_input.dart';
import '../util/how_found_church_options.dart';
import '../util/scroll_to_save.dart';
import '../widgets/sibval_app_bar.dart';
import 'archived_visitors_page.dart';
import 'visitor_tiles.dart';

/// Sem equivalente no app nativo — feature nova (24/08/2026, unificada numa
/// só tela em 25/08/2026 a pedido do usuário; papel renomeado de "Recepção"
/// pra "Introdução" depois). Área única "Introdução" — o que cada um vê
/// dentro dela depende do papel (ver
/// `CurrentUserProfile.canRegisterVisitors`/`canViewVisitorSummaries`/
/// `canViewVisitorDetails`, `lib/data/user_repository.dart`):
/// - Introdução: formulário de cadastro + lista completa do que ela mesma
///   cadastrou, com exclusão.
/// - Pastor: lista completa (`visitors`, telefone incluso como link de
///   WhatsApp), só leitura.
/// - Dirigentes (sem Introdução nem Pastor): lista resumida
///   (`visitorSummaries`, nome/igreja/primeira visita, sem telefone), só
///   leitura — é a única que de fato só tem acesso a essa coleção
///   (`firestore.rules`: `visitors` só libera `read` pra Introdução/Pastor).
/// As duas listas só mostram visitantes de hoje — ver `Visitor.isFromToday`/
/// `VisitorRepository.watchAll`/`watchSummaries` (25/08/2026, pedido do
/// usuário: cadastros de dias anteriores "arquivam", saindo da lista sem
/// serem apagados — ver `ArchivedVisitorsPage`, agrupada por data). Ver doc
/// comment de `Visitor`/`VisitorSummary` (`lib/models/visitor.dart`) para o
/// desenho completo de coleções. Cards/selo compartilhados com
/// `ArchivedVisitorsPage` em `visitor_tiles.dart`.
class IntroductionPage extends ConsumerStatefulWidget {
  const IntroductionPage({super.key});

  @override
  ConsumerState<IntroductionPage> createState() => _IntroductionPageState();
}

class _IntroductionPageState extends ConsumerState<IntroductionPage> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _phoneController = TextEditingController();
  final _churchController = TextEditingController();
  final _invitedByController = TextEditingController();
  final _invitedByFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _firstVisit = true;
  bool _sending = false;
  String? _nameError;
  String? _howFoundValue;
  String? _howFoundError;

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
    _invitedByController.dispose();
    _invitedByFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    var hasError = false;
    if (name.isEmpty) {
      hasError = true;
    }
    if (_howFoundValue == null) {
      hasError = true;
    }
    if (hasError) {
      setState(() {
        _nameError = name.isEmpty ? 'Informe o nome do visitante.' : null;
        _howFoundError = _howFoundValue == null ? 'Selecione como conheceu a igreja.' : null;
      });
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _sending = true;
      _nameError = null;
      _howFoundError = null;
    });
    _scrollController.scrollToSaveButton();
    try {
      final howFoundCategory =
          howFoundChurchOptions.firstWhere((o) => o.detail == _howFoundValue).category;
      await ref.read(visitorRepositoryProvider).registerVisitor(
            name: name,
            phone: _phoneController.text.trim(),
            church: _churchController.text.trim(),
            firstVisit: _firstVisit,
            createdByUid: uid,
            howFoundCategory: howFoundCategory,
            howFoundDetail: _howFoundValue!,
            invitedByName: _invitedByController.text.trim(),
          );
      _nameController.clear();
      _phoneController.clear();
      _churchController.clear();
      _invitedByController.clear();
      setState(() {
        _firstVisit = true;
        _howFoundValue = null;
      });
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
    // Introdução e Pastor leem a mesma coleção completa (`visitors`) — só quem
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
            const ScreenTitle('Introdução'),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                    DropdownButtonFormField<String>(
                      initialValue: _howFoundValue,
                      decoration: InputDecoration(
                        labelText: 'Como conheceu a igreja',
                        errorText: _howFoundError,
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: howFoundChurchInvitedByDetail,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/images/icon_sibval.png', width: 18, height: 18),
                              const SizedBox(width: 8),
                              Text(howFoundChurchInvitedByDetail),
                            ],
                          ),
                        ),
                        for (final option in howFoundChurchOptions.where((o) => o.detail != howFoundChurchInvitedByDetail))
                          DropdownMenuItem(value: option.detail, child: Text(option.detail)),
                      ],
                      onChanged: (value) => setState(() {
                        _howFoundValue = value;
                        _howFoundError = null;
                        if (value != howFoundChurchInvitedByDetail) _invitedByController.clear();
                      }),
                    ),
                    if (_howFoundValue == howFoundChurchInvitedByDetail) ...[
                      const SizedBox(height: 12),
                      _InvitedByField(controller: _invitedByController, focusNode: _invitedByFocusNode),
                    ],
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

/// Campo "Convidado por" com sugestão de nomes entre os membros cadastrados
/// (`members`, coleção com leitura aberta a todo autenticado — já cobre
/// "membros/usuários cadastrados", já que todo cadastro de usuário aprovado
/// vira também um `Member`, ver `MemberRepository.upsertFromUser`). Só
/// aparece quando o detalhe de "Como conheceu a igreja" é "Membro da
/// Igreja" (`howFoundChurchInvitedByDetail`).
class _InvitedByField extends ConsumerWidget {
  const _InvitedByField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).asData?.value ?? const [];
    final names = members.map((m) => m.name.trim()).where((n) => n.isNotEmpty).toSet().toList()..sort();

    return Autocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textEditingValue) {
        final query = _normalizeName(textEditingValue.text);
        if (query.isEmpty) return const Iterable<String>.empty();
        return names.where((name) => _normalizeName(name).contains(query)).take(8);
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Convidado por (opcional)',
            hintText: 'Nome de quem convidou',
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
        );
      },
    );
  }
}

const _diacritics = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
const _plainLetters = 'aaaaaeeeeiiiiooooouuuucn';

/// Case/acento-insensível — pra "joao" achar "João" e vice-versa.
String _normalizeName(String value) {
  var result = value.toLowerCase().trim();
  for (var i = 0; i < _diacritics.length; i++) {
    result = result.replaceAll(_diacritics[i], _plainLetters[i]);
  }
  return result;
}
