import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Formatador de contagem regressiva por extenso — "N dias, N horas, N
/// minutos e N segundos", omitindo as unidades maiores que já zeraram (ex.:
/// faltando 40 minutos, mostra só "40 minutos e 12 segundos", sem "0 dias, 0
/// horas"). Extraído de `ServiceOrderPrecheckPage._CountdownCard`
/// (28/08/2026) pra ser reaproveitado também por
/// `ServiceOrderMemberViewPage` (28/08/2026, pedido do usuário — timer da
/// visão dos demais membros/visitantes).
String formatServiceOrderCountdown(Duration d) {
  String plural(int n, String singular, String plural) =>
      n == 1 ? singular : plural;

  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;

  final parts = <String>[];
  if (days > 0) parts.add('$days ${plural(days, "dia", "dias")}');
  if (days > 0 || hours > 0) {
    parts.add('$hours ${plural(hours, "hora", "horas")}');
  }
  if (days > 0 || hours > 0 || minutes > 0) {
    parts.add('$minutes ${plural(minutes, "minuto", "minutos")}');
  }
  parts.add('$seconds ${plural(seconds, "segundo", "segundos")}');

  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} e ${parts.last}';
}

/// Janela de visualização antecipada da Ordem de Culto (29/08/2026, pedido
/// do usuário) — Louvor, admin e o próprio dono da ordem podem visualizar o
/// conteúdo completo a partir de 2 horas antes do horário marcado (antes só
/// Louvor/admin tinham essa visão, com 1 hora de antecedência). Compartilhado
/// entre `ServiceOrderPraiseViewPage` (Louvor/admin) e
/// `ServiceOrderPrecheckPage` (dono) — o dono continua só podendo marcar
/// momento como concluído depois de tocar "Iniciar Culto", esta janela só
/// libera a leitura.
bool isServiceOrderViewableEarly(DateTime dateTime) =>
    !DateTime.now().isBefore(dateTime.subtract(const Duration(hours: 2)));

/// Card com o contador regressivo — usado por `ServiceOrderMemberViewPage`
/// (28/08/2026, pedido do usuário: visão dos demais membros/visitantes).
/// [label] é o texto acima do número, [value] é o texto central (contagem
/// ou uma mensagem fixa, ex. "Aguardando o dirigente iniciar..." quando o
/// relógio já bateu mas o dirigente ainda não tocou em "Iniciar Culto").
class ServiceOrderCountdownCard extends StatelessWidget {
  const ServiceOrderCountdownCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            value,
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
