import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_order.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'service_order_bible_text_page.dart' show resolvedBibleVersesProvider;

/// Sem equivalente no app nativo — feature nova (29/08/2026, pedido do
/// usuário). Aberta ao tocar no momento "Momento Missionário" (dirigente em
/// `ServiceOrderLivePage`, e nas duas visões somente-leitura — Louvor/membro
/// comum, `ServiceOrderReadOnlyBody`). Layout revisado no mesmo dia, pedido
/// literal do usuário:
///
/// - "Tema: {tema}" no topo, em destaque/letras grandes — aparece **uma só
///   vez**, mesmo com mais de uma Divisa cadastrada (o tema é do momento
///   inteiro, não de cada texto).
/// - Abaixo, cabeçalho "Divisa" e o(s) texto(s) bíblico(s) selecionados
///   (`ServiceOrder.missionMottoReferences`, pode ter mais de um) em texto
///   padrão — menor que o tema — cada um com a referência ao final (ex.:
///   "Romanos 10:1-5"). Mais de um texto empilha um abaixo do outro.
///
/// Mesma fonte de `ServiceOrderBibleTextPage` (BLIVRE, com fallback pro
/// Almeida 1911 local) e mesmo crédito — sem os botões de zoom dela, que
/// essa tela não tem (texto de divisa costuma ser curto).
class ServiceOrderMissionMomentPage extends StatelessWidget {
  const ServiceOrderMissionMomentPage({
    super.key,
    required this.theme,
    required this.references,
  });

  final String theme;
  final List<BibleReference> references;

  @override
  Widget build(BuildContext context) {
    final filled = references.where((r) => r.isFilled).toList();
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tema: $theme',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SibValColors.goldAccent,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 28),
            if (filled.isEmpty)
              Text(
                'Nenhum texto bíblico cadastrado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary),
              )
            else ...[
              Text(
                'Divisa',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < filled.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                _MottoBlock(reference: filled[i]),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _MottoBlock extends ConsumerWidget {
  const _MottoBlock({required this.reference});

  final BibleReference reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedAsync = ref.watch(
      resolvedBibleVersesProvider((
        bookId: reference.bookId!,
        chapter: reference.chapter!,
      )),
    );
    return resolvedAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text(
        'Falha ao carregar: $error',
        style: TextStyle(color: context.textPrimary),
      ),
      data: (resolved) {
        final start = reference.verseStart!;
        final end = reference.verseEnd ?? start;
        final verses = resolved.verses
            .where((v) => v.number >= start && v.number <= end)
            .toList();
        if (verses.isEmpty) {
          return Text(
            'Versículo não encontrado.',
            style: TextStyle(color: context.textSecondary),
          );
        }
        // Texto padrão, um pouco menor que o tema (29/08/2026, pedido do
        // usuário) — parágrafo corrido dos versículos selecionados, sem
        // número de versículo (a "Divisa" é lida como uma citação única,
        // não como uma leitura capítulo a capítulo).
        final quote = verses.map((v) => v.text).join(' ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              quote,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reference.reference ?? '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: SibValColors.goldAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            // Crédito da fonte (mesmo texto de `ServiceOrderBibleTextPage`) —
            // só aparece com a BLIVRE; Almeida 1911 é domínio público.
            Text(
              resolved.fromBlivre
                  ? 'Fonte: Bíblia Livre (BLIVRE), licença CC BY 4.0'
                  : 'Fonte: Almeida 1911 (offline)',
              textAlign: TextAlign.right,
              style: TextStyle(color: context.textSecondary, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}
