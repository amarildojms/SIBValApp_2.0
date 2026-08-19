import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/google_logo.dart';
import 'complete_google_profile_page.dart';
import 'login_page.dart' show ApprovalResult, resolveApprovalState;

/// Espelha RegisterActivity/RegisterViewModel.kt do app nativo: cadastro fica
/// pendente de aprovação de um admin (ver ManageUsersPage) até poder entrar.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  DateTime? _birthdate;
  File? _pickedPhoto;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final birthdate = _birthdate;

    if (name.isEmpty) {
      _showMessage('Informe seu nome.');
      return;
    }
    if (birthdate == null) {
      _showMessage('Informe sua data de nascimento.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('E-mail inválido.');
      return;
    }
    if (password.length < 6) {
      _showMessage('A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('As senhas não coincidem.');
      return;
    }

    setState(() => _loading = true);
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) {
        _showMessage('Falha ao cadastrar.');
        return;
      }

      final repository = ref.read(userRepositoryProvider);
      await repository.createUserProfile(uid: uid, name: name, email: email, birthdate: birthdate);
      final photo = _pickedPhoto;
      if (photo != null) {
        await repository.uploadProfilePhoto(uid, photo);
      }

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showMessage('Cadastro enviado! Aguarde a aprovação para entrar.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showMessage(_messageForAuthError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Mesmo fluxo de _loginWithGoogle em login_page.dart — "Entrar com Google"
  /// tem o mesmo efeito em qualquer uma das duas telas.
  Future<void> _registerWithGoogle() async {
    setState(() => _loading = true);
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        _showMessage('Falha ao autenticar com Google.');
        return;
      }

      final googleCredential = GoogleAuthProvider.credential(idToken: idToken);
      final credential = await FirebaseAuth.instance.signInWithCredential(googleCredential);
      final uid = credential.user?.uid;
      if (uid == null) {
        _showMessage('Falha ao autenticar com Google.');
        return;
      }

      if (credential.additionalUserInfo?.isNewUser ?? false) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CompleteGoogleProfilePage(
            uid: uid,
            name: credential.user?.displayName ?? '',
            email: credential.user?.email ?? '',
          ),
        ));
        return;
      }

      final approval = await resolveApprovalState(uid);
      if (!mounted) return;
      switch (approval) {
        case ApprovalResult.approved:
          Navigator.of(context).pop();
        case ApprovalResult.pendingApproval:
          _showMessage('Seu cadastro ainda está aguardando aprovação.');
        case ApprovalResult.rejected:
          _showMessage('Seu cadastro foi rejeitado.');
        case ApprovalResult.blocked:
          _showMessage('Sua conta está bloqueada.');
        case ApprovalResult.accountDeleted:
          _showMessage('Cadastro não encontrado — complete seu perfil no app atual antes de testar aqui.');
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showMessage('Falha ao autenticar com Google.');
      }
    } on FirebaseAuthException catch (_) {
      _showMessage('Falha ao autenticar com Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageForAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'email-already-in-use':
        return 'Já existe uma conta com esse e-mail.';
      case 'weak-password':
        return 'Senha muito fraca.';
      default:
        return 'Falha ao cadastrar. Tente novamente.';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Cadastre-se')),
      body: SafeArea(
        bottom: true,
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    backgroundImage: _pickedPhoto != null ? FileImage(_pickedPhoto!) : null,
                    child: _pickedPhoto == null
                        ? Icon(Icons.person, size: 48, color: context.textSecondary)
                        : null,
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _pickPhoto,
                  child: const Text('Escolher foto'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBirthdate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de nascimento',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _birthdate != null ? DateFormat('dd/MM/yyyy').format(_birthdate!) : '',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirmar senha',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cadastrar'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('ou', style: TextStyle(color: context.textSecondary)),
                  ),
                  Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loading ? null : _registerWithGoogle,
                icon: const GoogleLogo(),
                label: const Text('Entrar com Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
