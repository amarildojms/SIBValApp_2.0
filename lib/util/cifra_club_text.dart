/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário: "podemos implementar uma maneira mais prática de eu inserir as
/// cifras? Importando um arquivo algo assim?" + confirmação de que a
/// exibição também deveria virar o formato "Cifra Club": linha de acordes
/// solta em cima, linha de letra embaixo — não mais `[Acorde]palavra`
/// inline). Usado por `CifraEditorPage` (botão "Importar arquivo") e por
/// `CifraViewPage` (decide qual dos dois renderizadores usar).
library;

import 'chord_transpose.dart';

/// `true` se [line], depois de aparada, tiver pelo menos um token e TODOS
/// os tokens (separados por espaço) baterem com `isChordToken`
/// (`chord_transpose.dart`) — ou seja, a linha inteira é só acordes soltos,
/// sem nenhuma palavra de letra junto.
bool isChordLine(String line) {
  final tokens = line.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty || (tokens.length == 1 && tokens.first.isEmpty)) {
    return false;
  }
  return tokens.every(isChordToken);
}

/// Limpa o texto bruto de um arquivo .txt importado (típico de página de
/// cifra colada/exportada) pra só sobrar os pares "linha de acorde / linha
/// de letra": descarta tudo antes do primeiro par reconhecível (título,
/// artista, "Tom:", "Capotraste", "Afinação" — linhas de cabeçalho que
/// variam demais entre sites pra valer a pena listar uma por uma; mais
/// simples e confiável é cortar tudo que vem antes da primeira linha que já
/// parece 100% acordes) e colapsa 3+ linhas em branco seguidas pra 1. Não
/// mexe em transposição nem reparseia acorde nenhum — só limpeza
/// estrutural de texto; se nenhuma linha de acorde for encontrada, devolve
/// o texto original só com as linhas em branco colapsadas (não teria como
/// saber onde cortar o cabeçalho).
String cleanCifraClubText(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  final firstChordLineIndex = lines.indexWhere(isChordLine);
  final body = firstChordLineIndex == -1
      ? lines
      : lines.sublist(firstChordLineIndex);

  final collapsed = <String>[];
  for (final line in body) {
    final isBlank = line.trim().isEmpty;
    if (isBlank && collapsed.isNotEmpty && collapsed.last.trim().isEmpty) {
      continue;
    }
    collapsed.add(line);
  }
  while (collapsed.isNotEmpty && collapsed.first.trim().isEmpty) {
    collapsed.removeAt(0);
  }
  while (collapsed.isNotEmpty && collapsed.last.trim().isEmpty) {
    collapsed.removeLast();
  }
  return collapsed.join('\n');
}
