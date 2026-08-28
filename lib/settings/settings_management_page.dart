import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/event_email_senders_page.dart';
import '../admin/manage_ministries_page.dart';
import '../admin/manage_users_page.dart';
import '../admin/members_page.dart';
import '../admin/recurring_event_flyer_repository_page.dart';
import '../data/user_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../main_shell.dart' show MoreTile, SettingsMailIcon;
import '../theme/app_theme.dart';
import '../theme/theme_settings_page.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Agrupa 6 tiles que antes viviam soltos no menu Mais: Tema, Rol
/// de Membros, Ministérios e Cargos, Gerenciar Usuários, Repositório de
/// Flyers e E-mails de eventos — cada um continua com seu próprio gate de
/// permissão (só Tema é irrestrito), agora dentro desta tela em vez de
/// espalhados na grade principal. Reaproveita `MoreTile`/`SettingsMailIcon`
/// (tornados públicos em `main_shell.dart` só pra isso) pra manter a
/// aparência idêntica ao menu Mais.
class SettingsManagementPage extends ConsumerWidget {
  const SettingsManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isAdmin = profile?.isAdmin ?? false;
    final canManageEventos = profile?.canManageEventos ?? false;
    final canManageBirthdays = profile?.canManageBirthdays ?? false;
    final pendingCountAsync = isAdmin
        ? ref.watch(pendingUserCountProvider)
        : const AsyncValue.data(0);
    final pendingCount = pendingCountAsync.asData?.value ?? 0;

    final tiles = [
      MoreTile(
        icon: Icons.brightness_6_outlined,
        label: 'Tema',
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ThemeSettingsPage())),
      ),
      if (uid != null)
        MoreTile(
          icon: Icons.people_outline,
          label: 'Rol de Membros',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MembersPage())),
        ),
      if (canManageBirthdays)
        MoreTile(
          icon: Icons.groups_outlined,
          label: 'Ministérios e Cargos',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ManageMinistriesPage()),
          ),
        ),
      if (isAdmin)
        MoreTile(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Gerenciar Usuários',
          badgeCount: pendingCount,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ManageUsersPage())),
        ),
      if (isAdmin)
        MoreTile(
          icon: Icons.collections_outlined,
          label: 'Repositório de Flyers',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecurringEventFlyerRepositoryPage()),
          ),
        ),
      if (canManageEventos)
        MoreTile(
          customIcon: SettingsMailIcon(color: context.textPrimary),
          label: 'E-mails de eventos',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EventEmailSendersPage()),
          ),
        ),
    ];

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Configurações e Gerenciamento'),
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
          ],
        ),
      ),
    );
  }
}
