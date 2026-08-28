import 'package:cloud_firestore/cloud_firestore.dart';

/// Que tipo de dado um "momento adicional" coleta quando o dirigente escolhe
/// incluí-lo numa ordem (28/08/2026, pedido do usuário) — definido pelo
/// admin ao cadastrar/editar o momento no catálogo. `none` é um momento sem
/// dado próprio (só o nome, como já era antes desta rodada); os demais
/// deixam o catálogo flexível o bastante pra cobrir "mais um momento de
/// Louvor" ou "mais uma Leitura bíblica" avulsa, sem precisar mexer no
/// cadastro fixo — o dirigente preenche o campo certo ao adicionar
/// (`ServiceOrderFormPage._pickExtraMoments`/`_ExtraMomentPickerSheet`), e
/// `ServiceOrderLivePage` sabe exibir/abrir cada tipo (`ServiceOrderItem.summary`,
/// sub-ação de leitura bíblica pra `bibleReference`).
enum ExtraMomentFieldKind {
  none,
  name,
  names,
  bibleReference;

  static ExtraMomentFieldKind fromName(String? value) =>
      ExtraMomentFieldKind.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ExtraMomentFieldKind.none,
      );

  String get label => switch (this) {
    ExtraMomentFieldKind.none => 'Nenhum (só o nome do momento)',
    ExtraMomentFieldKind.name => 'Um nome (ex.: nome do recém-nascido)',
    ExtraMomentFieldKind.names => 'Vários nomes (ex.: batizandos)',
    ExtraMomentFieldKind.bibleReference => 'Texto bíblico',
  };
}

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Catálogo administrável de "momentos adicionais" (renomeado de
/// "momentos especiais" na mesma sessão) que o dirigente pode inserir
/// avulsamente numa Ordem de Culto, tipo Batismo/Ceia do Senhor/
/// Apresentação de bebê — ou até um Louvor/Leitura bíblica extra, além dos
/// já padrão.
///
/// Gerenciado no botão "Configurar" de `ServiceOrderListPage`
/// (`manage_service_order_moments_page.dart`, seção "Momentos Adicionais").
/// `isDefault` marca o momento como parte da sequência padrão de toda ordem
/// de culto nova — junto com os 16 momentos fixos (`ServiceOrderMomentType`),
/// essa marcação entra em `settings/serviceOrderMomentOrder` como um token
/// `"extra:<id>"` (ver `ServiceOrderMomentOrderRepository`/
/// `resolveServiceOrderMomentTemplate`). `fieldKind` (mesma sessão) define
/// que dado o dirigente preenche ao escolher esse momento — o catálogo em si
/// só guarda a *definição* (nome + tipo de campo); o valor preenchido fica
/// na instância dentro de `ServiceOrder.momentOrder`
/// (`ServiceOrderItem.extraNames`/`.extraBibleReference`).
class ServiceOrderExtraMomentOption {
  final String id;
  final String name;
  final bool isDefault;
  final ExtraMomentFieldKind fieldKind;

  const ServiceOrderExtraMomentOption({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.fieldKind = ExtraMomentFieldKind.none,
  });

  factory ServiceOrderExtraMomentOption.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ServiceOrderExtraMomentOption(
      id: doc.id,
      name: data['name'] as String? ?? '',
      isDefault: data['isDefault'] as bool? ?? false,
      fieldKind: ExtraMomentFieldKind.fromName(data['fieldKind'] as String?),
    );
  }
}
