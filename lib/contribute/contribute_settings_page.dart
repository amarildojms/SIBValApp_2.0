import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/contribution_repository.dart';
import '../models/contribution_info.dart';
import '../theme/app_theme.dart';
import '../util/brazilian_banks.dart';
import '../util/cnpj_input.dart';
import '../util/cnpj_lookup.dart';
import '../util/scroll_to_save.dart';
import '../widgets/sibval_app_bar.dart';

/// Rascunho editável de uma chave PIX (22/08/2026) — dono dos próprios
/// controllers, mesmo padrão de `_MemberDialog` em `members_page.dart`.
/// [qrCodeStoragePath] só é apagado do Storage se a entrada for removida ou
/// tiver a imagem trocada e o formulário for de fato salvo — ver
/// `_ContributeSettingsPageState._save`.
class _PixDraft {
  _PixDraft({String label = '', String key = '', this.qrCodeUrl = '', this.qrCodeStoragePath = ''})
      : labelController = TextEditingController(text: label),
        keyController = TextEditingController(text: key);

  final TextEditingController labelController;
  final TextEditingController keyController;
  String qrCodeUrl;
  String qrCodeStoragePath;
  File? pickedFile;

  void dispose() {
    labelController.dispose();
    keyController.dispose();
  }
}

/// Rascunho editável de uma conta bancária (22/08/2026).
class _BankDraft {
  _BankDraft({
    String label = '',
    this.bankName,
    String agency = '',
    String operation = '',
    String account = '',
  }) : labelController = TextEditingController(text: label),
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
  late final _cnpjController = TextEditingController(
    text: CnpjInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: widget.initial.cnpj)).text,
  );

  late final List<_PixDraft> _pixDrafts = [
    for (final entry in widget.initial.pixEntries)
      _PixDraft(
        label: entry.label,
        key: entry.key,
        qrCodeUrl: entry.qrCodeUrl,
        qrCodeStoragePath: entry.qrCodeStoragePath,
      ),
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
  final _removedQrStoragePaths = <String>[];
  final _scrollController = ScrollController();

  bool _lookingUpCnpj = false;
  bool _saving = false;

  @override
  void dispose() {
    _churchNameController.dispose();
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
      if (legalName != null && legalName.isNotEmpty) _churchNameController.text = legalName;
    });
  }

  Future<void> _pickPixQrCode(_PixDraft draft) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) setState(() => draft.pickedFile = File(picked.path));
  }

  void _addPixDraft() => setState(() => _pixDrafts.add(_PixDraft()));

  void _removePixDraft(_PixDraft draft) {
    if (draft.qrCodeStoragePath.isNotEmpty) _removedQrStoragePaths.add(draft.qrCodeStoragePath);
    setState(() {
      _pixDrafts.remove(draft);
      draft.dispose();
    });
  }

  void _addBankDraft() => setState(() => _bankDrafts.add(_BankDraft()));

  void _removeBankDraft(_BankDraft draft) {
    setState(() {
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
        var url = draft.qrCodeUrl;
        var path = draft.qrCodeStoragePath;
        final picked = draft.pickedFile;
        if (picked != null) {
          final result = await repo.uploadPixQrCode(picked, oldStoragePath: path.isNotEmpty ? path : null);
          url = result.url;
          path = result.storagePath;
        }
        final label = draft.labelController.text.trim();
        final key = draft.keyController.text.trim();
        if (label.isEmpty && key.isEmpty && url.isEmpty) continue;
        pixEntries.add(PixEntry(label: label, key: key, qrCodeUrl: url, qrCodeStoragePath: path));
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
        pixEntries: pixEntries,
        bankAccounts: bankAccounts,
      );
      for (final path in _removedQrStoragePaths) {
        await repo.deleteQrCode(path);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                onChanged: _onCnpjChanged,
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
                decoration: const InputDecoration(labelText: 'Nome da igreja'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('PIX', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  TextButton.icon(
                    onPressed: _addPixDraft,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar chave'),
                  ),
                ],
              ),
              for (final draft in _pixDrafts) _buildPixCard(context, draft),
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
    );
  }

  Widget _buildPixCard(BuildContext context, _PixDraft draft) {
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
                    decoration: const InputDecoration(labelText: 'Identificação (ex.: Dízimos, Missões)'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remover chave',
                  onPressed: () => _removePixDraft(draft),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.keyController,
              decoration: InputDecoration(
                labelText: 'Chave PIX',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copiar chave',
                  onPressed: () {
                    if (draft.keyController.text.isEmpty) return;
                    Clipboard.setData(ClipboardData(text: draft.keyController.text));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave PIX copiada.')));
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('QR Code', style: TextStyle(color: context.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickPixQrCode(draft),
              child: Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: draft.pickedFile != null
                    ? Image.file(draft.pickedFile!, height: 180, fit: BoxFit.contain)
                    : draft.qrCodeUrl.isNotEmpty
                        ? Image.network(draft.qrCodeUrl, height: 180, fit: BoxFit.contain)
                        : Icon(Icons.qr_code_2_outlined, color: context.textSecondary, size: 40),
              ),
            ),
          ],
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
              onChanged: (value) => setState(() => draft.bankName = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.agencyController,
                    decoration: const InputDecoration(labelText: 'Agência'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.operationController,
                    decoration: const InputDecoration(labelText: 'Operação'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.accountController,
              decoration: const InputDecoration(labelText: 'Conta'),
            ),
          ],
        ),
      ),
    );
  }
}
