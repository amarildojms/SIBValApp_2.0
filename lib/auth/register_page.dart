import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../util/cpf_phone_input.dart';
import '../widgets/google_logo.dart';
import 'complete_google_profile_page.dart';
import 'login_page.dart' show ApprovalResult, resolveApprovalState;
import 'privacy_policy_page.dart';

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
  final _addressController = TextEditingController();
  final _originChurchController = TextEditingController();
  final _ministryController = TextEditingController();
  final _churchPositionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  DateTime? _birthdate;
  DateTime? _membershipDate;
  DateTime? _baptismDate;
  String? _admissionForm;
  String? _maritalStatus;
  File? _pickedPhoto;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedPrivacyPolicy = false;
  bool _loading = false;

  static const _admissionFormOptions = ['Batismo', 'Transferência', 'Aclamação', 'Reconciliação'];
  static const _maritalStatusOptions = ['Solteiro(a)', 'Casado(a)', 'Divorciado(a)', 'Viúvo(a)', 'União estável'];

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _originChurchController.dispose();
    _ministryController.dispose();
    _churchPositionController.dispose();
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

  /// Usado por Data de Membresia e Data de Batismo — ambas opcionais, sem a
  /// restrição de idade mínima do date picker de nascimento.
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
    if (!_acceptedPrivacyPolicy) {
      _showMessage('É preciso aceitar a Política de Privacidade para se cadastrar.');
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
      await repository.createUserProfile(
        uid: uid,
        name: name,
        email: email,
        birthdate: birthdate,
        cpf: cpf,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        membershipDate: _membershipDate,
        admissionForm: _admissionForm ?? '',
        originChurch: _originChurchController.text.trim(),
        baptismDate: _baptismDate,
        maritalStatus: _maritalStatus ?? '',
        ministry: _ministryController.text.trim(),
        churchPosition: _churchPositionController.text.trim(),
        privacyPolicyAccepted: _acceptedPrivacyPolicy,
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
              InkWell(
                onTap: _pickBirthdate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de nascimento *',
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
              InkWell(
                onTap: () => _pickDate(_membershipDate, (date) => setState(() => _membershipDate = date)),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Membresia',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _membershipDate != null ? DateFormat('dd/MM/yyyy').format(_membershipDate!) : '',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _admissionForm,
                decoration: const InputDecoration(labelText: 'Forma de Adesão'),
                items: [
                  for (final option in _admissionFormOptions) DropdownMenuItem(value: option, child: Text(option)),
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
                onTap: () => _pickDate(_baptismDate, (date) => setState(() => _baptismDate = date)),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Batismo',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _baptismDate != null ? DateFormat('dd/MM/yyyy').format(_baptismDate!) : '',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _maritalStatus,
                decoration: const InputDecoration(labelText: 'Estado civil'),
                items: [
                  for (final option in _maritalStatusOptions) DropdownMenuItem(value: option, child: Text(option)),
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
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptedPrivacyPolicy,
                    onChanged: (value) => setState(() => _acceptedPrivacyPolicy = value ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: context.textSecondary, fontSize: 14),
                          children: [
                            const TextSpan(
                              text: 'Li e concordo com a ',
                            ),
                            TextSpan(
                              text: 'Política de Privacidade',
                              style: const TextStyle(
                                color: SibValColors.goldAccent,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                                    ),
                            ),
                            const TextSpan(
                              text: ' e autorizo o tratamento dos meus dados pessoais conforme descrito.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_loading || !_acceptedPrivacyPolicy) ? null : _register,
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
