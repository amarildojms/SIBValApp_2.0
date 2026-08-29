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
import 'service_order_praise_view_page.dart' show ServiceOrderReadOnlyBody;
import 'service_order_preview_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Toque simples numa ordem de `ServiceOrderListPage` abre esta
/// tela (toque e segure abre o menu Editar/Excluir, ver
/// `ServiceOrderListPage._showActions`). O botão "Iniciar Culto" só fica
/// clicável na hora exata (`_canStart`) — a partir daí leva pro "modo
/// apresentação" (`ServiceOrderLivePage`), que grava o progresso de verdade.
///
/// **Revisão de 29/08/2026, pedido do usuário:** o dono passou a poder
/// visualizar a ordem completa (`ServiceOrderReadOnlyBody`, somente leitura,
/// sem tom — mesmo recorte que o dirigente já via em
/// `ServiceOrderLivePage`) a partir de `isServiceOrderViewableEarly` (2h
/// antes, mesma janela de Louvor/admin em `ServiceOrderPraiseViewPage`) —
/// antes disso continua vendo só a contagem regressiva + botões
/// (`_buildWaiting`). Isso não adianta a permissão de marcar momento como
/// concluído, que continua exclusiva de depois de tocar "Iniciar Culto" —
/// só a leitura foi liberada mais cedo. Passou a observar
/// `serviceOrderStreamProvider` (era só o `order` estático recebido por
/// parâmetro) pra refletir o progresso em tempo real assim que o culto é
/// retomado ("Continuar Culto"); `widget.order` vira só o valor inicial
/// (`orderAsync.value ?? widget.order`), sem tela de carregamento —
/// já se tem dado suficiente pra renderizar de imediato.
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

  bool _canStart(ServiceOrder order) => !DateTime.now().isBefore(order.dateTime);

  /// "Continuar Culto" em vez de "Iniciar Culto" (28/08/2026, pedido do
  /// usuário) quando já existe progresso salvo (`ServiceOrderLivePage`
  /// grava em `ServiceOrder.completedMomentKeys` a cada momento marcado).
  bool _hasProgress(ServiceOrder order) => order.completedMomentKeys.isNotEmpty;

  /// Grava `startedAt` (28/08/2026, pedido do usuário) antes de entrar no
  /// modo apresentação — é o que libera `ServiceOrderMemberViewPage` (demais
  /// membros/visitantes) de ficar travada no timer, e o que dispara a
  /// notificação `onServiceOrderStartedNotify` (Cloud Function). Não
  /// bloqueia a navegação se falhar (mesmo padrão não-fatal de
  /// `_prefillDateTime`/`service_order_form_page.dart`).
  Future<void> _startService(ServiceOrder order) async {
    try {
      await ref.read(serviceOrderRepositoryProvider).markStarted(order.id);
    } catch (_) {
      // Segue pro modo apresentação de qualquer jeito.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ServiceOrderLivePage(order: order)),
    );
  }

  void _openPreview(ServiceOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServiceOrderPreviewPage(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(serviceOrderStreamProvider(widget.order.id));
    final order = orderAsync.value ?? widget.order;
    final viewable = isServiceOrderViewableEarly(order.dateTime);
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
              child: order.isFinalized
                  ? _buildFinalized(order)
                  : viewable
                  ? _buildViewable(order)
                  : _buildWaiting(order),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiting(ServiceOrder order) {
    return Center(
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
            _CountdownCard(canStart: _canStart(order), target: order.dateTime),
            const SizedBox(height: 32),
            _actionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalized(ServiceOrder order) {
    return Center(
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
            _FinalizedCard(finalizedAt: order.finalizedAt),
            const SizedBox(height: 32),
            _actionButtons(order),
          ],
        ),
      ),
    );
  }

  /// Ordem completa, somente leitura, liberada 2h antes do horário
  /// (29/08/2026, pedido do usuário) — `showPraiseDetails: false` porque o
  /// tom é escondido do dirigente por decisão anterior (só o perfil Louvor
  /// vê, ver doc comment de `ServiceOrderLivePage._repertoireSummaryFor`).
  /// Envolvida num `Container` navy porque `ServiceOrderReadOnlyBody` foi
  /// desenhada pro fundo escuro do "modo apresentação" — o resto desta
  /// página continua no tema claro/escuro padrão do app.
  Widget _buildViewable(ServiceOrder order) {
    final started = order.isStarted;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
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
                _dateFormat.format(order.dateTime),
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (order.ownerName.isNotEmpty)
                Text(
                  'Dirigente: ${order.ownerName}',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
            ],
          ),
        ),
        if (!started)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: _CountdownCard(canStart: _canStart(order), target: order.dateTime),
          ),
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: SibValColors.navyBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: ServiceOrderReadOnlyBody(order: order, showPraiseDetails: false),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: _actionButtons(order),
        ),
      ],
    );
  }

  Widget _actionButtons(ServiceOrder order) {
    return Column(
      children: [
        if (!order.isFinalized)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: _canStart(order) ? () => _startService(order) : null,
              child: Text(_hasProgress(order) ? 'Continuar Culto' : 'Iniciar Culto'),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            onPressed: () => _openPreview(order),
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
