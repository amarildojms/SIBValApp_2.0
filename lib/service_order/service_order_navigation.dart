import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_repository.dart' show currentUidProvider;
import '../data/service_order_repository.dart';
import '../data/user_repository.dart';
import 'service_order_member_view_page.dart';
import 'service_order_praise_view_page.dart';
import 'service_order_precheck_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Despacho por papel/dono pra uma ordem de culto — **revisão de
/// 28/08/2026, mesma sessão**: só o dono da ordem (`ServiceOrder.ownerUid`)
/// vai pro Precheck (contagem regressiva + "Iniciar Culto") — antes bastava
/// ser Dirigentes/admin, mas edição/exclusão/iniciar/marcar momento viraram
/// exclusivos do dono ("Nem mesmo admin poderá fazer estas ações", pedido do
/// usuário), então mandar um Dirigentes/admin que não é dono pro Precheck só
/// mostraria um botão "Iniciar Culto" que falharia por permissão — em vez
/// disso, qualquer um que não seja o dono (dirigente não-dono, admin
/// não-dono, Louvor, membro comum ou acesso convidado) cai nas mesmas visões
/// somente-leitura de sempre: Louvor vai pra visão própria com tom/cifra, os
/// demais vão pra `ServiceOrderMemberViewPage` (travada num timer até o
/// dono tocar em "Iniciar Culto"). Compartilhado entre o toque numa ordem em
/// `ServiceOrderListPage` e o toque numa notificação de Ordem de Culto
/// (`NotificationType.serviceOrderReminder`/`.serviceOrderStarted`, em
/// `notification_navigation.dart`).
///
/// Recebe só `BuildContext` (lê o `ProviderContainer` direto de
/// `ProviderScope.containerOf`, mesmo padrão já usado pro caso
/// `NotificationType.membershipAnniversary` no mesmo arquivo de navegação)
/// em vez de um `WidgetRef` — `navigateForNotificationType` só tem
/// `BuildContext` em mãos (função solta, chamada tanto pelo toque na
/// Central quanto pelo toque na notificação do sistema), então esse é o
/// único jeito de reaproveitar a mesma função nos dois lugares sem duplicar
/// a lógica de despacho. Busca a ordem uma vez por id — `ServiceOrderListPage`
/// já tem o objeto completo em mãos, mas usa a mesma função por
/// simplicidade (uma leitura extra e barata, contra manter dois pontos de
/// entrada com a mesma regra).
Future<void> openServiceOrder(BuildContext context, String orderId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final profile = container.read(currentUserProfileProvider).asData?.value;
  final uid = container.read(currentUidProvider);
  final canViewPraise = profile?.canViewPraiseOrder ?? false;

  final order = await container
      .read(serviceOrderRepositoryProvider)
      .watchOne(orderId)
      .first;
  if (!context.mounted || order == null) return;

  if (order.ownerUid.isNotEmpty && order.ownerUid == uid) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServiceOrderPrecheckPage(order: order)),
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => canViewPraise
          ? ServiceOrderPraiseViewPage(orderId: orderId)
          : ServiceOrderMemberViewPage(orderId: orderId),
    ),
  );
}
