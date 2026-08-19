import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/member_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../util/church_membership_options.dart';
import '../util/cpf_phone_input.dart';
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
              decoration: const InputDecoration(labelText: 'Buscar por nome', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: FilterChip(
                label: const Text('Cadastros incompletos (sem data de membresia)'),
                selected: _onlyIncomplete,
                onSelected: (value) => setState(() => _onlyIncomplete = value),
              ),
            ),
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
              data: (members) {
                var filtered = _query.trim().isEmpty
                    ? members
                    : members.where((m) => m.name.toLowerCase().contains(_query.toLowerCase())).toList();
                if (canManage && _onlyIncomplete) {
                  filtered = filtered.where((m) => m.membershipDate == null).toList();
                }
                if (filtered.isEmpty) {
                  return Center(child: Text('Nenhum membro encontrado.', style: TextStyle(color: context.textSecondary)));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final member = filtered[index];
                    final dateLabel =
                        '${member.birthDay.toString().padLeft(2, '0')}/${member.birthMonth.toString().padLeft(2, '0')}';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
                        child: member.photoUrl.isEmpty ? const Icon(Icons.cake_outlined) : null,
                      ),
                      title: Text(member.name, style: TextStyle(color: context.textPrimary)),
                      subtitle: Text(
                        member.email.isNotEmpty ? '$dateLabel • ${member.email}' : dateLabel,
                        style: TextStyle(color: context.textSecondary),
                      ),
                      trailing: canManage && member.membershipDate == null
                          ? const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber)
                          : null,
                      onTap: canManage
                          ? () => showDialog<void>(context: context, builder: (_) => _MemberDialog(existing: member))
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
  late final _addressController = TextEditingController(text: widget.existing?.address ?? '');
  late final _originChurchController = TextEditingController(text: widget.existing?.originChurch ?? '');
  late final _ministryController = TextEditingController(text: widget.existing?.ministry ?? '');
  late final _churchPositionController = TextEditingController(text: widget.existing?.churchPosition ?? '');
  late DateTime? _membershipDate = widget.existing?.membershipDate;
  late DateTime? _baptismDate = widget.existing?.baptismDate;
  late String? _admissionForm = (widget.existing?.admissionForm ?? '').isNotEmpty ? widget.existing!.admissionForm : null;
  late String? _maritalStatus = (widget.existing?.maritalStatus ?? '').isNotEmpty ? widget.existing!.maritalStatus : null;
  File? _pickedPhoto;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _dateController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _originChurchController.dispose();
    _ministryController.dispose();
    _churchPositionController.dispose();
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

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final parts = _dateController.text.split('/');
    final day = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final cpf = _cpfController.text;
    if (name.isEmpty || day < 1 || day > 31 || month < 1 || month > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome e data de nascimento válidos (DD/MM).')),
      );
      return;
    }
    if (!CpfValidator.isValid(cpf)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um CPF válido.')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(memberRepositoryProvider);
    final uid = ref.read(currentUidProvider) ?? '';
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
          address: _addressController.text.trim(),
          membershipDate: _membershipDate,
          admissionForm: _admissionForm ?? '',
          originChurch: _originChurchController.text.trim(),
          baptismDate: _baptismDate,
          maritalStatus: _maritalStatus ?? '',
          ministry: _ministryController.text.trim(),
          churchPosition: _churchPositionController.text.trim(),
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
          address: _addressController.text.trim(),
          membershipDate: _membershipDate,
          admissionForm: _admissionForm ?? '',
          originChurch: _originChurchController.text.trim(),
          baptismDate: _baptismDate,
          maritalStatus: _maritalStatus ?? '',
          ministry: _ministryController.text.trim(),
          churchPosition: _churchPositionController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    ImageProvider? photoProvider;
    if (_pickedPhoto != null) {
      photoProvider = FileImage(_pickedPhoto!);
    } else if ((widget.existing?.photoUrl ?? '').isNotEmpty) {
      photoProvider = NetworkImage(widget.existing!.photoUrl);
    }

    return AlertDialog(
      title: Text(widget.existing == null ? 'Adicionar membro' : 'Editar membro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 36,
                backgroundImage: photoProvider,
                child: photoProvider == null ? const Icon(Icons.camera_alt_outlined) : null,
              ),
            ),
            const SizedBox(height: 16),
            Text('* Campos obrigatórios', style: TextStyle(color: context.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome *')),
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
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Endereço (opcional)'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Dados eclesiásticos', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickDate(_membershipDate, (date) => setState(() => _membershipDate = date)),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Membresia',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_membershipDate != null ? DateFormat('dd/MM/yyyy').format(_membershipDate!) : ''),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _admissionForm,
              decoration: const InputDecoration(labelText: 'Forma de Adesão'),
              items: [
                for (final option in admissionFormOptions) DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (value) => setState(() => _admissionForm = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _originChurchController,
              decoration: const InputDecoration(labelText: 'Igreja de origem'),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickDate(_baptismDate, (date) => setState(() => _baptismDate = date)),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Batismo',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_baptismDate != null ? DateFormat('dd/MM/yyyy').format(_baptismDate!) : ''),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _maritalStatus,
              decoration: const InputDecoration(labelText: 'Estado civil'),
              items: [
                for (final option in maritalStatusOptions) DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (value) => setState(() => _maritalStatus = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ministryController,
              decoration: const InputDecoration(labelText: 'Ministério'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _churchPositionController,
              decoration: const InputDecoration(labelText: 'Cargo/Função'),
            ),
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
}

/// Espelha DateMaskTextWatcher (MembersFragment.kt): só dígitos, insere a
/// barra depois do dia automaticamente.
class _BirthdayDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = trimmed.length > 2 ? '${trimmed.substring(0, 2)}/${trimmed.substring(2)}' : trimmed;
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
