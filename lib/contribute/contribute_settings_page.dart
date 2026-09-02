import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contribution_repository.dart';
import '../models/contribution_info.dart';
import '../theme/app_theme.dart';
import '../util/brazilian_banks.dart';
import '../util/cnpj_input.dart';
import '../util/cnpj_lookup.dart';
import '../util/scroll_to_save.dart';
import '../widgets/sibval_app_bar.dart';

/// Opção escolhida no diálogo de "alterações não salvas" ao tentar voltar
/// (`_ContributeSettingsPageState._confirmLeave`, 01/09/2026).
enum _LeaveAction { cancel, discard, save }

/// Rascunho editável de uma chave PIX (22/08/2026) — dono dos próprios
/// controllers, mesmo padrão de `_MemberDialog` em `members_page.dart`. A
/// partir de 01/09/2026 só existe dentro do popup de
/// `_ContributeSettingsPageState._showPixDialog` — a lista principal da tela
/// só mostra um resumo (`_buildPixTile`), não os campos abertos.
class _PixDraft {
  _PixDraft({String label = '', String key = '', String description = ''})
    : labelController = TextEditingController(text: label),
      keyController = TextEditingController(text: key),
      descriptionController = TextEditingController(text: description);

  final TextEditingController labelController;
  final TextEditingController keyController;
  final TextEditingController descriptionController;

  void dispose() {
    labelController.dispose();
    keyController.dispose();
    descriptionController.dispose();
  }
}

/// Rascunho editável de uma conta bancária (22/08/2026).
class _BankDraft {
  _BankDraft({String label = '', this.bankName, String agency = '', String operation = '', String account = ''})
    : labelController = TextEditingController(text: label),
      agencyController = TextEditingController(text: agency),
      operationController = TextEditingController(text: operation),
      accountController = TextEditingController(text: account);

  final TextEditingController labelController;
  String? bankName;
  final TextEditingController agencyController;
  final TextEditingController operationController;
  final TextEditingController accountController;

  void dispose() {
    labelController.dispose();
    agencyController.dispose();
    operationController.dispose();
    accountController.dispose();
  }
}

/// Tela de cadastro dos dados da Contribua (21/08/2026) — só chega aqui quem
/// é admin (gate na engrenagem de `contribute_page.dart`). Ao completar os 14
/// dígitos do CNPJ, busca a razão social automaticamente (`lookupCnpj`), mas
/// o campo continua editável — o admin pode ajustar o que a busca trouxer.
/// Suporta várias chaves PIX e várias contas bancárias (22/08/2026).
class ContributeSettingsPage extends ConsumerStatefulWidget {
  const ContributeSettingsPage({super.key, required this.initial});

  final ContributionInfo initial;

  @override
  ConsumerState<ContributeSettingsPage> createState() => _ContributeSettingsPageState();
}

class _ContributeSettingsPageState extends ConsumerState<ContributeSettingsPage> {
  late final _churchNameController = TextEditingController(text: widget.initial.churchName);
  late final _cityController = TextEditingController(text: widget.initial.city);
  late final _cnpjController = TextEditingController(
    text: CnpjInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: widget.initial.cnpj))
        .text,
  );

  late final List<_PixDraft> _pixDrafts = [
    for (final entry in widget.initial.pixEntries)
      _PixDraft(label: entry.label, key: entry.key, description: entry.description),
  ];
  late final List<_BankDraft> _bankDrafts = [
    for (final entry in widget.initial.bankAccounts)
      _BankDraft(
        label: entry.label,
        bankName: entry.bankName.isNotEmpty ? entry.bankName : null,
        agency: entry.agency,
        operation: entry.operation,
        account: entry.account,
      ),
  ];
  final _scrollController = ScrollController();

  bool _lookingUpCnpj = false;
  bool _saving = false;

  /// `true` assim que qualquer campo muda — usado pelo `PopScope` do `build`
  /// pra avisar antes de sair sem salvar (01/09/2026, pedido do usuário).
  /// Vira `false` de novo só quando a tela é recriada (não há "salvar
  /// parcial" — o único jeito de zerar é `_save()` ter sucesso, que já fecha
  /// a tela).
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _churchNameController.dispose();
    _cityController.dispose();
    _cnpjController.dispose();
    for (final draft in _pixDrafts) {
      draft.dispose();
    }
    for (final draft in _bankDrafts) {
      draft.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Preenche direto o campo "Nome da igreja" com a razão social encontrada —
  /// sem campo separado (22/08/2026, a pedido do usuário). Continua editável
  /// depois: o admin pode ajustar o texto normalmente.
  Future<void> _onCnpjChanged(String text) async {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14) return;
    setState(() => _lookingUpCnpj = true);
    final legalName = await lookupCnpj(text);
    if (!mounted) return;
    setState(() {
      _lookingUpCnpj = false;
      _dirty = true;
      if (legalName != null && legalName.isNotEmpty) _churchNameController.text = legalName;
    });
  }

  /// Abre o popup de cadastro/edição de uma chave PIX (01/09/2026, pedido do
  /// usuário — antes os campos abriam direto na lista, no fim da página).
  /// Edita sempre um rascunho temporário, só aplicado à lista de verdade (ou
  /// criado nela, se novo) quando o admin confirma — "Cancelar" de fato
  /// descarta o que foi digitado.
  Future<void> _showPixDialog({_PixDraft? existing}) async {
    // Chave nova pré-preenchida com o CNPJ já cadastrado (só dígitos, formato
    // de chave Pix tipo CNPJ) — pedido do usuário, continua editável.
    final cnpjDigits = _cnpjController.text.replaceAll(RegExp(r'\D'), '');
    final temp = _PixDraft(
      label: existing?.labelController.text ?? '',
      key: existing?.keyController.text ?? cnpjDigits,
      description: existing?.descriptionController.text ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Nova chave PIX' : 'Editar chave PIX'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: temp.labelController,
                decoration: const InputDecoration(
                  labelText: 'Identificação interna (ex.: Dízimos, Missões)',
                  helperText: 'Só pra você organizar aqui — não aparece pro usuário.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: temp.keyController,
                decoration: InputDecoration(
                  labelText: 'Chave PIX',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Copiar chave',
                    onPressed: () {
                      if (temp.keyController.text.isEmpty) return;
                      Clipboard.setData(ClipboardData(text: temp.keyController.text));
                      ScaffoldMessenger.of(dialogContext)
                          .showSnackBar(const SnackBar(content: Text('Chave PIX copiada.')));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: temp.descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (ex.: Oferta para Missões, Dízimo)',
                  helperText: 'Texto exibido no card da Contribua e na mensagem do código Pix gerado.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(existing == null ? 'Adicionar' : 'Salvar'),
          ),
        ],
      ),
    );

    final label = temp.labelController.text;
    final key = temp.keyController.text;
    final description = temp.descriptionController.text;
    // Adiado pro próximo frame: descartar os controllers na hora, logo após
    // o await, derrubava o app ("A TextEditingController was used after
    // being disposed") — o TextField que estava com foco no diálogo só
    // termina de perder o foco (e mexe no controller por causa disso) durante
    // a animação de saída, que ainda está rolando quando o Future do
    // showDialog já resolveu.
    WidgetsBinding.instance.addPostFrameCallback((_) => temp.dispose());
    if (confirmed != true) return;

    final isNew = existing == null;
    setState(() {
      _dirty = true;
      if (isNew) {
        _pixDrafts.add(_PixDraft(label: label, key: key, description: description));
      } else {
        existing.labelController.text = label;
        existing.keyController.text = key;
        existing.descriptionController.text = description;
      }
    });
    if (isNew && mounted) {
      final title = description.isNotEmpty ? description : (label.isNotEmpty ? label : 'Chave PIX');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chave "$title" adicionada com sucesso.')));
    }
  }

  void _removePixDraft(_PixDraft draft) {
    setState(() {
      _dirty = true;
      _pixDrafts.remove(draft);
      draft.dispose();
    });
  }

  void _addBankDraft() => setState(() {
    _dirty = true;
    _bankDrafts.add(_BankDraft());
  });

  void _removeBankDraft(_BankDraft draft) {
    setState(() {
      _dirty = true;
      _bankDrafts.remove(draft);
      draft.dispose();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _scrollController.scrollToSaveButton();
    try {
      final repo = ref.read(contributionRepositoryProvider);
      final pixEntries = <PixEntry>[];
      for (final draft in _pixDrafts) {
        final label = draft.labelController.text.trim();
        final key = draft.keyController.text.trim();
        final description = draft.descriptionController.text.trim();
        if (label.isEmpty && key.isEmpty && description.isEmpty) continue;
        pixEntries.add(PixEntry(label: label, key: key, description: description));
      }

      final bankAccounts = <BankAccountEntry>[];
      for (final draft in _bankDrafts) {
        final label = draft.labelController.text.trim();
        final bankName = draft.bankName ?? '';
        final agency = draft.agencyController.text.trim();
        final operation = draft.operationController.text.trim();
        final account = draft.accountController.text.trim();
        if (label.isEmpty && bankName.isEmpty && agency.isEmpty && operation.isEmpty && account.isEmpty) continue;
        bankAccounts.add(
          BankAccountEntry(label: label, bankName: bankName, agency: agency, operation: operation, account: account),
        );
      }

      await repo.update(
        churchName: _churchNameController.text.trim(),
        cnpj: _cnpjController.text.trim(),
        city: _cityController.text.trim(),
        pixEntries: pixEntries,
        bankAccounts: bankAccounts,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Diálogo mostrado ao tentar voltar com `_dirty` (01/09/2026, pedido do
  /// usuário) — diferente de `_confirmDiscardAndPop` (`introduction_page.dart`),
  /// aqui há uma terceira opção pra salvar direto, sem precisar reabrir o
  /// formulário e tocar em "Salvar" de novo.
  Future<void> _confirmLeave() async {
    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alterações não salvas'),
        content: const Text('Você tem alterações não salvas nesta tela. Deseja salvar antes de sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_LeaveAction.cancel),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_LeaveAction.discard),
            child: const Text('Sair sem salvar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_LeaveAction.save),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _LeaveAction.discard:
        Navigator.of(context).pop();
      case _LeaveAction.save:
        await _save(); // _save() já fecha a tela sozinho quando tem sucesso.
      case _LeaveAction.cancel:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ScreenTitle('Configurar Contribua'),
                const SizedBox(height: 8),
                TextField(
                  controller: _cnpjController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CnpjInputFormatter()],
                  onChanged: (text) {
                    _markDirty();
                    _onCnpjChanged(text);
                  },
                  decoration: InputDecoration(
                    labelText: 'CNPJ',
                    suffixIcon: _lookingUpCnpj
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _churchNameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => _markDirty(),
                  decoration: const InputDecoration(labelText: 'Nome da igreja'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => _markDirty(),
                  decoration: const InputDecoration(
                    labelText: 'Cidade',
                    helperText: 'Usada pra gerar o código Pix da Oferta para Missões.',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PIX',
                        style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showPixDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar chave'),
                    ),
                  ],
                ),
                for (final draft in _pixDrafts) _buildPixTile(context, draft),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contas Bancárias',
                        style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addBankDraft,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar conta'),
                    ),
                  ],
                ),
                for (final draft in _bankDrafts) _buildBankCard(context, draft),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPixTile(BuildContext context, _PixDraft draft) {
    final title = draft.descriptionController.text.isNotEmpty
        ? draft.descriptionController.text
        : draft.labelController.text.isNotEmpty
        ? draft.labelController.text
        : 'Chave PIX sem descrição';
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ListTile(
        onTap: () => _showPixDialog(existing: draft),
        title: Text(
          title,
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          draft.keyController.text.isNotEmpty ? draft.keyController.text : 'Chave ainda não preenchida',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remover chave',
          onPressed: () => _removePixDraft(draft),
        ),
      ),
    );
  }

  Widget _buildBankCard(BuildContext context, _BankDraft draft) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.labelController,
                    onChanged: (_) => _markDirty(),
                    decoration: const InputDecoration(labelText: 'Identificação (ex.: Conta principal)'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remover conta',
                  onPressed: () => _removeBankDraft(draft),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: draft.bankName,
              decoration: const InputDecoration(labelText: 'Banco'),
              items: [for (final bank in brazilianBanks) DropdownMenuItem(value: bank, child: Text(bank))],
              onChanged: (value) => setState(() {
                _dirty = true;
                draft.bankName = value;
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.agencyController,
                    onChanged: (_) => _markDirty(),
                    decoration: const InputDecoration(labelText: 'Agência'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.operationController,
                    onChanged: (_) => _markDirty(),
                    decoration: const InputDecoration(labelText: 'Operação'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.accountController,
              onChanged: (_) => _markDirty(),
              decoration: const InputDecoration(labelText: 'Conta'),
            ),
          ],
        ),
      ),
    );
  }
}
