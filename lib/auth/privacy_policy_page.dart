import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tela de Política de Privacidade, aberta a partir do link no checkbox de
/// consentimento em [RegisterPage]. Conteúdo abaixo é um placeholder — trocar
/// pelo texto definitivo da política (revisado juridicamente) assim que
/// disponível, mantendo a estrutura de seções.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _sections = <_PolicySection>[
    _PolicySection(
      title: '1. Introdução',
      body: 'Esta Política de Privacidade descreve como a SIBVal Connect coleta, usa, '
          'armazena e protege os dados pessoais informados no cadastro e no uso do '
          'aplicativo, em conformidade com a Lei Geral de Proteção de Dados (LGPD).',
    ),
    _PolicySection(
      title: '2. Dados coletados',
      body: 'Coletamos dados de identificação (nome, CPF, data de nascimento), '
          'contato (e-mail, telefone, endereço) e dados eclesiásticos (data de '
          'membresia, forma de adesão, igreja de origem, data de batismo, estado '
          'civil, ministério e cargo/função) informados voluntariamente no cadastro.',
    ),
    _PolicySection(
      title: '3. Finalidade do tratamento',
      body: 'Os dados são usados para identificação do membro, gestão da secretaria '
          'da igreja, comunicação institucional e funcionalidades do aplicativo '
          '(como o feed de aniversariantes e pedidos de oração).',
    ),
    _PolicySection(
      title: '4. Compartilhamento',
      body: 'Os dados não são vendidos ou compartilhados com terceiros para fins '
          'comerciais. Podem ser acessados por administradores autorizados da '
          'igreja para as finalidades descritas nesta política.',
    ),
    _PolicySection(
      title: '5. Direitos do titular',
      body: 'Você pode solicitar a qualquer momento a correção, atualização ou '
          'exclusão dos seus dados pessoais, entrando em contato com a secretaria '
          'da igreja.',
    ),
    _PolicySection(
      title: '6. Contato',
      body: 'Dúvidas sobre esta política podem ser enviadas para a secretaria da '
          'igreja pelos canais oficiais de contato.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Política de Privacidade')),
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

class _PolicySection {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;
}
