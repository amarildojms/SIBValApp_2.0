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

String _toneOffsetKey(String songId) => 'cifra_tone_offset_$songId';
String _capoOverrideKey(String songId) => 'cifra_capo_override_$songId';

class _CifraViewPageState extends ConsumerState<CifraViewPage> {
  int _semitones = 0;
  double _fontSize = _defaultFontSize;

  /// Casa do capotraste escolhida pelo usuário — `null` enquanto não
  /// alterado, cai pro `cifra.capo` salvo. Persiste por música
  /// (`SharedPreferences`, mesmo padrão de `_semitones`, 29/08/2026, pedido
  /// do usuário: "a preferência de capotraste também deve ficar
  /// memorizada").
  int? _capoOverride;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
        // Preferência de tom por música (28/08/2026, pedido do usuário: "se
        // um usuário alterou o tom em seu modo de visualização, deve manter
        // esta preferência para aquela música até que ele mude novamente").
        _semitones = prefs.getInt(_toneOffsetKey(widget.songId)) ?? 0;
        final capoKey = _capoOverrideKey(widget.songId);
        if (prefs.containsKey(capoKey)) _capoOverride = prefs.getInt(capoKey);
      });
    }
  }

  Future<void> _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newSize);
  }

  Future<void> _setSemitones(int value) async {
    setState(() => _semitones = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_toneOffsetKey(widget.songId), value);
  }

  Future<void> _setCapoOverride(int value) async {
    setState(() => _capoOverride = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_capoOverrideKey(widget.songId), value);
  }

  /// Abre a lista das 12 notas cromáticas (28/08/2026, pedido do usuário:
  /// "implementar a possibilidade de selecionar o tom além de subir e
  /// descer pelo + e -") — só disponível quando a cifra tem `baseTone`
  /// salvo (sem isso não há de onde calcular quantos semitons faltam pra
  /// chegar na nota escolhida). Convive com os botões +/- já existentes,
  /// que continuam funcionando normalmente.
  Future<void> _openTonePicker(String baseTone) async {
    // A cifra é menor (`baseTone` termina em "m") — a lista mostra as 12
    // notas já com o "m" (ex. "Em", "Dbm", "F#m"), não as notas puras
    // (28/08/2026, pedido do usuário). O acorde escolhido é sempre a nota
    // pura (`praiseToneNotes[i]`) — o "m" é só rótulo, a conta de semitons
    // usa a nota fundamental de qualquer jeito.
    final isMinor = baseTone.endsWith('m');
    final rootNote = isMinor ? baseTone.substring(0, baseTone.length - 1) : baseTone;
    // Tom atualmente selecionado (baseTone + `_semitones`) — usado só pra
    // destacar a lista, além do destaque já existente do tom original
    // (28/08/2026, pedido do usuário: "mostrar em destaque sempre o tom que
    // está selecionado, mas mantendo o destaque que já fizemos para o tom
    // original").
    final baseIdx = noteIndex(rootNote);
    final currentNote = baseIdx == null ? null : shiftNote(rootNote, _semitones);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Selecionar tom'),
        children: [
          for (final note in praiseToneNotes)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(note),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  // Tom selecionado: preenchimento dourado suave. Tom
                  // original: borda dourada (mantida como já era) — os dois
                  // se combinam quando coincidem.
                  color: note == currentNote
                      ? SibValColors.goldAccent.withValues(alpha: 0.15)
                      : null,
                  border: note == rootNote
                      ? Border.all(color: SibValColors.goldAccent, width: 1.5)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isMinor ? '${note}m' : note,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    final targetIndex = noteIndex(selected);
    if (baseIdx == null || targetIndex == null) return;
    _setSemitones((targetIndex - baseIdx + 12) % 12);
  }

  /// Casas do capotraste (0 = removido) — mesmo range do editor
  /// (`cifra_editor_page.dart`, `_capo` até 11). Alterar/remover mantém o tom
  /// selecionado transpondo só os acordes exibidos (28/08/2026, pedido do
  /// usuário) — ver cálculo de `chordSemitones` em [build].
  Future<void> _openCapoPicker(int originalCapo, int currentCapo) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Capotraste'),
        children: [
          for (var i = 0; i <= 11; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: i == currentCapo
                      ? SibValColors.goldAccent.withValues(alpha: 0.15)
                      : null,
                  border: i == originalCapo
                      ? Border.all(color: SibValColors.goldAccent, width: 1.5)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  i == 0 ? 'Sem capotraste' : '${i}ª casa',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    _setCapoOverride(selected);
  }

  @override
  Widget build(BuildContext context) {
    final cifraAsync = ref.watch(cifraForSongProvider(widget.songId));
    final cifraValue = cifraAsync.asData?.value;
    final baseTone = cifraValue?.baseTone ?? '';
    final artist = cifraValue?.songArtist ?? '';
    final originalCapo = cifraValue?.capo ?? 0;
    final effectiveCapo = _capoOverride ?? originalCapo;
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.songName,
                          style: const TextStyle(
                            color: SibValColors.goldAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),
                        // Cantor/banda abaixo do título (28/08/2026, pedido
                        // do usuário) — lido direto de `Cifra.songArtist`
                        // (já buscado por `cifraForSongProvider`), sem
                        // precisar passar mais um parâmetro pra esta tela.
                        if (artist.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              artist,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
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
                  // Alterar/remover o capotraste não muda o tom selecionado
                  // (o cantor continua no mesmo tom real) — só desloca os
                  // acordes exibidos pra compensar (28/08/2026, pedido do
                  // usuário). Se o capo sobe X casas a menos, os acordes
                  // escritos precisam subir X semitons pra soarem iguais.
                  final chordSemitones = _semitones + (originalCapo - effectiveCapo);
                  final displayTone = _transposeToneLabel(cifra.baseTone, _semitones);
                  return _CifraContent(
                    cifra: cifra,
                    chordSemitones: chordSemitones,
                    displayTone: displayTone,
                    displayCapo: effectiveCapo,
                    fontSize: _fontSize,
                  );
                },
              ),
            ),
            // Barra inferior compacta (29/08/2026, pedido do usuário) — Tom e
            // Capotraste numa linha só (antes eram duas), com o capotraste
            // no canto inferior esquerdo e o tom no direito. Borda superior
            // sutil separa visualmente a janela de leitura da cifra desta
            // barra de controles.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Controle de capotraste — só aparece quando a cifra de
                  // fato foi escrita com capo; se nunca teve, não há o que
                  // remover/alterar (28/08/2026, pedido do usuário).
                  if (originalCapo > 0)
                    InkWell(
                      onTap: () => _openCapoPicker(originalCapo, effectiveCapo),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Capo', style: TextStyle(color: context.textSecondary)),
                            const SizedBox(width: 6),
                            Text(
                              effectiveCapo == 0 ? 'Removido' : '${effectiveCapo}ª',
                              style: const TextStyle(
                                color: SibValColors.goldAccent,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tom', style: TextStyle(color: context.textSecondary)),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _setSemitones(_semitones - 1),
                      ),
                      InkWell(
                        onTap: baseTone.isEmpty ? null : () => _openTonePicker(baseTone),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Text(
                            // No lugar de "Original", o tom de verdade da
                            // música (28/08/2026, pedido do usuário) — só
                            // quando não transposta; deslocada por +/-,
                            // continua mostrando o delta.
                            _semitones == 0
                                ? (baseTone.isEmpty ? '—' : baseTone)
                                : (_semitones > 0 ? '+$_semitones' : '$_semitones'),
                            style: TextStyle(
                              color: baseTone.isEmpty
                                  ? context.textPrimary
                                  : SibValColors.goldAccent,
                              fontSize: 16,
                              decoration: baseTone.isEmpty ? null : TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _setSemitones(_semitones + 1),
                      ),
                      if (_semitones != 0)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _setSemitones(0),
                          child: const Text('Zerar'),
                        ),
                    ],
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
  const _CifraContent({
    required this.cifra,
    required this.chordSemitones,
    required this.displayTone,
    required this.displayCapo,
    required this.fontSize,
  });

  final Cifra cifra;

  /// Semitons aplicados aos acordes exibidos — soma o tom escolhido pelo
  /// usuário (`_semitones`) com a compensação de uma eventual troca de
  /// capotraste (28/08/2026). Não confundir com [displayTone], que reflete
  /// só o tom selecionado — trocar o capo não pode mudar o tom mostrado.
  final int chordSemitones;
  final String displayTone;
  final int displayCapo;
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
          text: transposeChord(match.group(1)!, chordSemitones),
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
      final transposed = transposeChordLine(line, chordSemitones);
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (cifra.baseTone.isNotEmpty || displayCapo > 0)
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
                if (displayCapo > 0)
                  Text(
                    'Capotraste: ${displayCapo}ª casa',
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
