import 'package:flutter/material.dart';

// Paleta reaproveitada de app/src/main/res/values/colors.xml do app Android original.
class SibValColors {
  static const navyBlue = Color(0xFF1B275B);
  static const navyBlueLight = Color(0xFF2E5E8A);
  static const navyBlueDark = Color(0xFF0A1D24);
  static const goldAccent = Color(0xFFC58C38);
}

/// Os dois temas (claro/escuro) — espelha o suporte a tema do app nativo, que
/// usa atributos de Material Theme (`?attr/colorOnSurface` etc.) em vez de
/// cores fixas, permitindo trocar de tema sem trocar o layout. Aqui, o
/// cabeçalho (AppBar) e a barra inferior continuam sempre no navy/dourado da
/// marca nos dois temas — só o conteúdo das páginas (fundo, texto, cards)
/// muda entre claro e escuro.
abstract final class AppTheme {
  static final dark = _build(
    colorScheme: const ColorScheme.dark(
      primary: SibValColors.goldAccent,
      onPrimary: SibValColors.navyBlueDark,
      surface: SibValColors.navyBlue,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white70,
      outline: Colors.white38,
      outlineVariant: Colors.white24,
      surfaceContainerHighest: SibValColors.navyBlueLight,
    ),
    scaffoldBackground: SibValColors.navyBlueDark,
    cardColor: SibValColors.navyBlueLight,
  );

  static final light = _build(
    colorScheme: const ColorScheme.light(
      primary: SibValColors.goldAccent,
      onPrimary: SibValColors.navyBlueDark,
      surface: Colors.white,
      onSurface: SibValColors.navyBlueDark,
      onSurfaceVariant: Color(0xFF5C6B72),
      outline: Color(0xFF8A9AA1),
      outlineVariant: Color(0xFFD8DEE1),
      surfaceContainerHighest: Color(0xFFEDEDED),
    ),
    scaffoldBackground: const Color(0xFFF6F5F2),
    cardColor: Colors.white,
  );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      cardColor: cardColor,
      cardTheme: CardThemeData(color: cardColor),
      dividerColor: colorScheme.outlineVariant,
      appBarTheme: const AppBarTheme(
        backgroundColor: SibValColors.navyBlue,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SibValColors.navyBlue,
        indicatorColor: SibValColors.goldAccent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? SibValColors.navyBlueDark : Colors.white70,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SibValColors.goldAccent,
          foregroundColor: SibValColors.navyBlueDark,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(bodyColor: colorScheme.onSurface, displayColor: colorScheme.onSurface),
    );
  }
}

/// Atalhos pra não repetir `Theme.of(context).colorScheme...` em toda tela —
/// usados no lugar das cores fixas (Colors.white/white70/white38) que só
/// funcionavam no tema escuro original.
extension AppColors on BuildContext {
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get textTertiary => Theme.of(this).colorScheme.outline;
}

/// Título de tela dentro do corpo — a SibValAppBar nunca mostra texto (só a
/// logo), então cada tela mostra seu próprio título aqui, igual ao nativo
/// (ex.: "Devocionais" em dourado no topo do conteúdo).
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(color: SibValColors.goldAccent, fontWeight: FontWeight.bold, fontSize: 19),
      ),
    );
  }
}
