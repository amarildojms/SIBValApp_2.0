import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_message.dart';
import 'post_repository.dart' show currentUidProvider;
import 'user_repository.dart' show currentUserProfileProvider;

/// Espelha o padrão client-side de `NotificationRepository`: busca as N mais
/// recentes e filtra o destinatário em memória (`AppMessage.isRecipient`), em
/// vez de depender de uma query `array-contains` (que exigiria um índice
/// composto e não cobriria `sendToAll`). Só admin cria (`firestore.rules`
/// nativo, `messages.create`) — o formulário (`MessageFormPage`) resolve
/// `recipientUids` (usuários selecionados + membros dos ministérios
/// selecionados) antes de chamar `send`.
class MessageRepository {
  MessageRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _messages => _firestore.collection('messages');
  CollectionReference<Map<String, dynamic>> get _members => _firestore.collection('members');

  Future<List<AppMessage>> getRecent({required String uid, int limit = 100}) async {
    final snapshot = await _messages.orderBy('createdAt', descending: true).limit(limit).get();
    return snapshot.docs.map(AppMessage.fromFirestore).where((m) => m.isRecipient(uid)).toList();
  }

  Future<AppMessage?> getById(String id) async {
    final doc = await _messages.doc(id).get();
    return doc.exists ? AppMessage.fromFirestore(doc) : null;
  }

  Future<void> markAsRead(String id, String uid) {
    return _messages.doc(id).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }

  /// Resolve os uids dos membros vinculados (`linkedUid`) aos ministérios em
  /// [ministryIds] — em lotes de 10 (limite do `whereIn`/`arrayContainsAny` do
  /// Firestore), igual ao helper equivalente no Cloud Functions nativo.
  Future<Set<String>> _resolveMinistryMemberUids(List<String> ministryIds) async {
    if (ministryIds.isEmpty) return {};
    final uids = <String>{};
    for (var i = 0; i < ministryIds.length; i += 10) {
      final chunk = ministryIds.skip(i).take(10).toList();
      final snapshot = await _members.where('ministryIds', arrayContainsAny: chunk).get();
      for (final doc in snapshot.docs) {
        final linkedUid = doc.data()['linkedUid'] as String? ?? '';
        if (linkedUid.isNotEmpty) uids.add(linkedUid);
      }
    }
    return uids;
  }

  Future<void> send({
    required String senderUid,
    required String senderName,
    required String title,
    required String body,
    required bool sendToAll,
    List<String> targetUserUids = const [],
    List<String> targetMinistryIds = const [],
    bool isMeeting = false,
    DateTime? meetingAt,
  }) async {
    var recipientUids = <String>{};
    if (!sendToAll) {
      recipientUids.addAll(targetUserUids);
      recipientUids.addAll(await _resolveMinistryMemberUids(targetMinistryIds));
    }

    final doc = _messages.doc();
    await doc.set({
      'title': title,
      'body': body,
      'senderUid': senderUid,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
      'sendToAll': sendToAll,
      'targetUserUids': targetUserUids,
      'targetMinistryIds': targetMinistryIds,
      'recipientUids': recipientUids.toList(),
      'isMeeting': isMeeting,
      'meetingAt': meetingAt != null ? Timestamp.fromDate(meetingAt) : null,
      'readBy': <String>[],
    });
  }
}

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(FirebaseFirestore.instance);
});

/// Usado por `MessageDetailPage` quando aberta a partir de uma notificação
/// (só tem o `targetId`/messageId, não o objeto já carregado da lista).
final messageByIdProvider = FutureProvider.autoDispose.family<AppMessage?, String>((ref, id) {
  return ref.watch(messageRepositoryProvider).getById(id);
});

final inboxMessagesProvider = FutureProvider.autoDispose<List<AppMessage>>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const [];
  return ref.watch(messageRepositoryProvider).getRecent(uid: uid);
});

/// Mensagens com `isMeeting` e `meetingAt` no futuro, mais próxima primeiro —
/// alimenta a seção "Próximas reuniões" no topo de `MessagesPage`.
final upcomingMeetingsProvider = FutureProvider.autoDispose<List<AppMessage>>((ref) async {
  final messages = await ref.watch(inboxMessagesProvider.future);
  final now = DateTime.now();
  final meetings = messages.where((m) => m.isMeeting && m.meetingAt != null && m.meetingAt!.isAfter(now)).toList()
    ..sort((a, b) => a.meetingAt!.compareTo(b.meetingAt!));
  return meetings;
});

final pendingMessagesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return 0;
  final messages = await ref.watch(inboxMessagesProvider.future);
  return messages.where((m) => !m.readBy.contains(uid)).length;
});

/// Só admin envia mensagens (gate no FAB de `MessagesPage`, espelhando
/// `firestore.rules` nativo `messages.create`).
final canSendMessagesProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProfileProvider).asData?.value?.isAdmin ?? false;
});
