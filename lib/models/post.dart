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
    );
  }

  DateTime? get eventDateSaoPaulo => eventDateTimeMillis != null
      ? toSaoPauloTime(DateTime.fromMillisecondsSinceEpoch(eventDateTimeMillis!, isUtc: true))
      : null;

  /// Verdadeiro a partir do dia seguinte ao do evento (o dia do evento em si
  /// ainda conta como "não ocorrido" pra manter o post fixado/tocável).
  bool get isPastEvent {
    final eventDate = eventDateSaoPaulo;
    if (eventDate == null) return false;
    final today = toSaoPauloTimeNow();
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return eventDay.isBefore(todayDay);
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
    return created.year == today.year && created.month == today.month && created.day == today.day;
  }
}

abstract final class PostType {
  static const manual = 'manual';
  static const devotional = 'devotional';
  static const event = 'event';
  static const birthday = 'birthday';

  /// `targetId` é o uid de quem faz aniversário de MEMBRESIA hoje. Não
  /// aparece na lista do feed — `home_feed_page.dart` usa esse documento só
  /// como fonte de dado em tempo real pro banner fixo acima da lista
  /// (`_MembershipAnniversaryBanner`, espelha `ownBirthdayBanner` do
  /// `HomeFragment.kt` nativo), visível só pro dono desse uid; todo mundo
  /// mais nem sabe que ele existe, mesmo a coleção `posts` sendo de leitura
  /// pública (filtro é só no cliente, 25/08/2026).
  static const membershipAnniversary = 'membership_anniversary';
}
