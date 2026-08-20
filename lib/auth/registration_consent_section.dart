import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'privacy_policy_page.dart';
import 'terms_of_use_page.dart';

/// Bloco de declaração e consentimento LGPD exibido no fim do formulário de
/// cadastro (`register_page.dart` e `complete_google_profile_page.dart`) —
/// extraído para evitar duplicar o mesmo texto/lógica nas duas telas, como já
/// acontece com `cpf_phone_input.dart`. Termos de Uso e Política de
/// Privacidade são obrigatórios para habilitar o cadastro; o consentimento de
/// comunicações é opcional — exigi-lo travaria um consentimento que a própria
/// Política de Privacidade (seção 17) define como devendo ser "livre", já que
/// não é essencial para o funcionamento básico da conta.
class RegistrationConsentSection extends StatelessWidget {
  const RegistrationConsentSection({
    super.key,
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.acceptedCommunications,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onCommunicationsChanged,
    this.enabled = true,
    this.dark = false,
  });

  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool acceptedCommunications;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<bool> onCommunicationsChanged;
  final bool enabled;

  /// Tela de completar perfil via Google usa fundo azul-marinho fixo com
  /// texto branco, independente do tema do app — mesma exceção documentada
  /// em `complete_google_profile_page.dart`.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final headingColor = dark ? Colors.white : context.textPrimary;
    final bodyColor = dark ? Colors.white70 : context.textSecondary;
    final linkColor = SibValColors.goldAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cadastro no Aplicativo',
          style: TextStyle(color: headingColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Ao realizar seu cadastro, você declara estar ciente e de acordo com o '
          'tratamento dos dados pessoais fornecidos, nos termos da Lei Geral de '
          'Proteção de Dados Pessoais (LGPD – Lei nº 13.709/2018) e demais normas '
          'aplicáveis.',
          style: TextStyle(color: bodyColor, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          'Seus dados serão utilizados para possibilitar o cadastro, identificação '
          'do usuário, acesso às funcionalidades do aplicativo, comunicação '
          'relacionada às atividades da igreja e cumprimento de obrigações legais, '
          'quando aplicável.',
          style: TextStyle(color: bodyColor, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          'Antes de concluir o cadastro, leia atentamente os documentos abaixo:',
          style: TextStyle(color: bodyColor, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 4),
        _SelectAllRow(
          allAccepted: acceptedTerms && acceptedPrivacy && acceptedCommunications,
          anyAccepted: acceptedTerms || acceptedPrivacy || acceptedCommunications,
          enabled: enabled,
          dark: dark,
          onChanged: (value) {
            onTermsChanged(value);
            onPrivacyChanged(value);
            onCommunicationsChanged(value);
          },
        ),
        _ConsentCheckbox(
          value: acceptedTerms,
          onChanged: onTermsChanged,
          enabled: enabled,
          dark: dark,
          text: TextSpan(
            style: TextStyle(color: bodyColor, fontSize: 14),
            children: [
              const TextSpan(text: 'Li e concordo com os '),
              TextSpan(
                text: 'Termos de Uso do Aplicativo',
                style: TextStyle(color: linkColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
                      ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        _ConsentCheckbox(
          value: acceptedPrivacy,
          onChanged: onPrivacyChanged,
          enabled: enabled,
          dark: dark,
          text: TextSpan(
            style: TextStyle(color: bodyColor, fontSize: 14),
            children: [
              const TextSpan(text: 'Li e estou ciente da '),
              TextSpan(
                text: 'Política de Privacidade',
                style: TextStyle(color: linkColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                      ),
              ),
              const TextSpan(
                text: ' e do tratamento dos meus dados pessoais, conforme as finalidades nela descritas.',
              ),
            ],
          ),
        ),
        _ConsentCheckbox(
          value: acceptedCommunications,
          onChanged: onCommunicationsChanged,
          enabled: enabled,
          dark: dark,
          text: TextSpan(
            style: TextStyle(color: bodyColor, fontSize: 14),
            children: const [
              TextSpan(
                text: 'Autorizo o recebimento de comunicações da igreja pelo aplicativo, '
                    'incluindo avisos, programações, eventos, atividades, notícias, '
                    'informações relacionadas à vida da igreja, a divulgação do meu '
                    'aniversário e meus pedidos de oração e a exposição de fotos minhas.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ao prosseguir, você confirma que as informações fornecidas são verdadeiras '
          'e que possui capacidade legal para realizar o cadastro. Caso o cadastro '
          'seja realizado em nome de menor de idade, o responsável legal deverá '
          'realizar ou autorizar o cadastro, conforme as condições estabelecidas pela '
          'legislação aplicável.',
          style: TextStyle(color: bodyColor, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          'O usuário poderá exercer os direitos previstos na LGPD, incluindo '
          'solicitar informações sobre o tratamento de seus dados, correção, '
          'atualização e, quando aplicável, eliminação ou revogação de '
          'consentimentos, observadas as hipóteses legais que autorizam ou obrigam '
          'a conservação dos dados.',
          style: TextStyle(color: bodyColor, fontSize: 12.5, height: 1.4),
        ),
      ],
    );
  }
}

/// Checkbox "marcar todas" acima das três opções — tristate: marcado quando
/// as três estão aceitas, indeterminado quando só parte está, desmarcado
/// quando nenhuma está. Tocar sempre alterna entre "aceitar as três" e
/// "desmarcar as três", em vez de seguir o ciclo padrão do tristate.
class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({
    required this.allAccepted,
    required this.anyAccepted,
    required this.enabled,
    required this.dark,
    required this.onChanged,
  });

  final bool allAccepted;
  final bool anyAccepted;
  final bool enabled;
  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final labelColor = dark ? Colors.white : context.textPrimary;
    return InkWell(
      onTap: enabled ? () => onChanged(!allAccepted) : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            tristate: true,
            value: allAccepted ? true : (anyAccepted ? null : false),
            fillColor: dark
                ? WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? SibValColors.goldAccent : Colors.transparent,
                  )
                : null,
            checkColor: dark ? SibValColors.navyBlueDark : null,
            side: dark ? const BorderSide(color: Colors.white70) : null,
            onChanged: enabled ? (_) => onChanged(!allAccepted) : null,
          ),
          Text(
            'Marcar todas as opções',
            style: TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.text,
    required this.enabled,
    required this.dark,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final TextSpan text;
  final bool enabled;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            fillColor: dark
                ? WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? SibValColors.goldAccent : Colors.transparent,
                  )
                : null,
            checkColor: dark ? SibValColors.navyBlueDark : null,
            side: dark ? const BorderSide(color: Colors.white70) : null,
            onChanged: enabled ? (checked) => onChanged(checked ?? false) : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichText(text: text),
            ),
          ),
        ],
      ),
    );
  }
}
