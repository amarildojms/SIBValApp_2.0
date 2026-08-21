import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Campo de data usado em todo o app (evento, batismo, membresia, cadastro,
/// filtro de eventos...) — toque abre o calendário nativo do Flutter
/// (`showDatePicker`), que já tem seu próprio ícone de lápis no cabeçalho
/// pra trocar pro modo de digitação manual (com a máscara da data), sem
/// precisar de nada extra deste widget. Chegou a ter um lápis próprio + modo
/// de digitação embutido no campo (21/08/2026), removido em 22/08/2026 a
/// pedido do usuário por duplicar o que o calendário nativo já oferece.
///
/// [decoration] é a base (borda, labelStyle...) usada tanto na tela clara
/// quanto na tela escura de completar perfil via Google — `labelText` e
/// `suffixIcon` são sempre sobrescritos por [label] e pelo ícone de calendário.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.enabled = true,
    this.decoration,
    this.style,
    this.iconColor,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool enabled;
  final InputDecoration? decoration;
  final TextStyle? style;
  final Color? iconColor;

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  Future<void> _openPicker(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? (now.isBefore(firstDate) ? firstDate : (now.isAfter(lastDate) ? lastDate : now));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final baseDecoration = decoration ?? const InputDecoration();
    final textStyle = style ?? TextStyle(color: context.textPrimary);
    return InkWell(
      onTap: enabled ? () => _openPicker(context) : null,
      child: InputDecorator(
        decoration: baseDecoration.copyWith(
          labelText: label,
          suffixIcon: Icon(Icons.calendar_today_outlined, color: iconColor),
        ),
        child: Text(value != null ? _dateFormat.format(value!) : '', style: textStyle),
      ),
    );
  }
}
