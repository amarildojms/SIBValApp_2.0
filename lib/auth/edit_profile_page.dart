import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/member_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../util/church_membership_options.dart';
import '../widgets/sibval_app_bar.dart';

/// Tela de edição de perfil aberta a partir do menu "Mais". Além de foto e
/// nome, permite completar os campos eclesiásticos opcionais do cadastro
/// (19/08/2026, paridade com `register_page.dart`) — é assim que o % de
/// cadastro mostrado na tela Mais sobe. `membershipDate` é só leitura aqui
/// (vem do `Member` vinculado): só o usuário autorizado (Secretaria) edita,
/// em Rol de Membros.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _originChurchController = TextEditingController();
  final _ministryController = TextEditingController();
  final _churchPositionController = TextEditingController();
  DateTime? _baptismDate;
  String? _admissionForm;
  String? _maritalStatus;
  File? _pickedPhoto;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _pickBaptismDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _baptismDate ?? now,
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (picked != null) setState(() => _baptismDate = picked);
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
        admissionForm: _admissionForm ?? '',
        originChurch: _originChurchController.text.trim(),
        baptismDate: _baptismDate,
        maritalStatus: _maritalStatus ?? '',
        ministry: _ministryController.text.trim(),
        churchPosition: _churchPositionController.text.trim(),
      );
      final photo = _pickedPhoto;
      if (photo != null) {
        await repository.uploadProfilePhoto(uid, photo);
      }
      ref.invalidate(currentUserProfileProvider);
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
    final membershipDate = memberAsync.asData?.value?.membershipDate;

    if (profile != null && !_initialized) {
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _addressController.text = profile.address;
      _originChurchController.text = profile.originChurch;
      _ministryController.text = profile.ministry;
      _churchPositionController.text = profile.churchPosition;
      _baptismDate = profile.baptismDate;
      _admissionForm = profile.admissionForm.isNotEmpty ? profile.admissionForm : null;
      _maritalStatus = profile.maritalStatus.isNotEmpty ? profile.maritalStatus : null;
      _initialized = true;
    }

    return Scaffold(
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
                                  : (profile.photoUrl.isNotEmpty ? NetworkImage(profile.photoUrl) : null)
                                      as ImageProvider?,
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
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Endereço (opcional)'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Dados eclesiásticos (opcional)',
                      style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Membresia',
                        helperText: 'Preenchida pela Secretaria em Rol de Membros',
                        helperMaxLines: 2,
                      ),
                      child: Text(membershipDate != null ? DateFormat('dd/MM/yyyy').format(membershipDate) : '—'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _admissionForm,
                      decoration: const InputDecoration(labelText: 'Forma de Adesão'),
                      items: [
                        for (final option in admissionFormOptions) DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: (value) => setState(() => _admissionForm = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _originChurchController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Igreja de origem'),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickBaptismDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data de Batismo',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(_baptismDate != null ? DateFormat('dd/MM/yyyy').format(_baptismDate!) : ''),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _maritalStatus,
                      decoration: const InputDecoration(labelText: 'Estado civil'),
                      items: [
                        for (final option in maritalStatusOptions) DropdownMenuItem(value: option, child: Text(option)),
                      ],
                      onChanged: (value) => setState(() => _maritalStatus = value),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ministryController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Ministério'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _churchPositionController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Cargo/Função'),
                    ),
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
    );
  }
}
