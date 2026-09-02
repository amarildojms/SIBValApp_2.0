import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'auth/communications_consent_banner.dart';
import 'auth/edit_profile_page.dart';
import 'auth/login_page.dart';
import 'auth/required_consent_gate_page.dart';
import 'contribute/contribute_page.dart';
import 'data/home_quick_tiles_repository.dart';
import 'data/member_repository.dart';
import 'data/post_repository.dart' show currentUidProvider;
import 'data/settings_repository.dart';
import 'data/user_repository.dart';
import 'data/devotional_repository.dart';
import 'devotionals/devotionals_list_page.dart';
import 'events/events_page.dart';
import 'home/home_page.dart';
import 'home/home_quick_tiles.dart';
import 'notifications/notification_permission_banner.dart';
import 'notifications/push_notification_service.dart';
import 'settings/about_page.dart';
import 'theme/app_theme.dart';
import 'util/cache_busted_image.dart';
import 'widgets/sibval_app_bar.dart';
import 'widgets/update_gate.dart';

/// Início é a aba inicial (índice 0, 02/09/2026 — era a aba central, índice
/// 2, antes do usuário pedir pra movê-la pra primeira posição) — usado tanto
/// pelo `NavigationBar` quanto por quem precisa levar o usuário pra lá de
/// fora da árvore de widgets do `MainShell` (ex.: toque numa notificação de
/// finalização de culto, ver `notification_navigation.dart`).
const homeTabIndex = 0;

/// Aba selecionada do `MainShell` — vira `StateProvider` (em vez de um campo
/// local em `_MainShellState`) justamente pra permitir essa troca de aba
/// vinda de fora, via `ref.read(mainShellTabIndexProvider.notifier).state`.
final mainShellTabIndexProvider = StateProvider<int>((ref) => homeTabIndex);

/// Espelha o bottom_nav_menu.xml original, com duas mudanças pedidas pelo
/// usuário em 02/09/2026: Início foi pra 1ª posição (era a 3ª, central) e
/// Mais saiu da barra por completo — agora só é alcançado pelo ícone "Mais"
/// da grade de Início (`HomeHighlights`/`MaisPage`, `Navigator.push`, não
/// mais uma aba do `IndexedStack`). O Mural (que tinha virado uma aba nova
/// nessa mesma sessão) também saiu da barra pelo mesmo motivo — vive dentro
/// de `MaisPage` como mais um `MoreTile`.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _pages = [
    HomePage(),
    DevotionalsListPage(),
    EventsPage(),
    ContributePage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(mainShellTabIndexProvider);
    final uid = ref.watch(currentUidProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final unreadDevotionalsAsync = uid != null
        ? ref.watch(unreadDevotionalsCountProvider)
        : const AsyncValue.data(0);
    final unreadDevotionals = unreadDevotionalsAsync.asData?.value ?? 0;
    // Espelha HomeFragment.kt `setUpNotifications()`: pede permissão de
    // notificação e registra o token FCM assim que há um uid logado. O
    // próprio serviço deduplica por uid, então chamar em todo build é
    // seguro.
    if (uid != null) {
      ref
          .read(pushNotificationServiceProvider)
          .requestPermissionAndRegisterToken(uid);
    }
    // Bloqueio obrigatório de atualização (21/08/2026) — vale pra qualquer
    // um, logado ou não, ver `update_gate.dart`.
    final updateStatus = ref.watch(updateStatusProvider).asData?.value;
    final versionConfig = ref.watch(appVersionConfigProvider).asData?.value;

    Widget child;
    if (updateStatus == UpdateStatus.forceBlocked && versionConfig != null) {
      child = UpdateRequiredPage(config: versionConfig);
    } else if (uid != null &&
        profile != null &&
        (!profile.acceptedTermsOfUse || !profile.acceptedPrivacyPolicy)) {
      // Contas logadas criadas antes dos Termos de Uso/checkbox de
      // privacidade existirem (20/08/2026) ficam bloqueadas aqui até
      // aceitarem — ver `RequiredConsentGatePage`.
      child = RequiredConsentGatePage(
        uid: uid,
        communicationsConsent: profile.communicationsConsent,
      );
    } else {
      child = Scaffold(
        body: Column(
          children: [
            const CommunicationsConsentBanner(),
            const NotificationPermissionBanner(),
            if (updateStatus == UpdateStatus.graceWarning &&
                versionConfig != null)
              UpdateAvailableBanner(config: versionConfig),
            Expanded(
              child: IndexedStack(index: index, children: _pages),
            ),
          ],
        ),
        bottomNavigationBar: MediaQuery.withClampedTextScaling(
          // Telas menores + "Fonte grande" (comum em Samsung/OneUI, já viu
          // esse tipo de estouro antes no telefone da Recepção) cortavam o
          // rótulo "Devocionais", o mais longo das quatro abas (02/09/2026,
          // Mural e Mais saíram da barra) — trava o quanto o texto pode
          // crescer além do que o layout fixo comporta.
          maxScaleFactor: 1.15,
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (newIndex) =>
                ref.read(mainShellTabIndexProvider.notifier).state = newIndex,
            backgroundColor: SibValColors.navyBlue,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('$unreadDevotionals'),
                  isLabelVisible: unreadDevotionals > 0,
                  child: const _BoldAssetIcon(
                    'assets/icons/ic_devocional.png',
                    size: 26,
                    color: Colors.white70,
                  ),
                ),
                selectedIcon: Badge(
                  label: Text('$unreadDevotionals'),
                  isLabelVisible: unreadDevotionals > 0,
                  child: const _BoldAssetIcon(
                    'assets/icons/ic_devocional.png',
                    size: 26,
                    color: SibValColors.navyBlueDark,
                  ),
                ),
                label: 'Devocionais',
              ),
              const NavigationDestination(
                icon: Icon(Icons.event_outlined),
                label: 'Eventos',
              ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_border),
                label: 'Contribua',
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: index == homeTabIndex,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop)
          ref.read(mainShellTabIndexProvider.notifier).state = homeTabIndex;
      },
      child: child,
    );
  }
}

/// O PNG do ícone de Devocionais (copiado do app nativo) tem linhas mais finas
/// que os ícones vetoriais do Material (Início, Contribua) no mesmo tamanho —
/// empilha cópias levemente deslocadas da mesma imagem pra "engordar" o traço
/// visualmente, sem precisar editar o arquivo de imagem.
class _BoldAssetIcon extends StatelessWidget {
  const _BoldAssetIcon(this.asset, {required this.size, required this.color});

  final String asset;
  final double size;
  final Color color;

  static const _offsets = [
    Offset.zero,
    Offset(-0.8, 0),
    Offset(0.8, 0),
    Offset(0, -0.8),
    Offset(0, 0.8),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          for (final offset in _offsets)
            Positioned.fill(
              child: Transform.translate(
                offset: offset,
                child: Image.asset(
                  asset,
                  color: color,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Engrenagem (configuração) com um pequeno envelope no canto — remete a
/// "configuração de e-mails" sem precisar de um ícone customizado novo (só
/// compõe dois `Icons` do Material já usados em outros lugares do app).
class SettingsMailIcon extends StatelessWidget {
  const SettingsMailIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.settings_outlined, color: color, size: 24),
          Positioned(
            bottom: -2,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mail_outline, color: color, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pública (02/09/2026, era `_MaisPage`) — deixou de ser uma aba do
/// `IndexedStack` e virou uma tela pushada normalmente
/// (`Navigator.push(MaterialPageRoute(builder: (_) => const MaisPage()))`),
/// alcançada pelo ícone "Mais" da grade de Início (`HomeHighlights`). Por
/// isso precisou sair do escopo privado do arquivo — mesmo motivo que já
/// tornou `MoreTile`/`SettingsMailIcon` públicos antes.
///
/// **Tiles dinâmicos** (03/09/2026, pedido do usuário: "se eu substituir um
/// dos 7 ícones [da Início] por algum que está dentro do menu Mais, ... o
/// ícone que saiu da tela inicial deve estar lá [no Mais] no lugar do que foi
/// para a tela inicial") — antes esta tela tinha sua própria lista fixa de
/// `MoreTile`s (Mural/Galeria/Hinários/Vínculos/Configurações/Aniversariantes/
/// Introdução/Ministério de Louvor), sem nenhuma relação com a ordem
/// configurável da grade de Início; uma troca lá nunca aparecia aqui. Agora
/// os dois usam a MESMA fonte de verdade (`buildHomeQuickTileDefs`/
/// `splitHomeQuickTiles`, `home/home_quick_tiles.dart`) — "Mais" mostra
/// exatamente o "pool" (todo ícone elegível que não está entre os 7 da
/// grade), na ordem persistida em `homeQuickTilesOrderProvider`.
class MaisPage extends ConsumerWidget {
  const MaisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.asData?.value;

    final defs = buildHomeQuickTileDefs(ref);
    final byId = {for (final d in defs) d.id: d};
    final savedOrder = ref.watch(homeQuickTilesOrderProvider);
    final pool = splitHomeQuickTiles(savedOrder, defs).pool;

    final tiles = [
      for (final id in pool)
        MoreTile(
          icon: byId[id]!.icon,
          imageAsset: byId[id]!.imageAsset,
          customIcon: byId[id]!.customIcon?.call(context.textPrimary),
          label: byId[id]!.label,
          badgeCount: byId[id]!.badgeCount,
          onTap: () => byId[id]!.onTap(context),
        ),
    ];

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: ListView(
        children: [
          if (uid != null && profile != null)
            _MoreHeader(profile: profile)
          else
            const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            mainAxisSpacing: 0,
            crossAxisSpacing: 8,
            childAspectRatio: 1.2,
            children: tiles,
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: uid == null
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      child: const Text('Entrar'),
                    ),
                  )
                : Column(
                    children: [
                      Text(
                        FirebaseAuth.instance.currentUser?.email ?? '',
                        style: TextStyle(color: context.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Sair'),
                      ),
                    ],
                  ),
          ),
          // "Sobre" (29/08/2026, pedido do usuário) — informação do app em
          // si, não uma ação de conta, por isso fica fora do bloco
          // Entrar/Sair acima, mas ainda no rodapé — visível a qualquer
          // usuário, logado ou em acesso convidado.
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutPage()),
              ),
              child: const Text('Sobre o app'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Substitui o título fixo "Mais": vira o link para editar o perfil (troca de
/// foto e outros dados), igual pedido pelo usuário. Também mostra o % de
/// cadastro preenchido e o tempo de membresia (19/08/2026), este último
/// vindo do `Member` vinculado (`myMemberProvider`) — só a Secretaria edita
/// `membershipDate`, então não existe em `CurrentUserProfile`.
class _MoreHeader extends ConsumerWidget {
  const _MoreHeader({required this.profile});

  final CurrentUserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(myMemberProvider);
    final member = memberAsync.asData?.value;
    final completionPercent = profile.completionPercent(member: member);
    final membershipLabel = _membershipDurationLabel(member?.membershipDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EditProfilePage())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SibValColors.navyBlueLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                backgroundImage: profile.photoUrl.isNotEmpty
                    ? NetworkImage(
                        cacheBustedPhotoUrl(
                          profile.photoUrl,
                          profile.photoUpdatedAt,
                        ),
                      )
                    : null,
                child: profile.photoUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.shortName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Editar perfil',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    if (membershipLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          membershipLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CompletionBadge(percent: completionPercent),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bolinha" com anel de progresso mostrando o % de cadastro preenchido —
/// fica no canto direito do card de perfil (`_MoreHeader`), com "Cadastro"
/// em cima e "completo" embaixo. Cor do anel numa escala vermelho→laranja→
/// verde conforme o percentual (28/08/2026, pedido do usuário — antes era
/// sempre `SibValColors.goldAccent`, sem refletir o quanto falta preencher).
class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.percent});

  final int percent;

  /// 0% = vermelho, 50% = laranja, 100% = verde — interpolação linear em
  /// dois trechos (vermelho→laranja e laranja→verde) em vez de um único
  /// `Color.lerp` ponta a ponta, que passaria por um marrom/oliva sem graça
  /// no meio do caminho.
  static Color _colorFor(int percent) {
    final t = (percent / 100).clamp(0, 1).toDouble();
    if (t <= 0.5) {
      return Color.lerp(Colors.red, Colors.orange, t / 0.5)!;
    }
    return Color.lerp(Colors.orange, Colors.green, (t - 0.5) / 0.5)!;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(percent);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Cadastro',
          style: TextStyle(color: Colors.white70, fontSize: 9),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (percent / 100).clamp(0, 1).toDouble(),
                strokeWidth: 3,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'completo',
          style: TextStyle(color: Colors.white70, fontSize: 9),
        ),
      ],
    );
  }
}

/// "Membro há X ano(s) e Y mês(es)" — omite a parte zerada (só anos se
/// months == 0, só meses se years == 0). `null` quando ainda não há data de
/// membresia registrada.
String? _membershipDurationLabel(DateTime? membershipDate) {
  if (membershipDate == null) return null;
  final now = DateTime.now();
  var totalMonths =
      (now.year - membershipDate.year) * 12 +
      (now.month - membershipDate.month);
  if (now.day < membershipDate.day) totalMonths--;
  if (totalMonths < 0) return null;
  final years = totalMonths ~/ 12;
  final months = totalMonths % 12;
  final yearsLabel = years == 1 ? '1 ano' : '$years anos';
  final monthsLabel = months == 1 ? '1 mês' : '$months meses';
  if (years == 0) return 'Membro há $monthsLabel';
  if (months == 0) return 'Membro há $yearsLabel';
  return 'Membro há $yearsLabel e $monthsLabel';
}

/// Tile em grade (ícone em cima, rótulo embaixo) — espelha o
/// GridLayoutManager(3) do MoreFragment.kt nativo, estilo "app de banco".
/// Insere uma quebra de linha manual no espaço mais próximo do meio do
/// texto, em vez de deixar o `Text` decidir sozinho onde quebrar — assim um
/// rótulo de duas ou mais palavras (ex.: "Ministérios e Cargos") sempre cai
/// em duas linhas balanceadas, em vez de ficar numa linha só quando cabe e
/// quebrar torto quando não cabe. Rótulo de uma palavra só volta inalterado.
String _forceTwoLineLabel(String label) {
  final spaceIndexes = [
    for (var i = 0; i < label.length; i++)
      if (label[i] == ' ') i,
  ];
  if (spaceIndexes.isEmpty) return label;
  final middle = label.length / 2;
  final splitAt = spaceIndexes.reduce(
    (a, b) => (a - middle).abs() <= (b - middle).abs() ? a : b,
  );
  return label.replaceRange(splitAt, splitAt + 1, '\n');
}

class MoreTile extends StatelessWidget {
  const MoreTile({
    super.key,
    this.icon,
    this.imageAsset,
    this.customIcon,
    this.imageSize = 22,
    required this.label,
    this.onTap,
    this.badgeCount = 0,
  }) : assert(icon != null || imageAsset != null || customIcon != null);

  final IconData? icon;
  final String? imageAsset;

  /// Substitui `icon`/`imageAsset` quando o ícone precisa de composição (ex.:
  /// engrenagem + envelope de "E-mails de eventos") — ver `SettingsMailIcon`.
  final Widget? customIcon;

  /// Tamanho do ícone de imagem dentro do CircleAvatar (22 por padrão) — Cantor
  /// Cristão e HCC usam 30 (20/08/2026, a pedido do usuário: ficavam pequenos
  /// perto dos ícones vetoriais dos demais tiles).
  final double imageSize;
  final String label;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = context.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              label: Text('$badgeCount'),
              isLabelVisible: badgeCount > 0,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                child:
                    customIcon ??
                    (imageAsset != null
                        ? Image.asset(
                            imageAsset!,
                            width: imageSize,
                            height: imageSize,
                            color: color,
                            colorBlendMode: BlendMode.srcIn,
                          )
                        : Icon(icon, color: color)),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _forceTwoLineLabel(label),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, height: 1.0),
            ),
          ],
        ),
      ),
    );
  }
}
