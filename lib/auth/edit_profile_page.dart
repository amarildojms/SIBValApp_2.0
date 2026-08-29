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
import '../util/church_membership_options.dart';
import '../util/photo_picker.dart';
import '../util/scroll_to_save.dart';
import '../widgets/address_fields.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';

/// Tela de edição de perfil aberta a partir do menu "Mais": foto, nome,
/// telefone, endereço e estado civil (dados pessoais). A seção "Dados
/// eclesiásticos" (forma de adesão em diante, incluindo ministérios/cargos)
/// vem do `Member` vinculado (`myMemberProvider`) — `membershipDate` e
/// ministérios/cargos continuam exclusividade do usuário autorizado
/// (Secretaria), editados em Rol de Membros; "Forma de Adesão", "Igreja de
/// origem" e "Data de Batismo" também podem ser preenchidos aqui pelo
/// próprio usuário (29/08/2026, pedido do usuário — antes só a data de
/// batismo tinha esse privilégio).
///
/// `maritalStatus` (estado civil) deixou de fazer parte da seção
/// eclesiástica em 29/08/2026 — virou dado pessoal comum, gravado em
/// `users/{uid}` (`AppUser.maritalStatus`), salvo junto com nome/telefone/
/// endereço pelo botão "Salvar" desta tela.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressKey = GlobalKey<AddressFieldsState>();
  final _originChurchController = TextEditingController();
  final _scrollController = ScrollController();
  File? _pickedPhoto;
  bool _initialized = false;
  bool _memberFieldsInitialized = false;
  bool _saving = false;
  bool _dirty = false;
  String? _maritalStatus;
  String? _admissionForm;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _nameController,
      _phoneController,
      _originChurchController,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _originChurchController.dispose();
    _scrollController.dispose();
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
        content: const Text(
          'Você fez alterações no seu perfil. Deseja salvar antes de sair?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedChangesAction.discard),
            child: const Text('Descartar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UnsavedChangesAction.save),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe seu nome.')));
      return;
    }
    final addressError = _addressKey.currentState!.validate();
    if (addressError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(addressError)));
      return;
    }

    setState(() => _saving = true);
    _scrollController.scrollToSaveButton();
    try {
      final repository = ref.read(userRepositoryProvider);
      final addressDetails = _addressKey.currentState!.value;
      await repository.updateName(uid, name);
      await repository.updateProfileDetails(
        uid: uid,
        phone: _phoneController.text.trim(),
        addressDetails: addressDetails,
        maritalStatus: _maritalStatus ?? '',
      );
      final member = ref.read(myMemberProvider).asData?.value;
      if (member != null) {
        // Mantém o Rol de Membros sincronizado com o que o próprio usuário
        // edita aqui (29/08/2026, pedido do usuário) — antes só
        // admissionForm/originChurch chegavam ao Member; telefone/endereço
        // ficavam presos em `users/{uid}`.
        await ref
            .read(memberRepositoryProvider)
            .updateSelfEditableDetails(
              member.id,
              phone: _phoneController.text.trim(),
              addressDetails: addressDetails,
              admissionForm: _admissionForm ?? '',
              originChurch: _originChurchController.text.trim(),
            );
      }
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
      _maritalStatus = profile.maritalStatus.isNotEmpty
          ? profile.maritalStatus
          : null;
      _initialized = true;
    }
    if (member != null && !_memberFieldsInitialized) {
      _originChurchController.text = member.originChurch;
      _admissionForm = member.admissionForm.isNotEmpty
          ? member.admissionForm
          : null;
      _memberFieldsInitialized = true;
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
                  controller: _scrollController,
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
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                backgroundImage: _pickedPhoto != null
                                    ? FileImage(_pickedPhoto!)
                                    : (profile.photoUrl.isNotEmpty
                                              ? NetworkImage(
                                                  cacheBustedPhotoUrl(
                                                    profile.photoUrl,
                                                    profile.photoUpdatedAt,
                                                  ),
                                                )
                                              : null)
                                          as ImageProvider?,
                                child:
                                    _pickedPhoto == null &&
                                        profile.photoUrl.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: 48,
                                        color: context.textSecondary,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: SibValColors.goldAccent,
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: SibValColors.navyBlueDark,
                                  ),
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
                        decoration: const InputDecoration(
                          labelText: 'Telefone (opcional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Endereço (opcional)',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AddressFields(
                        key: _addressKey,
                        initial: profile.addressDetails,
                        onAnyChange: _markDirty,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _maritalStatus,
                        decoration: const InputDecoration(
                          labelText: 'Estado civil (opcional)',
                        ),
                        items: [
                          for (final option in maritalStatusOptions)
                            DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _maritalStatus = value;
                          _markDirty();
                        }),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Dados eclesiásticos',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data de Membresia e Ministérios são preenchidos pela Secretaria em Rol de '
                        'Membros. Os demais campos abaixo você mesmo pode preencher.',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ReadOnlyField(
                        label: 'Data de Membresia',
                        value: _formatDate(member?.membershipDate),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _admissionForm,
                        decoration: const InputDecoration(
                          labelText: 'Forma de Adesão',
                        ),
                        items: [
                          for (final option in admissionFormOptions)
                            DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ),
                        ],
                        onChanged: member == null
                            ? null
                            : (value) => setState(() {
                                _admissionForm = value;
                                if (value == 'Batismo') {
                                  _originChurchController.text =
                                      'Segunda Igreja Batista em Valparaíso';
                                }
                                _markDirty();
                              }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _originChurchController,
                        enabled: member != null && _admissionForm != 'Batismo',
                        decoration: const InputDecoration(
                          labelText: 'Igreja de origem',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _BaptismDateField(member: member),
                      const SizedBox(height: 16),
                      _ReadOnlyField(
                        label: 'Ministérios e Cargos',
                        value: _ministriesLabel(member?.ministries),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saving ? null : () => _save(uid),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  static String _ministriesLabel(List<MemberMinistry>? ministries) {
    if (ministries == null || ministries.isEmpty) return '—';
    return ministries
        .map(
          (m) => m.cargos.isEmpty
              ? m.ministryName
              : '${m.ministryName} (${m.cargos.join(', ')})',
        )
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

  Future<void> _onPicked(DateTime? date) async {
    final member = widget.member;
    if (member == null || date == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .updateBaptismDate(member.id, date);
      ref.invalidate(myMemberProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    if (_saving) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Data de Batismo',
          suffixIcon: Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        child: Text(
          member?.baptismDate != null
              ? _formatDate(member!.baptismDate)
              : 'Toque para informar',
        ),
      );
    }
    return DateField(
      label: 'Data de Batismo',
      value: member?.baptismDate,
      enabled: member != null,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      onChanged: _onPicked,
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

String _formatDate(DateTime? date) =>
    date != null ? DateFormat('dd/MM/yyyy').format(date) : '—';
