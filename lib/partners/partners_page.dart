import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Espelha data/model/Partner.kt — lista estática, sem Firestore.
class _Partner {
  const _Partner(this.name, this.url);

  final String name;
  final String url;
}

const _partners = [
  _Partner('Convenção Batista Brasileira', 'https://convencaobatista.com.br/site/index.php'),
  _Partner('Convenção Batista do Planalto Central', 'https://cbpc.org.br/index'),
  _Partner('Ordem dos Pastores Batistas do Brasil', 'https://opbb.org.br/'),
  _Partner('Missões Nacionais', 'https://missoesnacionais.org.br/'),
  _Partner('Junta de Missões Mundiais', 'https://missoesmundiais.com.br/'),
  _Partner('Cristolândia', 'https://missoesnacionais.org.br/noticias/cristolandia'),
  _Partner('Rádio 3.16', 'https://rede316.com.br/'),
];

/// Espelha PartnersFragment.kt/fragment_partners.xml.
class PartnersPage extends StatelessWidget {
  const PartnersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vínculos Institucionais')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Conheça as instituições às quais somos filiados. Toque em cada uma para visitar seu site.',
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          for (final partner in _partners)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(partner.name),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => launchUrl(Uri.parse(partner.url), mode: LaunchMode.externalApplication),
              ),
            ),
        ],
      ),
    );
  }
}
