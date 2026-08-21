import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/message_repository.dart';
import '../data/ministry_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../util/scroll_to_save.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';

/// Envio de nova mensagem — só admin chega aqui (gate no FAB de
/// `MessagesPage`, espelhando `firestore.rules` nativo `messages.create`).
/// Direciona para todos, usuários específicos e/ou membros de ministérios
/// selecionados (união dos dois); `MessageRepository.send` resolve os uids
/// dos ministérios antes de gravar. Desmarcado por padrão (21/08/2026, a
/// pedido do usuário) — enviar pra todos é uma escolha deliberada, não o
/// padrão.
class MessageFormPage extends ConsumerStatefulWidget {
  const MessageFormPage({super.key});

  @override
  ConsumerState<MessageFormPage> createState() => _MessageFormPageState();
}

class _MessageFormPageState extends ConsumerState<MessageFormPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sendToAll = false;
  bool _isMeeting = false;
  DateTime? _meetingDate;
  TimeOfDay? _meetingTime;
  final _selectedUsers = <AppUser>[];
  final _selectedMinistryIds = <String>{};
  bool _sending = false;
  final _scrollController = ScrollController();

  static final _timeFormat = DateFormat('HH:mm', 'pt_BR');

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime? get _meetingAt {
    final date = _meetingDate;
    final time = _meetingTime;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickMeetingTime() async {
    final now = DateTime.now();
    final picked = await showTimePicker(context: context, initialTime: _meetingTime ?? TimeOfDay.fromDateTime(now));
    if (picked != null) setState(() => _meetingTime = picked);
  }

  Future<void> _pickMinistries(List<Ministry> allMinistries) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MinistryPickerDialog(ministries: allMinistries, initiallySelected: _selectedMinistryIds),
    );
    if (result != null) {
      setState(
        () => _selectedMinistryIds
          ..clear()
          ..addAll(result),
      );
    }
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showMessage('Preencha o título e o texto da mensagem.');
      return;
    }
    if (!_sendToAll && _selectedUsers.isEmpty && _selectedMinistryIds.isEmpty) {
      _showMessage('Selecione ao menos um usuário ou ministério, ou envie para todos.');
      return;
    }
    if (_isMeeting && _meetingAt == null) {
      _showMessage('Selecione a data e hora da reunião.');
      return;
    }

    final uid = ref.read(currentUidProvider);
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (uid == null || profile == null) return;

    setState(() => _sending = true);
    _scrollController.scrollToSaveButton();
    try {
      await ref
          .read(messageRepositoryProvider)
          .send(
            senderUid: uid,
            senderName: profile.shortName,
            title: title,
            body: body,
            sendToAll: _sendToAll,
            targetUserUids: _selectedUsers.map((u) => u.uid).toList(),
            targetMinistryIds: _selectedMinistryIds.toList(),
            isMeeting: _isMeeting,
            meetingAt: _meetingAt,
          );
      ref.invalidate(inboxMessagesProvider);
      if (!mounted) return;
      _showMessage('Mensagem enviada!');
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final ministriesAsync = ref.watch(ministriesProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            const ScreenTitle('Nova mensagem'),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Texto da mensagem', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enviar para todos os usuários'),
              value: _sendToAll,
              onChanged: (value) => setState(() => _sendToAll = value),
            ),
            if (!_sendToAll) ...[
              const SizedBox(height: 12),
              Text(
                'Usuários específicos',
                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              usersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
                data: (users) {
                  final approved = users.where((u) => u.status == UserStatus.approved && !u.isBlocked).toList();
                  return _UserAutocompleteField(
                    users: approved,
                    selected: _selectedUsers,
                    onAdd: (user) => setState(() => _selectedUsers.add(user)),
                  );
                },
              ),
              if (_selectedUsers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final user in _selectedUsers)
                      Chip(
                        label: Text(user.name.isNotEmpty ? user.name : user.email),
                        onDeleted: () => setState(() => _selectedUsers.remove(user)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Ministérios',
                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ministriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
                data: (ministries) {
                  final selectedNames = ministries
                      .where((m) => _selectedMinistryIds.contains(m.id))
                      .map((m) => m.name)
                      .join(', ');
                  return InkWell(
                    onTap: ministries.isEmpty ? null : () => _pickMinistries(ministries),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Selecionar ministérios',
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        enabled: ministries.isNotEmpty,
                      ),
                      child: Text(
                        ministries.isEmpty
                            ? 'Nenhum ministério cadastrado.'
                            : (selectedNames.isEmpty ? 'Nenhum selecionado' : selectedNames),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Marcar como reunião'),
              subtitle: const Text('Agenda a data/hora e lembra os destinatários 1 dia antes e no dia.'),
              value: _isMeeting,
              onChanged: (value) => setState(() => _isMeeting = value),
            ),
            if (_isMeeting) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DateField(
                      label: 'Data da reunião',
                      value: _meetingDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime(DateTime.now().year + 5),
                      onChanged: (date) => setState(() => _meetingDate = date),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickMeetingTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Hora',
                          suffixIcon: Icon(Icons.access_time_outlined),
                        ),
                        child: Text(
                          _meetingTime != null
                              ? _timeFormat.format(DateTime(2000, 1, 1, _meetingTime!.hour, _meetingTime!.minute))
                              : '',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de busca com sugestões (`Autocomplete`) em vez de listar todos os
/// usuários abaixo da caixa — só aparecem opções enquanto o admin digita um
/// nome/e-mail que combina, e usuários já selecionados somem das sugestões.
class _UserAutocompleteField extends StatefulWidget {
  const _UserAutocompleteField({required this.users, required this.selected, required this.onAdd});

  final List<AppUser> users;
  final List<AppUser> selected;
  final ValueChanged<AppUser> onAdd;

  @override
  State<_UserAutocompleteField> createState() => _UserAutocompleteFieldState();
}

class _UserAutocompleteFieldState extends State<_UserAutocompleteField> {
  TextEditingController? _fieldController;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<AppUser>(
      displayStringForOption: (u) => u.name.isNotEmpty ? u.name : u.email,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<AppUser>.empty();
        final selectedUids = widget.selected.map((u) => u.uid).toSet();
        return widget.users
            .where(
              (u) =>
                  !selectedUids.contains(u.uid) &&
                  (u.name.toLowerCase().contains(query) || u.email.toLowerCase().contains(query)),
            )
            .take(8);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _fieldController = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: 'Adicionar usuário', prefixIcon: Icon(Icons.search)),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final user in options)
                    ListTile(
                      title: Text(user.name.isNotEmpty ? user.name : user.email),
                      subtitle: user.name.isNotEmpty ? Text(user.email) : null,
                      onTap: () => onSelected(user),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      onSelected: (user) {
        widget.onAdd(user);
        _fieldController?.clear();
      },
    );
  }
}

/// Mesmo padrão de `members_page.dart` `_MinistryPickerDialog` — checklist em
/// diálogo, ministérios já em ordem alfabética (`ministriesProvider`).
class _MinistryPickerDialog extends StatefulWidget {
  const _MinistryPickerDialog({required this.ministries, required this.initiallySelected});

  final List<Ministry> ministries;
  final Set<String> initiallySelected;

  @override
  State<_MinistryPickerDialog> createState() => _MinistryPickerDialogState();
}

class _MinistryPickerDialogState extends State<_MinistryPickerDialog> {
  late final _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar ministérios'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final ministry in widget.ministries)
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: _selected.contains(ministry.id),
                title: Text(ministry.name),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _selected.add(ministry.id);
                  } else {
                    _selected.remove(ministry.id);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(context).pop(_selected), child: const Text('Confirmar')),
      ],
    );
  }
}
