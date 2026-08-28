import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cifra_repository.dart';
import '../models/cifra.dart';
import '../models/praise_repertoire.dart' show praiseToneNotes;
import '../theme/app_theme.dart';
import '../util/chord_transpose.dart';
import '../util/cifra_club_text.dart';
import '../widgets/sibval_app_bar.dart';

const _fontSizeKey = 'cifra_font_size';
const _defaultFontSize = 15.0;
const _minFontSize = 11.0;
const _maxFontSize = 24.0;
const _fontSizeStep = 2.0;

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Mostra a cifra de uma música em tela cheia — botões +/- (no
/// corpo da página, não na barra fixa — mesmo ajuste já feito em
/// `service_order_bible_text_page.dart`) transpõem o tom exibido
/// (client-side, `_semitones`, não altera `Cifra.content` salvo, ver
/// `chord_transpose.dart`) e outro par de botões +/- (28/08/2026, pedido do
/// usuário) ajusta o tamanho da fonte (`_fontSize`, preferência própria —
/// `cifra_font_size` — não compartilhada com a Bíblia/Hinário). Acessível a
/// quem já vê o repertório (Dirigentes/Louvor) ou tem acesso de edição de
/// cifra (`firestore.rules`).
class CifraViewPage extends ConsumerStatefulWidget {
  const CifraViewPage({super.key, required this.songId, required this.songName});

  final String songId;
  final String songName;

  @override
  ConsumerState<CifraViewPage> createState() => _CifraViewPageState();
}

class _CifraViewPageState extends ConsumerState<CifraViewPage> {
  int _semitones = 0;
  double _fontSize = _defaultFontSize;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize);
    }
  }

  Future<void> _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newSize);
  }

  /// Abre a lista das 12 notas cromáticas (28/08/2026, pedido do usuário:
  /// "implementar a possibilidade de selecionar o tom além de subir e
  /// descer pelo + e -") — só disponível quando a cifra tem `baseTone`
  /// salvo (sem isso não há de onde calcular quantos semitons faltam pra
  /// chegar na nota escolhida). Convive com os botões +/- já existentes,
  /// que continuam funcionando normalmente.
  Future<void> _openTonePicker(String baseTone) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Selecionar tom'),
        children: [
          for (final note in praiseToneNotes)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(note),
              child: Text(note, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
    if (selected == null) return;
    final isMinor = baseTone.endsWith('m');
    final rootNote = isMinor ? baseTone.substring(0, baseTone.length - 1) : baseTone;
    final baseIndex = noteIndex(rootNote);
    final targetIndex = noteIndex(selected);
    if (baseIndex == null || targetIndex == null) return;
    setState(() => _semitones = (targetIndex - baseIndex + 12) % 12);
  }

  @override
  Widget build(BuildContext context) {
    final cifraAsync = ref.watch(cifraForSongProvider(widget.songId));
    final baseTone = cifraAsync.asData?.value?.baseTone ?? '';
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.songName,
                      style: const TextStyle(
                        color: SibValColors.goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeFontSize(-_fontSizeStep),
                    icon: const Icon(Icons.text_decrease),
                  ),
                  IconButton(
                    onPressed: () => _changeFontSize(_fontSizeStep),
                    icon: const Icon(Icons.text_increase),
                  ),
                ],
              ),
            ),
            Expanded(
              child: cifraAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (cifra) {
                  if (cifra == null || cifra.content.trim().isEmpty) {
                    return Center(
                      child: Text(
                        'Cifra ainda não cadastrada.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    );
                  }
                  return _CifraContent(
                    cifra: cifra,
                    semitones: _semitones,
                    fontSize: _fontSize,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Text('Tom', style: TextStyle(color: context.textSecondary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => _semitones--),
                  ),
                  InkWell(
                    onTap: baseTone.isEmpty ? null : () => _openTonePicker(baseTone),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        _semitones == 0 ? 'Original' : (_semitones > 0 ? '+$_semitones' : '$_semitones'),
                        style: TextStyle(
                          color: baseTone.isEmpty ? context.textPrimary : SibValColors.goldAccent,
                          fontSize: 16,
                          decoration: baseTone.isEmpty ? null : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _semitones++),
                  ),
                  if (_semitones != 0)
                    TextButton(
                      onPressed: () => setState(() => _semitones = 0),
                      child: const Text('Zerar'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transpõe um tom no formato salvo (ex. "Gm") — separa o "m" de menor
/// antes de deslocar a nota, senão `shiftNote` não reconhece "Gm" como nota.
String _transposeToneLabel(String tone, int semitones) {
  if (tone.isEmpty || semitones == 0) return tone;
  final isMinor = tone.endsWith('m');
  final note = isMinor ? tone.substring(0, tone.length - 1) : tone;
  final shifted = shiftNote(note, semitones);
  return isMinor ? '${shifted}m' : shifted;
}

/// Cifras salvas antes de 28/08/2026 (rodada de import) ainda usam
/// `[Acorde]palavra` inline — detectadas por esta regex e renderizadas pelo
/// caminho antigo (`_lineSpans`), sem migração. Conteúdo novo (colado ou
/// importado de arquivo, já limpo por `cleanCifraClubText`) não tem
/// colchete nenhum e cai no formato "Cifra Club" de duas linhas
/// (`_lineSpansTwoLine`/`isChordLine`).
final RegExp _legacyBracketPattern = RegExp(r'\[[^\]\n]+\]');

class _CifraContent extends StatelessWidget {
  const _CifraContent({required this.cifra, required this.semitones, required this.fontSize});

  final Cifra cifra;
  final int semitones;
  final double fontSize;

  List<InlineSpan> _lineSpans(String line, BuildContext context) {
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in chordBracketPattern.allMatches(line)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: line.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: transposeChord(match.group(1)!, semitones),
          style: const TextStyle(
            color: SibValColors.goldAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd)));
    }
    if (spans.isEmpty) spans.add(const TextSpan(text: ' '));
    return spans;
  }

  /// Formato "Cifra Club": a linha inteira é acorde (`isChordLine`) — vira
  /// negrito/dourado, transposta como uma unidade (`transposeChordLine`,
  /// preserva alinhamento); senão é letra normal.
  List<InlineSpan> _lineSpansTwoLine(String line) {
    if (isChordLine(line)) {
      final transposed = transposeChordLine(line, semitones);
      return [
        TextSpan(
          text: transposed.isEmpty ? ' ' : transposed,
          style: const TextStyle(
            color: SibValColors.goldAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ];
    }
    return [TextSpan(text: line.isEmpty ? ' ' : line)];
  }

  @override
  Widget build(BuildContext context) {
    final lines = cifra.content.split('\n');
    final isLegacyFormat = _legacyBracketPattern.hasMatch(cifra.content);
    final displayTone = _transposeToneLabel(cifra.baseTone, semitones);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (cifra.baseTone.isNotEmpty || cifra.capo > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (cifra.baseTone.isNotEmpty)
                  Text(
                    'Tom: $displayTone',
                    style: const TextStyle(
                      color: SibValColors.goldAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (cifra.capo > 0)
                  Text(
                    'Capotraste: ${cifra.capo}ª casa',
                    style: TextStyle(color: context.textSecondary),
                  ),
              ],
            ),
          ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: context.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: fontSize,
                  height: 1.6,
                ),
                children: isLegacyFormat ? _lineSpans(line, context) : _lineSpansTwoLine(line),
              ),
            ),
          ),
      ],
    );
  }
}
