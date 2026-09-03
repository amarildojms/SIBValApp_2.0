import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../contribute/pix_offer_page.dart';
import '../models/notice.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Tela cheia de um aviso do Quadro de Avisos (03/09/2026) — destino do toque
/// tanto no painel rotativo da Início quanto na lista de gerenciamento.
/// "Fazer oferta" reaproveita `PixOfferPage` direto, sem duplicar nenhuma
/// lógica de geração de código Pix — ver doc comment de `Notice`.
class NoticeDetailPage extends StatelessWidget {
  const NoticeDetailPage({super.key, required this.notice});

  final Notice notice;

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notice.imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(notice.imageUrl, fit: BoxFit.cover, width: double.infinity),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                      ),
                    ),
                    if (notice.eventDate != null || (notice.eventTime?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.event_outlined, color: SibValColors.goldAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            [
                              if (notice.eventDate != null) _dateFormat.format(notice.eventDate!),
                              if (notice.eventTime?.isNotEmpty ?? false) notice.eventTime!,
                            ].join(' às '),
                            style: TextStyle(
                              color: SibValColors.goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      notice.message,
                      style: TextStyle(color: context.textPrimary, fontSize: 15, height: 1.4),
                    ),
                    if (notice.needsOffering && notice.offerPixKey.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PixOfferPage(
                                description: notice.offerDescription,
                                churchName: notice.offerChurchName,
                                city: notice.offerCity,
                                pixKey: notice.offerPixKey,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.volunteer_activism_outlined),
                          label: const Text('Fazer oferta'),
                        ),
                      ),
                    ],
                    if (notice.requiresRegistration && notice.registrationLink.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => launchUrl(
                            Uri.parse(notice.registrationLink),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: const Text('Inscreva-se'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
