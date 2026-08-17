import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_preference.dart';

/// Espelha a tela de Tema do app nativo (ThemePreference.kt): claro, escuro
/// ou automático (segue o sistema), aplicado na hora e persistido.
class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: ListView(
        children: [
          _ThemeOption(
            label: 'Automático',
            subtitle: 'Segue o tema do seu aparelho',
            mode: ThemeMode.system,
            groupValue: currentMode,
          ),
          _ThemeOption(
            label: 'Claro',
            mode: ThemeMode.light,
            groupValue: currentMode,
          ),
          _ThemeOption(
            label: 'Escuro',
            mode: ThemeMode.dark,
            groupValue: currentMode,
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends ConsumerWidget {
  const _ThemeOption({required this.label, this.subtitle, required this.mode, required this.groupValue});

  final String label;
  final String? subtitle;
  final ThemeMode mode;
  final ThemeMode groupValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RadioListTile<ThemeMode>(
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: mode,
      groupValue: groupValue,
      onChanged: (value) {
        if (value != null) ref.read(themeModeProvider.notifier).set(value);
      },
    );
  }
}
