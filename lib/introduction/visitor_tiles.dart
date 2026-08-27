import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/visitor.dart';
import '../theme/app_theme.dart';
import '../util/how_found_church_options.dart';

/// Cartões/selo reaproveitados entre `IntroductionPage` (lista de hoje) e
/// `ArchivedVisitorsPage` (dias anteriores, agrupados por data) —
/// 25/08/2026, extraído pra não duplicar a UI entre as duas telas.
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

/// Linha "Com: fulano, ciclano" logo abaixo do nome do visitante principal —
/// pedido do usuário (27/08/2026): destacada só em negrito (nome principal
/// junto, ver `_boldTitle`), cor `context.textPrimary` — não
/// `SibValColors.goldAccent` nem branco fixo, porque o card usa fundo branco
/// no tema claro (`cardColor` em `app_theme.dart`) e um branco hardcoded
/// ficaria invisível ali; `textPrimary` já responde ao tema (branco no
/// escuro, escuro no claro), mesma convenção do resto do app. Dentro do
/// `title` do `ListTile` em vez do `subtitle`, pra ficar visualmente colada
/// ao nome em vez de misturada com igreja/telefone/data. Compartilhada entre
/// `VisitorFullTile` (Introdução/Pastor) e `VisitorSummaryTile`
/// (Dirigentes) — os dois enxergam os nomes dos acompanhantes, só o
/// telefone do responsável fica restrito ao card completo.
class _CompanionsLine extends StatelessWidget {
  const _CompanionsLine(this.companions);

  final List<String> companions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        'Com: ${companions.join(', ')}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: context.textPrimary,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Nome do visitante principal em negrito — mesmo destaque da linha de
/// acompanhantes abaixo dele.
Widget _boldTitle(BuildContext context, String name) {
  return Text(
    name,
    style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
  );
}

Future<void> _openWhatsApp(String phone) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return;
  final fullNumber = digits.startsWith('55') ? digits : '55$digits';
  final uri = Uri.https('wa.me', '/$fullNumber');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Card com dados completos (Introdução/Pastor) — telefone, quando houver,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _boldTitle(context, visitor.name),
            if (visitor.companions.isNotEmpty)
              _CompanionsLine(visitor.companions),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visitor.church.isEmpty
                  ? 'Não congrega em uma igreja'
                  : visitor.church,
            ),
            Text(visitor.firstVisit ? 'Primeira visita' : 'Já visitou antes'),
            if (visitor.howFoundDetail.isNotEmpty)
              Text('Como conheceu: ${visitor.howFoundDetail}')
            else if (visitor.howFoundCategory.isNotEmpty)
              Text('Como conheceu: ${visitor.howFoundCategory}'),
            if (visitor.invitedByName.isNotEmpty)
              Text('Convidado por: ${visitor.invitedByName}'),
            if (visitor.phone.isNotEmpty)
              InkWell(
                onTap: () => _openWhatsApp(visitor.phone),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_outlined,
                      size: 14,
                      color: SibValColors.goldAccent,
                    ),
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
              Text(
                _dateFormat.format(visitor.createdAt!),
                style: const TextStyle(fontSize: 11),
              ),
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
      child: Stack(
        children: [
          ListTile(
            // Sem `trailing` — o selo saiu daqui e virou um `Positioned` no
            // canto superior direito do card (pedido do usuário,
            // 27/08/2026). O padding direito reserva o espaço do selo
            // (`VisitBadge._width` + folga) em toda altura do card, não só
            // na primeira linha, pra nome/igreja/como-conheceu nunca
            // ficarem embaixo dele.
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 140, 12),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _boldTitle(context, summary.name),
                if (summary.companions.isNotEmpty)
                  _CompanionsLine(summary.companions),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.church.isEmpty
                      ? 'Não congrega em uma igreja'
                      : summary.church,
                ),
                if (summary.howFoundDetail == howFoundChurchInvitedByDetail)
                  Text('Convidado por: ${summary.invitedByName}')
                else if (summary.howFoundDetail.isNotEmpty)
                  Text('Como conheceu: ${summary.howFoundDetail}')
                else if (summary.howFoundCategory.isNotEmpty)
                  Text('Como conheceu: ${summary.howFoundCategory}'),
                if (summary.createdAt != null)
                  Text(
                    _dateFormat.format(summary.createdAt!),
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: VisitBadge(firstVisit: summary.firstVisit),
          ),
        ],
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
