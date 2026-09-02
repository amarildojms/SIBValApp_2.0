import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/contribution_info.dart';

/// Espelha o padrão de `SettingsRepository` — sem equivalente no nativo,
/// pedido em 21/08/2026. Documento único (`settings/contribution`), só o
/// admin escreve (ver `firestore.rules` do repo nativo, exceção de leitura
/// pública aberta pro visitante também ver a página). Chegou a subir QR Code
/// (imagem) pro Storage entre 22/08/2026 e a reforma de 01/09/2026 — removido
/// junto com a exibição da chave crua na Contribua (ver doc comment de
/// `PixEntry`).
class ContributionRepository {
  ContributionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore.collection('settings').doc('contribution');

  Stream<ContributionInfo> watch() {
    return _doc.snapshots().map((doc) => ContributionInfo.fromMap(doc.data()));
  }

  Future<void> update({
    required String churchName,
    required String cnpj,
    required String city,
    required List<PixEntry> pixEntries,
    required List<BankAccountEntry> bankAccounts,
  }) {
    return _doc.set({
      'churchName': churchName,
      'cnpj': cnpj,
      'city': city,
      'pixEntries': pixEntries.map((e) => e.toMap()).toList(),
      'bankAccounts': bankAccounts.map((e) => e.toMap()).toList(),
    });
  }
}

final contributionRepositoryProvider = Provider<ContributionRepository>((ref) {
  return ContributionRepository(FirebaseFirestore.instance);
});

final contributionInfoProvider = StreamProvider.autoDispose<ContributionInfo>((ref) {
  return ref.watch(contributionRepositoryProvider).watch();
});
