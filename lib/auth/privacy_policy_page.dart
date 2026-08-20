import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tela de Política de Privacidade, aberta a partir do link no checkbox de
/// consentimento em [RegisterPage]. Texto definitivo (19/08/2026), baseado no
/// documento oficial fornecido pela Segunda Igreja Batista em Valparaíso —
/// mesmo conteúdo da versão pública hospedada para o campo de Política de
/// Privacidade da Play Console; qualquer alteração aqui deve ser replicada
/// lá também. A lista de dados coletados (seção 2) foi ampliada em relação
/// ao documento original para citar CPF e os campos eclesiásticos
/// explicitamente (o documento original só os cobria pela frase genérica
/// "informações necessárias para identificação e cadastro") — decisão
/// tomada com o usuário em 19/08/2026 por transparência exigida pela Play
/// Console para dados sensíveis como CPF.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _sections = <_PolicySection>[
    _PolicySection(
      title: 'Introdução',
      body: 'A SEGUNDA IGREJA BATISTA EM VALPARAÍSO, pessoa jurídica de direito '
          'privado, inscrita no CNPJ sob nº 36.862.399/0001-67, doravante '
          'denominada "Igreja", valoriza a privacidade, a segurança e a proteção '
          'dos dados pessoais de seus membros, congregados, visitantes e demais '
          'usuários do aplicativo.\n\n'
          'Esta Política de Privacidade tem por finalidade explicar, de maneira '
          'clara e transparente, como os dados pessoais são coletados, '
          'utilizados, armazenados, protegidos e, quando necessário, '
          'compartilhados por meio do aplicativo da Igreja.\n\n'
          'O tratamento de dados pessoais será realizado em conformidade com a '
          'Lei nº 13.709/2018 — Lei Geral de Proteção de Dados Pessoais (LGPD) e '
          'demais normas aplicáveis.\n\n'
          'Última atualização: 19 de agosto de 2026.',
    ),
    _PolicySection(
      title: '1. Responsável pelo tratamento dos dados',
      body: 'A Segunda Igreja Batista em Valparaíso é responsável pelas decisões '
          'referentes ao tratamento dos dados pessoais realizados no âmbito de '
          'suas atividades e do aplicativo, na qualidade de controladora, quando '
          'aplicável.\n\n'
          'Para assuntos relacionados à privacidade e proteção de dados '
          'pessoais, o usuário poderá entrar em contato pelos seguintes canais:\n'
          'E-mail: sibvalp2@gmail.com\n'
          'Telefone/WhatsApp: (61) 99189-3919\n'
          'Responsável pela privacidade: Pastor Presidente',
    ),
    _PolicySection(
      title: '2. Quais dados poderão ser coletados?',
      body: 'De acordo com as funcionalidades utilizadas pelo usuário, o '
          'aplicativo poderá coletar:\n'
          'nome completo;\n'
          'CPF;\n'
          'data de nascimento;\n'
          'telefone;\n'
          'endereço de e-mail;\n'
          'endereço, cidade e estado;\n'
          'foto de perfil, quando fornecida;\n'
          'dados de membresia (data de membresia, forma de adesão, igreja de '
          'origem, data de batismo, estado civil, ministério e cargo/função);\n'
          'informações necessárias para identificação e cadastro;\n'
          'informações relacionadas à participação em atividades e eventos da '
          'Igreja;\n'
          'informações fornecidas voluntariamente pelo usuário;\n'
          'pedidos de oração enviados pelo usuário;\n'
          'informações relacionadas a inscrições em eventos e atividades;\n'
          'dados técnicos necessários ao funcionamento e à segurança do '
          'aplicativo, tais como informações do dispositivo, registros de acesso '
          'e informações técnicas de conexão.\n\n'
          'A Igreja buscará limitar a coleta aos dados necessários para as '
          'finalidades informadas nesta Política.',
    ),
    _PolicySection(
      title: '3. Cadastro de membros e usuários',
      body: 'O aplicativo poderá disponibilizar uma área destinada ao cadastro e '
          'relacionamento com membros, congregados e demais participantes das '
          'atividades da Igreja.\n\n'
          'Os dados fornecidos poderão ser utilizados para:\n'
          'identificação do usuário;\n'
          'gerenciamento do cadastro;\n'
          'disponibilização das funcionalidades do aplicativo;\n'
          'organização das atividades da Igreja;\n'
          'comunicação relacionada à vida e às atividades da Igreja;\n'
          'gerenciamento de inscrições;\n'
          'segurança do aplicativo;\n'
          'manutenção e atualização dos registros;\n'
          'atendimento às solicitações do usuário.\n\n'
          'A Igreja não utilizará os dados para finalidades incompatíveis com '
          'aquelas informadas ao usuário.',
    ),
    _PolicySection(
      title: '4. Dados relacionados à organização religiosa',
      body: 'Em razão da finalidade do aplicativo, determinados dados poderão '
          'revelar a relação do usuário com a Segunda Igreja Batista em '
          'Valparaíso ou sua participação nas atividades da Igreja.\n\n'
          'A LGPD classifica como dados pessoais sensíveis, entre outros, '
          'aqueles relacionados à convicção religiosa ou à filiação a '
          'organização de caráter religioso.\n\n'
          'Por esse motivo, esses dados receberão tratamento compatível com sua '
          'natureza e serão utilizados somente para finalidades legítimas '
          'relacionadas às atividades da Igreja e demais hipóteses previstas na '
          'legislação.',
    ),
    _PolicySection(
      title: '5. Pedidos de oração',
      body: 'O aplicativo poderá disponibilizar uma área específica para que o '
          'usuário envie pedidos de oração.\n\n'
          'O usuário deverá fornecer somente as informações necessárias e '
          'evitar inserir dados pessoais de terceiros sem autorização.\n\n'
          'Pedidos de oração podem eventualmente conter informações pessoais '
          'sensíveis, inclusive informações relacionadas à saúde, vida familiar '
          'ou outras circunstâncias particulares.\n\n'
          'Por essa razão, recomendamos que o usuário não informe dados '
          'excessivos ou desnecessários.\n\n'
          'Quando um pedido de oração contiver dados pessoais sensíveis, a '
          'Igreja adotará as medidas e a base legal adequadas ao tratamento '
          'dessas informações.\n\n'
          'Os pedidos de oração serão acessíveis somente às pessoas autorizadas '
          'pela Igreja para essa finalidade.',
    ),
    _PolicySection(
      title: '6. Fotos e vídeos',
      body: 'O aplicativo poderá disponibilizar fotografias e outros conteúdos '
          'relacionados aos cultos, eventos, programações e atividades da '
          'Igreja.\n\n'
          'A Igreja adotará medidas para que a utilização de imagens observe a '
          'legislação aplicável e os direitos das pessoas retratadas.\n\n'
          'Quando houver necessidade de autorização específica para utilização '
          'da imagem de determinada pessoa, a Igreja poderá solicitar '
          'autorização própria.\n\n'
          'Caso o usuário identifique uma fotografia sua que considere '
          'inadequada ou cuja utilização queira questionar, poderá entrar em '
          'contato pelos canais de privacidade indicados nesta Política.',
    ),
    _PolicySection(
      title: '7. Aniversariantes',
      body: 'O aplicativo poderá disponibilizar uma área com os aniversariantes '
          'do dia, podendo apresentar informações como:\n'
          'nome;\n'
          'dia e mês de nascimento;\n'
          'fotografia, quando aplicável.\n\n'
          'A inclusão do usuário na lista de aniversariantes deverá observar a '
          'finalidade informada e as opções disponibilizadas no aplicativo.\n\n'
          'Quando necessário, o usuário poderá solicitar a retirada ou alteração '
          'de suas informações por meio dos canais disponibilizados pela '
          'Igreja.\n\n'
          'A Igreja não disponibilizará publicamente informações desnecessárias, '
          'como endereço residencial ou outros dados que não sejam necessários '
          'para essa finalidade.',
    ),
    _PolicySection(
      title: '8. Agenda da Igreja',
      body: 'O aplicativo poderá apresentar informações sobre:\n'
          'cultos;\n'
          'reuniões;\n'
          'congressos;\n'
          'conferências;\n'
          'eventos;\n'
          'cursos;\n'
          'programações;\n'
          'atividades dos ministérios;\n'
          'demais atividades promovidas ou divulgadas pela Igreja.\n\n'
          'A participação em determinadas atividades poderá exigir o '
          'fornecimento de informações adicionais para fins de inscrição e '
          'organização.',
    ),
    _PolicySection(
      title: '9. Devocionais e conteúdo religioso',
      body: 'O aplicativo poderá disponibilizar devocionais, estudos, mensagens, '
          'textos bíblicos e outros conteúdos relacionados à fé cristã e às '
          'atividades da Igreja.\n\n'
          'O acesso a esses conteúdos poderá ocorrer independentemente do '
          'cadastro de determinadas informações pessoais, quando tecnicamente '
          'possível.',
    ),
    _PolicySection(
      title: '10. PIX e ofertas',
      body: 'O aplicativo poderá disponibilizar informações e recursos '
          'destinados a facilitar a realização de dízimos, ofertas e '
          'contribuições, inclusive mediante divulgação da chave PIX oficial da '
          'Igreja.\n\n'
          'O aplicativo poderá direcionar o usuário para ambientes externos ou '
          'serviços financeiros de terceiros.\n\n'
          'A Igreja não solicitará senhas bancárias, códigos de autenticação ou '
          'outras credenciais bancárias por meio do aplicativo.\n\n'
          'O usuário deverá conferir cuidadosamente os dados do destinatário '
          'antes de realizar qualquer transferência.\n\n'
          'Quando uma operação financeira for realizada diretamente por uma '
          'instituição financeira ou plataforma de pagamento, o tratamento dos '
          'dados relacionados à transação também estará sujeito às políticas de '
          'privacidade e segurança daquela instituição.',
    ),
    _PolicySection(
      title: '11. Crianças e adolescentes',
      body: 'A Igreja reconhece a necessidade de proteção especial dos dados '
          'pessoais de crianças e adolescentes.\n\n'
          'O tratamento de dados de crianças e adolescentes será realizado '
          'observando-se o melhor interesse da criança ou do adolescente, '
          'conforme a LGPD e as orientações da Autoridade Nacional de Proteção '
          'de Dados.\n\n'
          'Quando determinada situação exigir autorização do responsável legal, '
          'serão adotados mecanismos adequados para obtenção dessa autorização.\n\n'
          'A Igreja poderá limitar determinadas funcionalidades do aplicativo '
          'para usuários menores de idade sempre que considerar necessário para '
          'sua proteção.\n\n'
          'Informações de crianças e adolescentes não deverão ser '
          'disponibilizadas publicamente sem fundamento adequado e sem a adoção '
          'das medidas de proteção necessárias.',
    ),
    _PolicySection(
      title: '12. Comunicações e notificações',
      body: 'O aplicativo poderá enviar notificações relacionadas a:\n'
          'cultos;\n'
          'eventos;\n'
          'reuniões;\n'
          'alterações de programação;\n'
          'avisos institucionais;\n'
          'atividades da Igreja;\n'
          'devocionais;\n'
          'funcionamento e segurança do aplicativo.\n\n'
          'O usuário poderá controlar as notificações por meio das '
          'configurações do aplicativo ou do dispositivo, quando essa '
          'funcionalidade estiver disponível.\n\n'
          'Comunicações que dependam de consentimento específico serão '
          'tratadas separadamente.',
    ),
    _PolicySection(
      title: '13. Compartilhamento de dados',
      body: 'A Igreja não comercializa dados pessoais de seus usuários.\n\n'
          'Os dados poderão ser compartilhados, quando necessário, com '
          'prestadores de serviços que auxiliem no funcionamento do aplicativo, '
          'tais como:\n'
          'empresa responsável pelo desenvolvimento ou manutenção do '
          'aplicativo;\n'
          'serviços de hospedagem;\n'
          'serviços de armazenamento de dados;\n'
          'serviços de envio de notificações;\n'
          'fornecedores de tecnologia;\n'
          'serviços necessários à segurança da plataforma.\n\n'
          'Também poderá ocorrer compartilhamento quando houver:\n'
          'obrigação legal ou regulatória;\n'
          'determinação de autoridade competente;\n'
          'necessidade de exercício regular de direitos;\n'
          'situação relacionada à proteção da vida ou da integridade física;\n'
          'outra hipótese autorizada pela legislação.\n\n'
          'Quando terceiros tratarem dados em nome da Igreja, serão adotadas '
          'medidas contratuais e administrativas compatíveis com a proteção '
          'dessas informações.',
    ),
    _PolicySection(
      title: '14. Segurança das informações',
      body: 'A Igreja adotará medidas técnicas e administrativas razoáveis para '
          'proteger os dados pessoais contra:\n'
          'acesso não autorizado;\n'
          'perda;\n'
          'destruição;\n'
          'alteração;\n'
          'divulgação indevida;\n'
          'utilização inadequada;\n'
          'tratamento ilícito.\n\n'
          'Apesar das medidas adotadas, nenhum sistema eletrônico é '
          'completamente livre de riscos.\n\n'
          'Na hipótese de incidente de segurança que possa acarretar risco ou '
          'dano relevante aos titulares, a Igreja adotará as providências '
          'cabíveis conforme a legislação aplicável.',
    ),
    _PolicySection(
      title: '15. Prazo de armazenamento',
      body: 'Os dados pessoais serão armazenados pelo período necessário para '
          'cumprir as finalidades para as quais foram coletados.\n\n'
          'Após o encerramento da finalidade, os dados poderão ser eliminados, '
          'ressalvadas as hipóteses em que a conservação seja necessária ou '
          'autorizada pela legislação, inclusive para:\n'
          'cumprimento de obrigação legal ou regulatória;\n'
          'exercício regular de direitos;\n'
          'prevenção de fraudes;\n'
          'preservação de informações necessárias à defesa da Igreja;\n'
          'outras hipóteses previstas em lei.',
    ),
    _PolicySection(
      title: '16. Direitos do usuário',
      body: 'Nos termos da LGPD, o titular dos dados poderá exercer, conforme '
          'aplicável, direitos como:\n'
          'confirmação da existência de tratamento;\n'
          'acesso aos dados;\n'
          'correção de dados incompletos, inexatos ou desatualizados;\n'
          'informações sobre o tratamento;\n'
          'informações sobre compartilhamento;\n'
          'anonimização, bloqueio ou eliminação, quando cabível;\n'
          'eliminação dos dados tratados com base no consentimento, quando '
          'aplicável;\n'
          'revogação do consentimento, quando esta for a base legal utilizada;\n'
          'oposição a determinados tratamentos, quando cabível;\n'
          'demais direitos previstos na legislação.\n\n'
          'As solicitações deverão ser encaminhadas para: sibvalp2@gmail.com\n\n'
          'A Igreja poderá solicitar informações necessárias para confirmar a '
          'identidade do solicitante e evitar que dados pessoais sejam '
          'fornecidos indevidamente a terceiros.',
    ),
    _PolicySection(
      title: '17. Consentimento',
      body: 'Quando o tratamento de dados depender de consentimento, este será '
          'solicitado de maneira livre, informada, específica e destacada.\n\n'
          'O usuário poderá retirar o consentimento quando desejar, sem '
          'comprometer a legalidade dos tratamentos realizados anteriormente '
          'com base naquele consentimento.\n\n'
          'A retirada do consentimento poderá impossibilitar o funcionamento de '
          'determinadas funcionalidades que dependam daquele tratamento.\n\n'
          'A Igreja poderá utilizar outras bases legais previstas na LGPD '
          'quando aplicáveis, não sendo todo tratamento de dados '
          'necessariamente baseado em consentimento.',
    ),
    _PolicySection(
      title: '18. Alterações desta política',
      body: 'Esta Política poderá ser atualizada para refletir alterações na '
          'legislação, nas funcionalidades do aplicativo ou nas atividades da '
          'Igreja.\n\n'
          'Quando houver alterações relevantes, a Igreja poderá comunicar os '
          'usuários por meio do aplicativo ou de outros canais adequados.\n\n'
          'A versão atualizada estará sempre disponível no aplicativo.',
    ),
    _PolicySection(
      title: '19. Legislação aplicável',
      body: 'Esta Política de Privacidade será interpretada de acordo com a '
          'legislação brasileira, especialmente a Lei nº 13.709/2018 — Lei '
          'Geral de Proteção de Dados Pessoais (LGPD) e demais normas '
          'aplicáveis.',
    ),
    _PolicySection(
      title: '20. Contato',
      body: 'SEGUNDA IGREJA BATISTA EM VALPARAÍSO\n'
          'CNPJ: 36.862.399/0001-67\n\n'
          'E-mail: sibvalp2@gmail.com\n'
          'Telefone/WhatsApp: (61) 99189-3919\n'
          'Endereço: Quadra 15, Lote 03, Chácaras Anhanguera A, Avenida '
          'Comercial do Valparaíso II, Valparaíso de Goiás\n'
          'Responsável pela privacidade: Pastor Presidente\n\n'
          'Última atualização: 19 de agosto de 2026.',
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
