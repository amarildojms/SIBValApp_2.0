import 'package:cloud_firestore/cloud_firestore.dart';

/// Sem equivalente no app nativo — feature nova (27/08/2026, pedido do
/// usuário). Ordem de culto semanal: sequência fixa de itens de liturgia,
/// alguns configuráveis (com valor padrão) e outros só um marcador de posição
/// sem dado próprio (Boas-vindas, Avisos/Comunicações, Oração pelas
/// crianças, Dedicação dos dízimos e ofertas, Oração de gratidão, Benção
/// Apostólica — sem campo no model, exibidos como texto fixo na tela).
///
/// `ownerUid`/`ownerName`: dono atual da ordem — só ele (ou admin) pode
/// editar/excluir (ver `firestore.rules` nativo, `isDirigentes() &&
/// resource.data.ownerUid == request.auth.uid`). Nasce igual a
/// `createdByUid`/`createdByName` na criação; a transferência de
/// propriedade (admin passa a ordem para outro dirigente) é feature futura,
/// ainda não implementada nesta tela — o campo já existe no model pra não
/// exigir migração depois.
class ServiceOrder {
  final String id;
  final DateTime dateTime;

  final PreludeStyle preludeStyle;
  final String preludeOther;

  final String prayerText;

  final List<BibleReference> bibleReadings;

  final String praise1;

  final String participation;

  final MissionMoment missionMoment;
  final String missionTheme;
  final String missionMotto;

  final BibleReference tithesBibleReading;
  final String congregationalHymn;

  final String praise2;
  final String intercessionModerator;
  final String message;
  final String praise3;

  final PreludeStyle postludeStyle;
  final String postludeOther;

  final String ownerUid;
  final String ownerName;
  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;

  /// Ordem dos momentos escolhida pelo dirigente na 2ª etapa do cadastro
  /// (`ServiceOrderReorderPage`, arrastar pra cima/baixo) — ponto de partida
  /// é a liturgia padrão (`ServiceOrderMomentType.values`, com os momentos
  /// vazios/"Não haverá" já excluídos), mas o dirigente pode reordenar,
  /// remover momentos extras adicionados e adicionar momentos do catálogo
  /// (`ServiceOrderExtraMomentOption`) antes de salvar.
  final List<ServiceOrderItem> momentOrder;

  /// Progresso do modo apresentação (`ServiceOrderLivePage`, 28/08/2026,
  /// pedido do usuário: "ao voltar deve continuar do último momento que ele
  /// marcou"). Cada chave é `"$index"` (momento simples, no índice de
  /// `momentOrder`) ou `"$index:$subKey"` pra sub-itens de um momento com
  /// leitura própria (ex. `"3:bible0"` pra primeira referência de "Leitura
  /// bíblica" no índice 3, `"7:tithesBible"`/`"7:tithesHymn"` pras
  /// subcategorias de "Dedicação dos dízimos e ofertas" no índice 7). Não
  /// entra em `toFieldsMap()`/`copyWith` — só `ServiceOrderRepository.
  /// updateProgress`/`finalize` escrevem esses três campos, pra uma edição
  /// normal (`update`) nunca resetar o progresso já feito.
  final List<String> completedMomentKeys;
  final bool isFinalized;
  final DateTime? finalizedAt;

  const ServiceOrder({
    required this.id,
    required this.dateTime,
    this.preludeStyle = PreludeStyle.instrumental,
    this.preludeOther = '',
    this.prayerText = 'Dirigente',
    this.bibleReadings = const [],
    this.praise1 = 'Ministério Adorai',
    this.participation = '',
    this.missionMoment = MissionMoment.naoHavera,
    this.missionTheme = '',
    this.missionMotto = '',
    this.tithesBibleReading = const BibleReference(),
    this.congregationalHymn = '',
    this.praise2 = 'Ministério Adorai',
    this.intercessionModerator = 'Pr. Ronan',
    this.message = 'Pr. Ronan',
    this.praise3 = 'Ministério Adorai',
    this.postludeStyle = PreludeStyle.instrumental,
    this.postludeOther = '',
    this.ownerUid = '',
    this.ownerName = '',
    this.createdByUid = '',
    this.createdByName = '',
    this.createdAt,
    this.momentOrder = const [],
    this.completedMomentKeys = const [],
    this.isFinalized = false,
    this.finalizedAt,
  });

  /// Cópia com `momentOrder` substituído — usado por
  /// `ServiceOrderReorderPage._save` (28/08/2026) pra ir do "rascunho" (que
  /// só carrega os momentos extras escolhidos na 1ª etapa) pra ordem final
  /// completa (fixos + extras, na sequência escolhida ao arrastar).
  ServiceOrder copyWith({List<ServiceOrderItem>? momentOrder}) {
    return ServiceOrder(
      id: id,
      dateTime: dateTime,
      preludeStyle: preludeStyle,
      preludeOther: preludeOther,
      prayerText: prayerText,
      bibleReadings: bibleReadings,
      praise1: praise1,
      participation: participation,
      missionMoment: missionMoment,
      missionTheme: missionTheme,
      missionMotto: missionMotto,
      tithesBibleReading: tithesBibleReading,
      congregationalHymn: congregationalHymn,
      praise2: praise2,
      intercessionModerator: intercessionModerator,
      message: message,
      praise3: praise3,
      postludeStyle: postludeStyle,
      postludeOther: postludeOther,
      ownerUid: ownerUid,
      ownerName: ownerName,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdAt: createdAt,
      momentOrder: momentOrder ?? this.momentOrder,
      completedMomentKeys: completedMomentKeys,
      isFinalized: isFinalized,
      finalizedAt: finalizedAt,
    );
  }

  /// Todos os campos editáveis, no formato gravado no Firestore — reaproveitado
  /// por `ServiceOrderRepository.create`/`update` (28/08/2026) pra não
  /// duplicar a serialização nos dois métodos.
  Map<String, dynamic> toFieldsMap() {
    return {
      'dateTimeMillis': dateTime.millisecondsSinceEpoch,
      'preludeStyle': preludeStyle.name,
      'preludeOther': preludeOther,
      'prayerText': prayerText,
      'bibleReadings': bibleReadings.map((r) => r.toMap()).toList(),
      'praise1': praise1,
      'participation': participation,
      'missionMoment': missionMoment.name,
      'missionTheme': missionTheme,
      'missionMotto': missionMotto,
      'tithesBibleReading': tithesBibleReading.toMap(),
      'congregationalHymn': congregationalHymn,
      'praise2': praise2,
      'intercessionModerator': intercessionModerator,
      'message': message,
      'praise3': praise3,
      'postludeStyle': postludeStyle.name,
      'postludeOther': postludeOther,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'momentOrder': momentOrder.map((m) => m.toMap()).toList(),
    };
  }

  factory ServiceOrder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ServiceOrder(
      id: doc.id,
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        (data['dateTimeMillis'] as num?)?.toInt() ?? 0,
      ),
      preludeStyle: PreludeStyle.fromName(data['preludeStyle'] as String?),
      preludeOther: data['preludeOther'] as String? ?? '',
      prayerText: data['prayerText'] as String? ?? '',
      bibleReadings:
          (data['bibleReadings'] as List<dynamic>?)
              ?.map((e) => BibleReference.fromMap(e as Map<String, dynamic>?))
              .toList() ??
          const [],
      praise1: data['praise1'] as String? ?? '',
      participation: data['participation'] as String? ?? '',
      missionMoment: MissionMoment.fromName(data['missionMoment'] as String?),
      missionTheme: data['missionTheme'] as String? ?? '',
      missionMotto: data['missionMotto'] as String? ?? '',
      tithesBibleReading: BibleReference.fromMap(
        data['tithesBibleReading'] as Map<String, dynamic>?,
      ),
      congregationalHymn: data['congregationalHymn'] as String? ?? '',
      praise2: data['praise2'] as String? ?? '',
      intercessionModerator: data['intercessionModerator'] as String? ?? '',
      message: data['message'] as String? ?? '',
      praise3: data['praise3'] as String? ?? '',
      postludeStyle: PreludeStyle.fromName(data['postludeStyle'] as String?),
      postludeOther: data['postludeOther'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      momentOrder:
          (data['momentOrder'] as List<dynamic>?)
              ?.map(ServiceOrderItem.fromDynamic)
              .whereType<ServiceOrderItem>()
              .toList() ??
          const [],
      completedMomentKeys:
          (data['completedMomentKeys'] as List<dynamic>?)?.cast<String>() ??
          const [],
      isFinalized: data['isFinalized'] as bool? ?? false,
      finalizedAt: (data['finalizedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Um "momento" fixo da liturgia padrão, na ordem original pedida pelo
/// usuário (mesma ordem de declaração do enum, reordenada em 28/08/2026 —
/// ver `[[feedback_flutter_migration_style]]` na memória automática pra
/// contexto de por que este arquivo documenta cada decisão de negócio).
/// `gratitudePrayer` (Oração de gratidão) foi removido nesta reordenação —
/// o usuário passou a pedir só um momento de oração relacionado nessa
/// posição, e reaproveitou `childrenPrayer` movido pra lá em vez de manter
/// os dois. Cada valor aponta pros mesmos dados coletados em `ServiceOrder`
/// (ex.: `praise1`/`praise2`/`praise3` são três momentos "Louvor" distintos,
/// reordenáveis independentemente) — os itens sem campo próprio
/// (`welcome`/`announcements`/`childrenPrayer`/`apostolicBlessing`) só
/// marcam a posição na sequência.
enum ServiceOrderMomentType {
  prelude,
  prayer,
  bibleReading,
  praise1,
  welcome,
  announcements,
  participation,
  missionMoment,
  tithesOffering,
  childrenPrayer,
  praise2,
  intercession,
  message,
  praise3,
  apostolicBlessing,
  postlude;

  static ServiceOrderMomentType? fromName(String value) {
    for (final type in ServiceOrderMomentType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  String get label => switch (this) {
    ServiceOrderMomentType.prelude => 'Prelúdio',
    ServiceOrderMomentType.prayer => 'Oração',
    ServiceOrderMomentType.bibleReading => 'Leitura bíblica',
    ServiceOrderMomentType.praise1 => 'Louvor',
    ServiceOrderMomentType.welcome => 'Boas-vindas',
    ServiceOrderMomentType.announcements => 'Avisos/Comunicações',
    ServiceOrderMomentType.participation => 'Participação Especial',
    ServiceOrderMomentType.missionMoment => 'Momento Missionário',
    ServiceOrderMomentType.tithesOffering => 'Dedicação dos dízimos e ofertas',
    ServiceOrderMomentType.childrenPrayer => 'Oração pelas crianças',
    ServiceOrderMomentType.praise2 => 'Louvor',
    ServiceOrderMomentType.intercession => 'Momento de Intercessão',
    ServiceOrderMomentType.message => 'Mensagem',
    ServiceOrderMomentType.praise3 => 'Louvor',
    ServiceOrderMomentType.apostolicBlessing => 'Benção Apostólica',
    ServiceOrderMomentType.postlude => 'Poslúdio',
  };
}

/// Um item da ordem final montada em `ServiceOrderReorderPage` — ou um
/// momento fixo da liturgia padrão (`type` != null) ou um momento extra
/// escolhido do catálogo administrável (28/08/2026, pedido do usuário; ver
/// `ServiceOrderExtraMomentOption`), tipo Batismo/Ceia do Senhor/
/// Apresentação de bebê. Nunca os dois ao mesmo tempo. `instanceId` só
/// existe em memória (não é persistido) — dá identidade estável pra
/// `ReorderableListView` mesmo quando dois momentos extras iguais são
/// adicionados duas vezes.
class ServiceOrderItem {
  final ServiceOrderMomentType? type;
  final String? extraMomentId;
  final String? extraMomentName;
  final Object instanceId;

  /// Dado preenchido pelo dirigente ao escolher um momento adicional com
  /// `ExtraMomentFieldKind.name`/`.names` (28/08/2026, pedido do usuário) —
  /// um elemento pro caso "um nome" (ex. recém-nascido), vários pro caso
  /// "vários nomes" (ex. batizandos). Vazio pros demais casos.
  final List<String> extraNames;

  /// Textos bíblicos preenchidos pelo dirigente pra um momento adicional com
  /// `ExtraMomentFieldKind.bibleReference` (ex.: "Ceia do Senhor" — pedido
  /// do usuário: "parecido com os dízimos e ofertas") — pode ter mais de um
  /// (28/08/2026, pedido do usuário), cada um vira uma subcategoria própria
  /// em `ServiceOrderLivePage` (mesmo mecanismo de "Leitura bíblica" com
  /// várias referências) — abre a leitura de verdade, só marca concluído ao
  /// voltar. Vazio se não se aplica ou nada foi preenchido.
  final List<BibleReference> extraBibleReferences;

  ServiceOrderItem.fixed(ServiceOrderMomentType type)
    : this._(
        type: type,
        extraMomentId: null,
        extraMomentName: null,
        extraNames: const [],
        extraBibleReferences: const [],
      );

  ServiceOrderItem.extra(
    String id,
    String name, {
    List<String> extraNames = const [],
    List<BibleReference> extraBibleReferences = const [],
  }) : this._(
         type: null,
         extraMomentId: id,
         extraMomentName: name,
         extraNames: extraNames,
         extraBibleReferences: extraBibleReferences,
       );

  ServiceOrderItem._({
    required this.type,
    required this.extraMomentId,
    required this.extraMomentName,
    required this.extraNames,
    required this.extraBibleReferences,
  }) : instanceId = Object();

  bool get isExtra => type == null;

  String get label => type?.label ?? extraMomentName ?? '';

  /// Texto curto abaixo do rótulo do momento (ex.: pra distinguir os três
  /// "Louvor" entre si, ou mostrar o nome/texto bíblico preenchido num
  /// momento adicional) — `null` pros itens fixos sem dado próprio e pros
  /// momentos adicionais sem nenhum campo preenchido. Reaproveitado por
  /// `ServiceOrderReorderPage`, `ServiceOrderPrecheckPage` e
  /// `ServiceOrderLivePage`.
  String? summary(ServiceOrder order) {
    final momentType = type;
    if (momentType == null) {
      final refs = extraBibleReferences
          .where((r) => r.isFilled)
          .map((r) => r.reference)
          .whereType<String>()
          .toList();
      if (refs.isNotEmpty) return refs.join('; ');
      if (extraNames.isNotEmpty) return extraNames.join(', ');
      return null;
    }
    switch (momentType) {
      case ServiceOrderMomentType.prelude:
        return order.preludeStyle == PreludeStyle.outro
            ? order.preludeOther
            : order.preludeStyle.label;
      case ServiceOrderMomentType.prayer:
        return order.prayerText.isEmpty ? null : order.prayerText;
      case ServiceOrderMomentType.bibleReading:
        final refs = order.bibleReadings
            .map((r) => r.reference)
            .whereType<String>()
            .toList();
        return refs.isEmpty ? null : refs.join('; ');
      case ServiceOrderMomentType.praise1:
        return order.praise1.isEmpty ? null : order.praise1;
      case ServiceOrderMomentType.welcome:
      case ServiceOrderMomentType.announcements:
      case ServiceOrderMomentType.childrenPrayer:
      case ServiceOrderMomentType.apostolicBlessing:
        return null;
      case ServiceOrderMomentType.participation:
        return order.participation.isEmpty ? null : order.participation;
      case ServiceOrderMomentType.missionMoment:
        if (order.missionMoment == MissionMoment.naoHavera) return null;
        return '${order.missionMoment.label} — ${order.missionTheme}';
      case ServiceOrderMomentType.tithesOffering:
        final parts = [
          if (order.tithesBibleReading.reference != null)
            order.tithesBibleReading.reference!,
          if (order.congregationalHymn.isNotEmpty) order.congregationalHymn,
        ];
        return parts.isEmpty ? null : parts.join(' · ');
      case ServiceOrderMomentType.praise2:
        return order.praise2.isEmpty ? null : order.praise2;
      case ServiceOrderMomentType.intercession:
        return order.intercessionModerator.isEmpty
            ? null
            : order.intercessionModerator;
      case ServiceOrderMomentType.message:
        return order.message.isEmpty ? null : order.message;
      case ServiceOrderMomentType.praise3:
        return order.praise3.isEmpty ? null : order.praise3;
      case ServiceOrderMomentType.postlude:
        return order.postludeStyle == PreludeStyle.outro
            ? order.postludeOther
            : order.postludeStyle.label;
    }
  }

  Map<String, dynamic> toMap() {
    if (type != null) return {'kind': 'fixed', 'type': type!.name};
    return {
      'kind': 'extra',
      'id': extraMomentId,
      'name': extraMomentName,
      if (extraNames.isNotEmpty) 'extraNames': extraNames,
      if (extraBibleReferences.isNotEmpty)
        'extraBibleReferences': extraBibleReferences.map((r) => r.toMap()).toList(),
    };
  }

  /// Aceita tanto o formato antigo (`String` com o nome do enum, gravado
  /// antes desta feature) quanto o novo (`Map`) — sem backfill, mesmo padrão
  /// já usado em outros campos desta base (ver `Devotional.baseVerse`).
  /// `extraBibleReferences` também aceita a chave antiga `extraBibleReference`
  /// (singular, um `Map` só — gravada antes do texto bíblico virar lista,
  /// 28/08/2026), envolvendo num array de 1 item.
  static ServiceOrderItem? fromDynamic(dynamic value) {
    if (value is String) {
      final type = ServiceOrderMomentType.fromName(value);
      return type != null ? ServiceOrderItem.fixed(type) : null;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      if (map['kind'] == 'extra') {
        final id = map['id'] as String?;
        final name = map['name'] as String?;
        if (id == null || name == null) return null;
        List<BibleReference> bibleRefs;
        final refsList = map['extraBibleReferences'] as List<dynamic>?;
        if (refsList != null) {
          bibleRefs = refsList
              .map((e) => BibleReference.fromMap(e as Map<String, dynamic>?))
              .toList();
        } else {
          final singleRefMap = map['extraBibleReference'] as Map<String, dynamic>?;
          bibleRefs = singleRefMap != null
              ? [BibleReference.fromMap(singleRefMap)]
              : const [];
        }
        return ServiceOrderItem.extra(
          id,
          name,
          extraNames:
              (map['extraNames'] as List<dynamic>?)?.cast<String>() ?? const [],
          extraBibleReferences: bibleRefs,
        );
      }
      final type = ServiceOrderMomentType.fromName(
        map['type'] as String? ?? '',
      );
      return type != null ? ServiceOrderItem.fixed(type) : null;
    }
    return null;
  }
}

/// Estilo de Prelúdio/Poslúdio. `naoHavera` (28/08/2026, pedido do usuário)
/// só se aplica ao Prelúdio — é o valor padrão lá, e faz o momento sair da
/// ordem inteiramente (ver `ServiceOrderReorderPage._buildDefaultOrder`); o
/// dropdown do Poslúdio continua só com as três opções originais
/// (`ServiceOrderFormPage`, `postludeStyleOptions`), sem essa quarta opção —
/// não foi pedido lá.
enum PreludeStyle {
  instrumental,
  ministerioAdorai,
  outro,
  naoHavera;

  static PreludeStyle fromName(String? value) => PreludeStyle.values.firstWhere(
    (e) => e.name == value,
    orElse: () => PreludeStyle.instrumental,
  );

  String get label => switch (this) {
    PreludeStyle.instrumental => 'Instrumental',
    PreludeStyle.ministerioAdorai => 'Ministério Adorai',
    PreludeStyle.outro => 'Outro',
    PreludeStyle.naoHavera => 'Não haverá',
  };
}

/// Momento Missionário — "Não haverá" é o valor padrão; qualquer outro abre
/// os campos Tema/Divisa na tela.
enum MissionMoment {
  missoesMundiais,
  missoesNacionais,
  missoesEstaduais,
  naoHavera;

  static MissionMoment fromName(String? value) =>
      MissionMoment.values.firstWhere(
        (e) => e.name == value,
        orElse: () => MissionMoment.naoHavera,
      );

  String get label => switch (this) {
    MissionMoment.missoesMundiais => 'Missões Mundiais',
    MissionMoment.missoesNacionais => 'Missões Nacionais',
    MissionMoment.missoesEstaduais => 'Missões Estaduais',
    MissionMoment.naoHavera => 'Não haverá',
  };
}

/// Livro/capítulo/versículo (faixa opcional) — mesma lógica do "Texto base"
/// de `Devotional`, reaproveitada aqui pra "Leitura bíblica" (lista, pode ter
/// mais de uma) e pro "Texto bíblico" da Dedicação dos dízimos e ofertas
/// (campo único). `null`/vazio quando não preenchido.
class BibleReference {
  final int? bookId;
  final String bookName;
  final int? chapter;
  final int? verseStart;
  final int? verseEnd;

  const BibleReference({
    this.bookId,
    this.bookName = '',
    this.chapter,
    this.verseStart,
    this.verseEnd,
  });

  bool get isFilled =>
      bookName.isNotEmpty && chapter != null && verseStart != null;

  /// "Livro capítulo:versículo" ou "Livro capítulo:início-fim" — `null` se
  /// não preenchido.
  String? get reference {
    if (!isFilled) return null;
    final end = verseEnd;
    final versePart = (end != null && end != verseStart)
        ? '$verseStart-$end'
        : '$verseStart';
    return '$bookName $chapter:$versePart';
  }

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'bookName': bookName,
      'chapter': chapter,
      'verseStart': verseStart,
      'verseEnd': verseEnd,
    };
  }

  factory BibleReference.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BibleReference();
    return BibleReference(
      bookId: (map['bookId'] as num?)?.toInt(),
      bookName: map['bookName'] as String? ?? '',
      chapter: (map['chapter'] as num?)?.toInt(),
      verseStart: (map['verseStart'] as num?)?.toInt(),
      verseEnd: (map['verseEnd'] as num?)?.toInt(),
    );
  }
}
