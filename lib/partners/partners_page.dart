import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha data/model/Partner.kt — lista estática, sem Firestore. Logos
/// adicionados em 20/08/2026 (arquivos enviados pelo usuário).
class _Partner {
  const _Partner(this.name, this.url, this.logoAsset);

  final String name;
  final String url;
  final String logoAsset;
}

const _partners = [
  _Partner(
    'Convenção Batista Brasileira',
    'https://convencaobatista.com.br/site/index.php',
    'assets/images/partners/convencao_batista_brasileira.png',
  ),
  _Partner(
    'Convenção Batista do Planalto Central',
    'https://cbpc.org.br/index',
    'assets/images/partners/convencao_batista_planalto_central.png',
  ),
  _Partner(
    'Ordem dos Pastores Batistas do Brasil',
    'https://opbb.org.br/',
    'assets/images/partners/ordem_pastores_batistas.png',
  ),
  _Partner(
    'Missões Nacionais',
    'https://missoesnacionais.org.br/',
    'assets/images/partners/missoes_nacionais.png',
  ),
  _Partner(
    'Junta de Missões Mundiais',
    'https://missoesmundiais.com.br/',
    'assets/images/partners/missoes_mundiais.png',
  ),
  _Partner(
    'Cristolândia',
    'https://missoesnacionais.org.br/noticias/cristolandia',
    'assets/images/partners/cristolandia.png',
  ),
  _Partner(
    'Rádio 3.16',
    'https://rede316.com.br/',
    'assets/images/partners/rede_316.png',
  ),
];

/// Espelha PartnersFragment.kt/fragment_partners.xml.
class PartnersPage extends StatelessWidget {
  const PartnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ScreenTitle('Vínculos Institucionais'),
          Text(
            'Conheça as instituições às quais somos filiados. Toque em cada uma para visitar seu site.',
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          for (final partner in _partners)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.asset(partner.logoAsset, fit: BoxFit.contain),
                  ),
                ),
                title: Text(partner.name),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(Uri.parse(partner.url), mode: LaunchMode.externalApplication),
              ),
            ),
        ],
        ),
      ),
    );
  }
}
