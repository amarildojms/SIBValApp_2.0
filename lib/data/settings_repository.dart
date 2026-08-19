import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/SettingsRepository.kt
/// (remetentes de e-mail de eventos + telefone do responsável por pedidos de
/// oração; `settings/prayer.responsiblePhone`, mesmo doc/campo do nativo).
class SettingsRepository {
  SettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _eventEmailSenders =>
      _firestore.collection('settings').doc('eventEmailSenders');

  DocumentReference<Map<String, dynamic>> get _prayer => _firestore.collection('settings').doc('prayer');

  Future<List<String>> getEventEmailSenders() async {
    final doc = await _eventEmailSenders.get();
    final emails = doc.data()?['emails'] as List?;
    return List<String>.from(emails ?? const []);
  }

  Future<void> setEventEmailSenders(List<String> emails) {
    return _eventEmailSenders.set({'emails': emails}, SetOptions(merge: true));
  }

  Future<String> getPrayerResponsiblePhone() async {
    final doc = await _prayer.get();
    return doc.data()?['responsiblePhone'] as String? ?? '';
  }

  Future<void> setPrayerResponsiblePhone(String phone) {
    return _prayer.set({'responsiblePhone': phone}, SetOptions(merge: true));
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(FirebaseFirestore.instance);
});

final eventEmailSendersProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(settingsRepositoryProvider).getEventEmailSenders();
});

final prayerResponsiblePhoneProvider = FutureProvider.autoDispose<String>((ref) {
  return ref.watch(settingsRepositoryProvider).getPrayerResponsiblePhone();
});
