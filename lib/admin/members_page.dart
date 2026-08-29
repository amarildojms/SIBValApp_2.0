import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/member_repository.dart';
import '../data/ministry_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/address.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../util/cache_busted_image.dart';
import '../util/church_membership_options.dart';
import '../util/cpf_phone_input.dart';
import '../util/masked_input.dart';
import '../widgets/address_fields.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha MembersFragment.kt/MembersViewModel.kt: lista de membros (alimenta
/// a tela de Aniversariantes), busca por nome, adicionar/editar/excluir com
/// foto e data de aniversário. Ampliada em 19/08/2026: a lista passa a ser
/// visível para qualquer autenticado (regra `read: if request.auth != null`
/// já liberada no `firestore.rules` nativo) — só quem tem
/// `canManageBirthdays` (papel Secretaria/admin) vê o filtro de cadastros
/// incompletos e pode adicionar/editar/excluir; os demais têm acesso só de
/// leitura.
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

/// Um membro conta como "cadastro incompleto" se faltar qualquer dado da
/// seção eclesiástica preenchida pela Secretaria — data de membresia, forma
/// de adesão, igreja de origem, data de batismo ou estado civil. Ministérios
/// e cargos ficam de fora de propósito (20/08/2026): é legítimo um membro
/// não participar de nenhum ministério.
bool _hasIncompleteEcclesiasticalData(Member m) {
  return m.membershipDate == null ||
      m.admissionForm.isEmpty ||
      m.originChurch.isEmpty ||
      m.baptismDate == null ||
      m.maritalStatus.isEmpty;
}

class _MembersPageState extends ConsumerState<MembersPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _onlyIncomplete = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final canManage = profileAsync.asData?.value?.canManageBirthdays ?? false;
    final incompleteCount = (membersAsync.asData?.value ?? const <Member>[])
        .where(_hasIncompleteEcclesiasticalData)
        .length;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: canManage
          ? FloatingActionButton(
              heroTag: 'members_fab',
              onPressed: () => showDialog<void>(context: context, builder: (_) => const _MemberDialog(existing: null)),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Rol de Membros'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(labelText: 'Buscar por nome ou CPF', prefixIcon: Icon(Icons.search)),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (canManage)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Badge(
                  label: Text('$incompleteCount'),
                  isLabelVisible: incompleteCount > 0,
                  alignment: AlignmentDirectional.topEnd,
                  child: FilterChip(
                    label: const Text('Cadastros incompletos (dados eclesiásticos)'),
                    selected: _onlyIncomplete,
                    onSelected: (value) => setState(() => _onlyIncomplete = value),
                  ),
                ),
              ),
            Expanded(
              child: membersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
                ),
                data: (members) {
                  var filtered = _query.trim().isEmpty
                      ? members
                      : members.where((m) {
                          final query = _query.toLowerCase();
                          final queryDigits = _query.replaceAll(RegExp(r'\D'), '');
                          final matchesName = m.name.toLowerCase().contains(query);
                          final matchesCpf = queryDigits.isNotEmpty && m.cpf.contains(queryDigits);
                          return matchesName || matchesCpf;
                        }).toList();
                  if (canManage && _onlyIncomplete) {
                    filtered = filtered.where(_hasIncompleteEcclesiasticalData).toList();
                  }
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('Nenhum membro encontrado.', style: TextStyle(color: context.textSecondary)),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      final dateLabel =
                          '${member.birthDay.toString().padLeft(2, '0')}/${member.birthMonth.toString().padLeft(2, '0')}';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: member.photoUrl.isNotEmpty
                              ? NetworkImage(cacheBustedPhotoUrl(member.photoUrl, member.photoUpdatedAt))
                              : null,
                          child: member.photoUrl.isEmpty ? const Icon(Icons.cake_outlined) : null,
                        ),
                        title: Text(member.name, style: TextStyle(color: context.textPrimary)),
                        // Quem só visualiza (sem `canManageBirthdays`) vê
                        // apenas nome, foto e aniversário — nada de e-mail
                        // (29/08/2026, pedido do usuário). Quem gerencia
                        // continua vendo o e-mail junto, útil pra achar
                        // duplicidade/contato.
                        subtitle: Text(
                          canManage && member.email.isNotEmpty
                              ? '$dateLabel • ${member.email}'
                              : dateLabel,
                          style: TextStyle(color: context.textSecondary),
                        ),
                        trailing: canManage && _hasIncompleteEcclesiasticalData(member)
                            ? const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber)
                            : null,
                        onTap: canManage
                            ? () => showDialog<void>(
                                context: context,
                                builder: (_) => _MemberDialog(existing: member),
                              )
                            : null,
                        onLongPress: canManage ? () => _confirmDelete(context, ref, member) : null,
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Member member) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir membro'),
        content: Text('Tem certeza que deseja excluir "${member.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(memberRepositoryProvider).delete(member).then((_) => ref.invalidate(membersProvider));
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _MemberDialog extends ConsumerStatefulWidget {
  const _MemberDialog({required this.existing});

  final Member? existing;

  @override
  ConsumerState<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends ConsumerState<_MemberDialog> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _emailController = TextEditingController(text: widget.existing?.email ?? '');
  late final _cpfController = TextEditingController(
    text: CpfInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: widget.existing?.cpf ?? ''))
        .text,
  );
  late final _dateController = TextEditingController(
    text: widget.existing != null
        ? '${widget.existing!.birthDay.toString().padLeft(2, '0')}/${widget.existing!.birthMonth.toString().padLeft(2, '0')}'
        : '',
  );
  late final _phoneController = TextEditingController(
    text: PhoneInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: widget.existing?.phone ?? ''))
        .text,
  );
  final _addressKey = GlobalKey<AddressFieldsState>();
  late final _originChurchController = TextEditingController(text: widget.existing?.originChurch ?? '');
  late DateTime? _membershipDate = widget.existing?.membershipDate;
  late DateTime? _baptismDate = widget.existing?.baptismDate;
  late String? _admissionForm = (widget.existing?.admissionForm ?? '').isNotEmpty
      ? widget.existing!.admissionForm
      : null;
  late String? _maritalStatus = (widget.existing?.maritalStatus ?? '').isNotEmpty
      ? widget.existing!.maritalStatus
      : null;
  late final List<_SelectedMinistry> _selectedMinistries = [
    for (final m in widget.existing?.ministries ?? const <MemberMinistry>[])
      _SelectedMinistry(ministryId: m.ministryId, ministryName: m.ministryName, cargos: {...m.cargos}),
  ];
  File? _pickedPhoto;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _dateController.dispose();
    _phoneController.dispose();
    _originChurchController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (picked != null) {
      setState(() => _pickedPhoto = File(picked.path));
    }
  }

  Future<void> _pickMinistries() async {
    final allMinistries = _cachedMinistries;
    final selectedIds = {for (final m in _selectedMinistries) m.ministryId};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MinistryPickerDialog(ministries: allMinistries, initiallySelected: selectedIds),
    );
    if (result == null) return;
    setState(() {
      _selectedMinistries.removeWhere((m) => !result.contains(m.ministryId));
      for (final id in result) {
        if (_selectedMinistries.any((m) => m.ministryId == id)) continue;
        final ministry = allMinistries.firstWhere((m) => m.id == id);
        _selectedMinistries.add(_SelectedMinistry(ministryId: ministry.id, ministryName: ministry.name, cargos: {}));
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final parts = _dateController.text.split('/');
    final day = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final cpf = _cpfController.text;
    if (name.isEmpty || day < 1 || day > 31 || month < 1 || month > 12) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Preencha nome e data de nascimento válidos (DD/MM).')));
      return;
    }
    if (!CpfValidator.isValid(cpf)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um CPF válido.')));
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(memberRepositoryProvider);
    final uid = ref.read(currentUidProvider) ?? '';
    final ministries = [
      for (final m in _selectedMinistries)
        MemberMinistry(ministryId: m.ministryId, ministryName: m.ministryName, cargos: m.cargos.toList()),
    ];
    try {
      if (widget.existing == null) {
        await repo.create(
          name: name,
          email: _emailController.text,
          cpf: cpf,
          birthDay: day,
          birthMonth: month,
          photoFile: _pickedPhoto,
          uid: uid,
          phone: _phoneController.text.trim(),
          addressDetails: _addressKey.currentState!.value,
          membershipDate: _membershipDate,
          admissionForm: _admissionForm ?? '',
          originChurch: _originChurchController.text.trim(),
          baptismDate: _baptismDate,
          maritalStatus: _maritalStatus ?? '',
          ministries: ministries,
        );
      } else {
        await repo.update(
          member: widget.existing!,
          name: name,
          email: _emailController.text,
          cpf: cpf,
          birthDay: day,
          birthMonth: month,
          photoFile: _pickedPhoto,
          phone: _phoneController.text.trim(),
          addressDetails: _addressKey.currentState!.value,
          membershipDate: _membershipDate,
          admissionForm: _admissionForm ?? '',
          originChurch: _originChurchController.text.trim(),
          baptismDate: _baptismDate,
          maritalStatus: _maritalStatus ?? '',
          ministries: ministries,
        );
      }
      ref.invalidate(membersProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Snapshot mais recente de `ministriesProvider`, atualizado a cada build
  /// (que já observa o provider) — usado por `_pickMinistries` pra não
  /// depender de um `ref.read` que pode não ter os dados carregados ainda.
  List<Ministry> _cachedMinistries = const [];

  @override
  Widget build(BuildContext context) {
    _cachedMinistries = ref.watch(ministriesProvider).asData?.value ?? _cachedMinistries;

    ImageProvider? photoProvider;
    if (_pickedPhoto != null) {
      photoProvider = FileImage(_pickedPhoto!);
    } else if ((widget.existing?.photoUrl ?? '').isNotEmpty) {
      photoProvider = NetworkImage(cacheBustedPhotoUrl(widget.existing!.photoUrl, widget.existing!.photoUpdatedAt));
    }
    // A foto de quem já tem conta (linkedUid) vem sempre do perfil do próprio
    // usuário (sincronizada pela Cloud Function `onUserPhotoUpdated`) — só é
    // editável aqui pra quem foi cadastrado manualmente e ainda não tem conta.
    final hasLinkedAccount = (widget.existing?.linkedUid ?? '').isNotEmpty;

    return AlertDialog(
      title: Text(widget.existing == null ? 'Adicionar membro' : 'Editar membro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: hasLinkedAccount ? null : _pickPhoto,
              child: CircleAvatar(
                radius: 36,
                backgroundImage: photoProvider,
                child: photoProvider == null ? const Icon(Icons.camera_alt_outlined) : null,
              ),
            ),
            if (hasLinkedAccount) ...[
              const SizedBox(height: 4),
              Text(
                'Foto sincronizada do perfil do usuário',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),
            Text('* Campos obrigatórios', style: TextStyle(color: context.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cpfController,
              decoration: const InputDecoration(labelText: 'CPF *'),
              keyboardType: TextInputType.number,
              inputFormatters: [CpfInputFormatter()],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Data de nascimento (DD/MM) *'),
              keyboardType: TextInputType.number,
              inputFormatters: [_BirthdayDateFormatter()],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-mail (opcional)'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneInputFormatter()],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Endereço (opcional)',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            AddressFields(key: _addressKey, initial: widget.existing?.addressDetails ?? Address.empty),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Dados eclesiásticos',
                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            DateField(
              label: 'Data de Membresia',
              value: _membershipDate,
              firstDate: DateTime(DateTime.now().year - 110),
              lastDate: DateTime.now(),
              onChanged: (date) => setState(() => _membershipDate = date),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _admissionForm,
              decoration: const InputDecoration(labelText: 'Forma de Adesão'),
              items: [for (final option in admissionFormOptions) DropdownMenuItem(value: option, child: Text(option))],
              onChanged: (value) => setState(() {
                _admissionForm = value;
                if (value == 'Batismo') {
                  _originChurchController.text = 'Segunda Igreja Batista em Valparaíso';
                }
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _originChurchController,
              enabled: _admissionForm != 'Batismo',
              decoration: const InputDecoration(labelText: 'Igreja de origem'),
            ),
            const SizedBox(height: 8),
            DateField(
              label: 'Data de Batismo',
              value: _baptismDate,
              firstDate: DateTime(DateTime.now().year - 110),
              lastDate: DateTime.now(),
              onChanged: (date) => setState(() => _baptismDate = date),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _maritalStatus,
              decoration: const InputDecoration(labelText: 'Estado civil'),
              items: [for (final option in maritalStatusOptions) DropdownMenuItem(value: option, child: Text(option))],
              onChanged: (value) => setState(() => _maritalStatus = value),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ministérios e Cargos',
                style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickMinistries,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar ministério'),
              ),
            ),
            for (final selected in _selectedMinistries) _buildMinistryCard(context, selected),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }

  /// Card de um ministério selecionado: nome + botão remover, e os cargos
  /// disponíveis naquele ministério (fonte viva: `ministriesProvider`, não
  /// congelada no momento da seleção) como `FilterChip` — marcar/desmarcar
  /// alterna se o membro exerce aquele cargo. É a resposta direta ao pedido
  /// "selecionar ministério → marcar os cargos que exerce".
  Widget _buildMinistryCard(BuildContext context, _SelectedMinistry selected) {
    final availableCargos = _cachedMinistries
        .firstWhere(
          (m) => m.id == selected.ministryId,
          orElse: () => Ministry(id: selected.ministryId, name: selected.ministryName, cargos: const []),
        )
        .cargos;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    selected.ministryName,
                    style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remover ministério',
                  onPressed: () => setState(() => _selectedMinistries.remove(selected)),
                ),
              ],
            ),
            if (availableCargos.isEmpty)
              Text('Nenhum cargo cadastrado para este ministério.', style: TextStyle(color: context.textSecondary))
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final cargo in availableCargos)
                    FilterChip(
                      label: Text(cargo),
                      selected: selected.cargos.contains(cargo),
                      onSelected: (value) => setState(() {
                        if (value) {
                          selected.cargos.add(cargo);
                        } else {
                          selected.cargos.remove(cargo);
                        }
                      }),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado local de um ministério selecionado no `_MemberDialog`, com os
/// cargos marcados para o membro dentro dele.
class _SelectedMinistry {
  _SelectedMinistry({required this.ministryId, required this.ministryName, required this.cargos});

  final String ministryId;
  final String ministryName;
  final Set<String> cargos;
}

/// Diálogo de checklist pra escolher quais ministérios o membro participa
/// (`_MemberDialog._pickMinistries`) — os cargos de cada um são marcados
/// depois, inline no formulário (`_buildMinistryCard`).
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
        child: widget.ministries.isEmpty
            ? const Text('Nenhum ministério cadastrado ainda.')
            : ListView(
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

/// Espelha DateMaskTextWatcher (MembersFragment.kt): só dígitos, insere a
/// barra depois do dia automaticamente.
class _BirthdayDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = digitsAfterEdit(oldValue, newValue);
    final trimmed = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = trimmed.length > 2 ? '${trimmed.substring(0, 2)}/${trimmed.substring(2)}' : trimmed;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
