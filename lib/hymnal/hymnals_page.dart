import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'hymn_list_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). "Hinários" agrupa Cantor Cristão e HCC, que antes eram dois
/// tiles separados no menu Mais — agora um só ("Hinários") abre esta tela
/// de escolha.
class HymnalsPage extends StatelessWidget {
  const HymnalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Hinários'),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: Image.asset('assets/icons/ic_cc.png', width: 30, height: 30),
                    title: Text('Cantor Cristão', style: TextStyle(color: context.textPrimary)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HymnListPage(hymnal: Hymnal.cantorCristao),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Image.asset('assets/icons/ic_hcc.png', width: 30, height: 30),
                    title: Text('HCC', style: TextStyle(color: context.textPrimary)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HymnListPage(hymnal: Hymnal.hinarioCristao),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
