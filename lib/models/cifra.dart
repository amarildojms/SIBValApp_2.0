import 'package:cloud_firestore/cloud_firestore.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Cifra (letra + acordes) de uma música — doc id = `songId`.
/// `content` é texto livre com acordes entre colchetes antes da
/// sílaba/palavra onde entram, ex.: `"[G]Digno é o [D]Senhor"` —
/// `chord_transpose.dart` sabe achar/transpor esses colchetes. `baseTone`/
/// `capo` são metadados de como a cifra foi escrita (pedido do usuário:
/// "poderemos alterar o tom das músicas, adicionar capotraste") — a
/// transposição de verdade acontece só na tela (`CifraViewPage`, botões +/-
/// client-side, não altera o documento); `capo` é só informativo (mostrado
/// na tela, não recalcula os acordes — capotraste muda o que se toca, não
/// o que se lê na cifra).
///
/// **Nem toda cifra vem do repertório mestre** (28/08/2026, pedido do
/// usuário: "deve ser possível incluir cifras além do que está no
/// repertório") — quando `songId` bate com o id de um `PraiseSong`
/// existente, a cifra fica "linkada" (nome/cantor vêm do catálogo, editáveis
/// só lá); quando não bate com nenhum, é uma cifra avulsa, com `songName`/
/// `songArtist` próprios, editáveis aqui mesmo (`songId`, nesse caso, é só
/// um id gerado pelo Firestore pra essa própria cifra, sem outro documento
/// associado).
class Cifra {
  final String id;
  final String songId;
  final String songName;
  final String songArtist;
  final String content;
  final String baseTone;
  final int capo;
  final String updatedByUid;
  final String updatedByName;
  final DateTime? updatedAt;

  const Cifra({
    required this.id,
    required this.songId,
    required this.songName,
    this.songArtist = '',
    this.content = '',
    this.baseTone = '',
    this.capo = 0,
    this.updatedByUid = '',
    this.updatedByName = '',
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'songId': songId,
    'songName': songName,
    'songArtist': songArtist,
    'content': content,
    'baseTone': baseTone,
    'capo': capo,
    'updatedByUid': updatedByUid,
    'updatedByName': updatedByName,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory Cifra.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Cifra(
      id: doc.id,
      songId: data['songId'] as String? ?? doc.id,
      songName: data['songName'] as String? ?? '',
      songArtist: data['songArtist'] as String? ?? '',
      content: data['content'] as String? ?? '',
      baseTone: data['baseTone'] as String? ?? '',
      capo: (data['capo'] as num?)?.toInt() ?? 0,
      updatedByUid: data['updatedByUid'] as String? ?? '',
      updatedByName: data['updatedByName'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
