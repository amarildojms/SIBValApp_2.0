import 'package:intl/intl.dart';

/// Espelha app/src/main/java/com/sibval/app/util/WeekdayFormat.kt: nome do dia
/// da semana em português, com a primeira letra maiúscula.
abstract final class WeekdayFormat {
  static final _abbreviated = DateFormat('EEE', 'pt_BR');
  static final _full = DateFormat('EEEE', 'pt_BR');

  static String abbreviated(DateTime date) => _capitalize(_abbreviated.format(date).replaceAll('.', ''));

  static String full(DateTime date) => _capitalize(_full.format(date));

  static String _capitalize(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
