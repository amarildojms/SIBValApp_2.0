import 'package:cloud_firestore/cloud_firestore.dart';

/// Um local/área da igreja cadastrado pelo admin (03/09/2026, pedido do
/// usuário: "Local/área deve ser configurável por um admin") — catálogo que
/// alimenta o dropdown "Local/Área" da Agenda (`AgendaEntryFormPage`), no
/// lugar do campo livre com sugestão que existia antes.
class AgendaLocation {
  const AgendaLocation({required this.id, required this.name});

  final String id;
  final String name;

  factory AgendaLocation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AgendaLocation(id: doc.id, name: data['name'] as String? ?? '');
  }
}
