import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Selo "Iniciado às HH:mm" (29/08/2026, pedido do usuário) — mostrado assim
/// que chega o horário de início de um evento (`Event.hasStarted`/
/// `Post.hasStarted`), reaproveitado por `event_card.dart` (linha do tempo
/// de eventos pontuais e recorrentes), `event_detail_page.dart` (em cima da
/// imagem) e `post_card.dart` (post do evento no feed "Início").
class EventStartedTag extends StatelessWidget {
  const EventStartedTag({super.key, required this.time});

  final DateTime time;

  static final _timeFormat = DateFormat('HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SibValColors.goldAccent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Iniciado às ${_timeFormat.format(time)}',
        style: const TextStyle(
          color: SibValColors.navyBlueDark,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
