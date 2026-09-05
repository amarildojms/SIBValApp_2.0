import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/hymnal_repository.dart';
import '../data/praise_repertoire_repository.dart';
import '../data/service_order_repository.dart';
import '../data/user_repository.dart';
import '../data/visitor_repository.dart';
import '../hymnal/hymn_detail_page.dart';
import '../introduction/visitor_tiles.dart';
import '../models/hymn.dart';
import '../models/notification.dart';
import '../models/praise_repertoire.dart';
import '../models/service_order.dart';
import '../models/visitor.dart';
import '../notifications/notification_read_sync.dart';
import '../praise/cifra_view_page.dart';
import '../praise/praise_lyrics_page.dart';
import '../theme/app_theme.dart';
import 'service_order_bible_text_page.dart';
import 'service_order_countdown.dart';
import 'service_order_mission_moment_page.dart';

/// Verde de "momento concluído" no modo apresentação — dourado já significa
/// "atual" nesta tela, então concluído precisa de uma cor própria pra não se
/// confundir com pendente (antes os dois compartilhavam o mesmo fundo quase
/// invisível, diferindo só pelo texto riscado/apagado — pedido do usuário,
/// 01/09/2026, "cores para identificar com mais facilidade o que já foi
/// concluído, e em que momento está").
const _doneGreen = Color(0xFF43A047);

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
/// (reaproveitado do Hinário). **29/08/2026, pedido do usuário**: quando o
/// momento tem mais de um texto bíblico (Leitura bíblica, momento adicional
/// com texto bíblico), 1 toque já abre todos juntos em
/// `ServiceOrderBibleTextPage` — deixou de ser 1 sub-ação por referência,
/// vira 1 sub-ação só pro momento inteiro (mesmo padrão que a "Divisa" do
/// Momento Missionário já usava, que fica de fora dessa mudança por já ter
/// regra própria). "Dedicação dos dízimos e ofertas" sempre
/// renderiza como grupo com as subcategorias Texto bíblico/Hino
/// Congregacional (`_MomentGroupCard`), mesmo que só uma esteja preenchida
/// — quando as duas ficam concluídas, o próprio momento também aparece
/// concluído (`_MomentGroupCard.isDone`, derivado das sub-ações).
///
/// **Momentos "Louvor"** mostram as músicas escaladas no repertório semanal
/// da semana do culto (`PraiseRepertoireRepository.getForDate`,
/// `praiseSlotLabelFor`), se houver — Ministério de Louvor
/// (`praise_repertoire.dart`). **04/09/2026, pedido do usuário** ("quem tiver
/// perfil instrumentista, verá as cifra... todos os outros usuários verão a
/// letra"): tocar numa música abre a cifra (`CifraViewPage`) quando o dono
/// tem o perfil **Instrumentista** (`CurrentUserProfile.isInstrumentista`,
/// distinto do papel Louvor — `canViewPraiseOrder`, que hoje só decide se o
/// dono acessa `ServiceOrderPraiseViewPage`/tom durante o culto) — mesmo
/// destino que `ServiceOrderPraiseViewPage` já dá pra quem só é
/// Instrumentista, sem ser dono. Sem esse perfil, abre a letra salva
/// (`PraiseSong.lyrics`, `PraiseLyricsPage`) quando a música tiver; sem cifra
/// aplicável nem letra, o momento continua só marcando concluído no toque.
/// Reaproveita o mesmo mecanismo de sub-ação de "Leitura bíblica"/hino (abre
/// de verdade, marca concluído só ao voltar); com mais de uma música
/// escalada no mesmo momento, cada uma vira uma sub-ação própria.
///
/// Ao concluir todos os momentos, aparece "Finalizar Culto" no rodapé —
/// marca `ServiceOrder.isFinalized` e volta pra lista.
///
/// **Selo "ao vivo" só no momento atual** (02/09/2026, dinâmico; removido do
/// cabeçalho fixo da tela em 05/09/2026, pedido do usuário) — aparece só do
/// lado esquerdo do card do momento atual (`isCurrent`), junto com o dourado
/// piscando — muda de posição sozinho conforme o culto avança, sem nenhum
/// estado extra (só reaproveita `isCurrent`, já calculado por
/// `_currentItemIndex`). Mesmo tratamento replicado nas visões somente-leitura
/// (Louvor/membro/dono antes de iniciar), ver `_PraiseMomentCard` em
/// `service_order_praise_view_page.dart`.
class ServiceOrderLivePage extends ConsumerStatefulWidget {
  const ServiceOrderLivePage({super.key, required this.order});

  final ServiceOrder order;

  @override
  ConsumerState<ServiceOrderLivePage> createState() =>
      _ServiceOrderLivePageState();
}

class _SubAction {
  const _SubAction({
    required this.key,
    required this.label,
    required this.open,
  });

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
    // Chega aqui por outro caminho que não o toque na notificação também
    // marca como lida/cancela da barra (24/08/2026, mesmo padrão das demais
    // telas ligadas a um tipo de notificação).
    syncNotificationsForScreen(
      ref,
      type: NotificationType.serviceOrderReminder,
      targetId: widget.order.id,
    );
    syncNotificationsForScreen(
      ref,
      type: NotificationType.serviceOrderStarted,
      targetId: widget.order.id,
    );
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

  String _baseKeyFor(
    int index,
    ServiceOrderItem item,
    List<ServiceOrderItem> items,
  ) {
    final raw = item.type?.name ?? 'extra:${item.extraMomentId}';
    final before = items
        .take(index)
        .where((i) => (i.type?.name ?? 'extra:${i.extraMomentId}') == raw)
        .length;
    return before == 0 ? raw : '$raw#$before';
  }

  List<_SubAction> _subActionsFor(
    String baseKey,
    ServiceOrderItem item,
    List<PraiseSong> catalog,
  ) {
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
    // "Leitura bíblica" (29/08/2026, pedido do usuário: "ao tocar no momento
    // carregue todos os textos na tela de uma vez") — 1 única sub-ação
    // mesmo com várias referências, mesmo padrão já usado pela "Divisa" do
    // Momento Missionário (`ServiceOrderMissionMomentPage`). Antes cada
    // referência virava uma sub-ação própria (`bible$j`), forçando
    // `_MomentGroupCard`; agora `subs.length` nunca passa de 1 aqui, então o
    // momento vira um `_MomentCard` normal, de toque único.
    if (item.type == ServiceOrderMomentType.bibleReading) {
      final refs = order.bibleReadings.where((r) => r.isFilled).toList();
      if (refs.isEmpty) return const [];
      return [
        _SubAction(
          key: '$baseKey:bible',
          label: 'Leitura bíblica',
          open: (ctx) => Navigator.of(ctx).push<void>(
            MaterialPageRoute(
              builder: (_) => ServiceOrderBibleTextPage(references: refs),
            ),
          ),
        ),
      ];
    }
    if (item.type == ServiceOrderMomentType.tithesOffering) {
      final subs = <_SubAction>[];
      // "Texto bíblico" dos dízimos ganhou lista repetível (29/08/2026,
      // pedido do usuário) — mesma regra de "Leitura bíblica": 1 sub-ação só,
      // mesmo com vários textos, abrindo todos juntos.
      final bibleRefs = order.tithesBibleReadings
          .where((r) => r.isFilled)
          .toList();
      if (bibleRefs.isNotEmpty) {
        subs.add(
          _SubAction(
            key: '$baseKey:tithesBible',
            label:
                'Texto bíblico: '
                '${bibleRefs.map((r) => r.reference).whereType<String>().join('; ')}',
            open: (ctx) => Navigator.of(ctx).push<void>(
              MaterialPageRoute(
                builder: (_) =>
                    ServiceOrderBibleTextPage(references: bibleRefs),
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
                  const SnackBar(
                    content: Text('Hino não encontrado no hinário.'),
                  ),
                );
                return;
              }
              await Navigator.of(ctx).push<void>(
                MaterialPageRoute(
                  builder: (_) => HymnDetailPage(
                    hymnal: resolved.$1,
                    songId: resolved.$2.id,
                  ),
                ),
              );
            },
          ),
        );
      }
      return subs;
    }
    // "Divisa" do Momento Missionário (29/08/2026, pedido do usuário) — 1
    // toque abre os textos selecionados (pode ter mais de um), com a divisa
    // em destaque no topo — ver `ServiceOrderMissionMomentPage`.
    if (item.type == ServiceOrderMomentType.missionMoment &&
        order.missionMottoReferences.any((r) => r.isFilled)) {
      return [
        _SubAction(
          key: '$baseKey:motto',
          label: 'Tema/Divisa',
          open: (ctx) => Navigator.of(ctx).push<void>(
            MaterialPageRoute(
              builder: (_) => ServiceOrderMissionMomentPage(
                theme: order.missionTheme,
                references: order.missionMottoReferences,
              ),
            ),
          ),
        ),
      ];
    }
    // Momento adicional com `ExtraMomentFieldKind.bibleReference` (ex.:
    // "Ceia do Senhor" — pedido do usuário: "parecido com os dízimos e
    // ofertas") — mesmo tratamento de leitura bíblica de verdade. Pode ter
    // mais de um texto — 1 única sub-ação que abre todos juntos (29/08/2026,
    // pedido do usuário), mesmo ajuste de "Leitura bíblica" acima.
    if (item.type == null && item.extraBibleReferences.isNotEmpty) {
      final refs = item.extraBibleReferences.where((r) => r.isFilled).toList();
      if (refs.isEmpty) return const [];
      return [
        _SubAction(
          key: '$baseKey:bible',
          label: item.label,
          open: (ctx) => Navigator.of(ctx).push<void>(
            MaterialPageRoute(
              builder: (_) => ServiceOrderBibleTextPage(references: refs),
            ),
          ),
        ),
      ];
    }
    // Momento "Louvor" (04/09/2026, pedido do usuário: "quem tiver perfil
    // instrumentista, verá as cifra ao tocar nas músicas do momento de
    // louvor. Todos os outros usuários verão a letra da música quando
    // houver") — antes só quem tinha o papel Louvor (`canViewPraiseOrder`)
    // via cifra; agora é por música, pra qualquer dono da ordem: quem é
    // Instrumentista abre a cifra, os demais abrem a letra salva
    // (`PraiseSong.lyrics`, catálogo mestre) quando existir; sem cifra
    // aplicável nem letra, o momento cai no comportamento padrão (`const
    // []`, marca concluído só). Sem repertório/música escalada pro momento,
    // idem.
    if (item.type != null) {
      final slot = praiseSlotLabelFor(item.type!);
      final songs = slot == null
          ? const <PraiseAssignment>[]
          : (_repertoire?.forSlot(slot) ?? const []);
      if (songs.isNotEmpty) {
        final isInstrumentista =
            ref.read(currentUserProfileProvider).asData?.value?.isInstrumentista ?? false;
        final subs = <_SubAction>[];
        for (var i = 0; i < songs.length; i++) {
          final song = songs[i];
          final label = song.songArtist.isEmpty ? song.songName : '${song.songName} — ${song.songArtist}';
          if (isInstrumentista) {
            subs.add(_SubAction(
              key: '$baseKey:cifra$i',
              label: label,
              open: (ctx) => Navigator.of(ctx).push<void>(
                MaterialPageRoute(
                  builder: (_) => CifraViewPage(songId: song.songId, songName: song.songName),
                ),
              ),
            ));
            continue;
          }
          final catalogSong = catalog.where((s) => s.id == song.songId).firstOrNull;
          if (catalogSong != null && catalogSong.hasLyrics) {
            subs.add(_SubAction(
              key: '$baseKey:letra$i',
              label: label,
              open: (ctx) => Navigator.of(ctx).push<void>(
                MaterialPageRoute(
                  builder: (_) => PraiseLyricsPage(
                    songName: catalogSong.name,
                    songArtist: catalogSong.artist,
                    lyrics: catalogSong.lyrics,
                  ),
                ),
              ),
            ));
          }
        }
        if (subs.isNotEmpty) return subs;
      }
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
      final numberPart = label
          .substring(prefix.length)
          .split(' — ')
          .first
          .trim();
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
        .map(
          (a) => a.songArtist.isEmpty
              ? a.songName
              : '${a.songName} — ${a.songArtist}',
        )
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
    return visitors.length == 1
        ? '1 visitante hoje.'
        : '${visitors.length} visitantes hoje.';
  }

  void _setDone(String key, bool done) => _setDoneMany([key], done);

  void _setDoneMany(Iterable<String> keys, bool done) {
    setState(() {
      if (done) {
        _done.addAll(keys);
      } else {
        _done.removeAll(keys);
      }
    });
    ref
        .read(serviceOrderRepositoryProvider)
        .updateProgress(widget.order.id, _done.toList())
        .catchError((_) {});
  }

  /// Toque no corpo do card/linha — quando já concluído, reabre o link (se
  /// houver) em vez de desmarcar (01/09/2026, pedido do usuário: "os
  /// momentos que possuem links clicáveis poderão ser abertos novamente
  /// mesmo que o momento já tenha sido concluído"). Desmarcar passou a ser
  /// exclusivo de `_onToggleDone`, acionado só pela bolinha dourada de
  /// check.
  Future<void> _onTapLeaf(String key, _SubAction? action) async {
    if (_done.contains(key)) {
      if (action != null) await action.open(context);
      return;
    }
    if (action != null) {
      await action.open(context);
      if (!mounted) return;
    }
    _setDone(key, true);
  }

  /// Toque na bolinha dourada de check — único jeito de desmarcar um
  /// momento já concluído (01/09/2026, pedido do usuário). Marcar por aqui
  /// (quando ainda não concluído) também funciona, direto, sem abrir o
  /// link — atalho simétrico, não pedido explicitamente mas natural pro
  /// mesmo botão.
  void _onToggleDone(String key) => _setDone(key, !_done.contains(key));

  ({int total, int done}) _progress(
    List<ServiceOrderItem> items,
    List<PraiseSong> catalog,
  ) {
    var total = 0;
    var done = 0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final baseKey = _baseKeyFor(i, item, items);
      final subs = _subActionsFor(baseKey, item, catalog);
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
        content: const Text(
          'Seu progresso fica salvo — pode continuar de onde parou.',
        ),
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
    // `ref.watch` (não `ref.read`) é o que importa aqui — `praiseSongsProvider`
    // é `autoDispose` e nada mais o mantém vivo durante o modo culto/visão do
    // Louvor; sem observá-lo, ele nunca chega a emitir os dados a tempo, e a
    // música do momento "Louvor" nunca vira clicável pra quem não é
    // Instrumentista (bug relatado pelo usuário, 04/09/2026).
    final catalog = ref.watch(praiseSongsProvider).asData?.value ?? const [];
    final progress = _progress(items, catalog);
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
                    final subs = _subActionsFor(baseKey, item, catalog);
                    final leaves = subs.isEmpty
                        ? [baseKey]
                        : subs.map((s) => s.key).toList();
                    final isItemDone =
                        leaves.isNotEmpty && leaves.every(_done.contains);
                    final currentIndex = _currentItemIndex(items, catalog);
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
                        onToggleSubDone: (sub) => _onToggleDone(sub.key),
                        onToggleAllDone: isItemDone
                            ? () => _setDoneMany(leaves, false)
                            : null,
                      );
                    }

                    final singleAction = subs.isEmpty ? null : subs.single;
                    final key = singleAction?.key ?? baseKey;
                    final extraSummary =
                        item.type == ServiceOrderMomentType.welcome
                        ? _welcomeSummary()
                        : (item.type != null
                              ? _repertoireSummaryFor(item.type!)
                              : null);
                    final momentCard = _MomentCard(
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
                      onToggleDone: () => _onToggleDone(key),
                    );
                    // Anotação livre logo abaixo de "Boas-vindas"/"Avisos/
                    // Comunicações" (28/08/2026, pedido do usuário) — ver doc
                    // comment de `ServiceOrder.welcomeNotes`/
                    // `.announcementsNotes`. Não é marcável, só texto.
                    final momentNotes = switch (item.type) {
                      ServiceOrderMomentType.welcome => order.welcomeNotes,
                      ServiceOrderMomentType.announcements =>
                        order.announcementsNotes,
                      _ => '',
                    };
                    if (momentNotes.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          momentCard,
                          _MomentNotesCard(text: momentNotes),
                        ],
                      );
                    }
                    return momentCard;
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

  int _currentItemIndex(List<ServiceOrderItem> items, List<PraiseSong> catalog) {
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final baseKey = _baseKeyFor(i, item, items);
      final subs = _subActionsFor(baseKey, item, catalog);
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
    ServiceOrderMomentType.gratitudePrayer => Icons.favorite,
    ServiceOrderMomentType.childrenPrayer => Icons.child_care,
    ServiceOrderMomentType.intercession => Icons.groups,
    ServiceOrderMomentType.message => Icons.record_voice_over,
    ServiceOrderMomentType.communion => Icons.wine_bar,
    ServiceOrderMomentType.apostolicBlessing => Icons.emoji_events,
    ServiceOrderMomentType.postlude => Icons.piano,
  };
}

/// Emoji pros momentos que o usuário quer manter com o glifo de verdade
/// (28/08/2026, "Material Icons não tem [gesto] de verdade") — `null` pros
/// demais tipos, que usam `Icon(_iconFor(type))` normal.
String? _emojiFor(ServiceOrderMomentType? type) => switch (type) {
  ServiceOrderMomentType.prayer => '🙏',
  ServiceOrderMomentType.welcome => '🫂',
  ServiceOrderMomentType.apostolicBlessing => '🤲',
  ServiceOrderMomentType.communion => '🍷',
  _ => null,
};

/// Ícone do momento — emoji (`_emojiFor`) quando existe, senão `Icon`
/// (`_iconFor`) normal. Reaproveitado por `_MomentCard`/`_MomentGroupCard`.
///
/// O emoji precisa do mesmo padrão de cor dos demais ícones (pendente/atual
/// piscando dourado/concluído verde — 01/09/2026, pedido do usuário: "não
/// quero que mude os ícones, quero apenas que mantenha no mesmo padrão de
/// cor") mas `TextStyle.color` não tem efeito sobre um glifo emoji colorido
/// (a fonte de emoji embute a própria cor, ignorando o `color` do texto) —
/// por isso o `ColorFiltered`/`BlendMode.srcIn` abaixo: usa o alfa do glifo
/// como máscara e pinta tudo com `color`, igual a um `Icon` monocromático
/// normal, só que com o desenho do emoji.
Widget _momentIcon(
  ServiceOrderMomentType? type, {
  required double size,
  required Color color,
}) {
  final emoji = _emojiFor(type);
  if (emoji != null) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
  return Icon(_iconFor(type), color: color, size: size);
}

/// Pulsa um valor 0..1 continuamente enquanto `enabled` — usado pro
/// destaque "dourado piscando" do momento atual (01/09/2026, pedido do
/// usuário: "vamos testar... se fica bom"). Desligado, o builder recebe
/// sempre `1.0` (estado "aceso" fixo), sem `AnimationController` rodando à
/// toa nos outros cards da lista.
class _PulseValue extends StatefulWidget {
  const _PulseValue({required this.enabled, required this.builder});

  final bool enabled;
  final ValueWidgetBuilder<double> builder;

  @override
  State<_PulseValue> createState() => _PulseValueState();
}

class _PulseValueState extends State<_PulseValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(context, 1, null);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) =>
          widget.builder(context, _animation.value, child),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.index,
    required this.item,
    required this.order,
    required this.isDone,
    required this.isCurrent,
    required this.onTap,
    required this.onToggleDone,
    this.isLink = false,
    this.extraSummary,
  });

  final int index;
  final ServiceOrderItem item;
  final ServiceOrder order;
  final bool isDone;
  final bool isCurrent;

  /// Toque no corpo do card — quando já concluído, reabre o link (bíblia/
  /// cifra/hino), se houver, sem desmarcar (01/09/2026, pedido do usuário).
  final VoidCallback onTap;

  /// Toque na bolinha dourada de check — único jeito de desmarcar um
  /// momento já concluído (01/09/2026, pedido do usuário).
  final VoidCallback onToggleDone;

  /// `true` quando o toque no card abre bíblia/hino/cifra em vez de só
  /// marcar concluído. O título do momento fica igual aos demais
  /// (01/09/2026, pedido do usuário: "todos os momentos com a fonte na
  /// mesma cor... Leitura bíblica e Louvor deve estar como os demais") — o
  /// dourado migrou pro texto de baixo (`summary`/`extraSummary`), que é o
  /// conteúdo de fato clicável: a referência bíblica ou o nome da música.
  final bool isLink;
  final String? extraSummary;

  @override
  Widget build(BuildContext context) {
    final baseSummary = item.summary(order);
    final summary = [?baseSummary, ?extraSummary].join('\n');
    final textColor = isDone ? _doneGreen : Colors.white;
    final summaryColor = isDone
        ? Colors.white24
        : (isLink ? SibValColors.goldAccent : Colors.white60);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      // Momento atual pisca em dourado (01/09/2026, pedido do usuário,
      // "testar se fica bom") — só o card com `isCurrent` roda a animação;
      // os demais recebem `t` fixo em 1.0 sem custo de controller.
      child: _PulseValue(
        enabled: isCurrent,
        builder: (context, t, _) {
          final goldPulse = SibValColors.goldAccent.withValues(
            alpha: 0.5 + 0.5 * t,
          );
          return Material(
            color: isCurrent
                ? const Color(0xFF1E3A5F)
                : (isDone
                      ? _doneGreen.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: isCurrent
                      ? Border.all(color: goldPulse, width: 1.5)
                      : (isDone
                            ? Border.all(
                                color: _doneGreen.withValues(alpha: 0.4),
                              )
                            : null),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selo "ao vivo" dinâmico (02/09/2026, pedido do usuário)
                    // — antes fixo só no cabeçalho da tela, agora acompanha o
                    // momento que está acontecendo, aparecendo do lado
                    // esquerdo do card atual, além do dourado piscando.
                    if (isCurrent) ...[
                      const ServiceOrderLiveBadge(size: 16),
                      const SizedBox(width: 8),
                    ],
                    _StatusBadgeTapTarget(
                      onTap: onToggleDone,
                      child: _StatusBadge(
                        index: index,
                        isDone: isDone,
                        isCurrent: isCurrent,
                        currentColor: goldPulse,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _momentIcon(
                      item.type,
                      size: 20,
                      color: isDone
                          ? _doneGreen
                          : (isCurrent ? goldPulse : Colors.white70),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.labelFor(order),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (summary.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                summary,
                                style: TextStyle(
                                  color: summaryColor,
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
          );
        },
      ),
    );
  }
}

/// Momento com sub-ações (28/08/2026, pedido do usuário) — "Leitura
/// bíblica" com mais de uma referência, ou "Dedicação dos dízimos e
/// ofertas" (sempre, mesmo com só uma subcategoria preenchida): cabeçalho
/// não-tocável + uma linha por sub-ação, cada uma marcando concluído só
/// depois de abrir a leitura de verdade.
/// Caixa com a anotação livre do dirigente pro momento "Boas-vindas"/"Avisos/
/// Comunicações" (28/08/2026, pedido do usuário) — logo abaixo do card do
/// momento, sem nenhuma interação (não marca concluído, não navega).
class _MomentNotesCard extends StatelessWidget {
  const _MomentNotesCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }
}

class _MomentGroupCard extends StatelessWidget {
  const _MomentGroupCard({
    required this.index,
    required this.item,
    required this.subs,
    required this.doneKeys,
    required this.isDone,
    required this.isCurrent,
    required this.onSubTap,
    required this.onToggleSubDone,
    required this.onToggleAllDone,
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

  /// Toque no corpo de uma sub-ação — reabre o link quando já concluída, em
  /// vez de desmarcar (01/09/2026, pedido do usuário, mesma regra do
  /// `_MomentCard`).
  final ValueChanged<_SubAction> onSubTap;

  /// Toque na bolinha dourada de check de uma sub-ação — único jeito de
  /// desmarcá-la (01/09/2026, pedido do usuário).
  final ValueChanged<_SubAction> onToggleSubDone;

  /// Toque na bolinha dourada de check do cabeçalho do grupo — só chega
  /// aqui quando `isDone` (todas as sub-ações concluídas); desmarca todas de
  /// uma vez, permitindo refazer o grupo inteiro (01/09/2026, pedido do
  /// usuário). `null` enquanto o grupo não está totalmente concluído — o
  /// cabeçalho continua não-tocável nesse caso, como sempre foi.
  final VoidCallback? onToggleAllDone;

  @override
  Widget build(BuildContext context) {
    final textColor = isDone ? _doneGreen : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _PulseValue(
        enabled: isCurrent,
        builder: (context, t, _) {
          final goldPulse = SibValColors.goldAccent.withValues(
            alpha: 0.5 + 0.5 * t,
          );
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF1E3A5F)
                  : (isDone
                        ? _doneGreen.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(14),
              border: isCurrent
                  ? Border.all(color: goldPulse, width: 1.5)
                  : (isDone
                        ? Border.all(color: _doneGreen.withValues(alpha: 0.4))
                        : null),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isCurrent) ...[
                      const ServiceOrderLiveBadge(size: 16),
                      const SizedBox(width: 8),
                    ],
                    _StatusBadgeTapTarget(
                      onTap: onToggleAllDone,
                      child: _StatusBadge(
                        index: index,
                        isDone: isDone,
                        isCurrent: isCurrent,
                        currentColor: goldPulse,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _momentIcon(
                      item.type,
                      size: 20,
                      color: isDone
                          ? _doneGreen
                          : (isCurrent ? goldPulse : Colors.white70),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 42, top: 4),
                    child: Text(
                      'Nada preenchido.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                for (final sub in subs)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 6),
                    child: _SubActionRow(
                      sub: sub,
                      isDone: doneKeys.contains(sub.key),
                      onTap: () => onSubTap(sub),
                      onToggleDone: () => onToggleSubDone(sub),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubActionRow extends StatelessWidget {
  const _SubActionRow({
    required this.sub,
    required this.isDone,
    required this.onTap,
    required this.onToggleDone,
  });

  final _SubAction sub;
  final bool isDone;

  /// Reabre o link quando já concluída, em vez de desmarcar (01/09/2026,
  /// pedido do usuário).
  final VoidCallback onTap;

  /// Toque no ícone de check — único jeito de desmarcar uma sub-ação já
  /// concluída (01/09/2026, pedido do usuário, mesma regra do `_MomentCard`).
  final VoidCallback onToggleDone;

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
              _StatusBadgeTapTarget(
                onTap: isDone ? onToggleDone : null,
                child: Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: isDone ? _doneGreen : Colors.white54,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sub.label,
                  style: TextStyle(
                    // Sub-ação sempre navega (abre bíblia/hino) — dourado
                    // padrão de "clicável" (28/08, pedido do usuário);
                    // concluída vira verde (01/09, ver `_doneGreen`).
                    color: isDone ? _doneGreen : SibValColors.goldAccent,
                    fontSize: 14,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (!isDone)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white38,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Área de toque isolada em volta da bolinha de status (badge do momento ou
/// ícone de check da sub-ação) — captura o toque antes que ele chegue no
/// `InkWell` do card/linha ao redor, permitindo um gesto próprio de
/// alternar concluído/pendente independente do toque no corpo (01/09/2026,
/// pedido do usuário: "só poderá ser desmarcado tocando na bolinha
/// dourada"). `onTap == null` desativa o toque (badge de grupo antes de
/// tudo concluído) sem quebrar o layout.
class _StatusBadgeTapTarget extends StatelessWidget {
  const _StatusBadgeTapTarget({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.index,
    required this.isDone,
    required this.isCurrent,
    this.currentColor = SibValColors.goldAccent,
  });

  final int index;
  final bool isDone;
  final bool isCurrent;

  /// Cor do badge quando `isCurrent` — recebe o dourado já pulsando (via
  /// `_PulseValue`, 01/09/2026) de quem chamou; sem chamador animado, cai no
  /// dourado sólido de sempre.
  final Color currentColor;

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: _doneGreen,
        child: Icon(Icons.check, size: 16, color: Colors.white),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: isCurrent ? currentColor : Colors.white12,
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
