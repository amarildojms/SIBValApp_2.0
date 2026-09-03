import 'package:cloud_firestore/cloud_firestore.dart';

/// Um aviso do Quadro de Avisos (03/09/2026, pedido do usuário, sem
/// equivalente no nativo) — cadastrado por quem tem `canManagePublications`
/// (papel Publicações ou admin), exibido num painel rotativo na Início
/// (`_NoticesCard`, `home_highlights.dart`) e em detalhe completo ao tocar
/// (`NoticeDetailPage`).
///
/// [offerPixKey]/[offerDescription]/[offerChurchName]/[offerCity] (quando
/// [needsOffering] é `true`) são um retrato — não uma referência viva — de
/// uma `PixEntry` escolhida na Contribua no momento do cadastro (via
/// `_OfferPickerSheet`, `notice_form_page.dart`): `PixEntry` não tem um id
/// estável (só posição numa lista), então editar/excluir a chave na
/// Contribua depois não afeta avisos já publicados. Preenchidos, dão pra
/// abrir `PixOfferPage` direto do aviso, sem duplicar nenhuma lógica de
/// geração de código Pix.
class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl = '',
    this.storagePath = '',
    this.needsOffering = false,
    this.offerPixKey = '',
    this.offerDescription = '',
    this.offerChurchName = '',
    this.offerCity = '',
    this.requiresRegistration = false,
    this.registrationLink = '',
    this.eventDateMillis,
    this.eventTime,
    required this.createdByUid,
    required this.createdByName,
    this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String imageUrl;
  final String storagePath;
  final bool needsOffering;
  final String offerPixKey;
  final String offerDescription;
  final String offerChurchName;
  final String offerCity;

  /// "Requer inscrição" (03/09/2026, pedido do usuário) — mesmo par de campos
  /// já usado em `Event.requiresRegistration`/`registrationLink`
  /// (`event_form_page.dart`), reaproveitado aqui pelo mesmo nome.
  final bool requiresRegistration;
  final String registrationLink;

  /// Data/horário do que o aviso anuncia (03/09/2026, pedido do usuário: "no
  /// cadastro de quadro de avisos acrescente os campos data e horários"),
  /// ambos opcionais e independentes um do outro — não é a data em que o
  /// aviso foi publicado (isso é [createdAt]). [eventTime] fica em texto
  /// livre "HH:mm" (mesmo formato de exibição do resto do app) porque um
  /// horário sem data (ou vice-versa) precisa continuar representável.
  final int? eventDateMillis;
  final String? eventTime;
  final String createdByUid;
  final String createdByName;
  final DateTime? createdAt;

  DateTime? get eventDate => eventDateMillis != null
      ? DateTime.fromMillisecondsSinceEpoch(eventDateMillis!)
      : null;

  factory Notice.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Notice(
      id: doc.id,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      needsOffering: data['needsOffering'] as bool? ?? false,
      offerPixKey: data['offerPixKey'] as String? ?? '',
      offerDescription: data['offerDescription'] as String? ?? '',
      offerChurchName: data['offerChurchName'] as String? ?? '',
      offerCity: data['offerCity'] as String? ?? '',
      requiresRegistration: data['requiresRegistration'] as bool? ?? false,
      registrationLink: data['registrationLink'] as String? ?? '',
      eventDateMillis: (data['eventDateMillis'] as num?)?.toInt(),
      eventTime: data['eventTime'] as String?,
      createdByUid: data['createdByUid'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'message': message,
    'imageUrl': imageUrl,
    'storagePath': storagePath,
    'needsOffering': needsOffering,
    'offerPixKey': offerPixKey,
    'offerDescription': offerDescription,
    'offerChurchName': offerChurchName,
    'offerCity': offerCity,
    'requiresRegistration': requiresRegistration,
    'registrationLink': registrationLink,
    'eventDateMillis': eventDateMillis,
    'eventTime': eventTime,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
  };
}
