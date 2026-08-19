import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import '../util/church_membership_options.dart';
import '../util/cpf_phone_input.dart';
import '../util/photo_picker.dart';
import 'privacy_policy_page.dart';

/// Espelha app/src/main/java/com/sibval/app/ui/auth/CompleteGoogleProfileActivity.kt
/// (+ CompleteGoogleProfileViewModel.kt): tela mostrada quando um login/cadastro
/// com Google é de uma conta nova (`isNewUser`) — falta coletar os mesmos dados
/// complementares do cadastro por e-mail (`register_page.dart`, incremento sem
/// equivalente no nativo) antes de criar `users/{uid}` como pendente de
/// aprovação: CPF (obrigatório), data de nascimento (obrigatória), foto e
/// demais dados eclesiásticos (opcionais), além do consentimento com a
/// Política de Privacidade.
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
  final _addressController = TextEditingController();
  final _originChurchController = TextEditingController();
  final _ministryController = TextEditingController();
  final _churchPositionController = TextEditingController();
  DateTime? _birthdate;
  DateTime? _baptismDate;
  String? _admissionForm;
  String? _maritalStatus;
  File? _pickedPhoto;
  bool _acceptedPrivacyPolicy = false;
  bool _loading = false;

  @override
  void dispose() {
    _cpfController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _originChurchController.dispose();
    _ministryController.dispose();
    _churchPositionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await pickAndCropProfilePhoto();
    if (photo != null) {
      setState(() => _pickedPhoto = photo);
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

  /// Usado pela Data de Batismo — opcional, sem a restrição de idade mínima
  /// do date picker de nascimento.
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
    if (!_acceptedPrivacyPolicy) {
      _showMessage('É preciso aceitar a Política de Privacidade para continuar.');
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
        cpf: cpf,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
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
              InkWell(
                onTap: _loading ? null : _pickBirthdate,
                child: InputDecorator(
                  decoration: _decoration('Data de nascimento *', suffixIcon: const Icon(Icons.calendar_today_outlined, color: Colors.white70)),
                  child: Text(
                    _birthdate != null ? DateFormat('dd/MM/yyyy').format(_birthdate!) : '',
                    style: _fieldStyle,
                  ),
                ),
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
              TextField(
                controller: _addressController,
                style: _fieldStyle,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Endereço (opcional)'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Dados eclesiásticos (opcional)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _admissionForm,
                style: _fieldStyle,
                dropdownColor: SibValColors.navyBlueLight,
                decoration: _decoration('Forma de Adesão'),
                items: [
                  for (final option in admissionFormOptions) DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: _loading ? null : (value) => setState(() => _admissionForm = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _originChurchController,
                style: _fieldStyle,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Igreja de origem'),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _loading ? null : () => _pickDate(_baptismDate, (date) => setState(() => _baptismDate = date)),
                child: InputDecorator(
                  decoration: _decoration('Data de Batismo', suffixIcon: const Icon(Icons.calendar_today_outlined, color: Colors.white70)),
                  child: Text(
                    _baptismDate != null ? DateFormat('dd/MM/yyyy').format(_baptismDate!) : '',
                    style: _fieldStyle,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _maritalStatus,
                style: _fieldStyle,
                dropdownColor: SibValColors.navyBlueLight,
                decoration: _decoration('Estado civil'),
                items: [
                  for (final option in maritalStatusOptions) DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: _loading ? null : (value) => setState(() => _maritalStatus = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ministryController,
                style: _fieldStyle,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Ministério'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _churchPositionController,
                style: _fieldStyle,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Cargo/Função'),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _acceptedPrivacyPolicy,
                    fillColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected) ? SibValColors.goldAccent : Colors.transparent,
                    ),
                    checkColor: SibValColors.navyBlueDark,
                    side: const BorderSide(color: Colors.white70),
                    onChanged: _loading ? null : (value) => setState(() => _acceptedPrivacyPolicy = value ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          children: [
                            const TextSpan(text: 'Li e concordo com a '),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: SibValColors.goldAccent,
                  foregroundColor: SibValColors.navyBlueDark,
                ),
                onPressed: (_loading || !_acceptedPrivacyPolicy) ? null : _finish,
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
