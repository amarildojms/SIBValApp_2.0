import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/devotional_repository.dart';
import '../data/event_repository.dart';
import '../data/home_quick_tiles_repository.dart';
import '../data/notice_repository.dart';
import '../data/post_repository.dart';
import '../data/user_repository.dart';
import '../devotionals/devotional_detail_page.dart';
import '../events/event_detail_page.dart';
import '../main_shell.dart' show mainShellTabIndexProvider, MaisPage;
import '../models/devotional.dart';
import '../models/event.dart';
import '../models/notice.dart';
import '../models/post.dart';
import '../notices/notice_detail_page.dart';
import '../service_order/service_order_countdown.dart';
import '../theme/app_theme.dart';
import '../util/verse_of_day.dart';
import 'home_quick_tiles.dart';

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
    // Ordem revisada (03/09/2026, pedido do usuário): Esta Semana + Avisos
    // (lado a lado, `_WeekAndNoticesRow`), Minha EBD, Devocional de Hoje,
    // Próximo na Igreja. "Esta Semana"/"Avisos" chegaram a virar dois cards
    // de largura total numa rodada anterior — revertido no mesmo dia (pedido
    // do usuário: "devem ser maiores na vertical somente, mas continuar um
    // ao lado do outro") — ficam mais altos, não mais largos.
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GreetingAndVerse(),
        _QuickAccessGrid(),
        _WeekAndNoticesRow(),
        _MyClassSection(),
        _TodayDevotionalSection(),
        _UpcomingEventsSection(),
        SizedBox(height: 8),
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
      // Compactado (02/09/2026, pedido do usuário: "veja se é possível
      // compactar... para que caiba tudo na tela sem necessidade de rolar")
      // — topo 16→10, fontes e paddings internos reduzidos em toda a seção.
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Que bom ter você por aqui!',
                  style: TextStyle(color: context.textSecondary, fontSize: 12.5),
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
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote,
                    color: SibValColors.goldAccent,
                    size: 16,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"${verse.text}"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontStyle: FontStyle.italic,
                      fontSize: 11.5,
                      height: 1.2,
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
      // Topo reduzido (03/09/2026, pedido do usuário: "coloque o título de
      // cada um um pouco mais para cima em cada card") — 12→8 só no topo,
      // aproxima o título da borda superior do card sem mudar o resto do
      // preenchimento.
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: title, onSeeAll: onSeeAll),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Grade de acesso rápido (02/09/2026, revisão pedida pelo usuário) —
/// quadrada, e nenhum ícone repete o que já está na barra inferior (Início/
/// Devocionais/Eventos/Contribua).
///
/// **Configurável** (02/09/2026, pedido do usuário: "ao tocar e segurar, deve
/// ser possível mudar as posições dos 7 ícones, e também deve exibir... os
/// outros itens que ficam dentro de Mais, assim o usuário pode arrastar
/// qualquer um para ficar entre os 7 principais") — toque e segure em
/// qualquer um dos 7 entra em "modo de edição": os outros ícones elegíveis
/// (hoje só dentro de "Mais") aparecem numa lista arrastável abaixo da
/// grade; arrastar um ícone sobre outro troca os dois de posição (dentro dos
/// 7, do "pool" pro meio dos 7, ou vice-versa). Ordem persistida por
/// aparelho em `homeQuickTilesOrderProvider`. "Mais" (8º item, sempre em
/// destaque) não participa da reordenação — é sempre o último ícone da
/// grade, fixo.
///
/// **Modo de edição em destaque** (02/09/2026, pedido do usuário: "deixe
/// apenas a área que mostra os ícones em destaque, deixando todo o resto da
/// tela sombreado") — em vez de só inserir a área arrastável no fluxo normal
/// da página, o conteúdo de edição é espelhado num `OverlayEntry` inserido no
/// `Overlay` raiz (acima de toda a tela, inclusive app bar/barra inferior),
/// com um véu escuro atrás — a cópia "no lugar" (`_placeholderKey`) fica
/// invisível mas mantém o espaço reservado (`Visibility.maintainSize`), pra
/// não afetar o scroll da página por trás. Os ícones também ganham uma
/// animação de balanço contínuo (`_WiggleTile`) enquanto editando, mesmo
/// efeito de "modo de reorganizar" de launchers Android/iOS.
class _QuickAccessGrid extends ConsumerStatefulWidget {
  const _QuickAccessGrid();

  @override
  ConsumerState<_QuickAccessGrid> createState() => _QuickAccessGridState();
}

class _QuickAccessGridState extends ConsumerState<_QuickAccessGrid> {
  bool _editing = false;
  final GlobalKey _placeholderKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Widget _editableContent = const SizedBox.shrink();

  /// Troca as posições de [a] e [b] dentro da lista completa persistida —
  /// opera só na sub-lista dos ids elegíveis pro usuário atual (`eligible`),
  /// preservando a posição de ids inelegíveis (ex.: um papel que o usuário
  /// não tem mais) intocada, e devolve tudo pra
  /// `homeQuickTilesOrderProvider`. Cobre os três casos de arrastar (dentro
  /// dos 7, dentro do "pool", ou entre os dois) com a mesma operação: um
  /// swap simples de valores.
  void _swap(List<String> fullOrder, bool Function(String) eligible, String a, String b) {
    if (a == b) return;
    final eligibleOrder = fullOrder.where(eligible).toList();
    final ia = eligibleOrder.indexOf(a);
    final ib = eligibleOrder.indexOf(b);
    if (ia == -1 || ib == -1) return;
    final tmp = eligibleOrder[ia];
    eligibleOrder[ia] = eligibleOrder[ib];
    eligibleOrder[ib] = tmp;
    final newFullOrder = <String>[];
    var ei = 0;
    for (final id in fullOrder) {
      if (eligible(id)) {
        newFullOrder.add(eligibleOrder[ei]);
        ei++;
      } else {
        newFullOrder.add(id);
      }
    }
    ref.read(homeQuickTilesOrderProvider.notifier).setOrder(newFullOrder);
  }

  void _startEditing() => setState(() => _editing = true);

  /// Sai do modo de edição — reaproveitado pelo botão "Concluído" e pelo
  /// botão de voltar (02/09/2026, pedido do usuário: "caso toque em voltar,
  /// deve... ter o mesmo comportamento que clicar em concluído"), ver
  /// `PopScope` no `build()`.
  void _stopEditing() {
    _removeOverlay();
    if (_editing) setState(() => _editing = false);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Insere (ou atualiza) o véu + cópia em destaque depois do frame atual —
  /// só então a posição/tamanho reservados por `_placeholderKey` já refletem
  /// o layout do modo de edição.
  void _syncOverlay() {
    if (!mounted) return;
    if (!_editing) {
      _removeOverlay();
      return;
    }
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: (_) => _buildSpotlight());
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  Widget _buildSpotlight() {
    final box = _placeholderKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return const SizedBox.shrink();
    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(color: Colors.black.withValues(alpha: 0.68)),
          ),
        ),
        Positioned(
          left: offset.dx,
          top: offset.dy,
          width: size.width,
          child: Material(color: Colors.transparent, child: _editableContent),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defs = buildHomeQuickTileDefs(ref);
    final byId = {for (final d in defs) d.id: d};
    final savedOrder = ref.watch(homeQuickTilesOrderProvider);
    // `splitHomeQuickTiles` é compartilhado com `MaisPage` (`main_shell.dart`)
    // — mesma fonte de verdade garante que trocar um ícone aqui move o outro
    // pro menu Mais automaticamente (03/09/2026, pedido do usuário).
    final split = splitHomeQuickTiles(savedOrder, defs);
    final fullOrder = split.fullOrder;
    final shown = split.shown;
    final pool = split.pool;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editing)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Arraste um ícone sobre outro para reorganizar',
                    // Cor fixa (não `context.textSecondary`) — este texto só
                    // aparece dentro do véu escuro do modo de edição
                    // (`_buildSpotlight`), nunca sobre o fundo normal do tema.
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
                TextButton(
                  onPressed: _stopEditing,
                  style: TextButton.styleFrom(
                    foregroundColor: SibValColors.goldAccent,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Concluído'),
                ),
              ],
            ),
          ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          // Quadrados um pouco mais baixos (02/09/2026, pedido do usuário:
          // "diminua um pouco mais os quadrados... mas mantenha o tamanho dos
          // ícones e os nomes deles") — só a caixa encolhe (padding vertical
          // do tile também reduzido, ver `_QuickAccessTile`); ícone (26) e
          // fonte do rótulo (11.5) ficam do mesmo tamanho.
          childAspectRatio: 1.1,
          children: [
            for (final id in shown)
              _editing
                  ? _WiggleTile(
                      key: ValueKey(id),
                      seed: id.hashCode,
                      child: _DraggableTile(
                        id: id,
                        def: byId[id]!,
                        onSwap: (other) =>
                            _swap(fullOrder, byId.containsKey, id, other),
                      ),
                    )
                  : _QuickAccessTile(
                      key: ValueKey(id),
                      icon: byId[id]!.icon,
                      imageAsset: byId[id]!.imageAsset,
                      customIcon: byId[id]!.customIcon,
                      label: byId[id]!.label,
                      badgeCount: byId[id]!.badgeCount,
                      live: byId[id]!.live,
                      onTap: () => byId[id]!.onTap(context),
                      onLongPress: _startEditing,
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
              // "Mais" ler como o item de destaque/chamada da grade. Fixo —
              // não participa da reordenação nem balança (02/09/2026).
              highlighted: true,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MaisPage())),
            ),
          ],
        ),
        if (_editing) ...[
          const SizedBox(height: 14),
          const Text(
            'ARRASTE PARA ADICIONAR',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final id in pool)
                _WiggleTile(
                  key: ValueKey(id),
                  seed: id.hashCode,
                  child: _DraggableTile(
                    id: id,
                    def: byId[id]!,
                    small: true,
                    onSwap: (other) =>
                        _swap(fullOrder, byId.containsKey, id, other),
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    // Guarda a versão mais recente do conteúdo editável pro `OverlayEntry`
    // reaproveitar, e (re)sincroniza o véu depois deste frame — cobre tanto
    // a entrada/saída do modo de edição quanto qualquer troca de ícone
    // (o `Positioned` do overlay precisa de posição/tamanho atualizados).
    _editableContent = content;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlay());

    return PopScope(
      // Voltar durante a edição só sai do modo de edição, sem navegar pra
      // lugar nenhum (02/09/2026, pedido do usuário) — mesmo efeito do botão
      // "Concluído".
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _stopEditing();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: KeyedSubtree(
          key: _placeholderKey,
          // Enquanto editando, o conteúdo "no lugar" fica invisível — a
          // cópia de verdade, interativa, vive no `OverlayEntry`
          // (`_buildSpotlight`), acima de toda a tela. `maintainSize` reserva
          // o mesmo espaço, então o resto da página não pula quando o modo
          // de edição liga/desliga.
          child: _editing
              ? Visibility(
                  visible: false,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}

/// Balanço contínuo (rotação pequena, ida e volta) enquanto `enabled` —
/// mesmo efeito de "modo de reorganizar" de launchers Android/iOS
/// (02/09/2026, pedido do usuário: "faça uma animação nos ícones... deixando
/// eles em movimento enquanto estamos editando"). Fase/duração variam por
/// [seed] (o `hashCode` do id do ícone) pra os ícones não balançarem todos
/// em sincronia, como aconteceria com um único `AnimationController`
/// compartilhado.
class _WiggleTile extends StatefulWidget {
  const _WiggleTile({super.key, required this.seed, required this.child});

  final int seed;
  final Widget child;

  @override
  State<_WiggleTile> createState() => _WiggleTileState();
}

class _WiggleTileState extends State<_WiggleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed.abs();
    final durationMs = 120 + (seed % 5) * 8;
    final clockwiseFirst = seed.isEven;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    _rotation = Tween<double>(
      begin: clockwiseFirst ? -0.045 : 0.045,
      end: clockwiseFirst ? 0.045 : -0.045,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    // Bug corrigido (03/09/2026, relatado pelo usuário: "os ícones apenas
    // ficaram tortos"): a versão anterior chamava `repeat()` e, em seguida,
    // atribuía `.value` pra dar uma fase inicial diferente por ícone —
    // `AnimationController.value=` chama `stop()` internamente, então isso
    // CANCELAVA a repetição recém-iniciada, deixando o ícone parado num
    // ângulo fixo (torto) em vez de balançando. Corrigido com um atraso
    // inicial diferente por ícone (0-300ms) antes de chamar `repeat()`, sem
    // nunca tocar em `.value` diretamente.
    Future.delayed(Duration(milliseconds: seed % 300), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotation,
      builder: (context, child) =>
          Transform.rotate(angle: _rotation.value, child: child),
      child: widget.child,
    );
  }
}

/// Tamanho fixo dos ícones "de adicionar" (pool, fora da grade de 7) e do
/// retrato mostrado durante o arraste (`feedback`) — grande o bastante pro
/// rótulo de duas linhas mais longo ("Configurações e Gerenciamento",
/// "Vínculos Institucionais"...) nunca estourar a caixa (02/09/2026, corrige
/// "BOTTOM OVERFLOWED BY 4.0 PIXELS" relatado pelo usuário — a caixa de 76
/// era pequena demais pro texto de duas linhas + ícone + preenchimento).
const _kDragTileSize = 90.0;

/// Ícone arrastável durante o modo de edição — ao mesmo tempo fonte
/// (`LongPressDraggable`, pra poder ser puxado pra outra posição) e alvo
/// (`DragTarget`, pra aceitar outro ícone arrastado sobre ele) — cobre os
/// três casos de troca com a mesma operação (`onSwap`, ver `_QuickAccessGridState._swap`).
class _DraggableTile extends StatelessWidget {
  const _DraggableTile({
    required this.id,
    required this.def,
    required this.onSwap,
    this.small = false,
  });

  final String id;
  final HomeQuickTileDef def;
  final ValueChanged<String> onSwap;

  /// `true` pros ícones do "pool" (fora dos 7) — tamanho fixo menor, já que
  /// vivem numa `Wrap` e não numa célula de grade.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final content = _QuickAccessTile(
      icon: def.icon,
      imageAsset: def.imageAsset,
      customIcon: def.customIcon,
      label: def.label,
      onTap: () {},
    );
    final sized = small
        ? SizedBox(width: _kDragTileSize, height: _kDragTileSize, child: content)
        : content;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != id,
      onAcceptWithDetails: (details) => onSwap(details.data),
      builder: (context, candidateData, rejectedData) {
        final highlighting = candidateData.isNotEmpty;
        return LongPressDraggable<String>(
          data: id,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: _kDragTileSize,
              height: _kDragTileSize,
              child: content,
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: sized),
          child: AnimatedScale(
            scale: highlighting ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: sized,
          ),
        );
      },
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    super.key,
    this.icon,
    this.imageAsset,
    this.customIcon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.badgeCount = 0,
    this.highlighted = false,
    this.live = false,
  }) : assert(icon != null || imageAsset != null || customIcon != null);

  final IconData? icon;
  final String? imageAsset;

  /// Substitui `icon`/`imageAsset` quando o ícone precisa de composição (ex.:
  /// mesa + boneco de "Introdução") — ver `_IntroductionTileIcon`.
  final Widget Function(Color color)? customIcon;
  final String label;
  final VoidCallback onTap;

  /// Toque e segure entra no modo de edição da grade (02/09/2026, pedido do
  /// usuário) — `null` pros ícones que não participam da reordenação
  /// ("Mais", e os próprios ícones já em modo de edição/arrastáveis).
  final VoidCallback? onLongPress;
  final int badgeCount;

  /// Verdadeiro só pro tile "Mais" (02/09/2026, pedido do usuário) — troca o
  /// card neutro + ícone dourado pelo par fundo dourado/ícone-texto navy,
  /// mesma combinação do botão primário do app (`ElevatedButtonTheme`).
  final bool highlighted;

  /// Selo "ao vivo" piscando no canto do ícone (02/09/2026, pedido do
  /// usuário) — hoje só usado por "Ordem de Culto", quando há uma ordem
  /// iniciada e ainda não finalizada, ver `ServiceOrderLiveBadge`. Aumentado
  /// (02/09/2026, pedido do usuário: "deixe um pouco maior") de 16 pra 22.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final iconColor = highlighted
        ? SibValColors.navyBlueDark
        : SibValColors.goldAccent;
    final labelColor = highlighted
        ? SibValColors.navyBlueDark
        : context.textPrimary;

    final iconWidget = customIcon != null
        ? customIcon!(iconColor)
        : (imageAsset != null
              ? Image.asset(
                  imageAsset!,
                  width: 26,
                  height: 26,
                  color: iconColor,
                  colorBlendMode: BlendMode.srcIn,
                )
              : Icon(icon, color: iconColor, size: 26));

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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
        // Preenchimento vertical reduzido (02/09/2026, pedido do usuário:
        // "diminua um pouco mais os quadrados... mas mantenha o tamanho dos
        // ícones e os nomes deles") — 10→6, e o espaço entre ícone e rótulo
        // logo abaixo (6→4); ícone (26) e fonte do rótulo (11.5) inalterados.
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Badge(
                  label: Text('$badgeCount'),
                  isLabelVisible: badgeCount > 0,
                  child: iconWidget,
                ),
                if (live)
                  const Positioned(
                    top: -9,
                    right: -12,
                    child: ServiceOrderLiveBadge(size: 22),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 11.5,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                    // Resumo do conteúdo (02/09/2026, pedido do usuário: "é
                    // possível ter um pequeno resumo da devocional do dia do
                    // que se trata?") — as duas primeiras linhas do texto
                    // corrido, sem nenhum resumo/IA à parte: a devocional
                    // não tem um campo de resumo próprio no model, então
                    // isto é só uma prévia do texto completo.
                    if (devotional.text.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        devotional.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 11.5,
                          height: 1.25,
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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

/// "Esta Semana" + "Avisos" lado a lado (02/09/2026, pedido do usuário — os
/// dois viraram cards de largura total numa rodada seguinte, e voltaram a
/// ficar lado a lado no mesmo dia: "devem ser maiores na vertical somente,
/// mas continuar um ao lado do outro"). Sempre visíveis, com uma mensagem de
/// estado vazio no lugar da lista quando não há dado.
/// Altura padrão compartilhada por "Esta Semana" e "Avisos" (03/09/2026,
/// pedido do usuário: "ESTA SEMANA deve ficar no tamanho padrão igual
/// AVISOS mesmo que não tenham eventos suficiente para preencher todo o
/// quadro") — os dois cards vivem em `Expanded`s de larguras iguais dentro
/// do mesmo `Row`, então aplicar a mesma fórmula à largura medida por cada
/// um (`LayoutBuilder`, já depois do padding interno do `_HighlightCard`)
/// garante a mesma altura nos dois sem precisar coordená-los entre si. É a
/// mesma conta já usada pra calcular a altura da imagem 16:9 do aviso —
/// "Esta Semana" nunca teve imagem, mas passa a reservar o mesmo espaço.
double _weekNoticeCardHeight(BuildContext context, double innerWidth) {
  final imageHeight = innerWidth * 9 / 16;
  final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
  return imageHeight + 56 * textScale;
}

class _WeekAndNoticesRow extends StatelessWidget {
  const _WeekAndNoticesRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
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
      // Altura padrão forçada, igual à de "Avisos" (03/09/2026, pedido do
      // usuário — ver `_weekNoticeCardHeight`), mesmo quando a lista de
      // eventos é curta (ou vazia): sobra espaço em branco abaixo do
      // conteúdo em vez do card encolher. `SingleChildScrollView` é só uma
      // defesa pro caso raro de a semana ter eventos demais pra caber na
      // altura padrão — nesse caso rola em vez de estourar
      // ("BOTTOM OVERFLOWED", mesmo bug já corrigido no card de Avisos).
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: _weekNoticeCardHeight(context, constraints.maxWidth),
            child: SingleChildScrollView(
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
                          // "Ver todos os eventos" (02/09/2026, era "Ver
                          // agenda completa") — pedido do usuário: "Agenda"
                          // vai virar uma função à parte (ícone da grade,
                          // ainda "Em breve"), esse link é só pra lista de
                          // eventos de verdade (Eventos).
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
            ),
          );
        },
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

/// "Avisos" — Quadro de Avisos (03/09/2026, pedido do usuário): painel que
/// passa dinamicamente pelos avisos cadastrados (`noticesProvider`, coleção
/// própria `notices` — não reaproveita mais os posts manuais do Mural, ver
/// `NoticeManagementPage`/`home_quick_tiles.dart`). Mostra "Nenhum aviso no
/// momento." quando não há nenhum, em vez de sumir (ver doc comment de
/// `_WeekAndNoticesRow`). Sem "Ver todos": só quem gerencia o quadro
/// (`canManagePublications`) tem uma lista completa, pelo ícone no menu Mais
/// — os demais usuários só veem o aviso tocando aqui (pedido explícito do
/// usuário), que abre `NoticeDetailPage` em tela cheia.
class _NoticesCard extends ConsumerStatefulWidget {
  const _NoticesCard();

  @override
  ConsumerState<_NoticesCard> createState() => _NoticesCardState();
}

class _NoticesCardState extends ConsumerState<_NoticesCard> {
  final _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _count = 0;

  void _ensureTimer(int count) {
    if (count == _count) return;
    _count = count;
    _autoAdvanceTimer?.cancel();
    if (count <= 1) return;
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients) return;
      final next = ((_pageController.page ?? 0).round() + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(noticesProvider);
    final notices = (noticesAsync.asData?.value ?? const <Notice>[])
        .take(5)
        .toList();
    _ensureTimer(notices.length);

    return _HighlightCard(
      title: 'Avisos',
      // Altura padrão sempre forçada, mesmo sem nenhum aviso cadastrado
      // (03/09/2026, corrige "BOTTOM OVERFLOWED" relatado pelo usuário —
      // voltar a ficar lado a lado de "Esta Semana" estreitou o card pela
      // metade) via `_weekNoticeCardHeight` — mesma fórmula usada por "Esta
      // Semana" pra forçar as duas alturas a baterem sempre, inclusive
      // quando um dos dois cards está vazio.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = _weekNoticeCardHeight(context, constraints.maxWidth);
          if (notices.isEmpty) {
            return SizedBox(
              height: height,
              child: Text(
                'Nenhum aviso no momento.',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
            );
          }
          return SizedBox(
            height: height,
            child: PageView.builder(
              controller: _pageController,
              itemCount: notices.length,
              itemBuilder: (context, index) => _NoticeRow(notice: notices[index]),
            ),
          );
        },
      ),
    );
  }
}

/// Imagem pequena em cima (ocupando a largura do card, na proporção
/// original 16:9, sem cortar — `BoxFit.contain`), título e descrição
/// embaixo (03/09/2026, revisão pedida pelo usuário — era imagem à esquerda/
/// texto à direita). O bloco de texto vive dentro de um `Expanded`, então
/// mesmo se a altura calculada em `_NoticesCardState.build` ficar apertada
/// (fonte grande do aparelho, título comprido...) o texto só encolhe/corta
/// com reticências em vez de estourar a caixa (mesmo cuidado defensivo já
/// usado no telefone de `VisitorFullTile`, ver
/// `[[feedback_adb_ui_diagnosis]]` na memória automática).
class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoticeDetailPage(notice: notice)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: notice.imageUrl.isNotEmpty
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Image.network(
                        notice.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const _NoticeIconThumb(),
                      ),
                    )
                  : const _NoticeIconThumb(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    notice.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.textSecondary, fontSize: 11),
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

class _NoticeIconThumb extends StatelessWidget {
  const _NoticeIconThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SibValColors.goldAccent.withValues(alpha: 0.15),
      child: const Center(
        child: Icon(
          Icons.campaign_outlined,
          color: SibValColors.goldAccent,
          size: 28,
        ),
      ),
    );
  }
}
