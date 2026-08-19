import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/user_repository.dart';
import '../theme/app_theme.dart';

/// Espelha app/src/main/java/com/sibval/app/ui/auth/CompleteGoogleProfileActivity.kt
/// (+ CompleteGoogleProfileViewModel.kt): tela mostrada quando um login/cadastro
/// com Google é de uma conta nova (`isNewUser`) — falta coletar data de
/// nascimento (obrigatória) e foto (opcional) antes de criar `users/{uid}`
/// como pendente de aprovação, igual ao cadastro por e-mail.
class CompleteGoogleProfilePage extends ConsumerStatefulWidget {
  const CompleteGoogleProfilePage({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
  });

  final String uid;
  final String name;
  final String email;

  @override
  ConsumerState<CompleteGoogleProfilePage> createState() => _CompleteGoogleProfilePageState();
}

class _CompleteGoogleProfilePageState extends ConsumerState<CompleteGoogleProfilePage> {
  DateTime? _birthdate;
  File? _pickedPhoto;
  bool _loading = false;

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

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _birthdate = picked);
    }
  }

  Future<void> _finish() async {
    final birthdate = _birthdate;
    if (birthdate == null) {
      _showMessage('Selecione sua data de nascimento.');
      return;
    }

    setState(() => _loading = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.createUserProfile(
        uid: widget.uid,
        name: widget.name,
        email: widget.email,
        birthdate: birthdate,
      );
      final photo = _pickedPhoto;
      if (photo != null) {
        await repository.uploadProfilePhoto(widget.uid, photo);
      }
      if (!mounted) return;
      await _showPendingApprovalDialog();
    } catch (_) {
      if (mounted) _showMessage('Não foi possível criar a conta.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPendingApprovalDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cadastro enviado!'),
        content: const Text(
          'Sua conta foi criada e está aguardando aprovação de um administrador. '
          'Você poderá entrar assim que for aprovado.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static const _fieldStyle = TextStyle(color: Colors.white);
  static const _fieldDecoration = InputDecoration(
    labelText: 'Data de nascimento',
    labelStyle: TextStyle(color: Colors.white70),
    suffixIcon: Icon(Icons.calendar_today_outlined, color: Colors.white70),
    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: SibValColors.goldAccent)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SibValColors.navyBlue,
      appBar: AppBar(backgroundColor: SibValColors.navyBlue, foregroundColor: Colors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Complete seu cadastro',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Só falta a sua data de nascimento para participar dos aniversariantes da igreja.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white24,
                  backgroundImage: _pickedPhoto != null ? FileImage(_pickedPhoto!) : null,
                  child: _pickedPhoto == null ? const Icon(Icons.person, size: 44, color: Colors.white70) : null,
                ),
              ),
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: SibValColors.goldAccent),
                  onPressed: _loading ? null : _pickPhoto,
                  child: const Text('Escolher foto (opcional)'),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _loading ? null : _pickBirthdate,
                child: InputDecorator(
                  decoration: _fieldDecoration,
                  child: Text(
                    _birthdate != null ? DateFormat('dd/MM/yyyy').format(_birthdate!) : '',
                    style: _fieldStyle,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SibValColors.goldAccent,
                  foregroundColor: SibValColors.navyBlueDark,
                ),
                onPressed: _loading ? null : _finish,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Concluir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
