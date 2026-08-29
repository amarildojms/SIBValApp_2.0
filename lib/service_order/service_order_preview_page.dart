import 'package:flutter/material.dart';

import '../models/service_order.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário: "uma maneira do dirigente acessar uma prévia do culto"). Lista
/// somente-leitura de `order.momentOrder` — é a lista de momentos que
/// existia em `ServiceOrderPrecheckPage` antes da 3ª rodada da mesma sessão
/// (removida de lá a pedido do usuário), revivida como tela própria, sempre
/// acessível (sem trava de horário, sem tracking de progresso — é só
/// consulta, não o modo apresentação de `ServiceOrderLivePage`).
class ServiceOrderPreviewPage extends StatelessWidget {
  const ServiceOrderPreviewPage({super.key, required this.order});

  final ServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final items = order.momentOrder;
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle('Prévia — ${serviceOrderDisplayName(order)}'),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum momento cadastrado nesta ordem.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final summary = item.summary(order);
                        final momentNotes = switch (item.type) {
                          ServiceOrderMomentType.welcome => order.welcomeNotes,
                          ServiceOrderMomentType.announcements =>
                            order.announcementsNotes,
                          _ => '',
                        };
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '- ${item.label}',
                                style: const TextStyle(
                                  color: SibValColors.goldAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (summary != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 2),
                                  child: Text(
                                    summary,
                                    style: TextStyle(color: context.textSecondary, fontSize: 13),
                                  ),
                                ),
                              // Anotação livre pro momento "Boas-vindas"/
                              // "Avisos/Comunicações" (28/08/2026, pedido do
                              // usuário) — ver doc comment de
                              // `ServiceOrder.welcomeNotes`/`.announcementsNotes`.
                              if (momentNotes.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 12, top: 2),
                                  child: Text(
                                    momentNotes,
                                    style: TextStyle(color: context.textSecondary, fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
