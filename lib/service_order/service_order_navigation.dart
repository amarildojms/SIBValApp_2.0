import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/service_order_repository.dart';
import '../data/user_repository.dart';
import 'service_order_member_view_page.dart';
import 'service_order_praise_view_page.dart';
import 'service_order_precheck_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Despacho por papel pra uma ordem de culto — Dirigentes/admin
/// vão pro Precheck (contagem regressiva + "Iniciar Culto"), Louvor vai pra
/// visão própria com tom/cifra, os demais (membro comum ou acesso
/// convidado, sem conta — `profile` pode ser `null`) vão pra
/// `ServiceOrderMemberViewPage` (travada num timer até o dirigente
/// iniciar). Compartilhado entre o toque numa ordem em
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
  final canManageOrders = profile?.canManageServiceOrders ?? false;
  final canViewPraise = profile?.canViewPraiseOrder ?? false;

  if (!canManageOrders) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => canViewPraise
            ? ServiceOrderPraiseViewPage(orderId: orderId)
            : ServiceOrderMemberViewPage(orderId: orderId),
      ),
    );
    return;
  }

  final order = await container.read(serviceOrderRepositoryProvider).watchOne(orderId).first;
  if (!context.mounted || order == null) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ServiceOrderPrecheckPage(order: order)),
  );
}
