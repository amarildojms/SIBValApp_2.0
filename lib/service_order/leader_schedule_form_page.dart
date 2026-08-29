import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/leader_schedule_repository.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';
import '../models/leader_schedule.dart';
import '../theme/app_theme.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Cadastro/edição de uma entrada da Escala de Dirigentes — só o
/// Pastor/admin (`canManageLeaderSchedule`) chega aqui com os campos
/// habilitados; Dirigentes abre a mesma tela em modo somente-leitura
/// (`readOnly: true`, sem botão Salvar/Excluir) a partir de
/// `LeaderScheduleListPage`.
class LeaderScheduleFormPage extends ConsumerStatefulWidget {
  const LeaderScheduleFormPage({
    super.key,
    this.editing,
    this.readOnly = false,
  });

  final LeaderScheduleEntry? editing;
  final bool readOnly;

  @override
  ConsumerState<LeaderScheduleFormPage> createState() =>
      _LeaderScheduleFormPageState();
}

class _LeaderScheduleFormPageState
    extends ConsumerState<LeaderScheduleFormPage> {
  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  DateTime? _date;
  String _leaderUid = '';
  String _leaderName = '';
  late final TextEditingController _themeController;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _date = editing.dateTime;
      _leaderUid = editing.leaderUid;
      _leaderName = editing.leaderName;
    } else {
      _date = _nextOrCurrentSunday(DateTime.now());
    }
    _themeController = TextEditingController(text: editing?.theme ?? '');
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  static DateTime _nextOrCurrentSunday(DateTime from) {
    final d = DateTime(from.year, from.month, from.day);
    return d.add(Duration(days: (7 - d.weekday) % 7));
  }

  Future<void> _pickLeader() async {
    final selected = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LeaderPickerSheet(),
    );
    if (selected != null) {
      setState(() {
        _leaderUid = selected.uid;
        _leaderName = selected.name;
      });
    }
  }

  Future<void> _save() async {
    final date = _date;
    if (date == null || _leaderUid.isEmpty) return;
    setState(() => _saving = true);
    final entry = LeaderScheduleEntry(
      id: '',
      dateTime: DateTime(date.year, date.month, date.day, 19, 0),
      leaderUid: _leaderUid,
      leaderName: _leaderName,
      theme: _themeController.text.trim(),
    );
    try {
      final repo = ref.read(leaderScheduleRepositoryProvider);
      if (_isEditing) {
        await repo.update(widget.editing!.id, entry);
      } else {
        await repo.create(entry);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir escala'),
        content: Text(
          'Tem certeza que deseja excluir a escala de ${_dateFormat.format(editing.dateTime)}?',
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
    if (confirm != true) return;
    await ref.read(leaderScheduleRepositoryProvider).delete(editing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _date != null && _leaderUid.isNotEmpty;
    return Scaffold(
      appBar: SibValAppBar(
        isHome: false,
        actions: [
          if (_isEditing && !widget.readOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle(
              widget.readOnly
                  ? 'Escala de Dirigentes'
                  : (_isEditing ? 'Editar Escala' : 'Nova Escala'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  DateField(
                    label: 'Data do culto',
                    value: _date,
                    enabled: !widget.readOnly,
                    firstDate: DateTime(DateTime.now().year - 1),
                    lastDate: DateTime(DateTime.now().year + 3),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (date) => setState(() => _date = date),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dirigente escalado',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: widget.readOnly ? null : _pickLeader,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        suffixIcon: widget.readOnly
                            ? null
                            : const Icon(Icons.person_search_outlined),
                      ),
                      child: Text(
                        _leaderName.isEmpty ? 'Toque para selecionar' : _leaderName,
                        style: TextStyle(
                          color: _leaderName.isEmpty
                              ? context.textSecondary
                              : context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tema do culto',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _themeController,
                    enabled: !widget.readOnly,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Opcional',
                    ),
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 18,
                          ),
                        ),
                        onPressed: (_saving || !canSave) ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salvar'),
                      ),
                    ),
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

/// Bottom sheet de seleção do dirigente escalado — candidatos são usuários
/// aprovados com o papel Dirigentes ou admin (28/08/2026, pedido do usuário
/// implícito: só quem pode de fato assumir uma ordem de culto depois faz
/// sentido aparecer aqui, mesmo critério de `isDirigentes()` no
/// `firestore.rules` nativo).
class _LeaderPickerSheet extends ConsumerStatefulWidget {
  const _LeaderPickerSheet();

  @override
  ConsumerState<_LeaderPickerSheet> createState() => _LeaderPickerSheetState();
}

class _LeaderPickerSheetState extends ConsumerState<_LeaderPickerSheet> {
  String _query = '';

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
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecionar dirigente',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar por nome',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
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
                          'Nenhum dirigente encontrado.',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        return ListTile(
                          title: Text(
                            user.name,
                            style: TextStyle(color: context.textPrimary),
                          ),
                          onTap: () => Navigator.of(context).pop(user),
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
