import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/contribution_info.dart';

/// Espelha o padrão de `SettingsRepository`, num repositório próprio por
/// causa do upload de imagem (QR Code do PIX) — sem equivalente no nativo,
/// pedido em 21/08/2026. Documento único (`settings/contribution`), só o
/// admin escreve (ver `firestore.rules`/`storage.rules` do repo nativo,
/// exceção de leitura pública aberta pro visitante também ver a página).
class ContributionRepository {
  ContributionRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore.collection('settings').doc('contribution');

  Stream<ContributionInfo> watch() {
    return _doc.snapshots().map((doc) => ContributionInfo.fromMap(doc.data()));
  }

  /// Sobe o QR Code de uma chave PIX, apagando o anterior (se houver) —
  /// separado de [update] porque agora há uma imagem por entrada da lista de
  /// chaves PIX, não uma só pro documento inteiro (22/08/2026).
  Future<({String url, String storagePath})> uploadPixQrCode(File file, {String? oldStoragePath}) async {
    if (oldStoragePath != null && oldStoragePath.isNotEmpty) {
      try {
        await _storage.ref(oldStoragePath).delete();
      } catch (_) {}
    }
    final storagePath = 'contribution/pix_qr_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final ref = _storage.ref(storagePath);
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    return (url: url, storagePath: storagePath);
  }

  /// Limpeza best-effort de QR Codes de chaves PIX removidas pelo admin —
  /// chamado depois que [update] já gravou a lista sem essas entradas, senão
  /// cancelar a edição sem salvar deixaria o Firestore com uma referência
  /// quebrada pra uma imagem já apagada.
  Future<void> deleteQrCode(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await _storage.ref(storagePath).delete();
    } catch (_) {}
  }

  Future<void> update({
    required String churchName,
    required String cnpj,
    required List<PixEntry> pixEntries,
    required List<BankAccountEntry> bankAccounts,
  }) {
    return _doc.set({
      'churchName': churchName,
      'cnpj': cnpj,
      'pixEntries': pixEntries.map((e) => e.toMap()).toList(),
      'bankAccounts': bankAccounts.map((e) => e.toMap()).toList(),
    });
  }
}

final contributionRepositoryProvider = Provider<ContributionRepository>((ref) {
  return ContributionRepository(FirebaseFirestore.instance, FirebaseStorage.instance);
});

final contributionInfoProvider = StreamProvider.autoDispose<ContributionInfo>((ref) {
  return ref.watch(contributionRepositoryProvider).watch();
});
