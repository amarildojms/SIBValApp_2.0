/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário: "na cifra poderemos alterar o tom das músicas"). Transposição
/// de acordes por semitom — usada por `CifraViewPage` pros botões +/- de
/// tom, client-side (não altera o `Cifra.content` salvo).
library;

const _sharpScale = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
const _flatScale = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

/// Encontra os acordes entre colchetes num texto de cifra (ex.:
/// `"[G]Digno é o [D]Senhor"`).
final RegExp chordBracketPattern = RegExp(r'\[([^\]]+)\]');

/// Rótulos que não são acorde (ex. "{Introdução}", "{Refrão}") — chaves em
/// vez de colchetes de propósito (29/08/2026, pedido do usuário). Um rótulo
/// como "Coro" começando com letra de nota (A-G) dentro de colchetes seria
/// mal interpretado como acorde por `chordBracketPattern`/`isChordToken` e
/// corrompido na transposição (ex. "[Coro]" virava "[C#oro]" ao subir 1
/// semitom) — chaves nunca colidem com a sintaxe de acorde, então
/// `CifraViewPage` só destaca visualmente o texto dentro, sem transpor nada.
final RegExp sectionLabelPattern = RegExp(r'\{([^}]+)\}');

/// `true` se [line] (depois de aparada) for inteiramente um rótulo entre
/// chaves, ex. `"{Refrão}"` — usado por `CifraViewPage` no formato "Cifra
/// Club" de duas linhas pra estilizar a linha inteira como destaque, em vez
/// de tratá-la como letra normal.
bool isSectionLabelLine(String line) {
  final trimmed = line.trim();
  return trimmed.length > 1 && trimmed.startsWith('{') && trimmed.endsWith('}');
}

/// Índice cromático (0-11) de [note] (ex. "F#", "Db") na escala — `null` se
/// não reconhecida. Usado por `CifraViewPage` (28/08/2026, pedido do
/// usuário: "implementar a possibilidade de selecionar o tom") pra calcular
/// quantos semitons faltam entre o tom original salvo e o tom escolhido
/// direto numa lista, em vez de só subir/descer um semitom por vez.
int? noteIndex(String note) {
  final sharpIndex = _sharpScale.indexOf(note);
  if (sharpIndex != -1) return sharpIndex;
  final flatIndex = _flatScale.indexOf(note);
  return flatIndex != -1 ? flatIndex : null;
}

/// Desloca a nota fundamental de [note] (ex. "F#", "Db") em [semitones] —
/// mantém a grafia bemol/sustenido igual ao original; devolve [note] sem
/// alteração se não reconhecer a nota.
String shiftNote(String note, int semitones) {
  var index = _sharpScale.indexOf(note);
  var useFlat = false;
  if (index == -1) {
    index = _flatScale.indexOf(note);
    useFlat = index != -1;
  }
  if (index == -1) return note;
  final shifted = ((index + semitones) % 12 + 12) % 12;
  return useFlat ? _flatScale[shifted] : _sharpScale[shifted];
}

/// Transpõe um acorde inteiro (ex. "F#m7", "D/F#", "Csus4") por
/// [semitones] — reconhece a nota fundamental (`A`-`G` + `#`/`b` opcional)
/// no início e, se houver, o baixo depois de "/", deslocando as duas.
/// O sufixo (m, 7, sus4...) não é tocado.
String transposeChord(String chord, int semitones) {
  if (semitones == 0) return chord;
  final match = RegExp(r'^([A-G][#b]?)(.*)$').firstMatch(chord);
  if (match == null) return chord;
  final root = match.group(1)!;
  final rest = match.group(2)!;
  final newRoot = shiftNote(root, semitones);

  final slash = RegExp(r'^(.*)/([A-G][#b]?)$').firstMatch(rest);
  if (slash != null) {
    final suffix = slash.group(1)!;
    final bass = slash.group(2)!;
    return '$newRoot$suffix/${shiftNote(bass, semitones)}';
  }
  return '$newRoot$rest';
}

/// Transpõe todos os acordes entre colchetes de [content] por [semitones] —
/// o resto do texto (letra) fica intacto.
String transposeContent(String content, int semitones) {
  if (semitones == 0) return content;
  return content.replaceAllMapped(
    chordBracketPattern,
    (m) => '[${transposeChord(m.group(1)!, semitones)}]',
  );
}

/// Sufixos de acorde reconhecidos (repetíveis/combináveis) — lista
/// deliberadamente ampla, mas não exaustiva; é uma heurística
/// (`isChordToken`/`isChordLine`), não um parser musical completo. Palavras
/// de letra que por acaso começam com A-G (ex. "Amor", "Deus") não batem
/// porque o restante do token não se encaixa em nenhuma combinação destes
/// sufixos.
final RegExp _chordSuffixPattern = RegExp(
  r'^(maj7|maj9|maj13|dim7|dim|aug|sus2|sus4|sus|add2|add4|add9|add11|add13|'
  r'm7b5|mM7|m7|m9|m11|m13|m6|M7|M9|m|M|6\/9|6|7|9|11|13|\+|°|º)*$',
);

/// `true` se [token] (uma "palavra" isolada, sem espaço) tem cara de acorde
/// — nota fundamental (`A`-`G`) + acidente opcional + sufixo reconhecido
/// (`_chordSuffixPattern`) + baixo opcional depois de `/`. Base de
/// `isChordLine`/`cleanCifraClubText` (`cifra_club_text.dart`) e de
/// `transposeChordLine` — mais rígido que o `RegExp` usado dentro de
/// `transposeChord` (que só olha a raiz, porque ali o token já veio de
/// dentro de colchetes, sabidamente um acorde).
bool isChordToken(String token) {
  if (token.isEmpty) return false;
  final match = RegExp(r'^([A-G])([#b]?)(.*)$').firstMatch(token);
  if (match == null) return false;
  final rest = match.group(3)!;
  final slashIndex = rest.indexOf('/');
  if (slashIndex == -1) return _chordSuffixPattern.hasMatch(rest);
  final suffix = rest.substring(0, slashIndex);
  final bass = rest.substring(slashIndex + 1);
  if (!RegExp(r'^[A-G][#b]?$').hasMatch(bass)) return false;
  return _chordSuffixPattern.hasMatch(suffix);
}

/// Transpõe todos os acordes de uma "linha de acordes" no formato Cifra
/// Club (acordes soltos separados por espaço, numa linha acima da letra —
/// ver `cifra_club_text.dart`) por [semitones]. Como o novo nome de um
/// acorde pode ter comprimento diferente do antigo (ex. "C" → "C#"), a
/// diferença é absorvida no espaço em branco logo DEPOIS do token (nunca
/// menos de 1 espaço quando já havia espaço ali) — mantém razoavelmente
/// alinhada a coluna dos acordes seguintes/a letra embaixo. Tokens que não
/// são acorde (ex. "|", "%") atravessam sem alteração.
String transposeChordLine(String line, int semitones) {
  if (semitones == 0) return line;
  final buffer = StringBuffer();
  var i = 0;
  while (i < line.length) {
    if (line[i] == ' ') {
      var j = i;
      while (j < line.length && line[j] == ' ') {
        j++;
      }
      buffer.write(line.substring(i, j));
      i = j;
      continue;
    }
    var j = i;
    while (j < line.length && line[j] != ' ') {
      j++;
    }
    final token = line.substring(i, j);
    i = j;
    if (!isChordToken(token)) {
      buffer.write(token);
      continue;
    }
    final transposed = transposeChord(token, semitones);
    buffer.write(transposed);
    final delta = transposed.length - token.length;
    if (delta == 0) continue;
    var k = i;
    while (k < line.length && line[k] == ' ') {
      k++;
    }
    final spaceCount = k - i;
    if (spaceCount > 0) {
      final newCount = (spaceCount - delta).clamp(1, spaceCount + 20);
      buffer.write(' ' * newCount);
      i = k;
    }
  }
  return buffer.toString();
}
