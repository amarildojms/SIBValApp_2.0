import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/cifra_repository.dart';
import '../data/praise_repertoire_repository.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'cifra_view_page.dart';

/// Detalhe somente-leitura de um ensaio (semana) — músicas escaladas com
/// nome/cantor/tom, agrupadas por momento, e os links de playlist. Toque
/// numa música com cifra cadastrada abre `CifraViewPage`; sem cifra, a linha
/// não é tocável (28/08/2026, pedido do usuário: "se houver cifra, ao tocar
/// ele irá abrir a cifra").
///
/// As músicas aparecem em pastas por mês referência (02/09/2026, pedido do
/// usuário — mesmo padrão já usado no picker de música de
/// `WeeklyRepertoireFormPage`) — o mês vem do catálogo mestre
/// (`praiseSongsProvider`, casado por `songId`), já que `PraiseAssignment`
/// não denormaliza esse campo; música removida do catálogo depois de
/// escalada cai na pasta "Sem mês definido".
class EnsaioDetailPage extends ConsumerWidget {
  const EnsaioDetailPage({super.key, required this.repertoire});

  final WeeklyRepertoire repertoire;

  static final _dateFormat = DateFormat("EEEE, dd/MM/yyyy", 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cifrasAsync = ref.watch(cifrasProvider);
    // Ids das músicas que já têm cifra com conteúdo — usado só pra decidir
    // se a linha vira link (28/08/2026, pedido do usuário) sem precisar
    // observar um stream por música.
    final songIdsWithCifra = (cifrasAsync.asData?.value ?? const [])
        .where((c) => c.content.trim().isNotEmpty)
        .map((c) => c.songId)
        .toSet();

    final catalogSongs = ref.watch(praiseSongsProvider).asData?.value ?? const [];
    final referenceMonthById = {for (final s in catalogSongs) s.id: s.referenceMonthKey};

    final groups = <String?, List<PraiseAssignment>>{};
    for (final assignment in repertoire.assignments) {
      groups.putIfAbsent(referenceMonthById[assignment.songId], () => []).add(assignment);
    }
    final groupKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return b.compareTo(a);
      });

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle(_dateFormat.format(repertoire.weekDate)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (repertoire.assignments.isEmpty)
                    Text(
                      'Nenhuma música escalada.',
                      style: TextStyle(color: context.textSecondary),
                    )
                  else if (groupKeys.length <= 1)
                    // Só uma pasta (ou nenhuma música com mês definido) —
                    // mostra a lista direto, sem `ExpansionTile` supérfluo.
                    for (final assignment in repertoire.assignments)
                      _AssignmentTile(
                        assignment: assignment,
                        hasCifra: songIdsWithCifra.contains(assignment.songId),
                      )
                  else
                    for (final key in groupKeys)
                      ExpansionTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(praiseReferenceMonthLabel(key)),
                        // Fechadas por padrão (03/09/2026, pedido do
                        // usuário — mesmo ajuste aplicado ao Repertório
                        // Mensal).
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(left: 8),
                        children: [
                          for (final assignment in groups[key]!)
                            _AssignmentTile(
                              assignment: assignment,
                              hasCifra: songIdsWithCifra.contains(assignment.songId),
                            ),
                        ],
                      ),
                  if (repertoire.links.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Links de playlist',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final link in repertoire.links)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link, color: SibValColors.goldAccent),
                        title: Text(
                          link,
                          style: const TextStyle(color: SibValColors.goldAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => launchUrl(
                          Uri.parse(link),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment, required this.hasCifra});

  final PraiseAssignment assignment;
  final bool hasCifra;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (assignment.songArtist.isNotEmpty) assignment.songArtist,
      if (assignment.toneDisplay.isNotEmpty) 'Tom: ${assignment.toneDisplay}',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.music_note_outlined),
      title: Text(
        assignment.songName,
        style: TextStyle(
          color: hasCifra ? SibValColors.goldAccent : context.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: subtitleParts.isEmpty
          ? Text(assignment.slotLabel, style: TextStyle(color: context.textSecondary))
          : Text(
              '${subtitleParts.join(' · ')} · ${assignment.slotLabel}',
              style: TextStyle(color: context.textSecondary),
            ),
      trailing: hasCifra
          ? const Icon(Icons.chevron_right, color: SibValColors.goldAccent)
          : null,
      onTap: hasCifra
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CifraViewPage(
                  songId: assignment.songId,
                  songName: assignment.songName,
                ),
              ),
            )
          : null,
    );
  }
}
