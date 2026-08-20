import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../theme/app_theme.dart';

/// Intervalo mínimo entre exibições do banner para quem ainda não respondeu
/// ao checkbox 3 (comunicações) nem pediu para não perguntar de novo —
/// definido com o usuário em 20/08/2026: frequente o bastante para não cair
/// no esquecimento, espaçado o bastante para não parecer insistência (a
/// Política de Privacidade, seção 17, exige consentimento "livre").
const _bannerInterval = Duration(days: 21);

/// Sugere ativar o consentimento de comunicações (checkbox opcional do
/// cadastro, ver `registration_consent_section.dart`) para quem não aceitou
/// no cadastro. Não altera nada além de gravar a preferência em
/// `users/{uid}.communicationsConsent` — nenhuma outra tela (aniversariantes,
/// galeria, pedidos de oração) passa a checar essa flag por enquanto.
class CommunicationsConsentBanner extends ConsumerWidget {
  const CommunicationsConsentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.asData?.value;
    if (uid == null || profile == null || profile.communicationsConsent) {
      return const SizedBox.shrink();
    }
    return _EligibilityGate(uid: uid);
  }
}

/// Decide, de forma assíncrona (shared_preferences), se já passou tempo
/// suficiente desde a última exibição — e, ao decidir mostrar, já grava o
/// timestamp atual como "última exibição" (evita reabrir a cada rebuild).
class _EligibilityGate extends StatefulWidget {
  const _EligibilityGate({required this.uid});

  final String uid;

  @override
  State<_EligibilityGate> createState() => _EligibilityGateState();
}

class _EligibilityGateState extends State<_EligibilityGate> {
  bool _eligible = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('comm_consent_optout_${widget.uid}') ?? false) return;

    final lastShownMs = prefs.getInt('comm_consent_last_shown_${widget.uid}');
    final eligible = lastShownMs == null ||
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs)) >= _bannerInterval;
    if (!eligible) return;

    await prefs.setInt('comm_consent_last_shown_${widget.uid}', DateTime.now().millisecondsSinceEpoch);
    if (mounted) setState(() => _eligible = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_eligible) return const SizedBox.shrink();
    return _ConsentBannerCard(uid: widget.uid, onHide: () => setState(() => _eligible = false));
  }
}

class _ConsentBannerCard extends ConsumerWidget {
  const _ConsentBannerCard({required this.uid, required this.onHide});

  final String uid;
  final VoidCallback onHide;

  Future<void> _accept(WidgetRef ref) async {
    await ref.read(userRepositoryProvider).setCommunicationsConsent(uid, true);
    ref.invalidate(currentUserProfileProvider);
  }

  Future<void> _optOutForever() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('comm_consent_optout_$uid', true);
    onHide();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: SibValColors.navyBlueLight,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Você ainda não autorizou o recebimento de comunicações da igreja '
                      '(avisos, programações, divulgação de aniversário e fotos). Quer '
                      'ativar agora?',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: SibValColors.goldAccent),
                          onPressed: () => _accept(ref),
                          child: const Text('Ativar'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          onPressed: onHide,
                          child: const Text('Agora não'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white54),
                          onPressed: _optOutForever,
                          child: const Text('Não perguntar novamente'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
