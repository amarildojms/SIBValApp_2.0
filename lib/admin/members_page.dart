import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/member_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha MembersFragment.kt/MembersViewModel.kt: lista de membros (alimenta
/// a tela de Aniversariantes), busca por nome, adicionar/editar/excluir com
/// foto e data de aniversário. Só chega aqui quem tem canManageBirthdays
/// (gate fica no tile do menu Mais).
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<void>(context: context, builder: (_) => const _MemberDialog(existing: null)),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const ScreenTitle('Membros'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Buscar por nome', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
              data: (members) {
                final filtered = _query.trim().isEmpty
                    ? members
                    : members.where((m) => m.name.toLowerCase().contains(_query.toLowerCase())).toList();
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
                      onTap: () => showDialog<void>(context: context, builder: (_) => _MemberDialog(existing: member)),
                      onLongPress: () => _confirmDelete(context, ref, member),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
  late final _dateController = TextEditingController(
    text: widget.existing != null
        ? '${widget.existing!.birthDay.toString().padLeft(2, '0')}/${widget.existing!.birthMonth.toString().padLeft(2, '0')}'
        : '',
  );
  File? _pickedPhoto;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dateController.dispose();
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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final parts = _dateController.text.split('/');
    final day = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    if (name.isEmpty || day < 1 || day > 31 || month < 1 || month > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome e data de aniversário válidos (DD/MM).')),
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
          birthDay: day,
          birthMonth: month,
          photoFile: _pickedPhoto,
          uid: uid,
        );
      } else {
        await repo.update(
          member: widget.existing!,
          name: name,
          email: _emailController.text,
          birthDay: day,
          birthMonth: month,
          photoFile: _pickedPhoto,
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
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'E-mail (opcional)'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Aniversário (DD/MM)'),
              keyboardType: TextInputType.number,
              inputFormatters: [_BirthdayDateFormatter()],
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
