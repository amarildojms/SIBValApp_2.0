import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sibval_app_bar.dart';

/// Placeholder genérico "Em breve" (02/09/2026) — usado pelos ícones da
/// grade de Início que ainda não têm uma tela de verdade por trás (EBD,
/// Agenda, PGMs; ver `home_highlights.dart`). Sem equivalente no nativo —
/// aqui só pra não deixar o ícone sem destino nenhum enquanto a
/// funcionalidade não é implementada.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTitle(title),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.construction_outlined,
                      size: 48,
                      color: context.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Em breve',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Essa funcionalidade ainda está sendo preparada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
