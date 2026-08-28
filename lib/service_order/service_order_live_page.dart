import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/hymnal_repository.dart';
import '../data/praise_repertoire_repository.dart';
import '../data/service_order_repository.dart';
import '../data/visitor_repository.dart';
import '../hymnal/hymn_detail_page.dart';
import '../introduction/visitor_tiles.dart';
import '../models/hymn.dart';
import '../models/praise_repertoire.dart';
import '../models/service_order.dart';
import '../models/visitor.dart';
import '../theme/app_theme.dart';
import 'service_order_bible_text_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). "Modo apresentação": aberto ao tocar em "Iniciar Culto"/
/// "Continuar Culto" em `ServiceOrderPrecheckPage`. Layout deliberadamente
/// diferente do resto do app (tela cheia escura, sem `SibValAppBar`).
///
/// **Progresso persiste no Firestore** (`ServiceOrder.completedMomentKeys`,
/// `ServiceOrderRepository.updateProgress`) — pedido do usuário: sair e
/// voltar continua de onde parou. Cada chave é `"<tipo>:<sub>"` (ex.:
/// `"bibleReading:bible0"`, `"tithesOffering:tithesHymn"`) ou só `"<tipo>"`
/// pros momentos sem sub-ação — baseada no **tipo/id do momento**, não no
/// índice na lista, pra sobreviver a uma reordenação numa edição posterior
/// (`_baseKeyFor` desempata com `#N` no raro caso de dois momentos extras
/// iguais na mesma ordem).
///
/// **Leitura bíblica/Texto bíblico/Hino Congregacional** (pedido do
/// usuário) não marcam concluído no toque direto — abrem a leitura de
/// verdade e só marcam ao voltar de lá. O texto bíblico abre em
/// `ServiceOrderBibleTextPage` (28/08/2026, pedido do usuário — só o
/// versículo selecionado, não a página inteira da Bíblia como
/// `BibleReaderPage` mostrava antes); o hino continua em `HymnDetailPage`
/// (reaproveitado do Hinário). "Dedicação dos dízimos e ofertas" sempre
/// renderiza como grupo com as subcategorias Texto bíblico/Hino
/// Congregacional (`_MomentGroupCard`), mesmo que só uma esteja preenchida
/// — quando as duas ficam concluídas, o próprio momento também aparece
/// concluído (`_MomentGroupCard.isDone`, derivado das sub-ações).
///
/// **Momentos "Louvor"** mostram as músicas escaladas no repertório semanal
/// da semana do culto (`PraiseRepertoireRepository.getForDate`,
/// `praiseSlotLabelFor`), se houver — Ministério de Louvor
/// (`praise_repertoire.dart`).
///
/// Ao concluir todos os momentos, aparece "Finalizar Culto" no rodapé —
/// marca `ServiceOrder.isFinalized` e volta pra lista.
class ServiceOrderLivePage extends ConsumerStatefulWidget {
  const ServiceOrderLivePage({super.key, required this.order});

  final ServiceOrder order;

  @override
  ConsumerState<ServiceOrderLivePage> createState() => _ServiceOrderLivePageState();
}

class _SubAction {
  const _SubAction({required this.key, required this.label, required this.open});

  final String key;
  final String label;
  final Future<void> Function(BuildContext context) open;
}

class _ServiceOrderLivePageState extends ConsumerState<ServiceOrderLivePage> {
  static final _dateFormat = DateFormat('EEEE, dd/MM', 'pt_BR');

  late final Set<String> _done = widget.order.completedMomentKeys.toSet();
  WeeklyRepertoire? _repertoire;

  /// `null` enquanto carrega; lista vazia depois de carregado e confirmado
  /// que não há visitantes (28/08/2026, pedido do usuário — mostrar
  /// "Não há visitantes" direto embaixo de "Boas-vindas", sem precisar
  /// tocar pra descobrir).
  List<VisitorSummary>? _visitors;
  bool _finalizing = false;

  @override
  void initState() {
    super.initState();
    _loadRepertoire();
    _loadVisitors();
  }

  Future<void> _loadRepertoire() async {
    try {
      final repertoire = await ref
          .read(praiseRepertoireRepositoryProvider)
          .getForDate(widget.order.dateTime);
      if (mounted) setState(() => _repertoire = repertoire);
    } catch (_) {
      // Sem repertório cadastrado pra essa semana, ou falha de rede — os
      // momentos "Louvor" simplesmente não mostram músicas, sem quebrar a tela.
    }
  }

  Future<void> _loadVisitors() async {
    try {
      final visitors = await ref
          .read(visitorRepositoryProvider)
          .getSummariesForDate(widget.order.dateTime);
      if (mounted) setState(() => _visitors = visitors);
    } catch (_) {
      // Falha de rede/permissão — "Boas-vindas" some volta a exigir toque
      // pra tentar de novo (ver `_showVisitorsSheet`), sem quebrar a tela.
    }
  }

  String _baseKeyFor(int index, ServiceOrderItem item, List<ServiceOrderItem> items) {
    final raw = item.type?.name ?? 'extra:${item.extraMomentId}';
    final before = items
        .take(index)
        .where((i) => (i.type?.name ?? 'extra:${i.extraMomentId}') == raw)
        .length;
    return before == 0 ? raw : '$raw#$before';
  }

  List<_SubAction> _subActionsFor(String baseKey, ServiceOrderItem item) {
    final order = widget.order;
    if (item.type == ServiceOrderMomentType.welcome) {
      // Sem sub-ação quando já sabemos que não há visitantes (28/08/2026,
      // pedido do usuário) — vira um card simples com a mensagem já visível,
      // sem precisar tocar pra descobrir. Enquanto `_visitors` ainda carrega
      // (`null`), ou se há visitantes, mantém o toque pra abrir a lista.
      if (_visitors != null && _visitors!.isEmpty) return const [];
      return [
        _SubAction(
          key: '$baseKey:visitors',
          label: 'Visitantes do dia',
          open: (ctx) => _showVisitorsSheet(ctx),
        ),
      ];
    }
    if (item.type == ServiceOrderMomentType.bibleReading) {
      final subs = <_SubAction>[];
      for (var j = 0; j < order.bibleReadings.length; j++) {
        final r = order.bibleReadings[j];
        if (!r.isFilled) continue;
        subs.add(
          _SubAction(
            key: '$baseKey:bible$j',
            label: r.reference ?? '',
            open: (ctx) => Navigator.of(ctx).push<void>(
              MaterialPageRoute(
                builder: (_) => ServiceOrderBibleTextPage(reference: r),
              ),
            ),
          ),
        );
      }
      return subs;
    }
    if (item.type == ServiceOrderMomentType.tithesOffering) {
      final subs = <_SubAction>[];
      final bibleRef = order.tithesBibleReading;
      if (bibleRef.isFilled) {
        subs.add(
          _SubAction(
            key: '$baseKey:tithesBible',
            label: 'Texto bíblico: ${bibleRef.reference}',
            open: (ctx) => Navigator.of(ctx).push<void>(
              MaterialPageRoute(
                builder: (_) => ServiceOrderBibleTextPage(reference: bibleRef),
              ),
            ),
          ),
        );
      }
      if (order.congregationalHymn.isNotEmpty) {
        subs.add(
          _SubAction(
            key: '$baseKey:tithesHymn',
            label: 'Hino Congregacional: ${order.congregationalHymn}',
            open: (ctx) async {
              final resolved = await _resolveHymn(order.congregationalHymn);
              if (!ctx.mounted) return;
              if (resolved == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Hino não encontrado no hinário.')),
                );
                return;
              }
              await Navigator.of(ctx).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      HymnDetailPage(hymnal: resolved.$1, songId: resolved.$2.id),
                ),
              );
            },
          ),
        );
      }
      return subs;
    }
    // Momento adicional com `ExtraMomentFieldKind.bibleReference` (ex.:
    // "Ceia do Senhor" — pedido do usuário: "parecido com os dízimos e
    // ofertas") — mesmo tratamento de leitura bíblica de verdade. Pode ter
    // mais de um texto (28/08/2026, pedido do usuário) — cada um vira uma
    // subcategoria própria, mesmo mecanismo de "Leitura bíblica".
    if (item.type == null && item.extraBibleReferences.isNotEmpty) {
      final subs = <_SubAction>[];
      for (var j = 0; j < item.extraBibleReferences.length; j++) {
        final r = item.extraBibleReferences[j];
        if (!r.isFilled) continue;
        subs.add(
          _SubAction(
            key: '$baseKey:bible$j',
            label: r.reference ?? '',
            open: (ctx) => Navigator.of(ctx).push<void>(
              MaterialPageRoute(
                builder: (_) => ServiceOrderBibleTextPage(reference: r),
              ),
            ),
          ),
        );
      }
      return subs;
    }
    return const [];
  }

  /// Visitantes cadastrados no dia do culto (28/08/2026, pedido do usuário —
  /// toque em "Boas-vindas") — lê `visitorSummaries` (papel Dirigentes já
  /// tem `read` liberado ali, diferente de `visitors` completo, restrito a
  /// Introdução/Pastor). Mostra "Não há visitantes." se a lista vier vazia.
  Future<void> _showVisitorsSheet(BuildContext ctx) async {
    List<VisitorSummary> visitors = const [];
    String? error;
    try {
      visitors = await ref
          .read(visitorRepositoryProvider)
          .getSummariesForDate(widget.order.dateTime);
    } catch (e) {
      error = '$e';
    }
    if (!ctx.mounted) return;
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visitantes do dia',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (error != null)
                Text(
                  'Falha ao carregar: $error',
                  style: TextStyle(color: context.textPrimary),
                )
              else if (visitors.isEmpty)
                Text(
                  'Não há visitantes.',
                  style: TextStyle(color: context.textSecondary),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final visitor in visitors)
                        VisitorSummaryTile(summary: visitor),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Casa o texto salvo em `congregationalHymn` (ex. "CC 45 — Nome do Hino",
  /// gravado por `_HymnField` no cadastro) contra os hinários de verdade.
  Future<(Hymnal, Hymn)?> _resolveHymn(String label) async {
    for (final hymnal in Hymnal.values) {
      final prefix = '${hymnal.titlePrefix} ';
      if (!label.startsWith(prefix)) continue;
      final numberPart = label.substring(prefix.length).split(' — ').first.trim();
      try {
        final songs = await ref.read(hymnSongsProvider(hymnal).future);
        for (final song in songs) {
          if (song.number == numberPart) return (hymnal, song);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Nome + cantor/banda das músicas escaladas pro momento — **sem o tom**
  /// (28/08/2026, pedido do usuário: por enquanto o tom só deve aparecer
  /// pro perfil do Ministério de Louvor, regra que ainda não existe; até lá,
  /// o dirigente vê só nome/cantor).
  String? _repertoireSummaryFor(ServiceOrderMomentType type) {
    final repertoire = _repertoire;
    if (repertoire == null) return null;
    final slot = praiseSlotLabelFor(type);
    if (slot == null) return null;
    final songs = repertoire.forSlot(slot);
    if (songs.isEmpty) return null;
    return songs
        .map((a) => a.songArtist.isEmpty ? a.songName : '${a.songName} — ${a.songArtist}')
        .join('\n');
  }

  /// Mostra direto se há visitantes ou não, sem precisar tocar pra descobrir
  /// (28/08/2026, pedido do usuário: "Boas-vindas só precisa mostrar se há
  /// visitantes ou não") — antes só o caso vazio tinha texto automático; com
  /// visitantes o card ficava mudo até o toque. Enquanto `_visitors` ainda
  /// carrega (`null`), não mostra nada.
  String? _welcomeSummary() {
    final visitors = _visitors;
    if (visitors == null) return null;
    if (visitors.isEmpty) return 'Não há visitantes.';
    return visitors.length == 1 ? '1 visitante hoje.' : '${visitors.length} visitantes hoje.';
  }

  void _setDone(String key, bool done) {
    setState(() {
      if (done) {
        _done.add(key);
      } else {
        _done.remove(key);
      }
    });
    ref
        .read(serviceOrderRepositoryProvider)
        .updateProgress(widget.order.id, _done.toList())
        .catchError((_) {});
  }

  Future<void> _onTapLeaf(String key, _SubAction? action) async {
    if (_done.contains(key)) {
      _setDone(key, false);
      return;
    }
    if (action != null) {
      await action.open(context);
      if (!mounted) return;
    }
    _setDone(key, true);
  }

  ({int total, int done}) _progress(List<ServiceOrderItem> items) {
    var total = 0;
    var done = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final baseKey = _baseKeyFor(i, item, items);
      final subs = _subActionsFor(baseKey, item);
      final leaves = subs.isEmpty ? [baseKey] : subs.map((s) => s.key).toList();
      if (leaves.isEmpty) continue;
      total++;
      if (leaves.every(_done.contains)) done++;
    }
    return (total: total, done: done);
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair do modo culto?'),
        content: const Text('Seu progresso fica salvo — pode continuar de onde parou.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar aqui'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (exit == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _finalizeCulto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar culto?'),
        content: const Text('A ordem de culto será marcada como finalizada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _finalizing = true);
    try {
      await ref.read(serviceOrderRepositoryProvider).finalize(widget.order.id);
      ref.invalidate(serviceOrdersProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _finalizing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha ao finalizar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final items = order.momentOrder;
    final progress = _progress(items);
    final allDone = progress.total > 0 && progress.done == progress.total;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        backgroundColor: SibValColors.navyBlue,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CULTO EM ANDAMENTO',
                            style: TextStyle(
                              color: SibValColors.goldAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dateFormat.format(order.dateTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: _confirmExit,
                    ),
                  ],
                ),
              ),
              _ProgressBar(total: progress.total, done: progress.done),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final baseKey = _baseKeyFor(index, item, items);
                    final subs = _subActionsFor(baseKey, item);
                    final leaves =
                        subs.isEmpty ? [baseKey] : subs.map((s) => s.key).toList();
                    final isItemDone =
                        leaves.isNotEmpty && leaves.every(_done.contains);
                    final currentIndex = _currentItemIndex(items);
                    final isCurrent = !isItemDone && index == currentIndex;

                    if (item.type == ServiceOrderMomentType.tithesOffering ||
                        subs.length > 1) {
                      return _MomentGroupCard(
                        index: index,
                        item: item,
                        subs: subs,
                        doneKeys: _done,
                        isDone: isItemDone,
                        isCurrent: isCurrent,
                        onSubTap: (sub) => _onTapLeaf(sub.key, sub),
                      );
                    }

                    final singleAction = subs.isEmpty ? null : subs.single;
                    final key = singleAction?.key ?? baseKey;
                    final extraSummary = item.type == ServiceOrderMomentType.welcome
                        ? _welcomeSummary()
                        : (item.type != null ? _repertoireSummaryFor(item.type!) : null);
                    return _MomentCard(
                      index: index,
                      item: item,
                      order: order,
                      isDone: _done.contains(key),
                      isCurrent: isCurrent,
                      // Só é de fato um "link" (abre bíblia/hino/cifra) quando
                      // há uma única sub-ação — os demais momentos só marcam
                      // concluído no toque, sem navegar a lugar nenhum (28/08,
                      // pedido do usuário: itens clicáveis em dourado).
                      isLink: singleAction != null,
                      extraSummary: extraSummary,
                      onTap: () => _onTapLeaf(key, singleAction),
                    );
                  },
                ),
              ),
              if (allDone)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SibValColors.goldAccent,
                        foregroundColor: SibValColors.navyBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _finalizing ? null : _finalizeCulto,
                      child: _finalizing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Finalizar Culto',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _currentItemIndex(List<ServiceOrderItem> items) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final baseKey = _baseKeyFor(i, item, items);
      final subs = _subActionsFor(baseKey, item);
      final leaves = subs.isEmpty ? [baseKey] : subs.map((s) => s.key).toList();
      if (leaves.isEmpty) continue;
      if (!leaves.every(_done.contains)) return i;
    }
    return items.length;
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 6,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation(SibValColors.goldAccent),
        ),
      ),
    );
  }
}

IconData _iconFor(ServiceOrderMomentType? type) {
  if (type == null) return Icons.auto_awesome;
  return switch (type) {
    ServiceOrderMomentType.prelude => Icons.piano,
    ServiceOrderMomentType.prayer => Icons.front_hand,
    ServiceOrderMomentType.bibleReading => Icons.menu_book,
    ServiceOrderMomentType.praise1 ||
    ServiceOrderMomentType.praise2 ||
    ServiceOrderMomentType.praise3 => Icons.music_note,
    ServiceOrderMomentType.welcome => Icons.waving_hand,
    ServiceOrderMomentType.announcements => Icons.campaign,
    ServiceOrderMomentType.participation => Icons.star,
    ServiceOrderMomentType.missionMoment => Icons.public,
    ServiceOrderMomentType.tithesOffering => Icons.volunteer_activism,
    ServiceOrderMomentType.childrenPrayer => Icons.child_care,
    ServiceOrderMomentType.intercession => Icons.groups,
    ServiceOrderMomentType.message => Icons.record_voice_over,
    ServiceOrderMomentType.apostolicBlessing => Icons.emoji_events,
    ServiceOrderMomentType.postlude => Icons.piano,
  };
}

/// Emoji pros três momentos que o usuário pediu pra trocar (28/08/2026) —
/// Material Icons não tem "mãos juntas em oração"/"abraço"/"mãos recebendo
/// bênção" de verdade, então usa emoji nesses três em vez de compor dois
/// `Icons` (padrão de `_ServiceOrderIcon` etc. em `main_shell.dart`, que só
/// funciona pra ícones vetoriais). `null` pros demais tipos, que continuam
/// com `Icon(_iconFor(type))` normal.
String? _emojiFor(ServiceOrderMomentType? type) => switch (type) {
  ServiceOrderMomentType.prayer => '🙏',
  ServiceOrderMomentType.welcome => '🫂',
  ServiceOrderMomentType.apostolicBlessing => '🤲',
  _ => null,
};

/// Ícone do momento — emoji (`_emojiFor`) quando existe, senão `Icon`
/// (`_iconFor`) normal. Reaproveitado por `_MomentCard`/`_MomentGroupCard`.
Widget _momentIcon(ServiceOrderMomentType? type, {required double size, required Color color}) {
  final emoji = _emojiFor(type);
  if (emoji != null) {
    return Text(emoji, style: TextStyle(fontSize: size));
  }
  return Icon(_iconFor(type), color: color, size: size);
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.index,
    required this.item,
    required this.order,
    required this.isDone,
    required this.isCurrent,
    required this.onTap,
    this.isLink = false,
    this.extraSummary,
  });

  final int index;
  final ServiceOrderItem item;
  final ServiceOrder order;
  final bool isDone;
  final bool isCurrent;
  final VoidCallback onTap;

  /// `true` quando o toque no card abre bíblia/hino/cifra em vez de só
  /// marcar concluído — nesse caso o nome do momento vem em dourado (28/08,
  /// pedido do usuário: "itens clicáveis na cor dourada padrão").
  final bool isLink;
  final String? extraSummary;

  @override
  Widget build(BuildContext context) {
    final baseSummary = item.summary(order);
    final summary = [?baseSummary, ?extraSummary].join('\n');
    final textColor = isDone
        ? Colors.white38
        : (isLink ? SibValColors.goldAccent : Colors.white);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isCurrent ? const Color(0xFF1E3A5F) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isCurrent
                  ? Border.all(color: SibValColors.goldAccent, width: 1.5)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBadge(index: index, isDone: isDone, isCurrent: isCurrent),
                const SizedBox(width: 12),
                _momentIcon(
                  item.type,
                  size: 20,
                  color: isDone
                      ? Colors.white24
                      : (isCurrent ? SibValColors.goldAccent : Colors.white70),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (summary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            summary,
                            style: TextStyle(
                              color: isDone ? Colors.white24 : Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Momento com sub-ações (28/08/2026, pedido do usuário) — "Leitura
/// bíblica" com mais de uma referência, ou "Dedicação dos dízimos e
/// ofertas" (sempre, mesmo com só uma subcategoria preenchida): cabeçalho
/// não-tocável + uma linha por sub-ação, cada uma marcando concluído só
/// depois de abrir a leitura de verdade.
class _MomentGroupCard extends StatelessWidget {
  const _MomentGroupCard({
    required this.index,
    required this.item,
    required this.subs,
    required this.doneKeys,
    required this.isDone,
    required this.isCurrent,
    required this.onSubTap,
  });

  final int index;
  final ServiceOrderItem item;
  final List<_SubAction> subs;
  final Set<String> doneKeys;

  /// Verdadeiro quando todas as sub-ações já foram concluídas (28/08/2026,
  /// pedido do usuário — "após marcar texto e hino como concluído, marcar
  /// também o próprio momento") — reflete o cabeçalho igual a um
  /// `_MomentCard` concluído (badge de check, texto riscado/apagado), sem
  /// precisar de nenhum toque próprio no cabeçalho (o estado é só derivado
  /// das sub-ações, não uma chave própria em `doneKeys`).
  final bool isDone;
  final bool isCurrent;
  final ValueChanged<_SubAction> onSubTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isDone ? Colors.white38 : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFF1E3A5F) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: isCurrent
            ? Border.all(color: SibValColors.goldAccent, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(index: index, isDone: isDone, isCurrent: isCurrent),
              const SizedBox(width: 12),
              _momentIcon(
                item.type,
                size: 20,
                color: isDone ? Colors.white24 : Colors.white70,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          if (subs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 42, top: 4),
              child: Text('Nada preenchido.', style: TextStyle(color: Colors.white38)),
            ),
          for (final sub in subs)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: _SubActionRow(
                sub: sub,
                isDone: doneKeys.contains(sub.key),
                onTap: () => onSubTap(sub),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubActionRow extends StatelessWidget {
  const _SubActionRow({required this.sub, required this.isDone, required this.onTap});

  final _SubAction sub;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: isDone ? SibValColors.goldAccent : Colors.white54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sub.label,
                  style: TextStyle(
                    // Sub-ação sempre navega (abre bíblia/hino) — dourado
                    // padrão de "clicável" (28/08, pedido do usuário).
                    color: isDone ? Colors.white38 : SibValColors.goldAccent,
                    fontSize: 14,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (!isDone)
                const Icon(Icons.chevron_right, size: 18, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.index,
    required this.isDone,
    required this.isCurrent,
  });

  final int index;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: SibValColors.goldAccent,
        child: Icon(Icons.check, size: 16, color: SibValColors.navyBlue),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: isCurrent ? SibValColors.goldAccent : Colors.white12,
      child: Text(
        '${index + 1}',
        style: TextStyle(
          color: isCurrent ? SibValColors.navyBlue : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
