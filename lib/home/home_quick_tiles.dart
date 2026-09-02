import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bible/bible_book_list_page.dart';
import '../birthdays/birthdays_page.dart';
import '../data/cifra_repository.dart';
import '../data/message_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/prayer_repository.dart' show pendingPrayerCountProvider;
import '../data/service_order_repository.dart';
import '../data/user_repository.dart';
import '../gallery/album_list_page.dart';
import '../hymnal/hymnals_page.dart';
import '../introduction/introduction_page.dart';
import '../messages/messages_page.dart';
import '../partners/partners_page.dart';
import '../praise/praise_ministry_page.dart';
import '../prayer/prayer_page.dart';
import '../service_order/service_order_list_page.dart';
import '../settings/settings_management_page.dart';
import '../widgets/coming_soon_page.dart';
import 'mural_page.dart';

/// Todo ícone elegível pra grade de acesso rápido de Início e pro menu
/// "Mais" — as duas telas são faces da MESMA lista (03/09/2026, pedido do
/// usuário: "se eu substituir um dos 7 ícones por algum que está dentro do
/// menu Mais, ... o ícone que saiu da tela inicial deve estar lá [no Mais]
/// no lugar do que foi para a tela inicial"). Extraído de
/// `home_highlights.dart` pra também ser usado por `MaisPage`
/// (`main_shell.dart`) — antes "Mais" tinha sua própria lista fixa de tiles,
/// completamente alheia à ordem configurável da Início, então uma troca na
/// grade nunca refletia lá.
///
/// `HomeQuickTileDef.id` estável, persistido em
/// `homeQuickTilesOrderProvider` (`home_quick_tiles_repository.dart`) — quem
/// decide se um id aparece na grade de Início (7 primeiros elegíveis) ou no
/// "pool" do menu Mais (o resto) é `splitHomeQuickTiles`, não este arquivo.
class HomeQuickTileDef {
  const HomeQuickTileDef({
    required this.id,
    required this.label,
    this.icon,
    this.imageAsset,
    this.customIcon,
    required this.onTap,
    this.badgeCount = 0,
    this.live = false,
  }) : assert(icon != null || imageAsset != null || customIcon != null);

  final String id;
  final String label;
  final IconData? icon;
  final String? imageAsset;

  /// Substitui `icon`/`imageAsset` quando o ícone precisa de composição (ex.:
  /// mesa + boneco de "Introdução") — ver [IntroductionTileIcon]. Recebe a
  /// cor já resolvida por quem for desenhar o tile (`_QuickAccessTile` usa
  /// dourado/navy conforme destaque; `MoreTile` usa `context.textPrimary`).
  final Widget Function(Color color)? customIcon;
  final void Function(BuildContext context) onTap;
  final int badgeCount;

  /// Selo "ao vivo" piscando (só "Ordem de Culto", quando há alguma ordem
  /// iniciada e não finalizada — 02/09/2026, pedido do usuário).
  final bool live;
}

/// Todo ícone elegível pra grade de Início — os 7 originais mais os que hoje
/// só vivem dentro de "Mais" (02/09/2026, pedido do usuário: "deve exibir...
/// os outros itens que ficam dentro de Mais, assim o usuário pode arrastar
/// qualquer um para ficar entre os 7 principais"). Cada um tem seu próprio
/// gate de permissão/login, igual já tinham em `MaisPage`/`_QuickAccessGrid`
/// antes desta mudança — só reunidos aqui numa lista só. `ids` batem com
/// `defaultHomeQuickTileOrder` (`home_quick_tiles_repository.dart`).
List<HomeQuickTileDef> buildHomeQuickTileDefs(WidgetRef ref) {
  final uid = ref.watch(currentUidProvider);
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  final isAdmin = profile?.isAdmin ?? false;

  final pendingMessagesAsync = uid != null
      ? ref.watch(pendingMessagesCountProvider)
      : const AsyncValue.data(0);
  final pendingMessages = pendingMessagesAsync.asData?.value ?? 0;

  final canViewPrayerRequests = profile?.canViewPrayerRequests ?? false;
  final pendingPrayerAsync = canViewPrayerRequests
      ? ref.watch(pendingPrayerCountProvider)
      : const AsyncValue.data(0);
  final pendingPrayer = pendingPrayerAsync.asData?.value ?? 0;

  final pendingUsersAsync = isAdmin
      ? ref.watch(pendingUserCountProvider)
      : const AsyncValue.data(0);
  final pendingUsers = pendingUsersAsync.asData?.value ?? 0;

  // Selo "ao vivo" no ícone "Ordem de Culto" (02/09/2026, pedido do
  // usuário) — verdadeiro quando alguma ordem já foi iniciada
  // (`ServiceOrder.isStarted`) e ainda não finalizada, mesmo critério já
  // usado nas telas de apresentação (`ServiceOrderLivePage`/
  // `ServiceOrderPraiseViewPage`/`ServiceOrderMemberViewPage`).
  final orders = ref.watch(serviceOrdersProvider).asData?.value ?? const [];
  final anyOrderLive = orders.any((o) => o.isStarted && !o.isFinalized);

  final canAccessIntroduction =
      (profile?.canRegisterVisitors ?? false) ||
      (profile?.canViewVisitorSummaries ?? false) ||
      (profile?.canViewVisitorDetails ?? false);
  final canAccessPraise =
      (profile?.canViewPraiseOrder ?? false) || ref.watch(canEditCifrasProvider);

  return [
    HomeQuickTileDef(
      id: 'bible',
      label: 'Bíblia',
      icon: Icons.menu_book,
      onTap: (ctx) => Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => const BibleBookListPage()),
      ),
    ),
    HomeQuickTileDef(
      id: 'serviceOrder',
      label: 'Ordem de Culto',
      icon: Icons.church,
      live: anyOrderLive,
      onTap: (ctx) => Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => const ServiceOrderListPage()),
      ),
    ),
    HomeQuickTileDef(
      id: 'prayer',
      label: 'Oração',
      imageAsset: 'assets/icons/ic_prayer.png',
      badgeCount: pendingPrayer,
      onTap: (ctx) => Navigator.of(
        ctx,
      ).push(MaterialPageRoute(builder: (_) => const PrayerPage())),
    ),
    HomeQuickTileDef(
      id: 'ebd',
      label: 'EBD',
      icon: Icons.school_outlined,
      onTap: (ctx) => Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => const ComingSoonPage(title: 'EBD')),
      ),
    ),
    HomeQuickTileDef(
      id: 'messages',
      label: 'Mensagens',
      icon: Icons.mail_outline,
      badgeCount: pendingMessages,
      onTap: (ctx) => Navigator.of(
        ctx,
      ).push(MaterialPageRoute(builder: (_) => const MessagesPage())),
    ),
    HomeQuickTileDef(
      id: 'agenda',
      label: 'Agenda',
      icon: Icons.calendar_month_outlined,
      onTap: (ctx) => Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => const ComingSoonPage(title: 'Agenda'),
        ),
      ),
    ),
    HomeQuickTileDef(
      id: 'pgms',
      label: 'PGMs',
      icon: Icons.groups_outlined,
      onTap: (ctx) => Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => const ComingSoonPage(title: 'PGMs')),
      ),
    ),
    HomeQuickTileDef(
      id: 'mural',
      label: 'Mural',
      icon: Icons.dynamic_feed_outlined,
      onTap: (ctx) => Navigator.of(
        ctx,
      ).push(MaterialPageRoute(builder: (_) => const MuralPage())),
    ),
    HomeQuickTileDef(
      id: 'gallery',
      label: 'Galeria',
      icon: Icons.photo_camera_outlined,
      onTap: (ctx) => Navigator.of(
        ctx,
      ).push(MaterialPageRoute(builder: (_) => const AlbumListPage())),
    ),
    HomeQuickTileDef(
      id: 'hymnals',
      label: 'Hinários',
      icon: Icons.library_music_outlined,
      onTap: (ctx) => Navigator.of(
        ctx,
      ).push(MaterialPageRoute(builder: (_) => const HymnalsPage())),
    ),
    HomeQuickTileDef(
      id: 'partners',
      label: 'Vínculos Institucionais',
      icon: Icons.handshake_outlined,
      onTap: (ctx) => Navigator.of(
        ctx,
      ).push(MaterialPageRoute(builder: (_) => const PartnersPage())),
    ),
    HomeQuickTileDef(
      id: 'settingsManagement',
      label: 'Configurações e Gerenciamento',
      icon: Icons.settings_outlined,
      badgeCount: isAdmin ? pendingUsers : 0,
      onTap: (ctx) => Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => const SettingsManagementPage()),
      ),
    ),
    if (uid != null)
      HomeQuickTileDef(
        id: 'birthdays',
        label: 'Aniversariantes',
        icon: Icons.cake_outlined,
        onTap: (ctx) => Navigator.of(
          ctx,
        ).push(MaterialPageRoute(builder: (_) => const BirthdaysPage())),
      ),
    if (canAccessIntroduction)
      HomeQuickTileDef(
        id: 'introduction',
        label: 'Introdução',
        customIcon: (color) => IntroductionTileIcon(color: color),
        onTap: (ctx) => Navigator.of(
          ctx,
        ).push(MaterialPageRoute(builder: (_) => const IntroductionPage())),
      ),
    if (canAccessPraise)
      HomeQuickTileDef(
        id: 'praiseMinistry',
        label: 'Ministério de Louvor',
        icon: Icons.queue_music_outlined,
        onTap: (ctx) => Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => const PraiseMinistryPage()),
        ),
      ),
  ];
}

/// Divide a ordem persistida (`homeQuickTilesOrderProvider`) em [shown] (os 7
/// primeiros ids elegíveis pro usuário atual — grade de Início) e [pool] (o
/// resto — menu Mais), preenchendo automaticamente no fim os ids de [defs]
/// ainda sem posição salva (ex.: ícone novo adicionado numa versão futura do
/// app). [fullOrder] é devolvido pra quem precisa persistir uma troca de
/// posição de volta (`_QuickAccessGridState._swap`) sem recalcular esse
/// preenchimento de novo.
({List<String> fullOrder, List<String> shown, List<String> pool})
splitHomeQuickTiles(List<String> savedOrder, List<HomeQuickTileDef> defs) {
  final eligibleIds = defs.map((d) => d.id).toSet();
  final knownIds = savedOrder.toSet();
  final fullOrder = [
    ...savedOrder,
    ...defs.map((d) => d.id).where((id) => !knownIds.contains(id)),
  ];
  final eligibleOrder = fullOrder.where(eligibleIds.contains).toList();
  return (
    fullOrder: fullOrder,
    shown: eligibleOrder.take(7).toList(),
    pool: eligibleOrder.skip(7).toList(),
  );
}

/// Mesa + boneco — mesma composição de `_IntroductionIcon`, que existia
/// (privada) em `main_shell.dart` antes desta extração; agora pública e
/// única, reaproveitada tanto pela grade de Início (`_QuickAccessTile`)
/// quanto pelo menu Mais (`MoreTile`).
class IntroductionTileIcon extends StatelessWidget {
  const IntroductionTileIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.desk_outlined, color: color, size: 26),
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
