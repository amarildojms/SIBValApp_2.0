import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin/event_email_senders_page.dart';
import 'admin/manage_ministries_page.dart';
import 'admin/manage_users_page.dart';
import 'admin/members_page.dart';
import 'admin/recurring_event_flyer_repository_page.dart';
import 'auth/communications_consent_banner.dart';
import 'auth/edit_profile_page.dart';
import 'auth/login_page.dart';
import 'auth/required_consent_gate_page.dart';
import 'bible/bible_book_list_page.dart';
import 'birthdays/birthdays_page.dart';
import 'contribute/contribute_page.dart';
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
import 'hymnal/hymn_list_page.dart';
import 'introduction/introduction_page.dart';
import 'messages/messages_page.dart';
import 'models/hymn.dart';
import 'notifications/notification_permission_banner.dart';
import 'notifications/push_notification_service.dart';
import 'partners/partners_page.dart';
import 'prayer/prayer_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_settings_page.dart';
import 'util/cache_busted_image.dart';
import 'widgets/sibval_app_bar.dart';
import 'widgets/update_gate.dart';

/// Espelha o bottom_nav_menu.xml original: Devocionais, Eventos, Início,
/// Contribua, Mais. Só o Início tem conteúdo real nesta fase — os demais são
/// placeholders "em breve" até as próximas fases da migração.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = _homeIndex; // Início é a aba central, igual ao app original.

  static const _pages = [
    DevotionalsListPage(),
    EventsPage(),
    HomeFeedPage(),
    ContributePage(),
    _MaisPage(),
  ];

  static const _homeIndex = 2;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == _homeIndex,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _index = _homeIndex);
      },
      child: Consumer(
        builder: (context, ref, _) {
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
            ref.read(pushNotificationServiceProvider).requestPermissionAndRegisterToken(uid);
          }
          // Bloqueio obrigatório de atualização (21/08/2026) — vale pra
          // qualquer um, logado ou não, ver `update_gate.dart`.
          final updateStatus = ref.watch(updateStatusProvider).asData?.value;
          final versionConfig = ref.watch(appVersionConfigProvider).asData?.value;
          if (updateStatus == UpdateStatus.forceBlocked && versionConfig != null) {
            return UpdateRequiredPage(config: versionConfig);
          }
          // Contas logadas criadas antes dos Termos de Uso/checkbox de
          // privacidade existirem (20/08/2026) ficam bloqueadas aqui até
          // aceitarem — ver `RequiredConsentGatePage`.
          if (uid != null && profile != null && (!profile.acceptedTermsOfUse || !profile.acceptedPrivacyPolicy)) {
            return RequiredConsentGatePage(uid: uid, communicationsConsent: profile.communicationsConsent);
          }
          return Scaffold(
            body: Column(
              children: [
                const CommunicationsConsentBanner(),
                const NotificationPermissionBanner(),
                if (updateStatus == UpdateStatus.graceWarning && versionConfig != null)
                  UpdateAvailableBanner(config: versionConfig),
                Expanded(
                  child: IndexedStack(index: _index, children: _pages),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              backgroundColor: SibValColors.navyBlue,
              destinations: [
                NavigationDestination(
                  icon: Badge(
                    label: Text('$unreadDevotionals'),
                    isLabelVisible: unreadDevotionals > 0,
                    child: const _BoldAssetIcon('assets/icons/ic_devocional.png', size: 26, color: Colors.white70),
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
                const NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Eventos'),
                const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Início'),
                const NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Contribua'),
                const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
              ],
            ),
          );
        },
      ),
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

  static const _offsets = [Offset.zero, Offset(-0.8, 0), Offset(0.8, 0), Offset(0, -0.8), Offset(0, 0.8)];

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
                child: Image.asset(asset, color: color, colorBlendMode: BlendMode.srcIn),
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
class _SettingsMailIcon extends StatelessWidget {
  const _SettingsMailIcon({required this.color});

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

/// Mesa de recepção (ícone `desk_outlined`, que já traz um monitor
/// embutido no desenho) com um boneco (pessoa) no canto — mesma composição
/// de `_SettingsMailIcon` acima, só trocando os dois ícones combinados.
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
    final canManageEventos = profile?.canManageEventos ?? false;
    final canViewPrayerRequests = profile?.canViewPrayerRequests ?? false;
    // NOVO (24/08/2026, unificado numa só tela em 25/08/2026, papel
    // renomeado de "Recepção" pra "Introdução" depois): área Introdução — o
    // que cada um vê dentro dela depende do papel, ver introduction_page.dart.
    // Um tile só, visível pra quem tem qualquer um dos três papéis (ou admin).
    final canAccessIntroduction = (profile?.canRegisterVisitors ?? false) ||
        (profile?.canViewVisitorSummaries ?? false) ||
        (profile?.canViewVisitorDetails ?? false);
    final pendingCountAsync = isAdmin ? ref.watch(pendingUserCountProvider) : const AsyncValue.data(0);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;
    final pendingPrayerCountAsync = canViewPrayerRequests
        ? ref.watch(pendingPrayerCountProvider)
        : const AsyncValue.data(0);
    final pendingPrayerCount = pendingPrayerCountAsync.asData?.value ?? 0;
    final pendingMessagesCountAsync = uid != null ? ref.watch(pendingMessagesCountProvider) : const AsyncValue.data(0);
    final pendingMessagesCount = pendingMessagesCountAsync.asData?.value ?? 0;

    final tiles = [
      // Tier 1 — disponível para todos, sem login.
      _MoreTile(
        icon: Icons.photo_camera_outlined,
        label: 'Galeria',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlbumListPage())),
      ),
      _MoreTile(
        icon: Icons.menu_book,
        label: 'Bíblia',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BibleBookListPage())),
      ),
      _MoreTile(
        imageAsset: 'assets/icons/ic_cc.png',
        imageSize: 30,
        label: 'Cantor Cristão',
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HymnListPage(hymnal: Hymnal.cantorCristao))),
      ),
      _MoreTile(
        imageAsset: 'assets/icons/ic_hcc.png',
        imageSize: 30,
        label: 'HCC',
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HymnListPage(hymnal: Hymnal.hinarioCristao))),
      ),
      _MoreTile(
        imageAsset: 'assets/icons/ic_prayer.png',
        label: 'Pedido de Oração',
        badgeCount: pendingPrayerCount,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrayerPage())),
      ),
      _MoreTile(
        icon: Icons.handshake_outlined,
        label: 'Vínculos Institucionais',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnersPage())),
      ),
      _MoreTile(
        icon: Icons.brightness_6_outlined,
        label: 'Tema',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ThemeSettingsPage())),
      ),
      // Tier 2 — só pra quem está autenticado. Rol de Membros passa a ser
      // visível a todo autenticado (19/08/2026) — só edição/exclusão/inserção
      // e a seção de pendentes ficam restritas a canManageBirthdays, dentro
      // da própria tela.
      if (uid != null)
        _MoreTile(
          icon: Icons.cake_outlined,
          label: 'Aniversariantes',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BirthdaysPage())),
        ),
      if (uid != null)
        _MoreTile(
          icon: Icons.people_outline,
          label: 'Rol de Membros',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembersPage())),
        ),
      if (uid != null)
        _MoreTile(
          icon: Icons.mail_outline,
          label: 'Mensagens',
          badgeCount: pendingMessagesCount,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MessagesPage())),
        ),
      if (profile?.canManageBirthdays ?? false)
        _MoreTile(
          icon: Icons.groups_outlined,
          label: 'Ministérios e Cargos',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageMinistriesPage())),
        ),
      // Tier 3 — admin / secretaria / eventos.
      if (isAdmin)
        _MoreTile(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Gerenciar Usuários',
          badgeCount: pendingCount,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageUsersPage())),
        ),
      if (isAdmin)
        _MoreTile(
          icon: Icons.collections_outlined,
          label: 'Repositório de Flyers',
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecurringEventFlyerRepositoryPage())),
        ),
      if (canManageEventos)
        _MoreTile(
          customIcon: _SettingsMailIcon(color: context.textPrimary),
          label: 'E-mails de eventos',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventEmailSendersPage())),
        ),
      // NOVO (24/08/2026): área Introdução — ver lib/models/visitor.dart.
      if (canAccessIntroduction)
        _MoreTile(
          customIcon: _IntroductionIcon(color: context.textPrimary),
          label: 'Introdução',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IntroductionPage())),
        ),
      // Tier 4 — recursos ainda não implementados.
      const _MoreTile(icon: Icons.church_outlined, label: 'Ordem de Culto', enabled: false, comingSoon: true),
    ];

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: ListView(
        children: [
          if (uid != null && profile != null) _MoreHeader(profile: profile) else const SizedBox(height: 16),
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
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage())),
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
                      ElevatedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sair')),
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
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: SibValColors.navyBlueLight, borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                backgroundImage: profile.photoUrl.isNotEmpty
                    ? NetworkImage(cacheBustedPhotoUrl(profile.photoUrl, profile.photoUpdatedAt))
                    : null,
                child: profile.photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.shortName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    const Text('Editar perfil', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    if (membershipLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(membershipLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
/// em cima e "completo" embaixo.
class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Cadastro', style: TextStyle(color: Colors.white70, fontSize: 9)),
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
                valueColor: const AlwaysStoppedAnimation(SibValColors.goldAccent),
              ),
              Text(
                '$percent%',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        const Text('completo', style: TextStyle(color: Colors.white70, fontSize: 9)),
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
  var totalMonths = (now.year - membershipDate.year) * 12 + (now.month - membershipDate.month);
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
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    this.icon,
    this.imageAsset,
    this.customIcon,
    this.imageSize = 22,
    required this.label,
    this.onTap,
    this.badgeCount = 0,
    this.enabled = true,
    this.comingSoon = false,
  }) : assert(icon != null || imageAsset != null || customIcon != null);

  final IconData? icon;
  final String? imageAsset;

  /// Substitui `icon`/`imageAsset` quando o ícone precisa de composição (ex.:
  /// engrenagem + envelope de "E-mails de eventos") — ver `_SettingsMailIcon`.
  final Widget? customIcon;

  /// Tamanho do ícone de imagem dentro do CircleAvatar (22 por padrão) — Cantor
  /// Cristão e HCC usam 30 (20/08/2026, a pedido do usuário: ficavam pequenos
  /// perto dos ícones vetoriais dos demais tiles).
  final double imageSize;
  final String label;
  final VoidCallback? onTap;
  final int badgeCount;
  final bool enabled;

  /// Quando true, mostra "(Em breve)" numa linha separada abaixo do rótulo,
  /// em vez de embutido no texto do rótulo (evita quebra estranha no meio).
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? context.textPrimary : context.textTertiary;
    return InkWell(
      onTap: enabled ? onTap : null,
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
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, height: 1.0),
            ),
            if (comingSoon)
              Text(
                '(Em breve)',
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 10, fontStyle: FontStyle.italic, height: 1.0),
              ),
          ],
        ),
      ),
    );
  }
}
