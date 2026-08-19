import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin/event_email_senders_page.dart';
import 'admin/manage_users_page.dart';
import 'admin/members_page.dart';
import 'admin/recurring_event_flyer_repository_page.dart';
import 'auth/edit_profile_page.dart';
import 'auth/login_page.dart';
import 'bible/bible_book_list_page.dart';
import 'birthdays/birthdays_page.dart';
import 'data/post_repository.dart' show currentUidProvider;
import 'data/user_repository.dart';
import 'devotionals/devotionals_list_page.dart';
import 'events/events_page.dart';
import 'gallery/album_list_page.dart';
import 'home/home_feed_page.dart';
import 'hymnal/hymn_list_page.dart';
import 'models/hymn.dart';
import 'partners/partners_page.dart';
import 'prayer/prayer_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_settings_page.dart';
import 'widgets/sibval_app_bar.dart';

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
    _ComingSoonPage(title: 'Contribua'),
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
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          backgroundColor: SibValColors.navyBlue,
          destinations: [
            NavigationDestination(
              icon: const _BoldAssetIcon('assets/icons/ic_devocional.png', size: 26, color: Colors.white70),
              selectedIcon:
                  const _BoldAssetIcon('assets/icons/ic_devocional.png', size: 26, color: SibValColors.navyBlueDark),
              label: 'Devocionais',
            ),
            const NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Eventos'),
            const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Início'),
            const NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Contribua'),
            const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mais'),
          ],
        ),
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
                child: Image.asset(asset, color: color, colorBlendMode: BlendMode.srcIn),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle(title),
          Expanded(
            child: Center(
              child: Text('Em breve.', style: TextStyle(color: context.textSecondary, fontSize: 16)),
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
    final canManageBirthdays = profile?.canManageBirthdays ?? false;
    final canManageEventos = profile?.canManageEventos ?? false;
    final pendingCountAsync = isAdmin ? ref.watch(pendingUserCountProvider) : const AsyncValue.data(0);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;

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
        label: 'Cantor Cristão',
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HymnListPage(hymnal: Hymnal.cantorCristao))),
      ),
      _MoreTile(
        imageAsset: 'assets/icons/ic_hcc.png',
        label: 'HCC',
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HymnListPage(hymnal: Hymnal.hinarioCristao))),
      ),
      _MoreTile(
        imageAsset: 'assets/icons/ic_prayer.png',
        label: 'Pedido de Oração',
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
      // Tier 2 — só pra quem está autenticado.
      if (uid != null)
        _MoreTile(
          icon: Icons.cake_outlined,
          label: 'Aniversariantes',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BirthdaysPage())),
        ),
      // Tier 3 — admin / secretaria / eventos.
      if (canManageBirthdays)
        _MoreTile(
          icon: Icons.people_outline,
          label: 'Rol de Membros',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MembersPage())),
        ),
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
          icon: Icons.email_outlined,
          label: 'E-mails de eventos',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventEmailSendersPage())),
        ),
      // Tier 4 — recursos ainda não implementados.
      const _MoreTile(icon: Icons.church_outlined, label: 'Ordem de Culto', enabled: false, comingSoon: true),
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
            mainAxisSpacing: 20,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: tiles,
          ),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(24),
            child: uid == null
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage())),
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
/// foto e outros dados), igual pedido pelo usuário.
class _MoreHeader extends StatelessWidget {
  const _MoreHeader({required this.profile});

  final CurrentUserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: SibValColors.navyBlueLight, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                backgroundImage: profile.photoUrl.isNotEmpty ? NetworkImage(profile.photoUrl) : null,
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
                    const Text(
                      'Editar perfil',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile em grade (ícone em cima, rótulo embaixo) — espelha o
/// GridLayoutManager(3) do MoreFragment.kt nativo, estilo "app de banco".
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    this.icon,
    this.imageAsset,
    required this.label,
    this.onTap,
    this.badgeCount = 0,
    this.enabled = true,
    this.comingSoon = false,
  }) : assert(icon != null || imageAsset != null);

  final IconData? icon;
  final String? imageAsset;
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              label: Text('$badgeCount'),
              isLabelVisible: badgeCount > 0,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: imageAsset != null
                    ? Image.asset(imageAsset!, width: 22, height: 22, color: color, colorBlendMode: BlendMode.srcIn)
                    : Icon(icon, color: color),
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
