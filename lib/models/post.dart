import 'package:cloud_firestore/cloud_firestore.dart';

import 'event.dart' show toSaoPauloTime, toSaoPauloTimeNow;

/// Espelha app/src/main/java/com/sibval/app/data/model/Post.kt — mesma coleção
/// `posts` no Firestore, criada tanto pelo app quanto pelas Cloud Functions
/// (posts automáticos de devocional, evento e aniversário).
///
/// `eventDateTimeMillis` vem direto do documento (gravado pela Cloud Function
/// que cria/reposta o post de evento) — permite ao card saber se o evento já
/// passou (selo "Finalizado") sem precisar buscar o evento à parte a cada
/// atualização do feed em tempo real.
class Post {
  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final String imageUrl;
  final String storagePath;
  final DateTime? createdAt;
  final List<String> likedBy;
  final int commentCount;
  final String postType;
  final String targetId;
  final int? eventDateTimeMillis;
  final bool isRecurringEvent;

  const Post({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.imageUrl,
    required this.storagePath,
    required this.createdAt,
    required this.likedBy,
    required this.commentCount,
    required this.postType,
    required this.targetId,
    this.eventDateTimeMillis,
    this.isRecurringEvent = false,
  });

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Post(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      likedBy: List<String>.from(data['likedBy'] as List? ?? const []),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      postType: data['postType'] as String? ?? PostType.manual,
      targetId: data['targetId'] as String? ?? '',
      eventDateTimeMillis: (data['eventDateTimeMillis'] as num?)?.toInt(),
      isRecurringEvent: data['isRecurring'] as bool? ?? false,
    );
  }

  DateTime? get eventDateSaoPaulo => eventDateTimeMillis != null
      ? toSaoPauloTime(
          DateTime.fromMillisecondsSinceEpoch(
            eventDateTimeMillis!,
            isUtc: true,
          ),
        )
      : null;

  /// Verdadeiro assim que chega o horário de início do evento (fuso
  /// America/Sao_Paulo) — alimenta o selo "Iniciado às HH:mm" em
  /// `post_card.dart` (29/08/2026, pedido do usuário; mesmo critério de
  /// `Event.hasStarted`). Fica `true` até ser suplantado por [isPastEvent]
  /// (5h depois), quando o selo vira "Finalizado".
  bool get hasStarted {
    final eventDate = eventDateSaoPaulo;
    if (eventDate == null) return false;
    return !toSaoPauloTimeNow().isBefore(eventDate);
  }

  /// Verdadeiro a partir de 5 horas depois do horário de início do evento —
  /// critério de "Finalizado" (27/08/2026, pedido do usuário; antes era
  /// baseado no dia civil — "verdadeiro a partir do dia seguinte"). Usado
  /// pro selo "Finalizado"/sombreamento do card em `post_card.dart` e pra
  /// rebaixar o post pro fim da lista do Mural em `mural_page.dart`.
  bool get isPastEvent {
    final eventDate = eventDateSaoPaulo;
    if (eventDate == null) return false;
    return toSaoPauloTimeNow().isAfter(eventDate.add(const Duration(hours: 5)));
  }

  /// Verdadeiro se a data do evento (`eventDateSaoPaulo`) cai no dia de hoje
  /// (fuso America/Sao_Paulo) — usado por `mural_page.dart#_feedRank`
  /// pra subir o post do evento pro topo do feed no próprio dia (27/08/2026,
  /// pedido do usuário), e por `post_card.dart` pra trocar `(dia da semana)`
  /// por `(Hoje)` no texto sem precisar repostar. Diferente de [isFromToday],
  /// que compara `createdAt` (quando o post foi publicado), não a data do
  /// evento em si.
  bool get isEventToday {
    final eventDate = eventDateSaoPaulo;
    if (eventDate == null) return false;
    final today = toSaoPauloTimeNow();
    return eventDate.year == today.year &&
        eventDate.month == today.month &&
        eventDate.day == today.day;
  }

  /// Verdadeiro se a data do evento cai amanhã (fuso America/Sao_Paulo) —
  /// usado só por `post_card.dart` pra trocar `(dia da semana)` por
  /// `(Amanhã)` no texto do post, sem precisar repostar.
  bool get isEventTomorrow {
    final eventDate = eventDateSaoPaulo;
    if (eventDate == null) return false;
    final tomorrow = toSaoPauloTimeNow().add(const Duration(days: 1));
    return eventDate.year == tomorrow.year &&
        eventDate.month == tomorrow.month &&
        eventDate.day == tomorrow.day;
  }

  /// Verdadeiro só no dia em que o post foi criado (fuso America/Sao_Paulo) —
  /// usado por [PostType.membershipAnniversary] pra deixar de aparecer
  /// fixado assim que o dia do aniversário passa (24/08/2026, a pedido do
  /// usuário: antes ficava fixado até a limpeza semanal do feed, na
  /// segunda-feira seguinte).
  bool get isFromToday {
    if (createdAt == null) return false;
    final created = toSaoPauloTime(createdAt!.toUtc());
    final today = toSaoPauloTimeNow();
    return created.year == today.year &&
        created.month == today.month &&
        created.day == today.day;
  }
}

abstract final class PostType {
  static const manual = 'manual';
  static const devotional = 'devotional';
  static const event = 'event';
  static const birthday = 'birthday';

  /// `targetId` é o uid de quem faz aniversário de MEMBRESIA hoje. Não
  /// aparece na lista do feed — `mural_page.dart` usa esse documento só
  /// como fonte de dado em tempo real pro banner fixo acima da lista
  /// (`_MembershipAnniversaryBanner`, espelha `ownBirthdayBanner` do
  /// `HomeFragment.kt` nativo), visível só pro dono desse uid; todo mundo
  /// mais nem sabe que ele existe, mesmo a coleção `posts` sendo de leitura
  /// pública (filtro é só no cliente, 25/08/2026).
  static const membershipAnniversary = 'membership_anniversary';
}
