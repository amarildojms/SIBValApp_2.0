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
