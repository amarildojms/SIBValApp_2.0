import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/login_page.dart';
import '../data/notification_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../notifications/notifications_page.dart';
import '../theme/app_theme.dart';
import '../util/cache_busted_image.dart';

/// Espelha app_bar_main.xml/MainActivity.kt: barra fixa navy, sem texto de
/// título em nenhuma tela — só a logo centralizada. À esquerda, o sino de
/// notificação (com badge) na aba Início, ou seta de voltar em qualquer outra
/// tela. À direita, o ícone de entrar (deslogado) ou de logado (não é mais
/// atalho de logout — isso só existe na tela "Mais").
class SibValAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SibValAppBar({super.key, required this.isHome, this.actions = const [], this.bottom});

  final bool isHome;

  /// Ícones extras (ex.: aumentar/diminuir fonte na Bíblia/Hinário/Devocional),
  /// inseridos antes do ícone de login.
  final List<Widget> actions;

  /// Ex.: a TabBar de Eventos (Eventos/Programação Semanal).
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: SibValColors.navyBlue,
      foregroundColor: Colors.white,
      // Material 3 aplica um tint de "surfaceTintColor" sobre a AppBar quando o
      // conteúdo rola por baixo dela (scrolledUnderElevation) — sem isso, o azul
      // muda de tom ao rolar a tela. Desligado de propósito: a cor da marca deve
      // ficar sempre fixa.
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      leading: isHome ? const _NotificationBellButton() : const _BackButton(),
      title: Image.asset('assets/images/logo.png', height: 40),
      centerTitle: true,
      actions: [...actions, const _LoginButton(), const SizedBox(width: 8)],
      bottom: bottom,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.maybePop(context),
    );
  }
}

class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final uid = ref.watch(currentUidProvider);
    final unreadCount =
        notificationsAsync.asData?.value.where((n) => uid != null && !n.readBy.contains(uid)).length ?? 0;
    return IconButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsPage()),
      ),
      icon: Badge(
        label: Text('$unreadCount'),
        isLabelVisible: unreadCount > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _LoginButton extends ConsumerWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.login),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        ),
      );
    }
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final photoUrl = profile?.photoUrl ?? '';
    return Padding(
      padding: const EdgeInsets.all(8),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white24,
        backgroundImage: photoUrl.isNotEmpty
            ? NetworkImage(cacheBustedPhotoUrl(photoUrl, profile?.photoUpdatedAt))
            : null,
        child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
      ),
    );
  }
}
