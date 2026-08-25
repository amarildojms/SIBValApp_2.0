import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/visitor.dart';
import '../theme/app_theme.dart';

/// Cartões/selo reaproveitados entre `ReceptionPage` (lista de hoje) e
/// `ArchivedVisitorsPage` (dias anteriores, agrupados por data) —
/// 25/08/2026, extraído pra não duplicar a UI entre as duas telas.
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

Future<void> _openWhatsApp(String phone) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return;
  final fullNumber = digits.startsWith('55') ? digits : '55$digits';
  final uri = Uri.https('wa.me', '/$fullNumber');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Card com dados completos (Recepção/Pastor) — telefone, quando houver,
/// vira link de WhatsApp. Sem `TextDecoration.underline` (25/08/2026: em
/// algumas fontes/aparelhos — relatado num Samsung — o sublinhado renderizava
/// alto o bastante pra parecer um traço cortando os dígitos); o ícone de
/// balão já indica que é tocável.
class VisitorFullTile extends StatelessWidget {
  const VisitorFullTile({super.key, required this.visitor, this.onDelete});

  final Visitor visitor;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(visitor.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(visitor.church.isEmpty ? 'Não congrega em uma igreja' : visitor.church),
            Text(visitor.firstVisit ? 'Primeira visita' : 'Já visitou antes'),
            if (visitor.phone.isNotEmpty)
              InkWell(
                onTap: () => _openWhatsApp(visitor.phone),
                child: Row(
                  children: [
                    const Icon(Icons.chat_outlined, size: 14, color: SibValColors.goldAccent),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        visitor.phone,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: SibValColors.goldAccent),
                      ),
                    ),
                  ],
                ),
              ),
            if (visitor.createdAt != null)
              Text(_dateFormat.format(visitor.createdAt!), style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: onDelete != null
            ? IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete!(visitor.id),
              )
            : null,
      ),
    );
  }
}

/// Card resumido (Dirigentes) — nome/igreja/primeira visita, sem telefone.
class VisitorSummaryTile extends StatelessWidget {
  const VisitorSummaryTile({super.key, required this.summary});

  final VisitorSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(summary.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.church.isEmpty ? 'Não congrega em uma igreja' : summary.church),
            if (summary.createdAt != null)
              Text(_dateFormat.format(summary.createdAt!), style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: VisitBadge(firstVisit: summary.firstVisit),
      ),
    );
  }
}

/// Selo "Primeira visita"/"Já visitou" com largura fixa — um `Chip` comum
/// encolhe pro tamanho do próprio texto, deixando os dois cards com selos de
/// tamanhos diferentes lado a lado (pedido do usuário, 25/08/2026).
class VisitBadge extends StatelessWidget {
  const VisitBadge({super.key, required this.firstVisit});

  final bool firstVisit;

  static const _width = 116.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: firstVisit
            ? SibValColors.goldAccent.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        firstVisit ? 'Primeira visita' : 'Já visitou',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: context.textPrimary),
      ),
    );
  }
}
