import 'package:cloud_firestore/cloud_firestore.dart';

/// Nome de exibição do culto — o `theme` preenchido pelo dirigente, ou
/// "Culto" quando vazio (28/08/2026, pedido do usuário). Reaproveitado em
/// toda tela/notificação que hoje mostra a palavra "Culto" solta.
String serviceOrderDisplayName(ServiceOrder order) =>
    order.theme.isNotEmpty ? order.theme : 'Culto';

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

  /// Anotação livre do dirigente pro momento "Boas-vindas" (28/08/2026,
  /// pedido do usuário) — exibida logo abaixo desse momento (formulário,
  /// prévia, modo apresentação e as duas visões somente-leitura) só quando
  /// não vazia. Não é um "momento" em si — não entra em `momentOrder`, não é
  /// reordenável nem marcável como concluído, só um texto informativo fixo
  /// na posição de Boas-vindas.
  final String welcomeNotes;

  final List<BibleReference> bibleReadings;

  final String praise1;

  /// Mesma ideia de `welcomeNotes`, só que pro momento "Avisos/Comunicações"
  /// (28/08/2026, pedido do usuário — "implemente o campo anotações abaixo
  /// de avisos também com as mesmas funcionalidades").
  final String announcementsNotes;

  final String participation;

  final MissionMoment missionMoment;
  final String missionTheme;

  /// "Divisa" do Momento Missionário — era texto livre, virou seleção de
  /// texto(s) bíblico(s) (29/08/2026, pedido do usuário; pode ter mais de
  /// um, mesmo mecanismo de `bibleReadings`/`extraBibleReferences`). Sem
  /// backfill: ordens salvas antes desta mudança tinham `missionMotto`
  /// (`String`, campo removido) — esse texto livre antigo não é convertido
  /// automaticamente (não dá pra virar referência bíblica estruturada por
  /// conta própria); o dirigente precisa reeditar a ordem e selecionar de
  /// novo. Ver `ServiceOrderMissionMomentPage` (tela aberta ao tocar no
  /// momento) e `ServiceOrderItem.summary`.
  final List<BibleReference> missionMottoReferences;

  /// "Texto bíblico" da Dedicação dos dízimos e ofertas — era campo único
  /// (`BibleReference`), virou lista repetível (29/08/2026, pedido do
  /// usuário; mesmo mecanismo de `bibleReadings`/`missionMottoReferences`).
  /// `ServiceOrder.fromFirestore` cai pro campo antigo `tithesBibleReading`
  /// (singular) quando `tithesBibleReadings` não existe, pra não quebrar
  /// ordens salvas antes desta mudança.
  final List<BibleReference> tithesBibleReadings;
  final String congregationalHymn;

  final String praise2;
  final String intercessionModerator;
  final String message;
  final String communionResponsible;
  final String praise3;

  final PreludeStyle postludeStyle;
  final String postludeOther;

  /// Tema do culto (28/08/2026, pedido do usuário) — vazio por padrão;
  /// preenchido só em cultos especiais. Quando vazio, telas/notificações
  /// usam "Culto" no lugar (ver `serviceOrderDisplayName`).
  final String theme;

  final String ownerUid;
  final String ownerName;
  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;

  /// Marca quando o dirigente de fato tocou em "Iniciar Culto"
  /// (`ServiceOrderRepository.markStarted`, 28/08/2026, pedido do usuário) —
  /// separado do horário agendado (`dateTime`): a visão dos demais
  /// membros/visitantes (`ServiceOrderMemberViewPage`) fica travada num
  /// timer até este campo existir, mesmo que o relógio já tenha passado do
  /// horário. Fora de `toFieldsMap()`/`copyWith`, mesmo tratamento de
  /// `isFinalized`/`finalizedAt` — só `markStarted` escreve, pra uma edição
  /// normal nunca resetar.
  final DateTime? startedAt;
  bool get isStarted => startedAt != null;

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
    this.welcomeNotes = '',
    this.bibleReadings = const [],
    this.praise1 = 'Ministério Adorai',
    this.announcementsNotes = '',
    this.participation = '',
    this.missionMoment = MissionMoment.naoHavera,
    this.missionTheme = '',
    this.missionMottoReferences = const [],
    this.tithesBibleReadings = const [],
    this.congregationalHymn = '',
    this.praise2 = 'Ministério Adorai',
    this.intercessionModerator = 'Pr. Ronan',
    this.message = 'Pr. Ronan',
    this.communionResponsible = '',
    this.praise3 = 'Ministério Adorai',
    this.postludeStyle = PreludeStyle.instrumental,
    this.postludeOther = '',
    this.theme = '',
    this.ownerUid = '',
    this.ownerName = '',
    this.createdByUid = '',
    this.createdByName = '',
    this.createdAt,
    this.startedAt,
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
      welcomeNotes: welcomeNotes,
      bibleReadings: bibleReadings,
      praise1: praise1,
      announcementsNotes: announcementsNotes,
      participation: participation,
      missionMoment: missionMoment,
      missionTheme: missionTheme,
      missionMottoReferences: missionMottoReferences,
      tithesBibleReadings: tithesBibleReadings,
      congregationalHymn: congregationalHymn,
      praise2: praise2,
      intercessionModerator: intercessionModerator,
      message: message,
      communionResponsible: communionResponsible,
      praise3: praise3,
      postludeStyle: postludeStyle,
      postludeOther: postludeOther,
      theme: theme,
      ownerUid: ownerUid,
      ownerName: ownerName,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdAt: createdAt,
      startedAt: startedAt,
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
      'welcomeNotes': welcomeNotes,
      'bibleReadings': bibleReadings.map((r) => r.toMap()).toList(),
      'praise1': praise1,
      'announcementsNotes': announcementsNotes,
      'participation': participation,
      'missionMoment': missionMoment.name,
      'missionTheme': missionTheme,
      'missionMottoReferences': missionMottoReferences
          .map((r) => r.toMap())
          .toList(),
      'tithesBibleReadings': tithesBibleReadings.map((r) => r.toMap()).toList(),
      'congregationalHymn': congregationalHymn,
      'praise2': praise2,
      'intercessionModerator': intercessionModerator,
      'message': message,
      'communionResponsible': communionResponsible,
      'praise3': praise3,
      'postludeStyle': postludeStyle.name,
      'postludeOther': postludeOther,
      'theme': theme,
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
      welcomeNotes: data['welcomeNotes'] as String? ?? '',
      bibleReadings:
          (data['bibleReadings'] as List<dynamic>?)
              ?.map((e) => BibleReference.fromMap(e as Map<String, dynamic>?))
              .toList() ??
          const [],
      praise1: data['praise1'] as String? ?? '',
      announcementsNotes: data['announcementsNotes'] as String? ?? '',
      participation: data['participation'] as String? ?? '',
      missionMoment: MissionMoment.fromName(data['missionMoment'] as String?),
      missionTheme: data['missionTheme'] as String? ?? '',
      missionMottoReferences:
          (data['missionMottoReferences'] as List<dynamic>?)
              ?.map((e) => BibleReference.fromMap(e as Map<String, dynamic>?))
              .toList() ??
          const [],
      tithesBibleReadings:
          (data['tithesBibleReadings'] as List<dynamic>?)
              ?.map((e) => BibleReference.fromMap(e as Map<String, dynamic>?))
              .toList() ??
          [
            BibleReference.fromMap(
              data['tithesBibleReading'] as Map<String, dynamic>?,
            ),
          ].where((r) => r.isFilled).toList(),
      congregationalHymn: data['congregationalHymn'] as String? ?? '',
      praise2: data['praise2'] as String? ?? '',
      intercessionModerator: data['intercessionModerator'] as String? ?? '',
      message: data['message'] as String? ?? '',
      communionResponsible: data['communionResponsible'] as String? ?? '',
      praise3: data['praise3'] as String? ?? '',
      postludeStyle: PreludeStyle.fromName(data['postludeStyle'] as String?),
      postludeOther: data['postludeOther'] as String? ?? '',
      theme: data['theme'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
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
/// `gratitudePrayer` (Oração de Gratidão) tinha sido removido naquela
/// reordenação (o usuário só queria um momento de oração relacionado ali,
/// reaproveitando `childrenPrayer`) — reintroduzido em 29/08/2026, a pedido
/// do usuário, logo depois de `tithesOffering` ("Dedicação dos dízimos e
/// ofertas"). Cada valor aponta pros mesmos dados coletados em
/// `ServiceOrder` (ex.: `praise1`/`praise2`/`praise3` são três momentos
/// "Louvor" distintos, reordenáveis independentemente) — os itens sem campo
/// próprio (`welcome`/`announcements`/`gratitudePrayer`/`childrenPrayer`/
/// `apostolicBlessing`) só marcam a posição na sequência.
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
  gratitudePrayer,
  childrenPrayer,
  praise2,
  intercession,
  message,
  communion,
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
    ServiceOrderMomentType.gratitudePrayer => 'Oração de Gratidão',
    ServiceOrderMomentType.childrenPrayer => 'Oração pelas crianças',
    ServiceOrderMomentType.praise2 => 'Louvor',
    ServiceOrderMomentType.intercession => 'Momento de Intercessão',
    ServiceOrderMomentType.message => 'Mensagem',
    ServiceOrderMomentType.communion => 'Ceia do Senhor',
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

  /// Título exibido pro momento — sempre igual a [label] (05/09/2026,
  /// revisão: o usuário pediu de volta o título genérico "Momento
  /// Missionário", só acrescentando o que foi selecionado **abaixo**, no
  /// `summary()`, em vez de substituir o título). Mantido como método (em
  /// vez de virar `label` direto nos call sites) só pra não precisar tocar
  /// de novo nos 4 lugares que já passaram a chamar `labelFor(order)`.
  String labelFor(ServiceOrder order) => label;

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
      case ServiceOrderMomentType.gratitudePrayer:
      case ServiceOrderMomentType.childrenPrayer:
      case ServiceOrderMomentType.apostolicBlessing:
        return null;
      case ServiceOrderMomentType.participation:
        return order.participation.isEmpty ? null : order.participation;
      case ServiceOrderMomentType.missionMoment:
        // O título do momento continua genérico ("Momento Missionário") —
        // só o que foi selecionado ("Missões Mundiais"/"Nacionais"/
        // "Estaduais") aparece no resumo abaixo do título (05/09/2026,
        // pedido do usuário). Tema/divisa **não** entram mais aqui — quem
        // mostra isso é o link "Tema/Divisa" (sub-ação), sempre exibido
        // junto com este resumo, nunca no lugar dele (ver
        // `_MomentCard`/`_PraiseMomentCard`, que pararam de esconder o
        // resumo quando há sub-ação pra este tipo específico).
        if (order.missionMoment == MissionMoment.naoHavera) return null;
        return order.missionMoment.label;
      case ServiceOrderMomentType.tithesOffering:
        final refs = order.tithesBibleReadings
            .map((r) => r.reference)
            .whereType<String>()
            .join('; ');
        final parts = [
          if (refs.isNotEmpty) refs,
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
      case ServiceOrderMomentType.communion:
        return order.communionResponsible.isEmpty
            ? null
            : order.communionResponsible;
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
        'extraBibleReferences': extraBibleReferences
            .map((r) => r.toMap())
            .toList(),
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
          final singleRefMap =
              map['extraBibleReference'] as Map<String, dynamic>?;
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
/// de `Devotional`, reaproveitada aqui em toda lista repetível de texto
/// bíblico da Ordem de Culto: "Leitura bíblica", "Divisa" do Momento
/// Missionário e "Texto bíblico" da Dedicação dos dízimos e ofertas (lista
/// desde 29/08/2026, era campo único antes). `null`/vazio quando não
/// preenchido.
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
