/// Espelha RecurringEventUtils.kt — rótulos de dia da semana (1=domingo,
/// igual a java.util.Calendar) e de antecedência de lembrete.
String weekdayLabel(int weekday) => switch (weekday) {
  1 => 'Domingo',
  2 => 'Segunda-feira',
  3 => 'Terça-feira',
  4 => 'Quarta-feira',
  5 => 'Quinta-feira',
  6 => 'Sexta-feira',
  7 => 'Sábado',
  _ => '',
};

/// Segunda a sábado, domingo por último — mesma ordem de WEEKDAY_ORDER no nativo.
const weekdayOrder = [2, 3, 4, 5, 6, 7, 1];

const weekdayLabels = [
  (2, 'Segunda-feira'),
  (3, 'Terça-feira'),
  (4, 'Quarta-feira'),
  (5, 'Quinta-feira'),
  (6, 'Sexta-feira'),
  (7, 'Sábado'),
  (1, 'Domingo'),
];

String reminderLeadLabel(int minutes) => switch (minutes) {
  30 => '30 minutos antes',
  120 => '2 horas antes',
  240 => '4 horas antes',
  360 => '6 horas antes',
  480 => '8 horas antes',
  720 => '12 horas antes',
  1440 => '1 dia antes',
  4320 => '3 dias antes',
  10080 => '1 semana antes',
  _ => '$minutes minutos antes',
};

const reminderLeadPresets = [30, 120, 240, 360, 480, 720, 1440, 4320, 10080];

const reminderLeadLabels = [
  (30, '30 minutos antes'),
  (120, '2 horas antes'),
  (240, '4 horas antes'),
  (360, '6 horas antes'),
  (480, '8 horas antes'),
  (720, '12 horas antes'),
  (1440, '1 dia antes'),
  (4320, '3 dias antes'),
  (10080, '1 semana antes'),
];
