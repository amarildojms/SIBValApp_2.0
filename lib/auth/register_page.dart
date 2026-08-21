import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/user_repository.dart';
import '../models/address.dart';
import '../theme/app_theme.dart';
import '../util/age.dart';
import '../util/cpf_phone_input.dart';
import '../util/photo_picker.dart';
import '../util/scroll_to_save.dart';
import '../widgets/address_fields.dart';
import '../widgets/date_field.dart';
import '../widgets/google_logo.dart';
import 'complete_google_profile_page.dart';
import 'login_page.dart' show ApprovalResult, resolveApprovalState;
import 'registration_consent_section.dart';

/// Espelha RegisterActivity/RegisterViewModel.kt do app nativo: cadastro fica
/// pendente de aprovação de um admin (ver ManageUsersPage) até poder entrar.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressKey = GlobalKey<AddressFieldsState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _scrollController = ScrollController();
  DateTime? _birthdate;
  DateTime? _baptismDate;
  File? _pickedPhoto;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTermsOfUse = false;
  bool _acceptedPrivacyPolicy = false;
  bool _acceptedCommunications = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await pickAndCropProfilePhoto();
    if (photo != null) {
      setState(() => _pickedPhoto = photo);
    }
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final cpf = _cpfController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final birthdate = _birthdate;

    if (name.isEmpty) {
      _showMessage('Informe seu nome.');
      return;
    }
    if (!CpfValidator.isValid(cpf)) {
      _showMessage('Informe um CPF válido.');
      return;
    }
    if (birthdate == null) {
      _showMessage('Informe sua data de nascimento.');
      return;
    }
    if (ageInYears(birthdate) < minimumRegistrationAge) {
      _showMessage('É preciso ter pelo menos $minimumRegistrationAge anos para se cadastrar.');
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
    if (!_acceptedTermsOfUse || !_acceptedPrivacyPolicy) {
      _showMessage('É preciso aceitar os Termos de Uso e a Política de Privacidade para se cadastrar.');
      return;
    }

    setState(() => _loading = true);
    _scrollController.scrollToSaveButton();
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) {
        _showMessage('Falha ao cadastrar.');
        return;
      }

      final repository = ref.read(userRepositoryProvider);
      await repository.createUserProfile(
        uid: uid,
        name: name,
        email: email,
        birthdate: birthdate,
        cpf: cpf,
        phone: _phoneController.text.trim(),
        addressDetails: _addressKey.currentState!.value,
        baptismDate: _baptismDate,
        privacyPolicyAccepted: _acceptedPrivacyPolicy,
        termsOfUseAccepted: _acceptedTermsOfUse,
        communicationsConsent: _acceptedCommunications,
      );
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
          controller: _scrollController,
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
              Text(
                '* Campos obrigatórios',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome completo *'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [CpfInputFormatter()],
                decoration: const InputDecoration(labelText: 'CPF *'),
              ),
              const SizedBox(height: 16),
              DateField(
                label: 'Data de nascimento *',
                value: _birthdate,
                firstDate: DateTime(DateTime.now().year - 110),
                lastDate: maxBirthdateForAge(minimumRegistrationAge),
                onChanged: (date) => setState(() => _birthdate = date),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail *'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
              ),
              const SizedBox(height: 16),
              Text(
                'Endereço (opcional)',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              AddressFields(key: _addressKey, initial: Address.empty),
              const SizedBox(height: 16),
              DateField(
                label: 'Data de Batismo (opcional)',
                value: _baptismDate,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                onChanged: (date) => setState(() => _baptismDate = date),
              ),
              const SizedBox(height: 24),
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
              RegistrationConsentSection(
                acceptedTerms: _acceptedTermsOfUse,
                acceptedPrivacy: _acceptedPrivacyPolicy,
                acceptedCommunications: _acceptedCommunications,
                enabled: !_loading,
                onTermsChanged: (value) => setState(() => _acceptedTermsOfUse = value),
                onPrivacyChanged: (value) => setState(() => _acceptedPrivacyPolicy = value),
                onCommunicationsChanged: (value) => setState(() => _acceptedCommunications = value),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_loading || !_acceptedTermsOfUse || !_acceptedPrivacyPolicy) ? null : _register,
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
