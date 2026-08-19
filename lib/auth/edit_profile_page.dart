import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Tela de edição de perfil aberta a partir do menu "Mais" — por ora só foto
/// e nome; outros dados (telefone, endereço etc.) entram em fases futuras.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _nameController = TextEditingController();
  File? _pickedPhoto;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
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

    if (profile != null && !_initialized) {
      _nameController.text = profile.name;
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
