import 'package:cloud_firestore/cloud_firestore.dart';

/// Papéis configuráveis (sibval_app_2.0, 03/09/2026) — antes cada papel
/// (Secretaria, Mídia, Dirigentes...) e o que ele concedia eram hardcoded em
/// `UserRole` (removido de `app_user.dart`) e em `CurrentUserProfile`. Agora
/// o admin cria/renomeia/exclui papéis livremente em `ManageRolesPage`
/// (`lib/admin/manage_roles_page.dart`) e escolhe, por papel, quais das
/// capacidades abaixo ele concede.
///
/// A lista de capacidades possíveis continua fixa — exige código novo pra
/// crescer (cada uma corresponde a um ponto real de checagem em alguma tela
/// ou coleção do Firestore, ver `firestore.rules`/`hasCapability`) — só a
/// associação papel→capacidades é dado, não código.
abstract final class Capability {
  static const viewPrayerRequests = 'view_prayer_requests';
  static const manageBirthdays = 'manage_birthdays';
  static const manageEventos = 'manage_eventos';
  static const manageGallery = 'manage_gallery';
  static const managePublications = 'manage_publications';
  static const registerVisitors = 'register_visitors';
  static const viewVisitorSummaries = 'view_visitor_summaries';
  static const viewVisitorDetails = 'view_visitor_details';
  static const manageServiceOrders = 'manage_service_orders';
  static const viewPraiseOrder = 'view_praise_order';
  static const manageLeaderSchedule = 'manage_leader_schedule';
  static const viewLeaderSchedule = 'view_leader_schedule';

  /// Instrumentista (04/09/2026, pedido do usuário) — distinto do papel
  /// Louvor (`viewPraiseOrder`, acesso ao Ministério de Louvor inteiro):
  /// controla só se a Ordem de Culto abre a cifra (em vez da letra) ao tocar
  /// numa música do momento "Louvor" — ver
  /// `CurrentUserProfile.isInstrumentista`,
  /// `ServiceOrderReadOnlyBody._detailRowsFor` e
  /// `ServiceOrderLivePage._subActionsFor`.
  static const instrumentista = 'instrumentista';

  /// Diaconia (04/09/2026, pedido do usuário) — recebe/confirma doações de
  /// alimento e Pix da campanha "Doe para Cestas Básicas" (e demais
  /// campanhas configuráveis) — painel `BasketDiaconiaDashboardPage`, marca
  /// entrega de alimento e também pode confirmar Pix (mesma ação que
  /// Tesouraria). Também gerencia o catálogo/configuração de uma campanha já
  /// existente — ver `CurrentUserProfile.canManageBasketDonations`.
  static const manageBasketDonations = 'manage_basket_donations';

  /// Tesouraria (04/09/2026, pedido do usuário) — confirma que uma doação
  /// via Pix de fato caiu na conta do banco; mesma ação de confirmação que
  /// Diaconia também pode fazer (não é uma aprovação em duas etapas
  /// obrigatórias) — ver `CurrentUserProfile.canConfirmBasketPix`.
  static const confirmBasketPix = 'confirm_basket_pix';

  /// Ordem de exibição em `ManageRolesPage`.
  static const all = <(String id, String label)>[
    (viewPrayerRequests, 'Ver pedidos de oração'),
    (manageBirthdays, 'Gerenciar aniversariantes'),
    (manageEventos, 'Gerenciar eventos'),
    (manageGallery, 'Gerenciar galeria de fotos'),
    (managePublications, 'Gerenciar publicações (devocionais, Mural, Quadro de Avisos)'),
    (registerVisitors, 'Cadastrar visitantes (Introdução)'),
    (viewVisitorSummaries, 'Ver resumo de visitantes'),
    (viewVisitorDetails, 'Ver detalhes completos de visitantes'),
    (manageServiceOrders, 'Gerenciar Ordem de Culto'),
    (viewPraiseOrder, 'Ver Ordem de Culto (Ministério de Louvor)'),
    (manageLeaderSchedule, 'Gerenciar Escala de Dirigentes'),
    (viewLeaderSchedule, 'Ver Escala de Dirigentes'),
    (instrumentista, 'Ver cifra na Ordem de Culto (Instrumentista)'),
    (manageBasketDonations, 'Receber/confirmar doações de cestas (Diaconia)'),
    (confirmBasketPix, 'Confirmar Pix recebido de doações (Tesouraria)'),
  ];

  static String labelFor(String id) =>
      all.firstWhere((c) => c.$1 == id, orElse: () => (id, id)).$2;
}

class AppRole {
  final String id;
  final String label;
  final List<String> capabilities;

  const AppRole({
    required this.id,
    required this.label,
    required this.capabilities,
  });

  factory AppRole.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppRole(
      id: doc.id,
      label: data['label'] as String? ?? doc.id,
      capabilities: List<String>.from(data['capabilities'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {'label': label, 'capabilities': capabilities};

  AppRole copyWith({String? label, List<String>? capabilities}) => AppRole(
        id: id,
        label: label ?? this.label,
        capabilities: capabilities ?? this.capabilities,
      );
}

/// Papéis pré-existentes antes desta mudança (03/09/2026) — semeados com as
/// mesmas capacidades que já tinham hardcoded, pra ninguém perder acesso na
/// migração. IDs mantidos de propósito: `SIBValApp2/functions/index.js`
/// (`syncMemberMinistryRoles`, que concede/revoga `introducao`/`dirigentes`
/// automaticamente por ministério) e qualquer `users.roles` já gravado
/// continuam funcionando sem backfill. Só usado por
/// `RoleRepository.seedDefaultsIfEmpty`.
const defaultAppRoles = <AppRole>[
  AppRole(id: 'secretaria', label: 'Secretaria', capabilities: [Capability.manageBirthdays]),
  AppRole(id: 'midia', label: 'Mídia', capabilities: [Capability.manageGallery]),
  AppRole(id: 'intercessao', label: 'Intercessão', capabilities: [Capability.viewPrayerRequests]),
  AppRole(id: 'eventos', label: 'Eventos', capabilities: [Capability.manageEventos]),
  AppRole(id: 'publicacoes', label: 'Publicações', capabilities: [Capability.managePublications]),
  AppRole(id: 'introducao', label: 'Introdução', capabilities: [Capability.registerVisitors]),
  AppRole(
    id: 'dirigentes',
    label: 'Dirigentes',
    capabilities: [
      Capability.viewVisitorSummaries,
      Capability.manageServiceOrders,
      Capability.viewLeaderSchedule,
    ],
  ),
  AppRole(
    id: 'pastor',
    label: 'Pastor',
    capabilities: [
      Capability.viewVisitorDetails,
      Capability.manageLeaderSchedule,
      Capability.viewLeaderSchedule,
    ],
  ),
  AppRole(id: 'louvor', label: 'Louvor', capabilities: [Capability.viewPraiseOrder]),
  // "Instrumentista" (04/09/2026, pedido do usuário) NÃO entra aqui de
  // propósito — [defaultAppRoles] só semeia numa instalação nova, e a
  // coleção `roles` desta base já não está mais vazia (não tem efeito
  // nenhum acrescentar aqui). Pra ganhar este papel em produção, o admin
  // cria "Instrumentista" manualmente em "Gerenciar Perfis de Acesso"
  // (`ManageRolesPage`) e marca a capacidade [Capability.instrumentista].
];
