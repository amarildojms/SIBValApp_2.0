import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_order.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Uma música do repertório mensal (catálogo mestre do Ministério
/// de Louvor, `praiseSongs`) — "mensal" é só o nome da aba
/// (`PraiseMinistryPage`), não particiona por mês: é o catálogo de todas as
/// músicas que o ministério já usa, de onde o repertório semanal escolhe.
class PraiseSong {
  final String id;
  final String name;
  final String artist;

  const PraiseSong({required this.id, required this.name, this.artist = ''});

  factory PraiseSong.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PraiseSong(
      id: doc.id,
      name: data['name'] as String? ?? '',
      artist: data['artist'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'artist': artist};
}

/// "Momento" de Louvor pro qual uma música do repertório semanal foi
/// escalada — por padrão os três momentos "Louvor" fixos da liturgia
/// (`ServiceOrderMomentType.praise1/2/3`), mas o usuário pediu flexibilidade
/// pra "mais ou menos casos" — por isso é texto livre, com essas três opções
/// sugeridas + "Outro". `praiseSlotLabelFor` faz o casamento automático com
/// a Ordem de Culto (`ServiceOrderLivePage`).
const praiseSlotLabels = ['Louvor 1', 'Louvor 2', 'Louvor 3'];

/// `null` se [type] não for um dos três momentos "Louvor" fixos — momentos
/// especiais/outros não recebem música automática do repertório.
String? praiseSlotLabelFor(ServiceOrderMomentType type) => switch (type) {
  ServiceOrderMomentType.praise1 => praiseSlotLabels[0],
  ServiceOrderMomentType.praise2 => praiseSlotLabels[1],
  ServiceOrderMomentType.praise3 => praiseSlotLabels[2],
  _ => null,
};

/// As 12 notas cromáticas disponíveis no dropdown de tom (28/08/2026,
/// pedido do usuário — antes era texto livre) — grafia mista sustenido/bemol
/// (a mesma combinação mais comum em cifras em português); o usuário listou
/// 10 (faltavam Bb/B) — completadas aqui pra cobrir os 12 tons de verdade.
const praiseToneNotes = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'];

/// Uma música escalada pro repertório de uma semana específica — nome/artista
/// denormalizados de `PraiseSong` no momento da escala (não reagem a uma
/// renomeação posterior no catálogo mestre, igual a outros denormalizados já
/// usados nesta base, ex. `Post.authorName`). Tom (28/08/2026, pedido do
/// usuário) virou dropdown (`toneNote`, uma das `praiseToneNotes`) + check
/// "Menor" (`toneIsMinor`) em vez de texto livre — `toneDisplay` monta o
/// texto final (ex. "F#m") pra exibição/cifra.
class PraiseAssignment {
  final String songId;
  final String songName;
  final String songArtist;
  final String toneNote;
  final bool toneIsMinor;
  final String slotLabel;

  const PraiseAssignment({
    required this.songId,
    required this.songName,
    required this.songArtist,
    required this.toneNote,
    this.toneIsMinor = false,
    required this.slotLabel,
  });

  String get toneDisplay =>
      toneNote.isEmpty ? '' : (toneIsMinor ? '${toneNote}m' : toneNote);

  Map<String, dynamic> toMap() => {
    'songId': songId,
    'songName': songName,
    'songArtist': songArtist,
    'toneNote': toneNote,
    'toneIsMinor': toneIsMinor,
    'slotLabel': slotLabel,
  };

  factory PraiseAssignment.fromMap(Map<String, dynamic> map) {
    // Compatibilidade com o formato antigo (28/08/2026, texto livre `tone`,
    // ex. "F#m") — sem backfill, mesmo padrão já usado em outros campos
    // desta base: se não houver `toneNote` salvo, tenta separar o "m" final
    // do texto livre antigo.
    final legacyTone = map['tone'] as String?;
    String toneNote;
    bool toneIsMinor;
    if (map.containsKey('toneNote')) {
      toneNote = map['toneNote'] as String? ?? '';
      toneIsMinor = map['toneIsMinor'] as bool? ?? false;
    } else if (legacyTone != null && legacyTone.isNotEmpty) {
      toneIsMinor = legacyTone.endsWith('m');
      toneNote = toneIsMinor
          ? legacyTone.substring(0, legacyTone.length - 1)
          : legacyTone;
    } else {
      toneNote = '';
      toneIsMinor = false;
    }
    return PraiseAssignment(
      songId: map['songId'] as String? ?? '',
      songName: map['songName'] as String? ?? '',
      songArtist: map['songArtist'] as String? ?? '',
      toneNote: toneNote,
      toneIsMinor: toneIsMinor,
      slotLabel: map['slotLabel'] as String? ?? '',
    );
  }
}

/// Repertório de uma semana específica (`weeklyRepertoires/{weekKey}`, doc id
/// = `weekKeyFor(date)` — a data do domingo daquela semana, formato
/// `yyyy-MM-dd`, ver `PraiseRepertoireRepository`) — as músicas escaladas
/// (`assignments`) e os links de playlist (`links`, YouTube/Spotify/etc.,
/// múltiplos). `ServiceOrderLivePage` busca por essa chave a partir de
/// `ServiceOrder.dateTime` pra preencher os momentos "Louvor" automaticamente.
class WeeklyRepertoire {
  final String id;
  final DateTime weekDate;
  final List<PraiseAssignment> assignments;
  final List<String> links;

  const WeeklyRepertoire({
    required this.id,
    required this.weekDate,
    this.assignments = const [],
    this.links = const [],
  });

  List<PraiseAssignment> forSlot(String slotLabel) =>
      assignments.where((a) => a.slotLabel == slotLabel).toList();

  Map<String, dynamic> toMap() => {
    'weekDateMillis': weekDate.millisecondsSinceEpoch,
    'assignments': assignments.map((a) => a.toMap()).toList(),
    'links': links,
  };

  factory WeeklyRepertoire.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WeeklyRepertoire(
      id: doc.id,
      weekDate: DateTime.fromMillisecondsSinceEpoch(
        (data['weekDateMillis'] as num?)?.toInt() ?? 0,
      ),
      assignments:
          (data['assignments'] as List<dynamic>?)
              ?.map((e) => PraiseAssignment.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      links: (data['links'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}
