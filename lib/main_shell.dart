import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'auth/communications_consent_banner.dart';
import 'auth/edit_profile_page.dart';
import 'auth/login_page.dart';
import 'auth/required_consent_gate_page.dart';
import 'bible/bible_book_list_page.dart';
import 'birthdays/birthdays_page.dart';
import 'contribute/contribute_page.dart';
import 'data/cifra_repository.dart';
import 'data/member_repository.dart';
import 'data/post_repository.dart' show currentUidProvider;
import 'data/prayer_repository.dart';
import 'data/settings_repository.dart';
import 'data/user_repository.dart';
import 'data/devotional_repository.dart';
import 'devotionals/devotionals_list_page.dart';
import 'events/events_page.dart';
import 'gallery/album_list_page.dart';
import 'data/message_repository.dart';
import 'home/home_feed_page.dart';
import 'hymnal/hymnals_page.dart';
import 'introduction/introduction_page.dart';
import 'messages/messages_page.dart';
import 'notifications/notification_permission_banner.dart';
import 'notifications/push_notification_service.dart';
import 'partners/partners_page.dart';
import 'praise/praise_ministry_page.dart';
import 'prayer/prayer_page.dart';
import 'service_order/service_order_list_page.dart';
import 'settings/settings_management_page.dart';
import 'theme/app_theme.dart';
import 'util/cache_busted_image.dart';
import 'widgets/sibval_app_bar.dart';
import 'widgets/update_gate.dart';

/// Início é a aba central (índice 2), igual ao app original — usado tanto
/// pelo `NavigationBar` quanto por quem precisa levar o usuário pra lá de
/// fora da árvore de widgets do `MainShell` (ex.: toque numa notificação de
/// aniversário de MEMBRESIA, ver `notification_navigation.dart`).
const homeTabIndex = 2;

/// Aba selecionada do `MainShell` — vira `StateProvider` (em vez de um campo
/// local em `_MainShellState`) justamente pra permitir essa troca de aba
/// vinda de fora, via `ref.read(mainShellTabIndexProvider.notifier).state`.
final mainShellTabIndexProvider = StateProvider<int>((ref) => homeTabIndex);

/// Espelha o bottom_nav_menu.xml original: Devocionais, Eventos, Início,
/// Contribua, Mais. Só o Início tem conteúdo real nesta fase — os demais são
/// placeholders "em breve" até as próximas fases da migração.
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _pages = [
    DevotionalsListPage(),
    EventsPage(),
    HomeFeedPage(),
    ContributePage(),
    _MaisPage(),
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
          // rótulo "Devocionais", o mais longo dos cinco — trava o quanto o
          // texto da barra pode crescer além do que o layout fixo comporta.
          maxScaleFactor: 1.15,
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (newIndex) =>
                ref.read(mainShellTabIndexProvider.notifier).state = newIndex,
            backgroundColor: SibValColors.navyBlue,
            destinations: [
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
                icon: Icon(Icons.home_outlined),
                label: 'Início',
              ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_border),
                label: 'Contribua',
              ),
              const NavigationDestination(
                icon: Icon(Icons.more_horiz),
                label: 'Mais',
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

/// Igreja com uma nota musical no canto — remete a "ordem de culto"
/// (liturgia musical) sem precisar de um ícone customizado novo, mesma
/// composição de `SettingsMailIcon`/`_IntroductionIcon` acima.
class _ServiceOrderIcon extends StatelessWidget {
  const _ServiceOrderIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.church_outlined, color: color, size: 24),
          Positioned(
            top: -3,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.music_note, color: color, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mesa de recepção (ícone `desk_outlined`, que já traz um monitor
/// embutido no desenho) com um boneco (pessoa) no canto — mesma composição
/// de `SettingsMailIcon` acima, só trocando os dois ícones combinados.
/// Nome da classe mantido (ícone continua sendo a "mesa"), só o papel/rótulo
/// visível virou "Introdução".
class _IntroductionIcon extends StatelessWidget {
  const _IntroductionIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.desk_outlined, color: color, size: 24),
          Positioned(
            top: -3,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: color, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaisPage extends ConsumerWidget {
  const _MaisPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.asData?.value;
    final isAdmin = profile?.isAdmin ?? false;
    final canViewPrayerRequests = profile?.canViewPrayerRequests ?? false;
    // NOVO (24/08/2026, unificado numa só tela em 25/08/2026, papel
    // renomeado de "Recepção" pra "Introdução" depois): área Introdução — o
    // que cada um vê dentro dela depende do papel, ver introduction_page.dart.
    // Um tile só, visível pra quem tem qualquer um dos três papéis (ou admin).
    final canAccessIntroduction =
        (profile?.canRegisterVisitors ?? false) ||
        (profile?.canViewVisitorSummaries ?? false) ||
        (profile?.canViewVisitorDetails ?? false);
    final pendingCountAsync = isAdmin
        ? ref.watch(pendingUserCountProvider)
        : const AsyncValue.data(0);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;
    final pendingPrayerCountAsync = canViewPrayerRequests
        ? ref.watch(pendingPrayerCountProvider)
        : const AsyncValue.data(0);
    final pendingPrayerCount = pendingPrayerCountAsync.asData?.value ?? 0;
    final pendingMessagesCountAsync = uid != null
        ? ref.watch(pendingMessagesCountProvider)
        : const AsyncValue.data(0);
    final pendingMessagesCount = pendingMessagesCountAsync.asData?.value ?? 0;

    final tiles = [
      // Tier 1 — disponível para todos, sem login.
      MoreTile(
        icon: Icons.photo_camera_outlined,
        label: 'Galeria',
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AlbumListPage())),
      ),
      MoreTile(
        icon: Icons.menu_book,
        label: 'Bíblia',
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BibleBookListPage())),
      ),
      // Hinários (28/08/2026, pedido do usuário) — antes eram dois tiles
      // separados (Cantor Cristão / HCC), agora um só que abre a escolha.
      MoreTile(
        icon: Icons.library_music_outlined,
        label: 'Hinários',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const HymnalsPage())),
      ),
      MoreTile(
        imageAsset: 'assets/icons/ic_prayer.png',
        label: 'Pedido de Oração',
        badgeCount: pendingPrayerCount,
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrayerPage())),
      ),
      MoreTile(
        icon: Icons.handshake_outlined,
        label: 'Vínculos Institucionais',
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PartnersPage())),
      ),
      // "Configurações e Gerenciamento" (28/08/2026, pedido do usuário) —
      // agrupa Tema/Rol de Membros/Ministérios e Cargos/Gerenciar Usuários/
      // Repositório de Flyers/E-mails de eventos, que antes eram 6 tiles
      // separados aqui — cada um continua com seu próprio gate de permissão
      // dentro de `SettingsManagementPage`, então quem não tem acesso a
      // nenhum deles ainda vê pelo menos o Tema (sem gate). O selo de
      // pendentes de Gerenciar Usuários borbulha pro tile de fora, pra um
      // admin não precisar entrar só pra notar.
      MoreTile(
        icon: Icons.settings_outlined,
        label: 'Configurações e Gerenciamento',
        badgeCount: isAdmin ? pendingCount : 0,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsManagementPage()),
        ),
      ),
      // Tier 2 — só pra quem está autenticado.
      if (uid != null)
        MoreTile(
          icon: Icons.cake_outlined,
          label: 'Aniversariantes',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const BirthdaysPage())),
        ),
      if (uid != null)
        MoreTile(
          icon: Icons.mail_outline,
          label: 'Mensagens',
          badgeCount: pendingMessagesCount,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MessagesPage())),
        ),
      // Tier 3 — admin / secretaria / eventos / dirigentes / introdução.
      // Introdução e Ordem de Culto sobem pro topo deste tier (28/08/2026,
      // pedido do usuário) — antes ficavam no fim da lista inteira.
      // NOVO (24/08/2026): área Introdução — ver lib/models/visitor.dart.
      if (canAccessIntroduction)
        MoreTile(
          customIcon: _IntroductionIcon(color: context.textPrimary),
          label: 'Introdução',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const IntroductionPage())),
        ),
      // NOVO (27/08/2026): Ordem de Culto — dirigente/admin cadastra e gera;
      // Louvor (28/08/2026, papel novo) só enxerga, numa visão própria com
      // tom/cifra (ver `openServiceOrder`, `service_order_navigation.dart`). Abre
      // primeiro a lista das ordens já cadastradas — antes ia direto pro
      // cadastro. Tile incondicional (28/08/2026, pedido do usuário) — a
      // partir de agora tem uma visão pra qualquer usuário, logado ou em
      // acesso convidado (`ServiceOrderMemberViewPage`, mesmo padrão de
      // leitura pública já usado por `posts`/`devotionals`), travada num
      // timer até o dirigente tocar em "Iniciar Culto".
      MoreTile(
        customIcon: _ServiceOrderIcon(color: context.textPrimary),
        label: 'Ordem de Culto',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ServiceOrderListPage()),
        ),
      ),
      // NOVO (28/08/2026): Ministério de Louvor — repertório mensal/semanal
      // + menu ☰ com "Cifras". Gate é só Louvor/admin
      // (`canViewPraiseOrder`) + quem o admin selecionou individualmente
      // como editor de cifra (`canEditCifrasProvider` — não é um papel, ver
      // `lib/data/cifra_repository.dart`) — **Dirigentes NÃO entra mais**
      // aqui (pedido explícito do usuário: "Dirigente não deve ter acesso a
      // nada em Ministério de Louvor"; antes `canManageServiceOrders`
      // também dava acesso). A Ordem de Culto em si continua toda de
      // Dirigentes — isso é só o Ministério de Louvor.
      if ((profile?.canViewPraiseOrder ?? false) || ref.watch(canEditCifrasProvider))
        MoreTile(
          icon: Icons.queue_music_outlined,
          label: 'Ministério de Louvor',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PraiseMinistryPage()),
          ),
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
            padding: const EdgeInsets.all(24),
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
