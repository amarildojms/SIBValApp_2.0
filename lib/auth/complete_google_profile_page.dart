import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_repository.dart';
import '../models/address.dart';
import '../theme/app_theme.dart';
import '../util/age.dart';
import '../util/cpf_phone_input.dart';
import '../util/photo_picker.dart';
import '../util/scroll_to_save.dart';
import '../widgets/address_fields.dart';
import '../widgets/date_field.dart';
import 'registration_consent_section.dart';

/// Espelha app/src/main/java/com/sibval/app/ui/auth/CompleteGoogleProfileActivity.kt
/// (+ CompleteGoogleProfileViewModel.kt): tela mostrada quando um login/cadastro
/// com Google é de uma conta nova (`isNewUser`) — falta coletar os mesmos dados
/// complementares do cadastro por e-mail (`register_page.dart`, incremento sem
/// equivalente no nativo) antes de criar `users/{uid}` como pendente de
/// aprovação: CPF (obrigatório), data de nascimento (obrigatória), foto,
/// telefone/endereço (opcionais) e o consentimento com a Política de
/// Privacidade. A seção "Dados eclesiásticos" não é mais coletada aqui
/// (20/08/2026) — virou exclusividade da Secretaria em Rol de Membros.
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
  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressKey = GlobalKey<AddressFieldsState>();
  final _scrollController = ScrollController();
  DateTime? _birthdate;
  DateTime? _baptismDate;
  File? _pickedPhoto;
  bool _acceptedTermsOfUse = false;
  bool _acceptedPrivacyPolicy = false;
  bool _acceptedCommunications = false;
  bool _loading = false;

  @override
  void dispose() {
    _cpfController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await pickAndCropProfilePhoto();
    if (photo != null) {
      setState(() => _pickedPhoto = photo);
    }
  }

  Future<void> _finish() async {
    final cpf = _cpfController.text.trim();
    final birthdate = _birthdate;

    if (!CpfValidator.isValid(cpf)) {
      _showMessage('Informe um CPF válido.');
      return;
    }
    if (birthdate == null) {
      _showMessage('Selecione sua data de nascimento.');
      return;
    }
    if (ageInYears(birthdate) < minimumRegistrationAge) {
      _showMessage('É preciso ter pelo menos $minimumRegistrationAge anos para se cadastrar.');
      return;
    }
    if (!_acceptedTermsOfUse || !_acceptedPrivacyPolicy) {
      _showMessage('É preciso aceitar os Termos de Uso e a Política de Privacidade para continuar.');
      return;
    }

    setState(() => _loading = true);
    _scrollController.scrollToSaveButton();
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.createUserProfile(
        uid: widget.uid,
        name: widget.name,
        email: widget.email,
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

  InputDecoration _decoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      suffixIcon: suffixIcon,
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: SibValColors.goldAccent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SibValColors.navyBlue,
      appBar: AppBar(backgroundColor: SibValColors.navyBlue, foregroundColor: Colors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
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
                'Faltam alguns dados para participar da igreja pelo app. Campos com * são obrigatórios.',
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
              TextField(
                controller: _cpfController,
                style: _fieldStyle,
                keyboardType: TextInputType.number,
                inputFormatters: [CpfInputFormatter()],
                decoration: _decoration('CPF *'),
              ),
              const SizedBox(height: 16),
              DateField(
                label: 'Data de nascimento *',
                value: _birthdate,
                enabled: !_loading,
                firstDate: DateTime(DateTime.now().year - 110),
                lastDate: maxBirthdateForAge(minimumRegistrationAge),
                decoration: _decoration('Data de nascimento *'),
                style: _fieldStyle,
                iconColor: Colors.white70,
                onChanged: (date) => setState(() => _birthdate = date),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                style: _fieldStyle,
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneInputFormatter()],
                decoration: _decoration('Telefone (opcional)'),
              ),
              const SizedBox(height: 16),
              const Text('Endereço (opcional)', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              AddressFields(
                key: _addressKey,
                initial: Address.empty,
                enabled: !_loading,
                decorationBuilder: _decoration,
                style: _fieldStyle,
                iconColor: Colors.white70,
                dropdownColor: SibValColors.navyBlue,
              ),
              const SizedBox(height: 16),
              DateField(
                label: 'Data de Batismo (opcional)',
                value: _baptismDate,
                enabled: !_loading,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                decoration: _decoration('Data de Batismo (opcional)'),
                style: _fieldStyle,
                iconColor: Colors.white70,
                onChanged: (date) => setState(() => _baptismDate = date),
              ),
              const SizedBox(height: 24),
              RegistrationConsentSection(
                dark: true,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: SibValColors.goldAccent,
                  foregroundColor: SibValColors.navyBlueDark,
                ),
                onPressed: (_loading || !_acceptedTermsOfUse || !_acceptedPrivacyPolicy) ? null : _finish,
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
