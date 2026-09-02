import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../bible/bible_book_list_page.dart';
import '../data/devotional_repository.dart';
import '../data/event_repository.dart';
import '../data/message_repository.dart';
import '../data/post_repository.dart';
import '../data/user_repository.dart';
import '../devotionals/devotional_detail_page.dart';
import '../events/event_detail_page.dart';
import '../main_shell.dart' show mainShellTabIndexProvider, MaisPage;
import '../messages/messages_page.dart';
import '../models/devotional.dart';
import '../models/event.dart';
import '../models/post.dart';
import '../data/prayer_repository.dart' show pendingPrayerCountProvider;
import '../prayer/prayer_page.dart';
import '../service_order/service_order_list_page.dart';
import '../theme/app_theme.dart';
import '../util/verse_of_day.dart';
import '../widgets/coming_soon_page.dart';
import 'mural_page.dart';

/// Índice da aba Eventos na barra inferior (`MainShell._pages`) — Início(0),
/// Devocionais(1), Eventos(2), Contribua(3). Usado pelo "Ver todos"/"Ver
/// agenda completa" abaixo, que apontam pra dados reais de evento —
/// diferente do ícone "Agenda" da grade (`ComingSoonPage`), que é uma função
/// futura ainda não implementada e não tem nada a ver com essa aba
/// (02/09/2026, pedido explícito do usuário).
const _eventsTabIndex = 2;

/// Início "painel" (02/09/2026, inspirado num modelo de referência trazido
/// pelo usuário, `NOVO_LAYOUT.jpeg`) — saudação + versículo, grade de acesso
/// rápido e cards com o que está por vir, exibidos em `HomePage` (era
/// `HomeFeedPage`, que também tinha o feed — o Mural virou uma tela própria,
/// ver `mural_page.dart`).
class HomeHighlights extends StatelessWidget {
  const HomeHighlights({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GreetingAndVerse(),
        _QuickAccessGrid(),
        _UpcomingEventsSection(),
        _TodayDevotionalSection(),
        _MyClassSection(),
        _WeekAndNoticesRow(),
        SizedBox(height: 4),
      ],
    );
  }
}

/// "Olá, {nome}!" + versículo do dia (02/09/2026, pedido do usuário) — duas
/// colunas lado a lado (02/09/2026, revisão pedida pelo usuário: "igual no
/// modelo" — no `NOVO_LAYOUT.jpeg`, a saudação ocupa a coluna esquerda e o
/// card do versículo a direita, não empilhados). Nome vem de
/// `currentUserProfileProvider` (só o primeiro nome); em acesso convidado
/// (`profile == null`) cai num "Olá!" genérico. Versículo vem de
/// `verse_of_day.dart` — lista curada local, sem coleção própria no
/// Firestore ainda (ver doc comment de lá pro porquê).
class _GreetingAndVerse extends ConsumerWidget {
  const _GreetingAndVerse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final firstName = (profile?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final greeting = firstName.isEmpty ? 'Olá!' : 'Olá, $firstName!';
    final verse = verseOfTheDay();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        // Centralizada na vertical (pedido do usuário) — a coluna da
        // saudação é mais baixa que o card do versículo, então `.center`
        // (era `.start`) alinha ela no meio da altura do card ao lado, em
        // vez de grudada no topo.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            // Saudação um pouco maior (6→7) e versículo um pouco mais
            // estreito (6→5), pedido do usuário.
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting 👋',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 23,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Que bom ter você por aqui!',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote,
                    color: SibValColors.goldAccent,
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"${verse.text}"',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    verse.reference,
                    style: const TextStyle(
                      color: SibValColors.goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rótulo de seção reaproveitado por qualquer bloco do painel de Início —
/// título em maiúsculas discreto + link opcional "Ver todos".
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: context.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Ver todos',
              style: TextStyle(
                color: SibValColors.goldAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

/// Caixa branca (`cardColor`) com o `HomeSectionHeader` já dentro, no topo —
/// reaproveitada por todos os blocos do painel abaixo da grade (pedido do
/// usuário: "dentro de uma caixa como no modelo" — no `NOVO_LAYOUT.jpeg`,
/// cada bloco é um card único, com o título dentro dele).
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.title,
    this.onSeeAll,
    required this.child,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: title, onSeeAll: onSeeAll),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Grade de acesso rápido (02/09/2026, revisão pedida pelo usuário) —
/// quadrada, e nenhum ícone repete o que já está na barra inferior (Início/
/// Devocionais/Eventos/Contribua). Lista definida pelo usuário: Bíblia,
/// Ordem de Culto, Oração, EBD, Mensagens, Agenda, PGMs, Mais. EBD/Agenda/
/// PGMs ainda não têm tela própria — abrem `ComingSoonPage`. "Agenda" aqui é
/// uma função futura distinta da aba Eventos (não redireciona pra lá,
/// diferente da 1ª versão desta grade).
class _QuickAccessGrid extends ConsumerWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final pendingMessagesAsync = uid != null
        ? ref.watch(pendingMessagesCountProvider)
        : const AsyncValue.data(0);
    final pendingMessages = pendingMessagesAsync.asData?.value ?? 0;
    // Badge de pedidos de oração pendentes (02/09/2026) — morava no tile
    // "Pedido de Oração" de `MaisPage`, removido de lá por duplicar este
    // ícone; migrado pra cá pra não perder o aviso.
    final canViewPrayerRequests =
        ref.watch(currentUserProfileProvider).asData?.value?.canViewPrayerRequests ??
        false;
    final pendingPrayerAsync = canViewPrayerRequests
        ? ref.watch(pendingPrayerCountProvider)
        : const AsyncValue.data(0);
    final pendingPrayer = pendingPrayerAsync.asData?.value ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
        children: [
          _QuickAccessTile(
            icon: Icons.menu_book,
            label: 'Bíblia',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BibleBookListPage()),
            ),
          ),
          _QuickAccessTile(
            icon: Icons.church,
            label: 'Ordem de Culto',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ServiceOrderListPage()),
            ),
          ),
          _QuickAccessTile(
            imageAsset: 'assets/icons/ic_prayer.png',
            label: 'Oração',
            badgeCount: pendingPrayer,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrayerPage()),
            ),
          ),
          _QuickAccessTile(
            icon: Icons.school_outlined,
            label: 'EBD',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComingSoonPage(title: 'EBD'),
              ),
            ),
          ),
          _QuickAccessTile(
            icon: Icons.mail_outline,
            label: 'Mensagens',
            badgeCount: pendingMessages,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MessagesPage()),
            ),
          ),
          _QuickAccessTile(
            icon: Icons.calendar_month_outlined,
            label: 'Agenda',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComingSoonPage(title: 'Agenda'),
              ),
            ),
          ),
          _QuickAccessTile(
            icon: Icons.groups_outlined,
            label: 'PGMs',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ComingSoonPage(title: 'PGMs'),
              ),
            ),
          ),
          _QuickAccessTile(
            icon: Icons.more_horiz,
            label: 'Mais',
            // Destaque (02/09/2026, pedido do usuário) — preenchido em
            // dourado sólido com ícone/texto navy, em vez do card neutro +
            // ícone dourado dos outros sete. Mesma dupla de cores já usada
            // pro botão primário do app (`ElevatedButtonTheme` em
            // `app_theme.dart`: fundo `goldAccent`, texto `navyBlueDark`) —
            // reaproveitada aqui em vez de inventar uma combinação nova, pra
            // "Mais" ler como o item de destaque/chamada da grade.
            highlighted: true,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MaisPage())),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    this.icon,
    this.imageAsset,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.highlighted = false,
  }) : assert(icon != null || imageAsset != null);

  final IconData? icon;
  final String? imageAsset;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  /// Verdadeiro só pro tile "Mais" (02/09/2026, pedido do usuário) — troca o
  /// card neutro + ícone dourado pelo par fundo dourado/ícone-texto navy,
  /// mesma combinação do botão primário do app (`ElevatedButtonTheme`).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final iconColor = highlighted
        ? SibValColors.navyBlueDark
        : SibValColors.goldAccent;
    final labelColor = highlighted
        ? SibValColors.navyBlueDark
        : context.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: highlighted
              ? SibValColors.goldAccent
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: highlighted
              ? null
              : Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              label: Text('$badgeCount'),
              isLabelVisible: badgeCount > 0,
              child: imageAsset != null
                  ? Image.asset(
                      imageAsset!,
                      width: 26,
                      height: 26,
                      color: iconColor,
                      colorBlendMode: BlendMode.srcIn,
                    )
                  : Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Próximo na Igreja" — os até 2 eventos publicados mais próximos
/// (`eventsProvider`, já ordenado ascendente por `dateTimeMillis`), dentro de
/// uma única `_HighlightCard`. Some da tela quando não há nenhum evento
/// publicado futuro.
class _UpcomingEventsSection extends ConsumerWidget {
  const _UpcomingEventsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final events = eventsAsync.asData?.value ?? const <Event>[];
    if (events.isEmpty) return const SizedBox.shrink();
    final upcoming = events.take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: _HighlightCard(
        title: 'Próximo na Igreja',
        onSeeAll: () =>
            ref.read(mainShellTabIndexProvider.notifier).state =
                _eventsTabIndex,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < upcoming.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _UpcomingEventRow(
                  event: upcoming[i],
                  // Cor do 2º card (02/09/2026, corrige bug relatado pelo
                  // usuário — ver nota em `_UpcomingEventRow`): era
                  // `navyBlueLight`, que é literalmente o `cardColor` do
                  // tema escuro — o preenchimento/contorno translúcidos
                  // ficavam idênticos ao fundo do `_HighlightCard` por trás,
                  // então o card parecia "sem caixinha". `navyBlueDark`
                  // nunca é `cardColor` de nenhum dos dois temas (é o
                  // `scaffoldBackground` do escuro, não o card), então
                  // sempre contrasta com o fundo do `_HighlightCard`.
                  accent: i.isEven
                      ? SibValColors.goldAccent
                      : SibValColors.navyBlueDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpcomingEventRow extends StatelessWidget {
  const _UpcomingEventRow({required this.event, required this.accent});

  final Event event;
  final Color accent;

  static final _timeFormat = DateFormat('HH:mm', 'pt_BR');
  static final _dayMonthFormat = DateFormat('dd/MM', 'pt_BR');

  String _dayLabel(DateTime day) {
    final now = toSaoPauloTimeNow();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    return _dayMonthFormat.format(day);
  }

  @override
  Widget build(BuildContext context) {
    final sp = event.dateTimeSaoPaulo;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailPage(eventId: event.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          // Contorno explícito, além da cor escolhida em
          // `_UpcomingEventsSection` já contrastar com qualquer `cardColor`
          // — defesa a mais contra o mesmo tipo de coincidência de cor caso
          // o accent mude de novo no futuro.
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_dayLabel(sp)} • ${_timeFormat.format(sp)}',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accent, size: 18),
          ],
        ),
      ),
    );
  }
}

/// "Devocional de Hoje" — dentro de uma `_HighlightCard`, só aparece quando
/// existe uma devocional publicada com `dateKey` igual ao dia de hoje (mesmo
/// critério de `Post.isFromToday` pro post automático de devocional no
/// Mural).
///
/// Imagem (02/09/2026, pedido do usuário: "use a imagem que já usamos como
/// padrão para devocionais em Flyers") — não duplica a lógica de escolher o
/// flyer (`recurringEventFlyers`, categoria `DevotionalFlyerCategory.dev`):
/// isso já é feito pela Cloud Function `postDevotionalToFeed`
/// (`SIBValApp2/functions/index.js`) toda vez que ela cria/atualiza o post
/// automático da devocional no Mural. Em vez disso, acha esse mesmo post
/// (`PostType.devotional`, `targetId == devotional.id`, mesmo vínculo já
/// usado por `PostCard` pra abrir `DevotionalDetailPage` a partir do flyer)
/// dentro de `postsProvider` e reaproveita o `imageUrl` dele. Sem post
/// encontrado ainda (ex.: gatilho em tempo real não rodou) ou sem imagem
/// configurada pro dia, cai no ícone de livro de sempre.
class _TodayDevotionalSection extends ConsumerWidget {
  const _TodayDevotionalSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devotionalsAsync = ref.watch(devotionalsProvider);
    final devotionals = devotionalsAsync.asData?.value ?? const <Devotional>[];
    final todayKey = DevotionalRepository.dateKeyOf(DateTime.now());
    Devotional? today;
    for (final d in devotionals) {
      if (d.dateKey == todayKey) {
        today = d;
        break;
      }
    }
    if (today == null) return const SizedBox.shrink();
    final devotional = today;

    final posts = ref.watch(postsProvider).asData?.value ?? const <Post>[];
    String imageUrl = '';
    for (final p in posts) {
      if (p.postType == PostType.devotional && p.targetId == devotional.id) {
        imageUrl = p.imageUrl;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: _HighlightCard(
        title: 'Devocional de Hoje',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  DevotionalDetailPage(devotionalId: devotional.id),
            ),
          ),
          child: Row(
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const _DevotionalIconThumb(),
                  ),
                )
              else
                const _DevotionalIconThumb(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      devotional.baseReference == null
                          ? devotional.title
                          : '${devotional.title} (${devotional.baseReference})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (devotional.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Por ${devotional.author}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícone de fallback do thumbnail de "Devocional de Hoje" — sem flyer
/// configurado pra essa categoria/dia (ou post ainda não sincronizado).
class _DevotionalIconThumb extends StatelessWidget {
  const _DevotionalIconThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: SibValColors.goldAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.menu_book,
        color: SibValColors.goldAccent,
        size: 28,
      ),
    );
  }
}

/// "Minha EBD" — placeholder (02/09/2026, pedido do usuário), sem dado real
/// por trás: o app não tem nenhuma coleção de frequência/lição de EBD ainda
/// (o próprio ícone "EBD" da grade acima também é "Em breve"). Fica como um
/// aviso simples até a funcionalidade existir de verdade.
class _MyClassSection extends StatelessWidget {
  const _MyClassSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: _HighlightCard(
        title: 'Minha EBD',
        child: Row(
          children: [
            const Icon(
              Icons.school_outlined,
              color: SibValColors.goldAccent,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Em breve você vai acompanhar por aqui sua frequência e a '
                'lição da semana.',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Esta Semana" + "Avisos" lado a lado (02/09/2026, pedido do usuário —
/// eram dois cards empilhados; "Avisos" também não estava aparecendo porque
/// escondia o card inteiro quando não havia nenhum post manual ainda, e o
/// usuário esperava ver a caixa mesmo assim). Os dois agora são sempre
/// visíveis, com uma mensagem de estado vazio no lugar da lista quando não
/// há dado — isso é o que garante o par ficar sempre "lado a lado", em vez
/// de um sumir e o outro ficar sozinho ocupando a linha inteira.
class _WeekAndNoticesRow extends StatelessWidget {
  const _WeekAndNoticesRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _ThisWeekCard()),
          SizedBox(width: 10),
          Expanded(child: _NoticesCard()),
        ],
      ),
    );
  }
}

/// "Esta Semana" — eventos publicados (`eventsProvider`) que caem nos
/// próximos 7 dias (hoje incluso), agrupados por dia civil (fuso
/// America/Sao_Paulo). Mostra "Nenhum evento essa semana." quando não há
/// nenhum, em vez de sumir (ver doc comment de `_WeekAndNoticesRow`).
class _ThisWeekCard extends ConsumerWidget {
  const _ThisWeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final events = eventsAsync.asData?.value ?? const <Event>[];
    final now = toSaoPauloTimeNow();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    final thisWeek =
        events.where((e) {
          final d = e.dateTimeSaoPaulo;
          final day = DateTime(d.year, d.month, d.day);
          return !day.isBefore(today) && day.isBefore(weekEnd);
        }).toList()
          ..sort((a, b) => a.dateTimeMillis.compareTo(b.dateTimeMillis));

    final groups = <DateTime, List<Event>>{};
    for (final e in thisWeek) {
      final d = e.dateTimeSaoPaulo;
      final day = DateTime(d.year, d.month, d.day);
      groups.putIfAbsent(day, () => []).add(e);
    }
    final days = groups.keys.toList()..sort();

    return _HighlightCard(
      title: 'Esta Semana',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Nenhum evento essa semana.',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
            )
          else
            for (final day in days)
              _WeekDayGroup(day: day, events: groups[day]!),
          InkWell(
            onTap: () =>
                ref.read(mainShellTabIndexProvider.notifier).state =
                    _eventsTabIndex,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // "Ver todos os eventos" (02/09/2026, era "Ver agenda
                  // completa") — pedido do usuário: "Agenda" vai virar uma
                  // função à parte (ícone da grade, ainda "Em breve"), esse
                  // link é só pra lista de eventos de verdade (Eventos).
                  'Ver todos os eventos',
                  style: TextStyle(
                    color: SibValColors.goldAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: SibValColors.goldAccent,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDayGroup extends StatelessWidget {
  const _WeekDayGroup({required this.day, required this.events});

  final DateTime day;
  final List<Event> events;

  static final _weekdayFormat = DateFormat('EEE', 'pt_BR');
  static final _timeFormat = DateFormat('HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdayFormat
        .format(day)
        .replaceAll('.', '')
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Text(
                  weekday,
                  style: const TextStyle(
                    color: SibValColors.goldAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final event in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '${_timeFormat.format(event.dateTimeSaoPaulo)} ${event.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Avisos" — reaproveita os posts manuais (`PostType.manual`) do Mural
/// (`postsProvider`) como fonte de dado: são literalmente publicações
/// escritas por quem tem o papel Publicações/admin, o mesmo conceito de
/// "aviso" do modelo de referência — sem coleção nova. Mostra "Nenhum aviso
/// no momento." quando não há nenhum, em vez de sumir (ver doc comment de
/// `_WeekAndNoticesRow`). Toque num aviso (ou "Ver todos") abre o Mural
/// completo (onde dá pra curtir/comentar de verdade).
class _NoticesCard extends ConsumerWidget {
  const _NoticesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);
    final posts = postsAsync.asData?.value ?? const <Post>[];
    final notices = posts
        .where((p) => p.postType == PostType.manual)
        .take(3)
        .toList();

    return _HighlightCard(
      title: 'Avisos',
      onSeeAll: notices.isEmpty
          ? null
          : () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MuralPage())),
      child: notices.isEmpty
          ? Text(
              'Nenhum aviso no momento.',
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            )
          : Column(
              children: [
                for (var i = 0; i < notices.length; i++) ...[
                  if (i > 0) Divider(height: 12, color: context.textTertiary),
                  _NoticeRow(post: notices[i]),
                ],
              ],
            ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MuralPage())),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 32,
                  height: 32,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: SibValColors.goldAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: SibValColors.goldAccent,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              post.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textPrimary, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}
