import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/post_repository.dart' show currentUidProvider;
import '../theme/app_theme.dart';

/// Mesmo intervalo do banner de consentimento de comunicações
/// (`communications_consent_banner.dart`) — frequente o bastante pra não cair
/// no esquecimento, espaçado o bastante pra não parecer insistência.
const _bannerInterval = Duration(days: 21);

/// Avisa quem negou a permissão de notificação do sistema (o pedido já
/// acontece automaticamente ao logar, ver
/// `PushNotificationService.requestPermissionAndRegisterToken` chamado em
/// `main_shell.dart`) — sem a permissão, avisos de eventos, devocionais,
/// curtidas/comentários etc. não chegam como notificação do sistema, só na
/// Central de Notificações dentro do app. Como o Android 13+/iOS não deixam
/// reabrir o diálogo do sistema depois de uma negativa, "Ativar" leva direto
/// pras configurações do app (`permission_handler`).
class NotificationPermissionBanner extends ConsumerWidget {
  const NotificationPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const SizedBox.shrink();
    return _EligibilityGate(uid: uid);
  }
}

/// Decide, de forma assíncrona, se deve mostrar o banner: permissão do
/// sistema negada + ainda não pediu pra não perguntar de novo + já passou o
/// intervalo mínimo desde a última exibição (shared_preferences, por uid,
/// mesmo esquema do banner de consentimento de comunicações).
class _EligibilityGate extends StatefulWidget {
  const _EligibilityGate({required this.uid});

  final String uid;

  @override
  State<_EligibilityGate> createState() => _EligibilityGateState();
}

class _EligibilityGateState extends State<_EligibilityGate> with WidgetsBindingObserver {
  bool _eligible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reavalia ao voltar das configurações do app (usuário pode ter ativado a
    // permissão lá) — some o banner sem esperar o próximo intervalo.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.denied) {
      if (mounted && _eligible) setState(() => _eligible = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notif_perm_optout_${widget.uid}') ?? false) return;

    final lastShownMs = prefs.getInt('notif_perm_last_shown_${widget.uid}');
    final eligible = lastShownMs == null ||
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs)) >= _bannerInterval;
    if (!eligible) return;

    await prefs.setInt('notif_perm_last_shown_${widget.uid}', DateTime.now().millisecondsSinceEpoch);
    if (mounted) setState(() => _eligible = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_eligible) return const SizedBox.shrink();
    return _PermissionBannerCard(uid: widget.uid, onHide: () => setState(() => _eligible = false));
  }
}

class _PermissionBannerCard extends StatelessWidget {
  const _PermissionBannerCard({required this.uid, required this.onHide});

  final String uid;
  final VoidCallback onHide;

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  Future<void> _optOutForever() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_perm_optout_$uid', true);
    onHide();
  }

  @override
  Widget build(BuildContext context) {
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
                child: Icon(Icons.notifications_off_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'As notificações estão desativadas para o app. Você pode perder avisos '
                      'de eventos, devocionais e outras novidades. Quer ativar?',
                      style: TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: SibValColors.goldAccent),
                          onPressed: _openSettings,
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
