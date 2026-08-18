import 'package:cloud_firestore/cloud_firestore.dart';

/// Espelha app/src/main/java/com/sibval/app/data/model/RecurringEvent.kt
/// (RecurringEventFlyer) — mesma coleção `recurringEventFlyers` no Firestore.
/// `dateKey` vazio = flyer padrão da categoria; senão "AAAA-MM-DD" da data
/// específica que ele deve ilustrar.
class RecurringEventFlyer {
  final String id;
  final String category;
  final String dateKey;
  final String flyerUrl;
  final String flyerStoragePath;
  final DateTime? createdAt;

  const RecurringEventFlyer({
    required this.id,
    required this.category,
    required this.dateKey,
    required this.flyerUrl,
    required this.flyerStoragePath,
    required this.createdAt,
  });

  factory RecurringEventFlyer.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RecurringEventFlyer(
      id: doc.id,
      category: data['category'] as String? ?? '',
      dateKey: data['dateKey'] as String? ?? '',
      flyerUrl: data['flyerUrl'] as String? ?? '',
      flyerStoragePath: data['flyerStoragePath'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Categorias exclusivas do cadastro de eventos recorrentes — cadastrados só
/// pelo app, nunca por e-mail.
abstract final class RecurringEventCategory {
  static const cla = 'cla';
  static const ebd = 'ebd';
  static const co = 'co';
  static const coo = 'coo';

  static const all = [cla, ebd, co, coo];
}

/// Categoria extra só do Repositório de Flyers (flyer padrão do post
/// automático de devocional) — não é uma categoria de evento/série
/// recorrente, por isso fica fora de [RecurringEventCategory].
abstract final class DevotionalFlyerCategory {
  static const dev = 'dev';
}

/// Categorias disponíveis no formulário do Repositório de Flyers.
const flyerRepositoryCategories = [
  RecurringEventCategory.cla,
  RecurringEventCategory.ebd,
  RecurringEventCategory.co,
  RecurringEventCategory.coo,
  DevotionalFlyerCategory.dev,
];

String recurringEventFlyerCategoryLabel(String category) => switch (category) {
  RecurringEventCategory.cla => 'Culto de Louvor e Adoração',
  RecurringEventCategory.ebd => 'Escola Bíblica Dominical',
  RecurringEventCategory.co => 'Culto de Oração',
  RecurringEventCategory.coo => 'Culto de Oração Online',
  DevotionalFlyerCategory.dev => 'Devocionais',
  _ => category,
};
