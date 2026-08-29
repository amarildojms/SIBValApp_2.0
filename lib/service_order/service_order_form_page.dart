import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_repository.dart';
import '../data/hymnal_repository.dart';
import '../data/member_repository.dart' show membersProvider;
import '../data/post_repository.dart' show currentUidProvider;
import '../data/service_order_extra_moment_repository.dart';
import '../data/service_order_moment_order_repository.dart';
import '../data/service_order_repository.dart';
import '../data/user_repository.dart';
import '../models/bible.dart';
import '../models/hymn.dart';
import '../models/member.dart';
import '../models/service_order.dart';
import '../models/service_order_extra_moment.dart';
import '../theme/app_theme.dart';
import '../util/scroll_to_save.dart';
import '../widgets/date_field.dart';
import '../widgets/sibval_app_bar.dart';
import 'service_order_reorder_page.dart';

/// Sem equivalente no app nativo — feature nova (27/08/2026, pedido do
/// usuário). 1ª etapa do cadastro (ou edição, 28/08/2026 — [editing] != null)
/// de Ordem de Culto — ver doc comment de `ServiceOrder`
/// (`lib/models/service_order.dart`). Ao tocar em "Avançar", os dados viram
/// um `ServiceOrder` "rascunho" empurrado pra `ServiceOrderReorderPage` (2ª
/// etapa): lá o dirigente arrasta os momentos pra reordenar como quiser e só
/// então salva/atualiza de fato no Firestore — esta tela não grava nada
/// sozinha.
///
/// Data/horário pré-preenchidos (27/08/2026, pedido do usuário): sempre o
/// próximo domingo às 19h a partir da data da última ordem cadastrada, ou a
/// partir de hoje se ainda não houver nenhuma (nunca hoje mesmo, sempre o
/// próximo domingo — ver `_prefillDateTime`/`_nextSunday`). Só roda no modo
/// cadastro — no modo edição os campos vêm de [editing]. "Leitura bíblica" e
/// "Texto bíblico" (Dedicação dos dízimos e ofertas) reaproveitam a mesma
/// lógica de livro/capítulo/versículo do "Texto base" de Devocionais
/// (`devotional_form_page.dart`) — os widgets
/// `_BookField`/`_ChapterDropdown`/`_VerseDropdown` são cópias adaptadas
/// (mesmo padrão de duplicação local já usado entre
/// `devotional_form_page.dart` e `introduction_page.dart`), empacotadas num
/// `BibleReferenceController` reaproveitável tanto pro campo único de
/// dízimos quanto pra lista repetível de leituras.
///
/// Aviso de saída sem salvar (28/08/2026, pedido do usuário): `_dirty`
/// (flag explícita, não um cálculo "algum campo não vazio" — vários campos
/// já nascem preenchidos com valor padrão, ex. "Dirigente"/"Ministério
/// Adorai", então isso daria falso positivo assim que a tela abre) vira
/// `true` só quando o usuário de fato interage com algum campo (listener
/// nos controllers, adicionado depois de já ter preenchido os valores
/// padrão em `initState` — mesma cautela do bug já corrigido em
/// `_IntroductionPageState`/`introduction_page.dart`, ver
/// `[[feedback_flutter_migration_style]]`).
///
/// Rótulos de campo removidos (28/08/2026, pedido do usuário) — só Data/
/// Horário e os campos de referência bíblica (Leitura bíblica/Texto
/// bíblico) mantêm o `labelText` ancorado na borda; os demais viraram
/// caixas sem rótulo (`hintText` quando o cabeçalho da seção sozinho não
/// distingue o campo, ex. Tema/Divisa) — o nome do momento em si vira o
/// cabeçalho "- Nome" em itálico/dourado (`_momentLabel`, mesmo estilo pros
/// itens fixos sem campo, ex. "- Avisos/Comunicações").
class ServiceOrderFormPage extends ConsumerStatefulWidget {
  const ServiceOrderFormPage({super.key, this.editing});

  /// Ordem já cadastrada sendo editada (toque e segure numa ordem da lista,
  /// `ServiceOrderListPage`) — `null` no cadastro de uma ordem nova.
  final ServiceOrder? editing;

  @override
  ConsumerState<ServiceOrderFormPage> createState() =>
      _ServiceOrderFormPageState();
}

class _ServiceOrderFormPageState extends ConsumerState<ServiceOrderFormPage> {
  final _scrollController = ScrollController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final _themeController = TextEditingController();

  PreludeStyle _preludeStyle = PreludeStyle.naoHavera;
  final _preludeOtherController = TextEditingController();
  final _preludeOtherFocusNode = FocusNode();

  final _prayerController = TextEditingController();

  final List<BibleReferenceController> _bibleReadingControllers = [];

  final _praise1Controller = TextEditingController();

  /// Anotação livre pro momento "Boas-vindas" (28/08/2026, pedido do
  /// usuário) — ver doc comment de `ServiceOrder.welcomeNotes`.
  final _welcomeNotesController = TextEditingController();

  /// Mesma ideia, pro momento "Avisos/Comunicações" — ver doc comment de
  /// `ServiceOrder.announcementsNotes`.
  final _announcementsNotesController = TextEditingController();

  final _participationController = TextEditingController();
  final _participationFocusNode = FocusNode();

  MissionMoment _missionMoment = MissionMoment.naoHavera;
  final _missionThemeController = TextEditingController();
  final _missionThemeFocusNode = FocusNode();
  final _missionMottoController = TextEditingController();
  final _missionMottoFocusNode = FocusNode();

  final _tithesBibleController = BibleReferenceController();
  final _congregationalHymnController = TextEditingController();
  final _congregationalHymnFocusNode = FocusNode();

  final _praise2Controller = TextEditingController();
  final _intercessionController = TextEditingController();
  final _messageController = TextEditingController();
  final _communionController = TextEditingController();
  final _praise3Controller = TextEditingController();

  PreludeStyle _postludeStyle = PreludeStyle.instrumental;
  final _postludeOtherController = TextEditingController();
  final _postludeOtherFocusNode = FocusNode();

  /// Momentos especiais escolhidos (28/08/2026, pedido do usuário — o
  /// "Adicionar momento" saiu da 2ª etapa e passou pra cá). Carregam pra
  /// `ServiceOrderReorderPage` via `draft.momentOrder`.
  List<ServiceOrderItem> _extraMoments = [];

  bool _submitting = false;

  /// Sequência padrão dos "Momentos do Culto" configurada em
  /// `ManageServiceOrderMomentsPage` (`settings/serviceOrderMomentOrder`,
  /// mistura momentos fixos + especiais marcados "padrão") — buscada uma vez
  /// em `initState` e repassada pra `ServiceOrderReorderPage`, que só a usa
  /// no modo cadastro (edição parte do arranjo já salvo). Cai no fallback
  /// `ServiceOrderMomentType.values` (só os fixos, sem especiais) até a
  /// busca terminar ou se ela falhar.
  List<ServiceOrderItem> _defaultMomentOrder = [
    for (final type in ServiceOrderMomentType.values) ServiceOrderItem.fixed(type),
  ];

  /// `true` assim que o usuário interage com algum campo — ver doc comment
  /// da classe. Controla o `PopScope` (aviso "sair sem salvar?").
  bool _dirty = false;

  /// Campos obrigatórios pendentes na última tentativa de avançar
  /// (28/08/2026, pedido do usuário) — populado por `_continue()`, lido por
  /// `highlightIfEmpty` (via `isError:`) em cada campo pra desenhar borda
  /// vermelha só nos que ainda faltam. Um campo sai da lista sozinho (visual,
  /// sem precisar remover daqui) assim que deixa de estar vazio — `isError`
  /// só é aplicado quando o campo *também* está vazio.
  Set<_RequiredField> _fieldErrors = {};

  /// `FocusNode` do primeiro campo pendente de cada tipo — usado por
  /// `_continue()` pra levar o cursor até lá quando a validação falha.
  FocusNode? _focusNodeFor(_RequiredField field) => switch (field) {
    _RequiredField.preludeOther => _preludeOtherFocusNode,
    _RequiredField.bibleReading => _bibleReadingControllers.isEmpty
        ? null
        : _bibleReadingControllers.first.bookFocusNode,
    _RequiredField.missionTheme => _missionThemeFocusNode,
    _RequiredField.missionMotto => _missionMottoFocusNode,
    _RequiredField.tithesBible => _tithesBibleController.bookFocusNode,
    _RequiredField.congregationalHymn => _congregationalHymnFocusNode,
    _RequiredField.postludeOther => _postludeOtherFocusNode,
  };

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedDate = DateTime(
        editing.dateTime.year,
        editing.dateTime.month,
        editing.dateTime.day,
      );
      _selectedTime = TimeOfDay(
        hour: editing.dateTime.hour,
        minute: editing.dateTime.minute,
      );
      _themeController.text = editing.theme;
      _preludeStyle = editing.preludeStyle;
      _preludeOtherController.text = editing.preludeOther;
      _prayerController.text = editing.prayerText;
      for (final reading in editing.bibleReadings) {
        _bibleReadingControllers.add(_controllerFor(reading));
      }
      _praise1Controller.text = editing.praise1;
      _welcomeNotesController.text = editing.welcomeNotes;
      _announcementsNotesController.text = editing.announcementsNotes;
      _participationController.text = editing.participation;
      _missionMoment = editing.missionMoment;
      _missionThemeController.text = editing.missionTheme;
      _missionMottoController.text = editing.missionMotto;
      _tithesBibleController.applyReference(editing.tithesBibleReading);
      _congregationalHymnController.text = editing.congregationalHymn;
      _praise2Controller.text = editing.praise2;
      _intercessionController.text = editing.intercessionModerator;
      _messageController.text = editing.message;
      _communionController.text = editing.communionResponsible;
      _praise3Controller.text = editing.praise3;
      _postludeStyle = editing.postludeStyle;
      _postludeOtherController.text = editing.postludeOther;
      _extraMoments = editing.momentOrder.where((i) => i.isExtra).toList();
    } else {
      _prayerController.text = 'Dirigente';
      _praise1Controller.text = 'Ministério Adorai';
      _praise2Controller.text = 'Ministério Adorai';
      _praise3Controller.text = 'Ministério Adorai';
      _intercessionController.text = 'Pr. Ronan';
      _messageController.text = 'Pr. Ronan';
      // Ceia do Senhor fica vazio por padrão (28/08/2026, pedido do usuário)
      // — diferente dos demais momentos com responsável fixo, porque esse
      // momento em si só entra na ordem quando preenchido (ver
      // `_isEmptyMoment` em `service_order_reorder_page.dart`).
    }
    if (_bibleReadingControllers.isEmpty) {
      _bibleReadingControllers.add(BibleReferenceController());
    }
    // Listeners adicionados só depois dos valores padrão/edição acima, senão
    // disparariam `_markDirty` antes mesmo do usuário tocar em qualquer campo.
    for (final controller in _textControllersToTrack) {
      controller.addListener(_markDirty);
    }
    if (editing == null) _prefillDateTime();
    _loadDefaultMomentOrder();
  }

  Future<void> _loadDefaultMomentOrder() async {
    List<ServiceOrderItem>? order;
    try {
      final tokens =
          await ref.read(serviceOrderMomentOrderRepositoryProvider).getTokens();
      final extras =
          await ref.read(serviceOrderExtraMomentRepositoryProvider).watchAll().first;
      order = resolveServiceOrderMomentTemplate(tokens, extras);
    } catch (_) {
      order = null;
    }
    if (!mounted || order == null) return;
    setState(() => _defaultMomentOrder = order!);
  }

  BibleReferenceController _controllerFor(BibleReference reference) {
    final controller = BibleReferenceController();
    controller.applyReference(reference);
    return controller;
  }

  List<TextEditingController> get _textControllersToTrack => [
    _themeController,
    _preludeOtherController,
    _prayerController,
    _praise1Controller,
    _welcomeNotesController,
    _announcementsNotesController,
    _participationController,
    _missionThemeController,
    _missionMottoController,
    _congregationalHymnController,
    _praise2Controller,
    _intercessionController,
    _messageController,
    _communionController,
    _praise3Controller,
    _postludeOtherController,
  ];

  /// Reconstrói a cada tecla (28/08/2026, pedido do usuário: realce de campo
  /// vazio precisa acompanhar o que o dirigente está digitando em tempo
  /// real) — antes só reconstruía na 1ª interação (`if (!_dirty)`), suficiente
  /// só pro aviso de "sair sem salvar?"; `_dirty = true` continua idempotente
  /// nas chamadas seguintes, então nada muda pro `PopScope`.
  void _markDirty() {
    setState(() => _dirty = true);
  }

  Future<void> _confirmDiscardAndPop() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text(
          'Os dados preenchidos no formulário ainda não foram salvos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar preenchendo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  /// Sempre o próximo domingo às 19h a partir da última ordem cadastrada —
  /// se ainda não houver nenhuma, o próximo domingo a partir de hoje (nunca
  /// hoje mesmo, mesmo que hoje já seja domingo).
  ///
  /// Envolto em try/catch (28/08/2026, corrige bug relatado pelo usuário:
  /// campos vinham vazios) — uma falha na consulta (ex.: `firestore.rules`
  /// de `serviceOrders` ainda não deployada em produção, ver
  /// `[[feedback_deploy_requires_explicit_ask]]`) deixava a exceção sem
  /// tratamento, `setState` nunca rodava e os campos ficavam `null` pra
  /// sempre. Agora qualquer falha cai no mesmo padrão de quem ainda não tem
  /// nenhuma ordem cadastrada.
  Future<void> _prefillDateTime() async {
    DateTime? latest;
    try {
      latest = await ref.read(serviceOrderRepositoryProvider).getLatestDateTime();
    } catch (_) {
      latest = null;
    }
    if (!mounted) return;
    final next = _nextSunday(latest ?? DateTime.now());
    setState(() {
      _selectedDate = DateTime(next.year, next.month, next.day);
      _selectedTime = TimeOfDay(hour: next.hour, minute: next.minute);
    });
  }

  void _addBibleReading() {
    setState(() {
      _bibleReadingControllers.add(BibleReferenceController());
      _dirty = true;
    });
  }

  void _removeBibleReading(int index) {
    final controller = _bibleReadingControllers.removeAt(index);
    controller.dispose();
    setState(() => _dirty = true);
  }

  Future<void> _pickExtraMoments() async {
    // Duas tentativas anteriores (asData?.value, depois .future do
    // provider) não resolveram o bug relatado — momentos adicionais já
    // cadastrados continuavam não aparecendo aqui. Trocado por uma leitura
    // direta no repositório (`getAll`, sem Riverpod no meio) e um erro
    // visível em vez de engolido, pra qualquer falha real (ex.: regra do
    // Firestore, rede) aparecer na tela em vez de só um picker vazio sem
    // explicação.
    List<ServiceOrderExtraMomentOption> catalog;
    try {
      catalog = await ref.read(serviceOrderExtraMomentRepositoryProvider).getAll();
    } catch (e) {
      if (mounted) _showError('Falha ao carregar momentos adicionais: $e');
      return;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<List<ServiceOrderItem>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ExtraMomentPickerSheet(
        catalog: catalog,
        initialItems: _extraMoments,
      ),
    );
    if (result == null) return;
    setState(() {
      _extraMoments = result;
      _dirty = true;
    });
  }

  /// Resumo do dado preenchido num momento adicional (nome/nomes ou texto
  /// bíblico) — `null` se o momento não tem campo ou nada foi preenchido.
  String? _extraSummary(ServiceOrderItem item) {
    final refs = item.extraBibleReferences
        .where((r) => r.isFilled)
        .map((r) => r.reference)
        .whereType<String>()
        .toList();
    if (refs.isNotEmpty) return refs.join('; ');
    if (item.extraNames.isNotEmpty) return item.extraNames.join(', ');
    return null;
  }

  void _removeExtraMoment(ServiceOrderItem item) {
    setState(() {
      _extraMoments = _extraMoments
          .where((e) => e.instanceId != item.instanceId)
          .toList();
      _dirty = true;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Valida e monta o `ServiceOrder` "rascunho" e empurra pra
  /// `ServiceOrderReorderPage` — só aquela tela grava/atualiza no Firestore
  /// de fato, depois do dirigente reordenar os momentos.
  Future<void> _continue() async {
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) {
      _showError('Selecione a data e o horário.');
      return;
    }
    // NOVO (28/08/2026, pedido do usuário): em vez de parar no 1º erro
    // encontrado, junta TODOS os campos obrigatórios pendentes — marca todos
    // em vermelho (`_fieldErrors`, lido por `highlightIfEmpty` em cada
    // campo) e move o cursor só pro primeiro deles, na ordem em que aparecem
    // no formulário (`_RequiredField.values`, declarado nessa mesma ordem).
    final errors = <_RequiredField>{};
    if (_preludeStyle == PreludeStyle.outro &&
        _preludeOtherController.text.trim().isEmpty) {
      errors.add(_RequiredField.preludeOther);
    }
    if (!_bibleReadingControllers.any((c) => c.toReference().isFilled)) {
      errors.add(_RequiredField.bibleReading);
    }
    if (_missionMoment != MissionMoment.naoHavera) {
      if (_missionThemeController.text.trim().isEmpty) {
        errors.add(_RequiredField.missionTheme);
      }
      if (_missionMottoController.text.trim().isEmpty) {
        errors.add(_RequiredField.missionMotto);
      }
    }
    if (!_tithesBibleController.toReference().isFilled) {
      errors.add(_RequiredField.tithesBible);
    }
    if (_congregationalHymnController.text.trim().isEmpty) {
      errors.add(_RequiredField.congregationalHymn);
    }
    if (_postludeStyle == PreludeStyle.outro &&
        _postludeOtherController.text.trim().isEmpty) {
      errors.add(_RequiredField.postludeOther);
    }

    if (errors.isNotEmpty) {
      setState(() => _fieldErrors = errors);
      _showError('Preencha os campos obrigatórios.');
      for (final field in _RequiredField.values) {
        if (errors.contains(field)) {
          _focusNodeFor(field)?.requestFocus();
          break;
        }
      }
      return;
    }
    if (_fieldErrors.isNotEmpty) setState(() => _fieldErrors = {});

    final uid = ref.read(currentUidProvider);
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (uid == null || profile == null) return;

    final editing = widget.editing;
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final bibleReadings = _bibleReadingControllers
        .map((c) => c.toReference())
        .where((r) => r.isFilled)
        .toList();

    final draft = ServiceOrder(
      id: editing?.id ?? '',
      dateTime: dateTime,
      preludeStyle: _preludeStyle,
      preludeOther: _preludeStyle == PreludeStyle.outro
          ? _preludeOtherController.text.trim()
          : '',
      prayerText: _prayerController.text.trim(),
      welcomeNotes: _welcomeNotesController.text.trim(),
      bibleReadings: bibleReadings,
      praise1: _praise1Controller.text.trim(),
      announcementsNotes: _announcementsNotesController.text.trim(),
      participation: _participationController.text.trim(),
      missionMoment: _missionMoment,
      missionTheme: _missionMoment == MissionMoment.naoHavera
          ? ''
          : _missionThemeController.text.trim(),
      missionMotto: _missionMoment == MissionMoment.naoHavera
          ? ''
          : _missionMottoController.text.trim(),
      tithesBibleReading: _tithesBibleController.toReference(),
      congregationalHymn: _congregationalHymnController.text.trim(),
      praise2: _praise2Controller.text.trim(),
      intercessionModerator: _intercessionController.text.trim(),
      message: _messageController.text.trim(),
      communionResponsible: _communionController.text.trim(),
      praise3: _praise3Controller.text.trim(),
      postludeStyle: _postludeStyle,
      postludeOther: _postludeStyle == PreludeStyle.outro
          ? _postludeOtherController.text.trim()
          : '',
      theme: _themeController.text.trim(),
      ownerUid: editing?.ownerUid ?? uid,
      ownerName: editing?.ownerName ?? profile.shortName,
      createdByUid: editing?.createdByUid ?? uid,
      createdByName: editing?.createdByName ?? profile.shortName,
      createdAt: editing?.createdAt,
      startedAt: editing?.startedAt,
      momentOrder: _extraMoments,
    );

    setState(() => _submitting = true);
    _scrollController.scrollToSaveButton();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ServiceOrderReorderPage(
          draft: draft,
          editingOrder: editing,
          defaultMomentOrder: _defaultMomentOrder,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      // Bypassa o `PopScope` (é um `pop()` direto, não o back
      // gesture/botão) — a ordem já foi salva com sucesso em
      // `ServiceOrderReorderPage`, não faz sentido perguntar "sair sem
      // salvar?" aqui.
      Navigator.of(context).pop();
      return;
    }
    setState(() => _submitting = false);
  }

  @override
  void dispose() {
    for (final controller in _textControllersToTrack) {
      controller.removeListener(_markDirty);
    }
    _scrollController.dispose();
    _themeController.dispose();
    _preludeOtherController.dispose();
    _preludeOtherFocusNode.dispose();
    _prayerController.dispose();
    for (final controller in _bibleReadingControllers) {
      controller.dispose();
    }
    _praise1Controller.dispose();
    _welcomeNotesController.dispose();
    _announcementsNotesController.dispose();
    _participationController.dispose();
    _participationFocusNode.dispose();
    _missionThemeController.dispose();
    _missionThemeFocusNode.dispose();
    _missionMottoController.dispose();
    _missionMottoFocusNode.dispose();
    _tithesBibleController.dispose();
    _congregationalHymnController.dispose();
    _congregationalHymnFocusNode.dispose();
    _praise2Controller.dispose();
    _intercessionController.dispose();
    _messageController.dispose();
    _communionController.dispose();
    _praise3Controller.dispose();
    _postludeOtherController.dispose();
    _postludeOtherFocusNode.dispose();
    super.dispose();
  }

  static const _fieldDecoration = InputDecoration(
    border: OutlineInputBorder(),
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmDiscardAndPop();
      },
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          // Título fixo fora do scroll (28/08/2026, pedido do usuário) —
          // antes vivia dentro do SingleChildScrollView e rolava junto com
          // os campos.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenTitle(
                _isEditing ? 'Editar Ordem de Culto' : 'Cadastro de Ordem de Culto',
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _momentBox(context, [
                          _sectionLabel(context, 'Data e horário'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DateField(
                                  label: 'Data',
                                  value: _selectedDate,
                                  firstDate: DateTime(DateTime.now().year - 1),
                                  lastDate: DateTime(DateTime.now().year + 3),
                                  decoration: _fieldDecoration,
                                  onChanged: (date) => setState(() {
                                    _selectedDate = date;
                                    _dirty = true;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: _TimeField(
                                  value: _selectedTime,
                                  onChanged: (time) => setState(() {
                                    _selectedTime = time;
                                    _dirty = true;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _sectionLabel(context, 'Tema'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _themeController,
                            decoration: _fieldDecoration.copyWith(
                              hintText: 'Preencha com tema ou cultos especiais',
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Prelúdio'),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<PreludeStyle>(
                            initialValue: _preludeStyle,
                            decoration: _fieldDecoration,
                            items: [
                              for (final style in PreludeStyle.values)
                                DropdownMenuItem(
                                  value: style,
                                  child: Text(style.label),
                                ),
                            ],
                            onChanged: (style) => setState(() {
                              _preludeStyle = style ?? PreludeStyle.naoHavera;
                              _dirty = true;
                            }),
                          ),
                          if (_preludeStyle == PreludeStyle.outro) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: _preludeOtherController,
                              focusNode: _preludeOtherFocusNode,
                              decoration: highlightIfEmpty(
                                _fieldDecoration.copyWith(
                                  hintText: 'Responsável pelo prelúdio',
                                ),
                                _preludeOtherController.text,
                                isError: _fieldErrors.contains(_RequiredField.preludeOther),
                              ),
                            ),
                          ],
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Oração'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _prayerController,
                            decoration: highlightIfEmpty(
                              _fieldDecoration.copyWith(hintText: 'Quem ora'),
                              _prayerController.text,
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Leitura bíblica'),
                          const SizedBox(height: 4),
                          for (var i = 0; i < _bibleReadingControllers.length; i++)
                            Padding(
                              key: ValueKey(_bibleReadingControllers[i]),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _BibleReferenceFields(
                                controller: _bibleReadingControllers[i],
                                onRemove: _bibleReadingControllers.length > 1
                                    ? () => _removeBibleReading(i)
                                    : null,
                                onChanged: _markDirty,
                                // Só a 1ª linha (é pra onde o foco vai ao
                                // falhar a validação) mostra vermelho — o
                                // erro é "nenhuma leitura preenchida", não
                                // "esta linha específica".
                                isError: i == 0 &&
                                    _fieldErrors.contains(_RequiredField.bibleReading),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _addBibleReading,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Adicionar leitura'),
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Louvor'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _praise1Controller,
                            decoration: highlightIfEmpty(
                              _fieldDecoration,
                              _praise1Controller.text,
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Boas-vindas'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _welcomeNotesController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: _fieldDecoration.copyWith(
                              hintText: 'Anotações (opcional)',
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Avisos/Comunicações'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _announcementsNotesController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: _fieldDecoration.copyWith(
                              hintText: 'Anotações (opcional)',
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Participação Especial'),
                          const SizedBox(height: 4),
                          _ParticipationField(
                            controller: _participationController,
                            focusNode: _participationFocusNode,
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Momento Missionário'),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<MissionMoment>(
                            initialValue: _missionMoment,
                            decoration: _fieldDecoration,
                            items: [
                              for (final moment in MissionMoment.values)
                                DropdownMenuItem(
                                  value: moment,
                                  child: Text(moment.label),
                                ),
                            ],
                            onChanged: (moment) => setState(() {
                              _missionMoment = moment ?? MissionMoment.naoHavera;
                              _dirty = true;
                            }),
                          ),
                          if (_missionMoment != MissionMoment.naoHavera) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: _missionThemeController,
                              focusNode: _missionThemeFocusNode,
                              decoration: highlightIfEmpty(
                                _fieldDecoration.copyWith(hintText: 'Tema'),
                                _missionThemeController.text,
                                isError: _fieldErrors.contains(_RequiredField.missionTheme),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _missionMottoController,
                              focusNode: _missionMottoFocusNode,
                              decoration: highlightIfEmpty(
                                _fieldDecoration.copyWith(hintText: 'Divisa'),
                                _missionMottoController.text,
                                isError: _fieldErrors.contains(_RequiredField.missionMotto),
                              ),
                            ),
                          ],
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Dedicação dos dízimos e ofertas'),
                          const SizedBox(height: 6),
                          _sectionLabel(context, 'Texto bíblico'),
                          const SizedBox(height: 4),
                          _BibleReferenceFields(
                            controller: _tithesBibleController,
                            onChanged: _markDirty,
                            isError: _fieldErrors.contains(_RequiredField.tithesBible),
                          ),
                          const SizedBox(height: 6),
                          _sectionLabel(context, 'Hino Congregacional'),
                          const SizedBox(height: 4),
                          _HymnField(
                            controller: _congregationalHymnController,
                            focusNode: _congregationalHymnFocusNode,
                            isError: _fieldErrors.contains(_RequiredField.congregationalHymn),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Oração pelas crianças'),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Louvor'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _praise2Controller,
                            decoration: highlightIfEmpty(
                              _fieldDecoration,
                              _praise2Controller.text,
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Momento de Intercessão'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _intercessionController,
                            decoration: highlightIfEmpty(
                              _fieldDecoration,
                              _intercessionController.text,
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Mensagem'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _messageController,
                            decoration: highlightIfEmpty(
                              _fieldDecoration,
                              _messageController.text,
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Ceia do Senhor'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _communionController,
                            decoration: _fieldDecoration.copyWith(
                              hintText: 'Responsável',
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Louvor'),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _praise3Controller,
                            decoration: highlightIfEmpty(
                              _fieldDecoration,
                              _praise3Controller.text,
                            ),
                          ),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Benção Apostólica'),
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Poslúdio'),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<PreludeStyle>(
                            initialValue: _postludeStyle,
                            decoration: _fieldDecoration,
                            items: [
                              for (final style in PreludeStyle.values)
                                if (style != PreludeStyle.naoHavera)
                                  DropdownMenuItem(
                                    value: style,
                                    child: Text(style.label),
                                  ),
                            ],
                            onChanged: (style) => setState(() {
                              _postludeStyle = style ?? PreludeStyle.instrumental;
                              _dirty = true;
                            }),
                          ),
                          if (_postludeStyle == PreludeStyle.outro) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: _postludeOtherController,
                              focusNode: _postludeOtherFocusNode,
                              decoration: highlightIfEmpty(
                                _fieldDecoration.copyWith(
                                  hintText: 'Descreva o poslúdio',
                                ),
                                _postludeOtherController.text,
                                isError: _fieldErrors.contains(_RequiredField.postludeOther),
                              ),
                            ),
                          ],
                        ]),

                        _momentBox(context, [
                          _momentLabel(context, 'Momentos Adicionais'),
                          const SizedBox(height: 4),
                          if (_extraMoments.isEmpty)
                            Text(
                              'Nenhum — toque em "Adicionar" pra incluir Batismo, '
                              'Ceia do Senhor, mais um Louvor etc.',
                              style: TextStyle(color: context.textSecondary, fontSize: 13),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final item in _extraMoments)
                                  Chip(
                                    label: Text(
                                      _extraSummary(item) != null
                                          ? '${item.label}: ${_extraSummary(item)}'
                                          : item.label,
                                    ),
                                    onDeleted: () => _removeExtraMoment(item),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _pickExtraMoments,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Adicionar momento'),
                            ),
                          ),
                        ]),

                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 18,
                              ),
                            ),
                            onPressed: _submitting ? null : _continue,
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Avançar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sempre o próximo domingo às 19h, estritamente depois de [from] — nunca
/// devolve o próprio dia de [from], mesmo que já seja domingo (pedido do
/// usuário: sem ordem cadastrada ainda, deve assumir o *próximo* domingo a
/// partir de hoje, não hoje mesmo).
DateTime _nextSunday(DateTime from) {
  var d = DateTime(
    from.year,
    from.month,
    from.day,
  ).add(const Duration(days: 1));
  while (d.weekday != DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return DateTime(d.year, d.month, d.day, 19, 0);
}

/// Campos obrigatórios validados por `_continue()` (28/08/2026, pedido do
/// usuário) — declarados na mesma ordem em que aparecem no formulário, pra
/// `_RequiredField.values` já servir como ordem de prioridade na hora de
/// decidir qual é "o primeiro campo que faltou preencher".
enum _RequiredField {
  preludeOther,
  bibleReading,
  missionTheme,
  missionMotto,
  tithesBible,
  congregationalHymn,
  postludeOther,
}

/// Realce sutil pra campo vazio (28/08/2026, pedido do usuário: "destaque os
/// campos que estão sem preenchimento... que não fique muito gritante") —
/// leve tingimento âmbar no fundo e na borda, deliberadamente discreto (evita
/// parecer erro de validação). Aplicado só nos campos de texto livre cujo
/// valor normal é ter algo digitado — **excluídos de propósito**: Tema (hint
/// já diz "cultos especiais"), as duas Anotações (hint já diz "opcional") e
/// Ceia do Senhor (nasce vazio de propósito, ver histórico da 13ª rodada —
/// só é preenchido quando o culto realmente vai ter Ceia). Reaproveitado
/// pelos `TextField`s soltos no formulário e por `_ParticipationField`/
/// `_HymnField` (que já se reconstroem sozinhos a cada tecla, via o próprio
/// listener do controller).
///
/// [isError] (28/08/2026, pedido do usuário: "marque os campos pendentes de
/// vermelho") — quando `true` e o campo está vazio, sobrepõe o âmbar por uma
/// borda/fundo vermelhos, mais fortes; usado só nos campos obrigatórios
/// (`_RequiredField`) depois de uma tentativa de avançar sem preenchê-los.
/// [highlightEmpty] = `false` desliga o âmbar (usado pelo campo "Livro" de
/// `_BibleReferenceFields`/`_BookField` — não participa do realce âmbar
/// geral, só do vermelho de erro, já que antes de 28/08/2026 ele nunca teve
/// destaque nenhum de campo vazio).
InputDecoration highlightIfEmpty(
  InputDecoration base,
  String text, {
  bool isError = false,
  bool highlightEmpty = true,
}) {
  if (text.trim().isNotEmpty) return base;
  if (isError) {
    const errorColor = Colors.red;
    return base.copyWith(
      filled: true,
      fillColor: errorColor.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: errorColor.withValues(alpha: 0.7), width: 1.5),
      ),
    );
  }
  if (!highlightEmpty) return base;
  const tint = Colors.amber;
  return base.copyWith(
    filled: true,
    fillColor: tint.withValues(alpha: 0.08),
    border: OutlineInputBorder(
      borderSide: BorderSide(color: tint.withValues(alpha: 0.55)),
    ),
  );
}

/// Caixa que agrupa um "momento" da liturgia com seu(s) campo(s) —
/// 28/08/2026, pedido do usuário: "colocar cada momento do formulário
/// dentro de caixas, separando assim melhor cada um deles". Borda discreta
/// (`outlineVariant`, mesmo tom neutro já usado em
/// `weekly_repertoire_form_page.dart`/`_AssignmentRow`), sem preencher o
/// fundo — só delimita visualmente onde um momento termina e o próximo
/// começa.
Widget _momentBox(BuildContext context, List<Widget> children) {
  // Fundo levemente tingido (28/08/2026, pedido do usuário) — mais claro que
  // o fundo da tela no tema escuro, mais escuro no tema claro. Blend por
  // `alpha` baixo em cima do `scaffoldBackgroundColor` de verdade (em vez de
  // uma cor fixa tipo `surfaceContainerHighest`) pra garantir que a diferença
  // seja "um pouco", nunca um tom muito diferente do fundo.
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final tintedBackground = Color.alphaBlend(
    (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.05 : 0.04),
    Theme.of(context).scaffoldBackgroundColor,
  );
  return Container(
    // Largura sempre igual à dos demais campos (28/08/2026, pedido do
    // usuário) — sem isso, uma caixa cujo único filho é um `Text` (Oração
    // pelas crianças/Benção Apostólica, sem campo) encolhia pra largura do
    // texto, já que nada ali força a largura máxima como um `TextField` faz.
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: tintedBackground,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    ),
  );
}

/// Cabeçalho de sub-campo que não é um "momento" da liturgia em si (Data e
/// horário, Texto bíblico/Hino Congregacional — sub-campos de "Dedicação dos
/// dízimos e ofertas") — estilo antigo, neutro.
Widget _sectionLabel(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      color: context.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    ),
  );
}

/// Cabeçalho de um momento da liturgia — "- Nome", itálico, dourado padrão
/// do app (28/08/2026, pedido do usuário: todo momento no mesmo padrão
/// visual, tenha campo próprio ou seja só um marcador de posição fixo, ex.
/// "- Prelúdio"/"- Avisos/Comunicações").
Widget _momentLabel(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(
      '- $text',
      style: const TextStyle(
        color: SibValColors.goldAccent,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}

/// Campo de horário, mesmo estilo visual de `DateField` — toque abre
/// `showTimePicker` nativo.
class _TimeField extends StatelessWidget {
  const _TimeField({required this.value, required this.onChanged});

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
        : '';
    return InkWell(
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Horário',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.access_time),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(text, style: TextStyle(color: context.textPrimary)),
      ),
    );
  }
}

/// Bottom sheet do botão "Adicionar momento" (28/08/2026 — saiu da 2ª etapa
/// do cadastro e veio pra cá; revisado na mesma sessão pra suportar
/// `ExtraMomentFieldKind`). Toque num momento sem campo (`.none`) alterna
/// marcado/desmarcado direto; num momento com campo (`.name`/`.names`/
/// `.bibleReference`) abre um diálogo pra preencher (ou editar, se já
/// preenchido) — "Concluir" devolve a lista final de `ServiceOrderItem`.
class _ExtraMomentPickerSheet extends StatefulWidget {
  const _ExtraMomentPickerSheet({
    required this.catalog,
    required this.initialItems,
  });

  final List<ServiceOrderExtraMomentOption> catalog;
  final List<ServiceOrderItem> initialItems;

  @override
  State<_ExtraMomentPickerSheet> createState() => _ExtraMomentPickerSheetState();
}

class _ExtraMomentPickerSheetState extends State<_ExtraMomentPickerSheet> {
  late final List<ServiceOrderItem> _items = List.of(widget.initialItems);

  ServiceOrderItem? _itemFor(String id) {
    for (final item in _items) {
      if (item.extraMomentId == id) return item;
    }
    return null;
  }

  String? _summaryFor(ServiceOrderItem item) {
    final refs = item.extraBibleReferences
        .where((r) => r.isFilled)
        .map((r) => r.reference)
        .whereType<String>()
        .toList();
    if (refs.isNotEmpty) return refs.join('; ');
    if (item.extraNames.isNotEmpty) return item.extraNames.join(', ');
    return null;
  }

  Future<void> _toggle(ServiceOrderExtraMomentOption option) async {
    final existing = _itemFor(option.id);
    if (option.fieldKind == ExtraMomentFieldKind.none) {
      setState(() {
        if (existing != null) {
          _items.removeWhere((i) => i.extraMomentId == option.id);
        } else {
          _items.add(ServiceOrderItem.extra(option.id, option.name));
        }
      });
      return;
    }
    final result = await _collectFieldData(option, existing);
    if (result == null || !mounted) return;
    setState(() {
      _items.removeWhere((i) => i.extraMomentId == option.id);
      _items.add(result);
    });
  }

  void _remove(String id) {
    setState(() => _items.removeWhere((i) => i.extraMomentId == id));
  }

  Future<ServiceOrderItem?> _collectFieldData(
    ServiceOrderExtraMomentOption option,
    ServiceOrderItem? existing,
  ) {
    switch (option.fieldKind) {
      case ExtraMomentFieldKind.name:
        return _collectSingleName(option, existing);
      case ExtraMomentFieldKind.names:
        return _collectMultipleNames(option, existing);
      case ExtraMomentFieldKind.bibleReference:
        return _collectBibleReferences(option, existing);
      case ExtraMomentFieldKind.none:
        return Future.value(ServiceOrderItem.extra(option.id, option.name));
    }
  }

  Future<ServiceOrderItem?> _collectSingleName(
    ServiceOrderExtraMomentOption option,
    ServiceOrderItem? existing,
  ) async {
    final controller = TextEditingController(
      text: (existing?.extraNames ?? const []).join(', '),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(option.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return null;
    return ServiceOrderItem.extra(option.id, option.name, extraNames: [result.trim()]);
  }

  /// Lista dinâmica de nomes (28/08/2026, pedido do usuário — antes era um
  /// campo único separado por vírgula) — mesmo botão "+ Adicionar" já usado
  /// em "Leitura bíblica"/"Momentos Especiais".
  Future<ServiceOrderItem?> _collectMultipleNames(
    ServiceOrderExtraMomentOption option,
    ServiceOrderItem? existing,
  ) async {
    final names = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => _MultiNameDialog(
        title: option.name,
        initial: existing?.extraNames ?? const [],
      ),
    );
    if (names == null || names.isEmpty) return null;
    return ServiceOrderItem.extra(option.id, option.name, extraNames: names);
  }

  /// Múltiplos textos bíblicos (28/08/2026, pedido do usuário) — cada um
  /// vira uma subcategoria própria em `ServiceOrderLivePage`.
  Future<ServiceOrderItem?> _collectBibleReferences(
    ServiceOrderExtraMomentOption option,
    ServiceOrderItem? existing,
  ) async {
    final refs = await showDialog<List<BibleReference>>(
      context: context,
      builder: (dialogContext) => _MultiBibleReferenceDialog(
        title: option.name,
        initial: existing?.extraBibleReferences ?? const [],
      ),
    );
    if (refs == null || refs.isEmpty) return null;
    return ServiceOrderItem.extra(option.id, option.name, extraBibleReferences: refs);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.catalog]..sort((a, b) => a.name.compareTo(b.name));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Momentos adicionais',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nenhum momento adicional cadastrado ainda. Peça pra um admin '
                  'cadastrar na engrenagem da tela Ordem de Culto.',
                  style: TextStyle(color: context.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in sorted)
                      Builder(
                        builder: (context) {
                          final item = _itemFor(option.id);
                          final selected = item != null;
                          final summary = item != null ? _summaryFor(item) : null;
                          return ListTile(
                            leading: Icon(
                              selected ? Icons.check_circle : Icons.circle_outlined,
                              color: selected ? SibValColors.goldAccent : null,
                            ),
                            title: Text(
                              option.name,
                              style: TextStyle(color: context.textPrimary),
                            ),
                            subtitle: summary != null
                                ? Text(summary, style: TextStyle(color: context.textSecondary))
                                : (option.fieldKind != ExtraMomentFieldKind.none
                                      ? Text(
                                          'Toque para preencher',
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      : null),
                            trailing: selected
                                ? IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => _remove(option.id),
                                  )
                                : null,
                            onTap: () => _toggle(option),
                          );
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_items),
                child: const Text('Concluir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de coletar 1+ nomes pra um momento adicional com
/// `ExtraMomentFieldKind.names` (28/08/2026, pedido do usuário — antes era
/// um campo único separado por vírgula, agora dá pra ir adicionando um de
/// cada vez).
class _MultiNameDialog extends StatefulWidget {
  const _MultiNameDialog({required this.title, required this.initial});

  final String title;
  final List<String> initial;

  @override
  State<_MultiNameDialog> createState() => _MultiNameDialogState();
}

class _MultiNameDialogState extends State<_MultiNameDialog> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    if (widget.initial.isEmpty) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    } else {
      for (final name in widget.initial) {
        _controllers.add(TextEditingController(text: name));
        _focusNodes.add(FocusNode());
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  /// Move o foco pro campo recém-criado (28/08/2026, pedido do usuário) —
  /// precisa esperar o próximo frame, já que o `TextField` novo só existe
  /// na árvore depois do `setState` reconstruir.
  void _add() {
    setState(() {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.last.requestFocus();
    });
  }

  void _remove(int index) {
    final controller = _controllers.removeAt(index);
    controller.dispose();
    final focusNode = _focusNodes.removeAt(index);
    focusNode.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _controllers.length; i++)
                Padding(
                  key: ValueKey(_controllers[i]),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          autofocus: i == 0,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(labelText: 'Nome ${i + 1}'),
                        ),
                      ),
                      if (_controllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _remove(i),
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar nome'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final names = _controllers
                .map((c) => c.text.trim())
                .where((n) => n.isNotEmpty)
                .toList();
            Navigator.of(context).pop(names);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Diálogo de coletar 1+ textos bíblicos pra um momento adicional com
/// `ExtraMomentFieldKind.bibleReference` (28/08/2026, pedido do usuário —
/// suportar mais de um, cada um virando subcategoria própria em
/// `ServiceOrderLivePage`) — mesmo botão "+ Adicionar leitura"/lista
/// dinâmica já usado em "Leitura bíblica" no formulário principal.
class _MultiBibleReferenceDialog extends StatefulWidget {
  const _MultiBibleReferenceDialog({required this.title, required this.initial});

  final String title;
  final List<BibleReference> initial;

  @override
  State<_MultiBibleReferenceDialog> createState() =>
      _MultiBibleReferenceDialogState();
}

class _MultiBibleReferenceDialogState extends State<_MultiBibleReferenceDialog> {
  final List<BibleReferenceController> _controllers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initial.isEmpty) {
      _controllers.add(BibleReferenceController());
    } else {
      for (final ref in widget.initial) {
        _controllers.add(BibleReferenceController()..applyReference(ref));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Move o foco pro campo "Livro" do texto recém-criado (28/08/2026,
  /// pedido do usuário) — `BibleReferenceController.bookFocusNode` já
  /// existe pra outros fins, só precisa do próximo frame pro `TextField`
  /// novo existir na árvore antes de focar.
  void _add() {
    final controller = BibleReferenceController();
    setState(() => _controllers.add(controller));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.bookFocusNode.requestFocus();
    });
  }

  void _remove(int index) {
    final controller = _controllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _controllers.length; i++)
                Padding(
                  key: ValueKey(_controllers[i]),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BibleReferenceFields(
                    controller: _controllers[i],
                    onRemove: _controllers.length > 1 ? () => _remove(i) : null,
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar texto'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final refs = _controllers
                .map((c) => c.toReference())
                .where((r) => r.isFilled)
                .toList();
            Navigator.of(context).pop(refs);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Empacota controller/focusNode + os valores de livro/capítulo/versículo de
/// uma referência bíblica — reaproveitado tanto pelo campo único "Texto
/// bíblico" (dízimos) quanto pela lista repetível "Leitura bíblica".
class BibleReferenceController {
  final bookController = TextEditingController();
  final bookFocusNode = FocusNode();
  int? bookId;
  int? chapter;
  int? verseStart;
  int? verseEnd;

  bool get isFilled => bookId != null && chapter != null && verseStart != null;

  /// Preenche a partir de uma referência já salva (28/08/2026 — modo edição
  /// de `ServiceOrderFormPage`).
  void applyReference(BibleReference reference) {
    bookController.text = reference.bookName;
    bookId = reference.bookId;
    chapter = reference.chapter;
    verseStart = reference.verseStart;
    verseEnd = reference.verseEnd;
  }

  BibleReference toReference() {
    if (!isFilled) return const BibleReference();
    return BibleReference(
      bookId: bookId,
      bookName: bookController.text.trim(),
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: verseEnd ?? verseStart,
    );
  }

  void dispose() {
    bookController.dispose();
    bookFocusNode.dispose();
  }
}

/// Linha "Livro" + "Capítulo/De/Até" de uma referência bíblica — [onRemove]
/// só é informado na lista repetível de "Leitura bíblica" (`null` no campo
/// único de dízimos). [onChanged] (28/08/2026) avisa o formulário pai a cada
/// alteração — usado pro aviso de "sair sem salvar", ver `_dirty` em
/// `ServiceOrderFormPage`.
class _BibleReferenceFields extends ConsumerStatefulWidget {
  const _BibleReferenceFields({
    required this.controller,
    this.onRemove,
    this.onChanged,
    this.isError = false,
  });

  final BibleReferenceController controller;
  final VoidCallback? onRemove;
  final VoidCallback? onChanged;

  /// Borda vermelha no campo "Livro" quando ainda vazio (28/08/2026, pedido
  /// do usuário) — ver `_RequiredField`/`ServiceOrderFormPage._continue()`.
  final bool isError;

  @override
  ConsumerState<_BibleReferenceFields> createState() =>
      _BibleReferenceFieldsState();
}

class _BibleReferenceFieldsState extends ConsumerState<_BibleReferenceFields> {
  BibleReferenceController get c => widget.controller;

  void _onBookSelected(BibleBook book) {
    widget.onChanged?.call();
    setState(() {
      c.bookId = book.id;
      c.chapter = null;
      c.verseStart = null;
      c.verseEnd = null;
    });
  }

  void _onBookTextEdited() {
    widget.onChanged?.call();
    if (c.bookId == null) return;
    setState(() {
      c.bookId = null;
      c.chapter = null;
      c.verseStart = null;
      c.verseEnd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _BookField(
                controller: c.bookController,
                focusNode: c.bookFocusNode,
                onSelected: _onBookSelected,
                onEdited: _onBookTextEdited,
                isError: widget.isError,
              ),
            ),
            if (widget.onRemove != null)
              IconButton(
                tooltip: 'Remover leitura',
                icon: const Icon(Icons.close),
                onPressed: widget.onRemove,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _ChapterDropdown(
                bookId: c.bookId,
                value: c.chapter,
                onChanged: (chapter) {
                  widget.onChanged?.call();
                  setState(() {
                    c.chapter = chapter;
                    c.verseStart = null;
                    c.verseEnd = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _VerseDropdown(
                label: 'De',
                bookId: c.bookId,
                chapter: c.chapter,
                minValue: null,
                value: c.verseStart,
                onChanged: (verse) {
                  widget.onChanged?.call();
                  setState(() {
                    c.verseStart = verse;
                    c.verseEnd = verse;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _VerseDropdown(
                label: 'Até',
                bookId: c.verseStart == null ? null : c.bookId,
                chapter: c.verseStart == null ? null : c.chapter,
                minValue: c.verseStart,
                value: c.verseEnd,
                onChanged: (verse) {
                  widget.onChanged?.call();
                  setState(() => c.verseEnd = verse);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Campo de livro digitável com sugestões da Bíblia — cópia adaptada de
/// `_BaseBookField` (`devotional_form_page.dart`), duplicada localmente
/// (mesmo padrão de duplicação já usado entre telas nesta base).
class _BookField extends ConsumerStatefulWidget {
  const _BookField({
    required this.controller,
    required this.focusNode,
    required this.onSelected,
    required this.onEdited,
    this.isError = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<BibleBook> onSelected;
  final VoidCallback onEdited;
  final bool isError;

  @override
  ConsumerState<_BookField> createState() => _BookFieldState();
}

class _BookFieldState extends ConsumerState<_BookField> {
  /// `true` logo após um toque numa sugestão — esconde a lista sem tirar o
  /// foco do campo (28/08/2026, corrige bug relatado pelo usuário: o
  /// `widget.focusNode.unfocus()` que existia aqui antes fazia o cursor
  /// "sair do campo" ao selecionar um livro). Volta a `false` assim que o
  /// usuário edita o texto de novo.
  bool _suppressSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!widget.focusNode.hasFocus) {
      final books =
          ref.read(bibleBooksProvider).asData?.value ?? const <BibleBook>[];
      final query = _normalizeText(widget.controller.text);
      if (query.isNotEmpty) {
        final exact = books.where((b) => _normalizeText(b.name) == query);
        if (exact.isNotEmpty) {
          widget.onSelected(exact.first);
          setState(() {});
          return;
        }
      }
    }
    setState(() {});
  }

  List<BibleBook> _matches(List<BibleBook> books) {
    if (_suppressSuggestions) return const <BibleBook>[];
    final query = _normalizeText(widget.controller.text);
    if (query.isEmpty) return books;
    return books.where((b) => _normalizeText(b.name).contains(query)).toList();
  }

  void _select(BibleBook book) {
    widget.controller.text = book.name;
    widget.controller.selection = TextSelection.collapsed(
      offset: book.name.length,
    );
    widget.onSelected(book);
    setState(() => _suppressSuggestions = true);
  }

  @override
  Widget build(BuildContext context) {
    final books =
        ref.watch(bibleBooksProvider).asData?.value ?? const <BibleBook>[];
    final matches = widget.focusNode.hasFocus
        ? _matches(books)
        : const <BibleBook>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              // 28/08/2026, corrige bug relatado pelo usuário ("dropdown do
              // livro ainda na cor errada"): `canvasColor` cai no mesmo tom
              // do fundo do `AlertDialog` quando este campo é usado dentro
              // de um diálogo (ex. "Leitura bíblica"/"Texto bíblico" em
              // `_MultiBibleReferenceDialog`) — mesma correção já aplicada
              // aos dropdowns de Capítulo/Versículo.
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final book = matches[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.textPrimary),
                  ),
                  onTap: () => _select(book),
                );
              },
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: highlightIfEmpty(
            const InputDecoration(
              labelText: 'Livro',
              hintText: 'Toque para escolher ou digite para buscar',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.arrow_drop_down),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            widget.controller.text,
            isError: widget.isError,
            // Este campo nunca teve o realce âmbar geral (28/08/2026) —
            // só passou a existir realce nele quando virou obrigatório, e aí
            // só o vermelho de erro depois de uma tentativa de avançar.
            highlightEmpty: false,
          ),
          onChanged: (_) {
            if (_suppressSuggestions) {
              setState(() => _suppressSuggestions = false);
            }
            widget.onEdited();
          },
        ),
      ],
    );
  }
}

class _ChapterDropdown extends ConsumerWidget {
  const _ChapterDropdown({
    required this.bookId,
    required this.value,
    required this.onChanged,
  });

  final int? bookId;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = bookId == null
        ? 0
        : (ref.watch(bibleChapterCountProvider(bookId!)).asData?.value ?? 0);
    return DropdownButtonFormField<int>(
      key: ValueKey('chapter-$bookId-$count'),
      isExpanded: true,
      // Cor do popup diferente do fundo do diálogo (28/08/2026, corrige bug
      // relatado pelo usuário: sem isso os dois caem em `canvasColor`, igual
      // ao fundo de `AlertDialog`, e a lista some visualmente).
      dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      initialValue: count > 0 && value != null && value! <= count
          ? value
          : null,
      decoration: const InputDecoration(
        labelText: 'Capítulo',
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      items: [
        for (var chapter = 1; chapter <= count; chapter++)
          DropdownMenuItem(value: chapter, child: Text('$chapter')),
      ],
      onChanged: count == 0 ? null : onChanged,
    );
  }
}

class _VerseDropdown extends ConsumerWidget {
  const _VerseDropdown({
    required this.label,
    required this.bookId,
    required this.chapter,
    required this.minValue,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? bookId;
  final int? chapter;
  final int? minValue;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verses = (bookId == null || chapter == null)
        ? const <BibleVerse>[]
        : ref
                  .watch(
                    bibleVersesProvider((bookId: bookId!, chapter: chapter!)),
                  )
                  .asData
                  ?.value ??
              const <BibleVerse>[];
    final numbers = verses
        .map((v) => v.number)
        .where((n) => minValue == null || n >= minValue!)
        .toList();
    return DropdownButtonFormField<int>(
      key: ValueKey(
        'verse-$label-$bookId-$chapter-$minValue-${numbers.length}',
      ),
      isExpanded: true,
      dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      initialValue: numbers.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
      ),
      items: [
        for (final number in numbers)
          DropdownMenuItem(value: number, child: Text('$number')),
      ],
      onChanged: numbers.isEmpty ? null : onChanged,
    );
  }
}

/// Campo "Participação Especial" com sugestão de nomes entre os membros
/// cadastrados (`membersProvider`) — mesmo padrão embutido-na-árvore de
/// `_InvitedByField` em `introduction_page.dart` (não `Autocomplete`, que já
/// causou um bug de assert nesta base).
class _ParticipationField extends ConsumerStatefulWidget {
  const _ParticipationField({
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  ConsumerState<_ParticipationField> createState() =>
      _ParticipationFieldState();
}

class _ParticipationFieldState extends ConsumerState<_ParticipationField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  List<String> _matches(List<Member> members) {
    final query = _normalizeText(widget.controller.text);
    if (query.isEmpty) return const [];
    final names =
        members
            .map((m) => m.name.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names
        .where((name) => _normalizeText(name).contains(query))
        .take(8)
        .toList();
  }

  void _select(String name) {
    widget.controller.text = name;
    widget.controller.selection = TextSelection.collapsed(offset: name.length);
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final members =
        ref.watch(membersProvider).asData?.value ?? const <Member>[];
    final matches = widget.focusNode.hasFocus
        ? _matches(members)
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final name = matches[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    name,
                    style: TextStyle(color: context.textPrimary),
                  ),
                  onTap: () => _select(name),
                );
              },
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: highlightIfEmpty(
            const InputDecoration(
              hintText: 'Digite pra buscar entre os membros',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            widget.controller.text,
          ),
        ),
      ],
    );
  }
}

/// Campo "Hino Congregacional" com sugestão combinando os dois hinários (HCC
/// e Cantor Cristão) — cada sugestão mostra o prefixo do hinário de origem
/// (`Hymnal.titlePrefix`) pra desambiguar.
class _HymnField extends ConsumerStatefulWidget {
  const _HymnField({
    required this.controller,
    required this.focusNode,
    this.isError = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isError;

  @override
  ConsumerState<_HymnField> createState() => _HymnFieldState();
}

class _HymnFieldState extends ConsumerState<_HymnField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  List<String> _matches(List<Hymn> cantorCristao, List<Hymn> hinarioCristao) {
    final query = _normalizeText(widget.controller.text);
    if (query.isEmpty) return const [];
    final all = [
      for (final hymn in cantorCristao)
        '${Hymnal.cantorCristao.titlePrefix} ${hymn.number} — ${hymn.title}',
      for (final hymn in hinarioCristao)
        '${Hymnal.hinarioCristao.titlePrefix} ${hymn.number} — ${hymn.title}',
    ];
    return all
        .where((label) => _normalizeText(label).contains(query))
        .take(8)
        .toList();
  }

  void _select(String label) {
    widget.controller.text = label;
    widget.controller.selection = TextSelection.collapsed(offset: label.length);
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cantorCristao =
        ref.watch(hymnSongsProvider(Hymnal.cantorCristao)).asData?.value ??
        const <Hymn>[];
    final hinarioCristao =
        ref.watch(hymnSongsProvider(Hymnal.hinarioCristao)).asData?.value ??
        const <Hymn>[];
    final matches = widget.focusNode.hasFocus
        ? _matches(cantorCristao, hinarioCristao)
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final label = matches[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    label,
                    style: TextStyle(color: context.textPrimary),
                  ),
                  onTap: () => _select(label),
                );
              },
            ),
          ),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: highlightIfEmpty(
            const InputDecoration(
              hintText: 'Digite pra buscar no HCC ou Cantor Cristão',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            widget.controller.text,
            isError: widget.isError,
          ),
        ),
      ],
    );
  }
}

const _diacritics = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
const _plainLetters = 'aaaaaeeeeiiiiooooouuuucn';

/// Case/acento-insensível — mesmo helper duplicado em outras telas desta
/// base (`_normalizeBookName`/`_normalizeName`).
String _normalizeText(String value) {
  var result = value.toLowerCase().trim();
  for (var i = 0; i < _diacritics.length; i++) {
    result = result.replaceAll(_diacritics[i], _plainLetters[i]);
  }
  return result;
}
