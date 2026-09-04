import 'package:flutter/material.dart';

/// Mesmo `showTimePicker` do Flutter, forçando o mostrador em formato 24h
/// (`alwaysUse24HourFormat: true`) independente da configuração de
/// data/hora do aparelho — o app inteiro exibe horário em 24h (`HH:mm`,
/// `DateFormat('HH:mm', 'pt_BR')`) em toda tela, mas o seletor do sistema
/// respeitava a preferência 12h/24h do Android, então um aparelho com "usar
/// formato de 12 horas" ligado mostrava AM/PM só no picker, inconsistente
/// com o resto do app (03/09/2026, pedido do usuário). Ponto único
/// reaproveitado por todo `showTimePicker` do app.
Future<TimeOfDay?> showTimePicker24h({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      );
    },
  );
}
