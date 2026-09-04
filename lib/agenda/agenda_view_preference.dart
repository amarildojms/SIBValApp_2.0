import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visualização do calendário da Agenda — Agenda (schedule)/Dia/Semana/Mês.
enum AgendaViewMode {
  agenda('Agenda', Icons.view_agenda_outlined),
  day('Dia', Icons.view_day_outlined),
  week('Semana', Icons.view_week_outlined),
  month('Mês', Icons.calendar_view_month_outlined);

  const AgendaViewMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _prefsKey = 'agenda_view_mode';

/// Lembra a última visualização escolhida na Agenda (03/09/2026, 2ª rodada,
/// pedido do usuário: "O layout da agenda escolhido pelo usuário, deve
/// ficar memorizado e sempre abrir como ele deixou da última vez") — mesmo
/// padrão de `ThemeModeNotifier` (`lib/theme/theme_preference.dart`).
class AgendaViewModeNotifier extends Notifier<AgendaViewMode> {
  @override
  AgendaViewMode build() {
    _load();
    return AgendaViewMode.agenda;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == null) return;
    state = AgendaViewMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => AgendaViewMode.agenda,
    );
  }

  Future<void> set(AgendaViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final agendaViewModeProvider =
    NotifierProvider<AgendaViewModeNotifier, AgendaViewMode>(AgendaViewModeNotifier.new);
