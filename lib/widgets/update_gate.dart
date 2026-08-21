import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/settings_repository.dart';
import '../models/app_version_config.dart';
import '../theme/app_theme.dart';

/// Tolerância entre a versão instalada ficar desatualizada e o bloqueio
/// obrigatório — decidido com o usuário em 21/08/2026 (opção "7 dias").
const _updateGracePeriod = Duration(days: 7);

enum UpdateStatus { upToDate, graceWarning, forceBlocked }

/// Build number instalado (o "+N" do `pubspec.yaml`) — não muda durante a
/// vida do app, então não precisa de `autoDispose`.
final currentBuildNumberProvider = FutureProvider<int>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return int.tryParse(info.buildNumber) ?? 0;
});

/// Compara o build instalado com `settings/appVersion.latestVersionCode`
/// (`appVersionConfigProvider`) e decide: em dia, dentro da tolerância de 7
/// dias (mostra o banner dispensável), ou tolerância vencida (bloqueia até
/// atualizar). A contagem de dias é persistida em `shared_preferences`,
/// chaveada pelo `latestVersionCode` — se o admin publicar uma versão nova
/// antes do bloqueio, a tolerância reinicia pra essa versão.
final updateStatusProvider = FutureProvider.autoDispose<UpdateStatus>((ref) async {
  final config = await ref.watch(appVersionConfigProvider.future);
  if (config == null) return UpdateStatus.upToDate;
  final currentCode = await ref.watch(currentBuildNumberProvider.future);
  if (currentCode >= config.latestVersionCode) return UpdateStatus.upToDate;

  final prefs = await SharedPreferences.getInstance();
  final key = 'update_first_outdated_${config.latestVersionCode}';
  var firstSeenMs = prefs.getInt(key);
  if (firstSeenMs == null) {
    firstSeenMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, firstSeenMs);
  }
  final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(firstSeenMs));
  return elapsed >= _updateGracePeriod ? UpdateStatus.forceBlocked : UpdateStatus.graceWarning;
});

const _defaultAndroidStoreUrl = 'https://play.google.com/store/apps/details?id=com.sibval.app';

String? _storeUrlFor(AppVersionConfig config) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return config.iosUrl.isNotEmpty ? config.iosUrl : null;
  }
  return config.androidUrl.isNotEmpty ? config.androidUrl : _defaultAndroidStoreUrl;
}

Future<void> _openStore(BuildContext context, AppVersionConfig config) async {
  final url = _storeUrlFor(config);
  if (url == null) return;
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir a loja.')));
    }
  }
}

/// Banner dispensável mostrado enquanto a atualização ainda está dentro da
/// tolerância de 7 dias — mesmo padrão visual de `CommunicationsConsentBanner`/
/// `NotificationPermissionBanner`. "Lembrar mais tarde" só esconde nesta
/// sessão (não grava opt-out): reaparece na próxima vez que o app abrir,
/// de propósito, já que a contagem para o bloqueio continua correndo.
class UpdateAvailableBanner extends StatefulWidget {
  const UpdateAvailableBanner({super.key, required this.config});

  final AppVersionConfig config;

  @override
  State<UpdateAvailableBanner> createState() => _UpdateAvailableBannerState();
}

class _UpdateAvailableBannerState extends State<UpdateAvailableBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
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
                child: Icon(Icons.system_update_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.config.latestVersionName.isNotEmpty
                          ? 'Uma nova versão do app (${widget.config.latestVersionName}) está disponível.'
                          : 'Uma nova versão do app está disponível.',
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: SibValColors.goldAccent),
                          onPressed: () => _openStore(context, widget.config),
                          child: const Text('Atualizar agora'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          onPressed: () => setState(() => _hidden = true),
                          child: const Text('Lembrar mais tarde'),
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

/// Tela cheia mostrada por `main_shell.dart` no lugar do app inteiro quando a
/// tolerância de 7 dias já venceu — sem botão de dispensar, mesmo padrão de
/// bloqueio de `RequiredConsentGatePage`.
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key, required this.config});

  final AppVersionConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atualização necessária'), automaticallyImplyLeading: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.system_update_outlined, size: 56, color: context.textPrimary),
              const SizedBox(height: 16),
              Text(
                'É preciso atualizar o app',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Uma nova versão está disponível há mais de 7 dias. Para continuar usando o '
                'SIBVal Connect, atualize o app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _openStore(context, config),
                child: const Text('Atualizar agora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
