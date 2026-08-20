import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_repository.dart';
import '../theme/app_theme.dart';
import 'registration_consent_section.dart';

/// Exibida por `main_shell.dart` no lugar do app inteiro quando o usuário
/// logado ainda não tem `termsOfUseAcceptedAt`/`privacyPolicyAcceptedAt`
/// gravados — contas criadas antes de 20/08/2026 (Termos de Uso) ou antes do
/// checkbox de Política de Privacidade existir no cadastro. Reaproveita o
/// mesmo bloco de consentimento do cadastro; comunicações continua opcional.
class RequiredConsentGatePage extends ConsumerStatefulWidget {
  const RequiredConsentGatePage({super.key, required this.uid, required this.communicationsConsent});

  final String uid;
  final bool communicationsConsent;

  @override
  ConsumerState<RequiredConsentGatePage> createState() => _RequiredConsentGatePageState();
}

class _RequiredConsentGatePageState extends ConsumerState<RequiredConsentGatePage> {
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  late bool _acceptedCommunications = widget.communicationsConsent;
  bool _loading = false;

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.acceptRequiredConsents(widget.uid);
      if (_acceptedCommunications != widget.communicationsConsent) {
        await repository.setCommunicationsConsent(widget.uid, _acceptedCommunications);
      }
      ref.invalidate(currentUserProfileProvider);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos e Privacidade'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _loading ? null : () => FirebaseAuth.instance.signOut(),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Atualizamos os Termos de Uso e a Política de Privacidade',
                style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Para continuar usando o SIBVal Connect, revise e aceite os documentos '
                'abaixo. Isso é pedido uma única vez.',
                style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              RegistrationConsentSection(
                acceptedTerms: _acceptedTerms,
                acceptedPrivacy: _acceptedPrivacy,
                acceptedCommunications: _acceptedCommunications,
                enabled: !_loading,
                onTermsChanged: (value) => setState(() => _acceptedTerms = value),
                onPrivacyChanged: (value) => setState(() => _acceptedPrivacy = value),
                onCommunicationsChanged: (value) => setState(() => _acceptedCommunications = value),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_loading || !_acceptedTerms || !_acceptedPrivacy) ? null : _continue,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
