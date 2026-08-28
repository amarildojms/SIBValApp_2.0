import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/service_order_repository.dart';
import '../models/notification.dart';
import '../models/service_order.dart';
import '../notifications/notification_read_sync.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'service_order_countdown.dart';
import 'service_order_live_page.dart';
import 'service_order_preview_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Toque simples numa ordem de `ServiceOrderListPage` abre esta
/// tela (toque e segure abre o menu Editar/Excluir, ver
/// `ServiceOrderListPage._showActions`). **Revisão da mesma sessão:** não
/// mostra mais a ordem completa — só a data/hora, o contador regressivo e
/// os dois botões centralizados ("Iniciar Culto" em cima, "Voltar" embaixo),
/// pedido explícito do usuário. O botão "Iniciar Culto" só fica clicável na
/// hora exata (`_canStart`) — antes disso leva pro "modo apresentação"
/// (`ServiceOrderLivePage`), que aí sim mostra a ordem completa, num layout
/// diferente pensado pra acompanhar o culto ao vivo.
class ServiceOrderPrecheckPage extends ConsumerStatefulWidget {
  const ServiceOrderPrecheckPage({super.key, required this.order});

  final ServiceOrder order;

  @override
  ConsumerState<ServiceOrderPrecheckPage> createState() =>
      _ServiceOrderPrecheckPageState();
}

class _ServiceOrderPrecheckPageState
    extends ConsumerState<ServiceOrderPrecheckPage> {
  static final _dateFormat =
      DateFormat("EEEE, d 'de' MMMM 'de' yyyy 'às' HH:mm", 'pt_BR');

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    syncNotificationsForScreen(ref, type: NotificationType.serviceOrderReminder, targetId: widget.order.id);
    syncNotificationsForScreen(ref, type: NotificationType.serviceOrderStarted, targetId: widget.order.id);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _canStart => !DateTime.now().isBefore(widget.order.dateTime);

  /// "Continuar Culto" em vez de "Iniciar Culto" (28/08/2026, pedido do
  /// usuário) quando já existe progresso salvo (`ServiceOrderLivePage`
  /// grava em `ServiceOrder.completedMomentKeys` a cada momento marcado).
  bool get _hasProgress => widget.order.completedMomentKeys.isNotEmpty;

  /// Grava `startedAt` (28/08/2026, pedido do usuário) antes de entrar no
  /// modo apresentação — é o que libera `ServiceOrderMemberViewPage` (demais
  /// membros/visitantes) de ficar travada no timer, e o que dispara a
  /// notificação `onServiceOrderStartedNotify` (Cloud Function). Não
  /// bloqueia a navegação se falhar (mesmo padrão não-fatal de
  /// `_prefillDateTime`/`service_order_form_page.dart`).
  Future<void> _startService() async {
    try {
      await ref
          .read(serviceOrderRepositoryProvider)
          .markStarted(widget.order.id);
    } catch (_) {
      // Segue pro modo apresentação de qualquer jeito.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ServiceOrderLivePage(order: widget.order)),
    );
  }

  void _openPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceOrderPreviewPage(order: widget.order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle(serviceOrderDisplayName(order)),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dateFormat.format(order.dateTime),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (order.ownerName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Dirigente: ${order.ownerName}',
                          style: TextStyle(color: context.textSecondary, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (order.isFinalized)
                        _FinalizedCard(finalizedAt: order.finalizedAt)
                      else
                        _CountdownCard(canStart: _canStart, target: order.dateTime),
                      const SizedBox(height: 32),
                      if (!order.isFinalized)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            onPressed: _canStart ? _startService : null,
                            child: Text(_hasProgress ? 'Continuar Culto' : 'Iniciar Culto'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: _openPreview,
                          child: const Text('Ver Prévia'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Voltar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalizedCard extends StatelessWidget {
  const _FinalizedCard({required this.finalizedAt});

  final DateTime? finalizedAt;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: SibValColors.navyBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: SibValColors.goldAccent, size: 28),
          const SizedBox(height: 8),
          const Text(
            'Culto finalizado',
            style: TextStyle(
              color: SibValColors.goldAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (finalizedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              _dateFormat.format(finalizedAt!),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card com o contador regressivo — "Pode iniciar" (sem contagem) quando o
/// horário já chegou/passou. Formato por extenso (28/08/2026, pedido do
/// usuário) — "N dias, N horas, N minutos e N segundos", omitindo as
/// unidades maiores que já zeraram (ex.: faltando 40 minutos, mostra só
/// "40 minutos e 12 segundos", sem "0 dias, 0 horas").
class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.canStart, required this.target});

  final bool canStart;
  final DateTime target;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: SibValColors.navyBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            canStart ? 'Pode iniciar' : 'Tempo para o início do culto',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            canStart
                ? '🎉'
                : formatServiceOrderCountdown(target.difference(DateTime.now())),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SibValColors.goldAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
