import 'package:flutter/material.dart';

import '../widgets/sibval_app_bar.dart';
import 'home_highlights.dart';

/// Início — painel-resumo (02/09/2026, inspirado num modelo de referência
/// trazido pelo usuário, `NOVO_LAYOUT.jpeg`): grade de acesso rápido + cards
/// "Próximo na Igreja"/"Devocional de Hoje" (`HomeHighlights`). Sem
/// equivalente direto no `HomeFragment.kt` nativo, que só mostrava o feed —
/// esse feed (Mural) virou uma aba própria, ver `mural_page.dart`.
///
/// Renomeado de `HomeFeedPage` (era o Início + o feed juntos numa página só)
/// pra `HomePage` na mesma sessão em que o Mural foi extraído — o nome velho
/// não fazia mais sentido sem o feed aqui dentro.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: SibValAppBar(isHome: true),
      body: SingleChildScrollView(child: HomeHighlights()),
    );
  }
}
