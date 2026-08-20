import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tela de Termos de Uso, aberta a partir do link no checkbox de consentimento
/// em [RegisterPage] e [CompleteGoogleProfilePage]. Conteúdo abaixo é um
/// RASCUNHO — diferente da Política de Privacidade (que veio de documento
/// oficial da igreja), este texto ainda não foi revisado juridicamente.
/// Trocar pelo texto definitivo assim que a igreja fornecer um, mantendo a
/// estrutura de seções.
class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  static const _sections = <_TermsSection>[
    _TermsSection(
      title: '1. Aceitação dos termos',
      body: 'Estes Termos de Uso regulam o acesso e a utilização do aplicativo SIBVal '
          'Connect, mantido pela Segunda Igreja Batista em Valparaíso. Ao criar uma '
          'conta ou usar o aplicativo, você declara ter lido, compreendido e '
          'concordado integralmente com estes termos.',
    ),
    _TermsSection(
      title: '2. Quem pode usar o aplicativo',
      body: 'O aplicativo destina-se a membros, congregados e visitantes da Segunda '
          'Igreja Batista em Valparaíso. O cadastro requer capacidade legal para '
          'assumir obrigações; quando realizado em nome de menor de idade, deve ser '
          'feito ou autorizado pelo responsável legal.',
    ),
    _TermsSection(
      title: '3. Cadastro e responsabilidade do usuário',
      body: 'O usuário é responsável pela veracidade, exatidão e atualização dos dados '
          'informados no cadastro, bem como pela guarda de sua senha. Cadastros novos '
          'ficam pendentes de aprovação de um administrador antes da liberação do '
          'acesso, para verificação do vínculo com a igreja.',
    ),
    _TermsSection(
      title: '4. Conteúdo enviado pelo usuário',
      body: 'Ao enviar pedidos de oração, fotos ou outros conteúdos pelo aplicativo, o '
          'usuário garante que tem o direito de compartilhá-los e concorda que esse '
          'conteúdo poderá ser acessado pelas pessoas autorizadas pela igreja para as '
          'finalidades descritas na Política de Privacidade. O usuário não deve '
          'inserir dados pessoais de terceiros sem autorização.',
    ),
    _TermsSection(
      title: '5. Uso apropriado',
      body: 'O aplicativo deve ser usado de forma respeitosa e compatível com sua '
          'finalidade institucional e religiosa. É vedado usá-lo para fins ilícitos, '
          'ofensivos, discriminatórios ou que violem direitos de terceiros.',
    ),
    _TermsSection(
      title: '6. Disponibilidade do serviço',
      body: 'A igreja envida esforços para manter o aplicativo disponível e '
          'funcionando corretamente, mas não garante disponibilidade ininterrupta. '
          'Manutenções, atualizações ou instabilidades técnicas podem causar '
          'indisponibilidade temporária.',
    ),
    _TermsSection(
      title: '7. Suspensão e encerramento de conta',
      body: 'A igreja poderá suspender ou encerrar o acesso de um usuário em caso de '
          'uso indevido do aplicativo, violação destes termos ou a pedido do próprio '
          'usuário, observados os direitos previstos na Política de Privacidade '
          'quanto à conservação e eliminação de dados.',
    ),
    _TermsSection(
      title: '8. Alterações destes termos',
      body: 'Estes Termos de Uso podem ser atualizados periodicamente. A versão '
          'vigente estará sempre disponível dentro do aplicativo. O uso continuado '
          'do aplicativo após uma alteração implica concordância com os novos '
          'termos.',
    ),
    _TermsSection(
      title: '9. Legislação aplicável',
      body: 'Estes Termos de Uso são regidos pela legislação brasileira, sem prejuízo '
          'das disposições da Lei Geral de Proteção de Dados Pessoais (LGPD) '
          'aplicáveis ao tratamento de dados pessoais no aplicativo.',
    ),
    _TermsSection(
      title: '10. Contato',
      body: 'Dúvidas sobre estes Termos de Uso podem ser enviadas para a secretaria da '
          'Segunda Igreja Batista em Valparaíso pelo e-mail sibvalp2@gmail.com ou '
          'pelo WhatsApp (61) 99189-3919.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos de Uso')),
      body: SafeArea(
        bottom: true,
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            for (final section in _sections) ...[
              Text(
                section.title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                section.body,
                style: TextStyle(color: context.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _TermsSection {
  const _TermsSection({required this.title, required this.body});

  final String title;
  final String body;
}
