/// Configuração de atualização obrigatória (21/08/2026) — lida de
/// `settings/appVersion` no Firestore, editada manualmente pelo admin a cada
/// publicação nova (sem tela própria no app; é infraestrutura, não conteúdo
/// do dia a dia). `latestVersionCode` é o `versionCode`/build number Android
/// (o "+N" em `pubspec.yaml`); enquanto o instalado for menor, o app está
/// desatualizado — ver `updateStatusProvider` (`lib/widgets/update_gate.dart`)
/// para a contagem de tolerância antes do bloqueio.
class AppVersionConfig {
  const AppVersionConfig({
    required this.latestVersionCode,
    this.latestVersionName = '',
    this.androidUrl = '',
    this.iosUrl = '',
  });

  final int latestVersionCode;
  final String latestVersionName;

  /// Link da loja — se vazio, cai pro link padrão da Play Store com o
  /// `applicationId` do app (`com.sibval.app`). Vazio na App Store por
  /// padrão porque o app ainda não foi publicado lá.
  final String androidUrl;
  final String iosUrl;

  static AppVersionConfig? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final code = (map['latestVersionCode'] as num?)?.toInt();
    if (code == null) return null;
    return AppVersionConfig(
      latestVersionCode: code,
      latestVersionName: map['latestVersionName'] as String? ?? '',
      androidUrl: map['androidUrl'] as String? ?? '',
      iosUrl: map['iosUrl'] as String? ?? '',
    );
  }
}
