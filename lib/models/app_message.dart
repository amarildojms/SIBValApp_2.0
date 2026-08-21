import 'package:cloud_firestore/cloud_firestore.dart';

/// Central de Mensagens (21/08/2026, sem equivalente no app nativo em Kotlin)
/// — mesma coleção `messages` no Firestore. Só admin cria (ver
/// `firestore.rules` nativo); o app filtra o destinatário em memória, mesmo
/// padrão já usado por `AppNotification` (`readBy`/`dismissedBy` client-side).
class AppMessage {
  final String id;
  final String title;
  final String body;
  final String senderUid;
  final String senderName;
  final DateTime? createdAt;

  /// Quando true, ignora [targetUserUids]/[targetMinistryIds]/[recipientUids]
  /// — todo usuário aprovado é destinatário.
  final bool sendToAll;

  /// Uids selecionados diretamente pelo admin no formulário.
  final List<String> targetUserUids;

  /// Ministérios selecionados — os membros vinculados a eles também recebem.
  final List<String> targetMinistryIds;

  /// União resolvida de [targetUserUids] + uids dos membros dos
  /// [targetMinistryIds], calculada uma vez no envio (`MessageRepository.send`)
  /// — é o que a Cloud Function e o filtro client-side (`inboxFor`) usam.
  final List<String> recipientUids;

  final bool isMeeting;
  final DateTime? meetingAt;
  final List<String> readBy;

  const AppMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.senderUid,
    required this.senderName,
    required this.createdAt,
    required this.sendToAll,
    required this.targetUserUids,
    required this.targetMinistryIds,
    required this.recipientUids,
    required this.isMeeting,
    required this.meetingAt,
    required this.readBy,
  });

  factory AppMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppMessage(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      sendToAll: data['sendToAll'] as bool? ?? false,
      targetUserUids: List<String>.from(data['targetUserUids'] as List? ?? const []),
      targetMinistryIds: List<String>.from(data['targetMinistryIds'] as List? ?? const []),
      recipientUids: List<String>.from(data['recipientUids'] as List? ?? const []),
      isMeeting: data['isMeeting'] as bool? ?? false,
      meetingAt: (data['meetingAt'] as Timestamp?)?.toDate(),
      readBy: List<String>.from(data['readBy'] as List? ?? const []),
    );
  }

  /// True quando [uid] é destinatário desta mensagem — `sendToAll` cobre todo
  /// mundo, senão checa a lista já resolvida.
  bool isRecipient(String uid) => sendToAll || recipientUids.contains(uid);
}
