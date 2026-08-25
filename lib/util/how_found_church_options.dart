/// Opções do campo "Como conheceu a igreja" (cadastro de visitante,
/// `introduction_page.dart`) — lista única, sem categorias visíveis (eram
/// cabeçalhos não selecionáveis num dropdown agrupado, removidos a pedido do
/// usuário: só as opções, direto). "Membro da Igreja" fica em primeiro lugar
/// (pedido do usuário: é o caso mais comum, acesso rápido). `category`
/// continua guardado em cada opção só pra fins de dado gravado
/// (`howFoundCategory`/`howFoundDetail`, ver `lib/models/visitor.dart`),
/// sem afetar mais a ordem/agrupamento exibido. Mesma categoria de
/// incremento que `church_membership_options.dart`.
class HowFoundChurchOption {
  const HowFoundChurchOption({required this.category, required this.detail});

  final String category;
  final String detail;
}

/// Só quando a opção escolhida for esta que o campo "Convidado por" (com
/// sugestão de nomes entre os membros cadastrados) aparece.
const howFoundChurchInvitedByDetail = 'Membro da Igreja';

const howFoundChurchOptions = <HowFoundChurchOption>[
  HowFoundChurchOption(category: 'Indicação', detail: howFoundChurchInvitedByDetail),
  HowFoundChurchOption(category: 'Internet', detail: 'Instagram'),
  HowFoundChurchOption(category: 'Internet', detail: 'Google'),
  HowFoundChurchOption(category: 'Indicação', detail: 'Familiar'),
  HowFoundChurchOption(category: 'Indicação', detail: 'Amigo'),
  HowFoundChurchOption(category: 'Comunidade', detail: 'Evento'),
  HowFoundChurchOption(category: 'Comunidade', detail: 'Convite'),
  HowFoundChurchOption(category: 'Comunidade', detail: 'Culto'),
  HowFoundChurchOption(category: 'Comunidade', detail: 'Evangelismo'),
  HowFoundChurchOption(category: 'Outros', detail: 'Outros'),
];
