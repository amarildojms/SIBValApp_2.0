import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/service_order_repository.dart';
import '../models/notification.dart';
import '../models/service_order.dart';
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import 'service_order_countdown.dart';
import 'service_order_praise_view_page.dart' show ServiceOrderReadOnlyBody;

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Visão da Ordem de Culto pros demais membros/visitantes (quem
/// não é Dirigente/admin nem tem o papel Louvor — inclusive acesso
/// convidado, sem conta) — aberta a partir de `ServiceOrderListPage`/
/// `openServiceOrder` (`service_order_navigation.dart`). Mesma tela cheia
/// escura das demais telas "de apresentação" da Ordem de Culto
/// (`ServiceOrderLivePage`/`ServiceOrderPraiseViewPage`), sem `SibValAppBar`.
///
/// **Travada até o dirigente tocar em "Iniciar Culto"** (`ServiceOrder.
/// isStarted`/`startedAt`, `ServiceOrderRepository.markStarted`) — mesmo que
/// o relógio já tenha passado do horário marcado, continua mostrando só a
/// contagem regressiva (confirmado com o usuário: nunca abre sozinha pelo
/// horário). Assim que `startedAt` é gravado, o `serviceOrderStreamProvider`
/// (tempo real) atualiza esta tela sozinha, sem precisar reabrir — mostra o
/// conteúdo completo via `ServiceOrderReadOnlyBody(showPraiseDetails: false)`
/// (mesma lista somente-leitura da visão do Louvor, `service_order_
/// praise_view_page.dart`, só que sem tom e sem toque nos momentos "Louvor"
/// pra abrir `CifraViewPage` — "igual à do Louvor, porém sem acesso às
/// cifras", pedido literal do usuário).
class ServiceOrderMemberViewPage extends ConsumerStatefulWidget {
  const ServiceOrderMemberViewPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ServiceOrderMemberViewPage> createState() =>
      _ServiceOrderMemberViewPageState();
}

class _ServiceOrderMemberViewPageState extends ConsumerState<ServiceOrderMemberViewPage> {
  static final _dateFormat = DateFormat('EEEE, dd/MM HH:mm', 'pt_BR');

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    // Chega aqui por outro caminho que não o toque na notificação (ex.: pelo
    // menu Mais) também marca como lida/cancela da barra (24/08/2026, mesmo
    // padrão das demais telas ligadas a um tipo de notificação).
    syncNotificationsForScreen(ref, type: NotificationType.serviceOrderReminder, targetId: widget.orderId);
    syncNotificationsForScreen(ref, type: NotificationType.serviceOrderStarted, targetId: widget.orderId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(serviceOrderStreamProvider(widget.orderId));
    return Scaffold(
      backgroundColor: SibValColors.navyBlue,
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: SibValColors.goldAccent),
          ),
          error: (error, _) => _ErrorOrEmpty(
            message: 'Falha ao carregar: $error',
          ),
          data: (order) {
            if (order == null) {
              return const _ErrorOrEmpty(message: 'Ordem não encontrada.');
            }
            return order.isStarted ? _buildStarted(order) : _buildWaiting(order);
          },
        ),
      ),
    );
  }

  Widget _buildWaiting(ServiceOrder order) {
    final displayName = serviceOrderDisplayName(order);
    final remaining = order.dateTime.difference(DateTime.now());
    final reached = !remaining.isPositive;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, color: SibValColors.goldAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _dateFormat.format(order.dateTime),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ServiceOrderCountdownCard(
              label: reached ? 'Aguardando o início' : 'Tempo para o início de $displayName',
              value: reached
                  ? 'Aguardando o dirigente iniciar $displayName'
                  : formatServiceOrderCountdown(remaining),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarted(ServiceOrder order) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ORDEM DO CULTO',
                style: TextStyle(
                  color: SibValColors.goldAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                serviceOrderDisplayName(order),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ServiceOrderReadOnlyBody(order: order, showPraiseDetails: false),
        ),
      ],
    );
  }
}

class _ErrorOrEmpty extends StatelessWidget {
  const _ErrorOrEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
