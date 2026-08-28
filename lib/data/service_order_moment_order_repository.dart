import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_order.dart';
import '../models/service_order_extra_moment.dart';
import 'service_order_extra_moment_repository.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Sequência padrão de "Momentos do Culto" usada ao montar uma
/// ordem de culto nova (`ServiceOrderReorderPage`, modo cadastro) — uma
/// lista única que mistura os 16 momentos fixos (`ServiceOrderMomentType`)
/// com os momentos especiais marcados como padrão
/// (`ServiceOrderExtraMomentOption.isDefault`), guardada como tokens em
/// `settings/serviceOrderMomentOrder` (`{order: List<String>}` — nome do
/// enum pros fixos, `"extra:<id>"` pros especiais). **Sem regra nova no
/// `firestore.rules`** — `match /settings/{docId}` já cobre qualquer
/// documento da coleção (`read` pra autenticado, `write` só admin).
///
/// Editável na seção "Momentos do Culto" de `ManageServiceOrderMomentsPage`
/// (arrastar pra reordenar) — marcar/desmarcar um momento especial como
/// padrão (seção "Momentos Especiais" da mesma tela) também
/// adiciona/remove o token correspondente daqui, mantendo as duas listas em
/// sincronia (ver `ManageServiceOrderMomentsPage._setExtraDefault`).
class ServiceOrderMomentOrderRepository {
  ServiceOrderMomentOrderRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('settings').doc('serviceOrderMomentOrder');

  List<String> _parseTokens(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return (snapshot.data()?['order'] as List<dynamic>?)?.cast<String>() ??
        const <String>[];
  }

  Future<List<String>> getTokens() async => _parseTokens(await _doc.get());

  Stream<List<String>> watchTokens() => _doc.snapshots().map(_parseTokens);

  Future<void> saveTokens(List<String> tokens) {
    return _doc.set({'order': tokens});
  }
}

final serviceOrderMomentOrderRepositoryProvider =
    Provider<ServiceOrderMomentOrderRepository>((ref) {
      return ServiceOrderMomentOrderRepository(FirebaseFirestore.instance);
    });

/// Tokens crus (`List<String>`), sem resolver contra o catálogo de extras —
/// usado internamente por `serviceOrderMomentTemplateProvider` e por quem só
/// precisa saber se um token específico está presente (ex.: toggle de
/// "padrão" em `ManageServiceOrderMomentsPage`).
final serviceOrderMomentOrderTokensProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
      return ref.watch(serviceOrderMomentOrderRepositoryProvider).watchTokens();
    });

/// Resolve os tokens salvos (`settings/serviceOrderMomentOrder`) contra o
/// catálogo de momentos especiais, devolvendo a sequência final como
/// `ServiceOrderItem` — pronta pra virar a ordem inicial de uma ordem de
/// culto nova. Todo `ServiceOrderMomentType` que não aparece nos tokens
/// salvos (documento nunca criado, ou um momento novo do app ainda não
/// reordenado) é acrescentado no fim, na ordem de declaração do enum —
/// garante que nenhum momento fixo suma da liturgia só por causa de
/// configuração desatualizada.
List<ServiceOrderItem> resolveServiceOrderMomentTemplate(
  List<String> tokens,
  List<ServiceOrderExtraMomentOption> extras,
) {
  final extrasById = {for (final e in extras) e.id: e};
  final items = <ServiceOrderItem>[];
  for (final token in tokens) {
    if (token.startsWith('extra:')) {
      final extra = extrasById[token.substring(6)];
      if (extra != null) items.add(ServiceOrderItem.extra(extra.id, extra.name));
    } else {
      final type = ServiceOrderMomentType.fromName(token);
      if (type != null) items.add(ServiceOrderItem.fixed(type));
    }
  }
  for (final type in ServiceOrderMomentType.values) {
    if (!items.any((i) => i.type == type)) items.add(ServiceOrderItem.fixed(type));
  }
  return items;
}

/// Versão pronta-pra-uso de `resolveServiceOrderMomentTemplate`, combinando
/// os dois providers fonte — usada pela seção "Momentos do Culto" de
/// `ManageServiceOrderMomentsPage` (precisa ficar reativa a mudanças ao
/// vivo). `ServiceOrderFormPage._loadDefaultMomentOrder` busca os dois de
/// uma vez só (não reativo) em vez de usar este provider, mesmo padrão
/// try/catch-com-fallback de `_prefillDateTime`.
final serviceOrderMomentTemplateProvider =
    Provider.autoDispose<AsyncValue<List<ServiceOrderItem>>>((ref) {
      final tokensAsync = ref.watch(serviceOrderMomentOrderTokensProvider);
      final extrasAsync = ref.watch(serviceOrderExtraMomentsProvider);
      if (tokensAsync.isLoading || extrasAsync.isLoading) {
        return const AsyncValue.loading();
      }
      if (tokensAsync.hasError) {
        return AsyncValue.error(tokensAsync.error!, tokensAsync.stackTrace!);
      }
      if (extrasAsync.hasError) {
        return AsyncValue.error(extrasAsync.error!, extrasAsync.stackTrace!);
      }
      return AsyncValue.data(
        resolveServiceOrderMomentTemplate(
          tokensAsync.value ?? const [],
          extrasAsync.value ?? const [],
        ),
      );
    });
