import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/hymnal_repository.dart';
import '../data/praise_repertoire_repository.dart';
import '../data/service_order_repository.dart';
import '../hymnal/hymn_detail_page.dart';
import '../models/hymn.dart';
import '../models/praise_repertoire.dart';
import '../models/notification.dart';
import '../models/service_order.dart';
import '../notifications/notification_read_sync.dart';
import '../praise/cifra_view_page.dart';
import '../theme/app_theme.dart';
import 'service_order_bible_text_page.dart';
import 'service_order_countdown.dart';
import 'service_order_mission_moment_page.dart';
import 'service_order_preview_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Visão da Ordem de Culto pra quem tem o papel Louvor — mesma
/// tela cheia escura de `ServiceOrderLivePage` (dirigente), mas:
/// - **Somente leitura**: nada é marcado concluído por um toque aqui. O
///   progresso vem direto de `serviceOrderStreamProvider` (Firestore em
///   tempo real) — quando o dirigente marca um momento em
///   `ServiceOrderLivePage`, aparece aqui sozinho, sem nenhuma ação do
///   usuário do Louvor.
/// - Textos bíblicos/hinos são tocáveis, mesmos destinos do dirigente
///   (`ServiceOrderBibleTextPage`/`HymnDetailPage`), só que sem marcar nada
///   ao voltar.
/// - Momentos "Louvor" mostram o tom de cada música (o dirigente não vê
///   isso, por pedido do usuário — "por hora, regra a ajustar depois") e
///   tocar numa música leva pra `CifraViewPage`.
/// - Acesso liberado 2h antes do horário do culto
///   (`isServiceOrderViewableEarly`, 29/08/2026 — era 1h, mesma janela agora
///   compartilhada com o dono da ordem em `ServiceOrderPrecheckPage`) — antes
///   disso mostra só a contagem regressiva (com botão "Ver Prévia", pedido do
///   usuário na mesma sessão). Um cronômetro fica visível no topo até o
///   horário exato, mesmo depois de já poder ver a ordem.
///
/// A lista de momentos somente-leitura (`ServiceOrderReadOnlyBody`, abaixo)
/// foi extraída pra cá pra ser reaproveitada também por
/// `ServiceOrderMemberViewPage` (28/08/2026, pedido do usuário — visão dos
/// demais membros/visitantes, "igual à do Louvor, porém sem acesso às
/// cifras") — `showPraiseDetails: false` esconde o tom e desliga o toque nos
/// momentos "Louvor" (só nome/cantor, sem link pra `CifraViewPage`); as
/// demais navegações (bíblia/hino) continuam iguais nos dois casos.
class ServiceOrderPraiseViewPage extends ConsumerStatefulWidget {
  const ServiceOrderPraiseViewPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ServiceOrderPraiseViewPage> createState() =>
      _ServiceOrderPraiseViewPageState();
}

class _ServiceOrderPraiseViewPageState
    extends ConsumerState<ServiceOrderPraiseViewPage> {
  static final _dateFormat = DateFormat('EEEE, dd/MM HH:mm', 'pt_BR');

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    // Chega aqui por outro caminho que não o toque na notificação também
    // marca como lida/cancela da barra (24/08/2026, mesmo padrão das demais
    // telas ligadas a um tipo de notificação).
    syncNotificationsForScreen(
      ref,
      type: NotificationType.serviceOrderReminder,
      targetId: widget.orderId,
    );
    syncNotificationsForScreen(
      ref,
      type: NotificationType.serviceOrderStarted,
      targetId: widget.orderId,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(serviceOrderStreamProvider(widget.orderId));
    return Scaffold(
      backgroundColor: SibValColors.navyBlue,
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: SibValColors.goldAccent),
          ),
          error: (error, _) => Center(
            child: Text(
              'Falha ao carregar: $error',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          data: (order) {
            if (order == null) {
              return const Center(
                child: Text(
                  'Ordem não encontrada.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            final available = isServiceOrderViewableEarly(order.dateTime);
            if (!available)
              return _NotYetAvailable(order: order, dateFormat: _dateFormat);
            return _buildOrder(order);
          },
        ),
      ),
    );
  }

  Widget _buildOrder(ServiceOrder order) {
    final started = !DateTime.now().isBefore(order.dateTime);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ORDEM DO CULTO — LOUVOR',
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (order.isFinalized)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _Banner(text: 'Culto finalizado', icon: Icons.check_circle),
          )
        else if (!started)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: _CountdownBanner(target: order.dateTime),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: _Banner(
              text: 'Culto em andamento',
              icon: Icons.play_circle_outline,
            ),
          ),
        Expanded(
          child: ServiceOrderReadOnlyBody(
            order: order,
            showPraiseDetails: true,
          ),
        ),
      ],
    );
  }
}

/// Lista somente-leitura dos momentos de uma ordem, com o progresso lido de
/// `order.completedMomentKeys` (nunca escreve nada) — extraída de dentro de
/// `_ServiceOrderPraiseViewPageState` (28/08/2026) pra ser reaproveitada
/// também por `ServiceOrderMemberViewPage`. Ver doc comment de
/// `ServiceOrderPraiseViewPage` acima pro que [showPraiseDetails] controla.
class ServiceOrderReadOnlyBody extends ConsumerStatefulWidget {
  const ServiceOrderReadOnlyBody({
    super.key,
    required this.order,
    required this.showPraiseDetails,
  });

  final ServiceOrder order;
  final bool showPraiseDetails;

  @override
  ConsumerState<ServiceOrderReadOnlyBody> createState() =>
      _ServiceOrderReadOnlyBodyState();
}

class _ServiceOrderReadOnlyBodyState
    extends ConsumerState<ServiceOrderReadOnlyBody> {
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

  List<String> _leafKeysFor(
    String baseKey,
    ServiceOrderItem item,
    ServiceOrder order,
  ) {
    // "Leitura bíblica"/momento adicional com texto bíblico (29/08/2026,
    // pedido do usuário: "carregue todos os textos de uma vez") — 1 chave só
    // pro momento inteiro, mesmo com várias referências — precisa bater com
    // a mesma chave única gravada por `ServiceOrderLivePage._subActionsFor`
    // (`'$baseKey:bible'`, sem sufixo de índice), senão o progresso aparece
    // sempre pendente nesta visão somente-leitura.
    if (item.type == ServiceOrderMomentType.bibleReading) {
      return order.bibleReadings.any((r) => r.isFilled)
          ? ['$baseKey:bible']
          : [baseKey];
    }
    if (item.type == ServiceOrderMomentType.tithesOffering) {
      final keys = <String>[];
      if (order.tithesBibleReadings.any((r) => r.isFilled)) {
        keys.add('$baseKey:tithesBible');
      }
      if (order.congregationalHymn.isNotEmpty) keys.add('$baseKey:tithesHymn');
      return keys;
    }
    if (item.type == null && item.extraBibleReferences.isNotEmpty) {
      return item.extraBibleReferences.any((r) => r.isFilled)
          ? ['$baseKey:bible']
          : [baseKey];
    }
    // "Divisa" (29/08/2026) — mesma chave única gravada por
    // `ServiceOrderLivePage._subActionsFor` (`'$baseKey:motto'`), não o
    // `baseKey` puro — sem isso o card ficaria sempre "pendente" nesta
    // visão somente-leitura mesmo depois do dirigente marcar concluído.
    if (item.type == ServiceOrderMomentType.missionMoment &&
        order.missionMottoReferences.any((r) => r.isFilled)) {
      return ['$baseKey:motto'];
    }
    return [baseKey];
  }

  bool _isDone(
    Set<String> completed,
    String baseKey,
    List<String> leaves,
    ServiceOrderItem item,
  ) {
    if (item.type == ServiceOrderMomentType.welcome) {
      return completed.contains(baseKey) ||
          completed.contains('$baseKey:visitors');
    }
    if (leaves.isEmpty) return true;
    return leaves.every(completed.contains);
  }

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

  Future<void> _openHymn(String label) async {
    final resolved = await _resolveHymn(label);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hino não encontrado no hinário.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            HymnDetailPage(hymnal: resolved.$1, songId: resolved.$2.id),
      ),
    );
  }

  void _openBibleText(List<BibleReference> references) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ServiceOrderBibleTextPage(references: references),
      ),
    );
  }

  void _openMissionMotto(String theme, List<BibleReference> references) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ServiceOrderMissionMomentPage(theme: theme, references: references),
      ),
    );
  }

  void _openCifra(String songId, String songName) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CifraViewPage(songId: songId, songName: songName),
      ),
    );
  }

  List<_DetailRow> _detailRowsFor(
    ServiceOrderItem item,
    ServiceOrder order,
    WeeklyRepertoire? repertoire,
  ) {
    final rows = <_DetailRow>[];
    if (item.type == ServiceOrderMomentType.bibleReading) {
      // 1 linha só, mesmo com várias referências (29/08/2026, pedido do
      // usuário: "carregue todos os textos na tela de uma vez") — mesmo
      // padrão já usado pela "Divisa" do Momento Missionário logo abaixo.
      final refs = order.bibleReadings.where((r) => r.isFilled).toList();
      if (refs.isNotEmpty) {
        rows.add(
          _DetailRow(
            label: refs.map((r) => r.reference).whereType<String>().join('; '),
            onTap: () => _openBibleText(refs),
          ),
        );
      }
    } else if (item.type == ServiceOrderMomentType.missionMoment) {
      // "Divisa" (29/08/2026, pedido do usuário) — 1 toque abre todos os
      // textos selecionados, mesmo comportamento de `ServiceOrderLivePage`.
      final refs = order.missionMottoReferences
          .where((r) => r.isFilled)
          .toList();
      if (refs.isNotEmpty) {
        rows.add(
          _DetailRow(
            label: 'Divisa',
            onTap: () => _openMissionMotto(order.missionTheme, refs),
          ),
        );
      }
    } else if (item.type == ServiceOrderMomentType.tithesOffering) {
      // 1 linha só, mesmo com vários textos (29/08/2026, pedido do usuário)
      // — mesmo ajuste de "Leitura bíblica" acima.
      final bibleRefs = order.tithesBibleReadings
          .where((r) => r.isFilled)
          .toList();
      if (bibleRefs.isNotEmpty) {
        rows.add(
          _DetailRow(
            label:
                'Texto bíblico: '
                '${bibleRefs.map((r) => r.reference).whereType<String>().join('; ')}',
            onTap: () => _openBibleText(bibleRefs),
          ),
        );
      }
      if (order.congregationalHymn.isNotEmpty) {
        rows.add(
          _DetailRow(
            label: 'Hino: ${order.congregationalHymn}',
            onTap: () => _openHymn(order.congregationalHymn),
          ),
        );
      }
    } else if (item.type == null && item.extraBibleReferences.isNotEmpty) {
      // Mesmo ajuste de "Leitura bíblica" acima — 1 linha só, mesmo com mais
      // de um texto.
      final refs = item.extraBibleReferences.where((r) => r.isFilled).toList();
      if (refs.isNotEmpty) {
        rows.add(
          _DetailRow(
            label: refs.map((r) => r.reference).whereType<String>().join('; '),
            onTap: () => _openBibleText(refs),
          ),
        );
      }
    } else if (item.type != null) {
      final slot = praiseSlotLabelFor(item.type!);
      if (slot != null && repertoire != null) {
        for (final assignment in repertoire.forSlot(slot)) {
          final base = assignment.songArtist.isEmpty
              ? assignment.songName
              : '${assignment.songName} — ${assignment.songArtist}';
          // Tom só pro Louvor (28/08/2026, pedido do usuário) — visão de
          // membro comum (`showPraiseDetails: false`) vê só nome/cantor, sem
          // tom e sem toque pra `CifraViewPage`.
          final label =
              widget.showPraiseDetails && assignment.toneDisplay.isNotEmpty
              ? '$base (Tom: ${assignment.toneDisplay})'
              : base;
          rows.add(
            _DetailRow(
              label: label,
              onTap: widget.showPraiseDetails
                  ? () => _openCifra(assignment.songId, assignment.songName)
                  : null,
            ),
          );
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final repertoireAsync = ref.watch(
      weeklyRepertoireForDateProvider(order.dateTime),
    );
    final repertoire = repertoireAsync.asData?.value;
    final completed = order.completedMomentKeys.toSet();
    final items = order.momentOrder;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final baseKey = _baseKeyFor(index, item, items);
        final leaves = _leafKeysFor(baseKey, item, order);
        final isDone = _isDone(completed, baseKey, leaves, item);
        final rows = _detailRowsFor(item, order, repertoire);
        final momentCard = _PraiseMomentCard(
          index: index,
          item: item,
          order: order,
          isDone: isDone,
          rows: rows,
        );
        // Anotação livre logo abaixo de "Boas-vindas"/"Avisos/Comunicações"
        // (28/08/2026, pedido do usuário) — mesma exibição somente-leitura
        // pras duas visões que reaproveitam este widget (Louvor e membro
        // comum).
        final momentNotes = switch (item.type) {
          ServiceOrderMomentType.welcome => order.welcomeNotes,
          ServiceOrderMomentType.announcements => order.announcementsNotes,
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
    );
  }
}

class _DetailRow {
  const _DetailRow({required this.label, this.onTap});
  final String label;

  /// `null` quando a linha não navega pra lugar nenhum (28/08/2026 —
  /// momento "Louvor" na visão de membro comum, `showPraiseDetails: false`,
  /// mostra só o texto sem virar link).
  final VoidCallback? onTap;
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: SibValColors.goldAccent, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: SibValColors.goldAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cronômetro no topo até o horário do culto (28/08/2026, pedido do
/// usuário: "o timer fica rodando no topo da ordem até o início").
class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({required this.target});
  final DateTime target;

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = target.difference(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            'Tempo até o início',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            _format(remaining.isNegative ? Duration.zero : remaining),
            style: const TextStyle(
              color: SibValColors.goldAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotYetAvailable extends StatelessWidget {
  const _NotYetAvailable({required this.order, required this.dateFormat});
  final ServiceOrder order;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_clock,
              color: SibValColors.goldAccent,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              dateFormat.format(order.dateTime),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'A ordem de culto fica disponível 2 horas antes do início.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // "Ver Prévia" na tela de espera (29/08/2026, pedido do usuário)
            // — mesmo botão que o dono já tinha em `ServiceOrderPrecheckPage`,
            // agora também disponível pra Louvor/admin antes da janela de 2h.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ServiceOrderPreviewPage(order: order),
                  ),
                ),
                child: const Text('Ver Prévia'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar'),
            ),
          ],
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

String? _emojiFor(ServiceOrderMomentType? type) => switch (type) {
  ServiceOrderMomentType.prayer => '🙏',
  ServiceOrderMomentType.welcome => '🫂',
  ServiceOrderMomentType.apostolicBlessing => '🤲',
  ServiceOrderMomentType.communion => '🍷',
  _ => null,
};

/// Caixa com a anotação livre do dirigente pro momento "Boas-vindas"/"Avisos/
/// Comunicações" (28/08/2026, pedido do usuário) — mesmo widget de
/// `service_order_live_page.dart`, duplicado aqui por ser privado ao arquivo
/// (Dart não exporta classes `_Foo` entre libraries).
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

class _PraiseMomentCard extends StatelessWidget {
  const _PraiseMomentCard({
    required this.index,
    required this.item,
    required this.order,
    required this.isDone,
    required this.rows,
  });

  final int index;
  final ServiceOrderItem item;
  final ServiceOrder order;
  final bool isDone;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final summary = item.summary(order);
    final emoji = _emojiFor(item.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isDone
                    ? SibValColors.goldAccent
                    : Colors.white12,
                child: isDone
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: SibValColors.navyBlue,
                      )
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              emoji != null
                  ? Text(emoji, style: const TextStyle(fontSize: 20))
                  : Icon(_iconFor(item.type), color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isDone ? Colors.white38 : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          if (rows.isEmpty && summary != null)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 4),
              child: Text(
                summary,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6),
              child: row.onTap != null
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: row.onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                // Toda linha tocável aqui navega (bíblia/hino/cifra)
                                // — dourado padrão de "clicável" (28/08, pedido do
                                // usuário).
                                child: Text(
                                  row.label,
                                  style: const TextStyle(
                                    color: SibValColors.goldAccent,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
