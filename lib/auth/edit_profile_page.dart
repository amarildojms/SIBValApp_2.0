import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/member_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/member.dart';
import '../theme/app_theme.dart';
import '../util/cache_busted_image.dart';
import '../util/photo_picker.dart';
import '../widgets/sibval_app_bar.dart';

/// Tela de edição de perfil aberta a partir do menu "Mais": foto, nome,
/// telefone e endereço. A seção "Dados eclesiásticos" (forma de adesão em
/// diante, incluindo ministérios/cargos) é só leitura aqui, vinda do
/// `Member` vinculado (`myMemberProvider`) — desde 20/08/2026 é
/// exclusividade do usuário autorizado (Secretaria), editada em Rol de
/// Membros, mesmo padrão que já valia só pra `membershipDate`.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  File? _pickedPhoto;
  bool _initialized = false;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [_nameController, _phoneController, _addressController]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_initialized && !_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickPhoto() async {
    final photo = await pickAndCropProfilePhoto();
    if (photo != null) {
      setState(() {
        _pickedPhoto = photo;
        _dirty = true;
      });
    }
  }

  Future<void> _handlePopAttempt(String? uid) async {
    if (uid == null) {
      Navigator.of(context).pop();
      return;
    }
    final action = await showDialog<_UnsavedChangesAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alterações não salvas'),
        content: const Text('Você fez alterações no seu perfil. Deseja salvar antes de sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_UnsavedChangesAction.discard),
            child: const Text('Descartar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_UnsavedChangesAction.save),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _UnsavedChangesAction.discard:
        Navigator.of(context).pop();
      case _UnsavedChangesAction.save:
        await _save(uid);
      case null:
        break;
    }
  }

  Future<void> _save(String uid) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe seu nome.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.updateName(uid, name);
      await repository.updateProfileDetails(
        uid: uid,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );
      final photo = _pickedPhoto;
      if (photo != null) {
        await repository.uploadProfilePhoto(uid, photo);
      }
      ref.invalidate(currentUserProfileProvider);
      _dirty = false;
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.asData?.value;
    final memberAsync = ref.watch(myMemberProvider);
    final member = memberAsync.asData?.value;

    if (profile != null && !_initialized) {
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _addressController.text = profile.address;
      _initialized = true;
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePopAttempt(uid);
      },
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: profile == null || uid == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ScreenTitle('Editar perfil'),
                      const SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: _pickPhoto,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                backgroundImage: _pickedPhoto != null
                                    ? FileImage(_pickedPhoto!)
                                    : (profile.photoUrl.isNotEmpty
                                        ? NetworkImage(cacheBustedPhotoUrl(profile.photoUrl, profile.photoUpdatedAt))
                                        : null) as ImageProvider?,
                                child: _pickedPhoto == null && profile.photoUrl.isEmpty
                                    ? Icon(Icons.person, size: 48, color: context.textSecondary)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: SibValColors.goldAccent,
                                  child: const Icon(Icons.edit, size: 16, color: SibValColors.navyBlueDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        enabled: false,
                        controller: TextEditingController(text: profile.email),
                        decoration: const InputDecoration(labelText: 'E-mail'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _addressController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Endereço (opcional)'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Dados eclesiásticos',
                        style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Preenchidos pela Secretaria em Rol de Membros.',
                        style: TextStyle(color: context.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      _ReadOnlyField(label: 'Data de Membresia', value: _formatDate(member?.membershipDate)),
                      const SizedBox(height: 16),
                      _ReadOnlyField(label: 'Forma de Adesão', value: _orDash(member?.admissionForm)),
                      const SizedBox(height: 16),
                      _ReadOnlyField(label: 'Igreja de origem', value: _orDash(member?.originChurch)),
                      const SizedBox(height: 16),
                      _BaptismDateField(member: member),
                      const SizedBox(height: 16),
                      _ReadOnlyField(label: 'Estado civil', value: _orDash(member?.maritalStatus)),
                      const SizedBox(height: 16),
                      _ReadOnlyField(label: 'Ministérios e Cargos', value: _ministriesLabel(member?.ministries)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saving ? null : () => _save(uid),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  static String _orDash(String? value) => (value == null || value.isEmpty) ? '—' : value;

  static String _ministriesLabel(List<MemberMinistry>? ministries) {
    if (ministries == null || ministries.isEmpty) return '—';
    return ministries
        .map((m) => m.cargos.isEmpty ? m.ministryName : '${m.ministryName} (${m.cargos.join(', ')})')
        .join('\n');
  }
}

/// Diferente dos demais campos eclesiásticos (só leitura aqui), a data de
/// batismo pode ser preenchida tanto pela Secretaria (em Rol de Membros)
/// quanto pelo próprio usuário — ver `firestore.rules` nativo
/// (`members.baptismDate`) e `MemberRepository.updateBaptismDate`. Só fica
/// editável depois que o cadastro é aprovado e o registro de `Member` existe
/// (`member != null`); antes disso não há onde gravar.
class _BaptismDateField extends ConsumerStatefulWidget {
  const _BaptismDateField({required this.member});

  final Member? member;

  @override
  ConsumerState<_BaptismDateField> createState() => _BaptismDateFieldState();
}

class _BaptismDateFieldState extends ConsumerState<_BaptismDateField> {
  bool _saving = false;

  Future<void> _pickDate() async {
    final member = widget.member;
    if (member == null || _saving) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: member.baptismDate ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(memberRepositoryProvider).updateBaptismDate(member.id, picked);
      ref.invalidate(myMemberProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    return InkWell(
      onTap: member == null ? null : _pickDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Data de Batismo',
          suffixIcon: _saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Icon(member == null ? null : Icons.edit_calendar_outlined, color: context.textSecondary),
        ),
        child: Text(member == null ? '—' : (member.baptismDate != null ? _formatDate(member.baptismDate) : 'Toque para informar')),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value),
    );
  }
}

enum _UnsavedChangesAction { save, discard }

String _formatDate(DateTime? date) => date != null ? DateFormat('dd/MM/yyyy').format(date) : '—';
