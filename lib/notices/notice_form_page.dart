import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/contribution_repository.dart' show contributionInfoProvider;
import '../data/notice_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../data/user_repository.dart';
import '../models/contribution_info.dart';
import '../models/notice.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Cadastro/edição de aviso do Quadro de Avisos (03/09/2026) — só chega aqui
/// quem tem `canManagePublications` (gate no FAB de `NoticeManagementPage`).
class NoticeFormPage extends ConsumerStatefulWidget {
  const NoticeFormPage({super.key, this.editing});

  final Notice? editing;

  @override
  ConsumerState<NoticeFormPage> createState() => _NoticeFormPageState();
}

class _NoticeFormPageState extends ConsumerState<NoticeFormPage> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _registrationLinkController = TextEditingController();
  File? _pickedImage;
  bool _needsOffering = false;
  String _offerPixKey = '';
  String _offerDescription = '';
  String _offerChurchName = '';
  String _offerCity = '';
  bool _requiresRegistration = false;
  bool _dirty = false;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _titleController.text = editing.title;
      _messageController.text = editing.message;
      _needsOffering = editing.needsOffering;
      _offerPixKey = editing.offerPixKey;
      _offerDescription = editing.offerDescription;
      _offerChurchName = editing.offerChurchName;
      _offerCity = editing.offerCity;
      _requiresRegistration = editing.requiresRegistration;
      _registrationLinkController.text = editing.registrationLink;
    }
    _titleController.addListener(_markDirty);
    _messageController.addListener(_markDirty);
    _registrationLinkController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _registrationLinkController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text('As alterações feitas serão perdidas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair sem salvar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _dirty = true;
      });
    }
  }

  Future<void> _pickOffer() async {
    final info = ref.read(contributionInfoProvider).asData?.value ?? ContributionInfo.empty;
    final options = info.pixEntries.where((p) => p.key.isNotEmpty && p.displayTitle.isNotEmpty).toList();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma chave Pix cadastrada na Contribua ainda.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<PixEntry>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Escolha o link de oferta',
                style: TextStyle(
                  color: sheetContext.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            for (final pix in options)
              ListTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: Text(pix.displayTitle),
                onTap: () => Navigator.of(sheetContext).pop(pix),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _offerPixKey = picked.key;
        _offerDescription = picked.displayTitle;
        _offerChurchName = info.churchName;
        _offerCity = info.city;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um título.')));
      return;
    }
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escreva o texto do aviso.')));
      return;
    }
    if (_needsOffering && _offerPixKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Busque o link de oferta na Contribua, ou desmarque a opção acima.')),
      );
      return;
    }
    final registrationLink = _registrationLinkController.text.trim();
    if (_requiresRegistration && registrationLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o link de inscrição, ou desmarque a opção acima.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(noticeRepositoryProvider);
      if (widget.editing != null) {
        await repo.update(
          notice: widget.editing!,
          title: title,
          message: message,
          imageFile: _pickedImage,
          needsOffering: _needsOffering,
          offerPixKey: _offerPixKey,
          offerDescription: _offerDescription,
          offerChurchName: _offerChurchName,
          offerCity: _offerCity,
          requiresRegistration: _requiresRegistration,
          registrationLink: registrationLink,
        );
      } else {
        final uid = ref.read(currentUidProvider) ?? '';
        final profile = ref.read(currentUserProfileProvider).asData?.value;
        await repo.create(
          title: title,
          message: message,
          imageFile: _pickedImage,
          needsOffering: _needsOffering,
          offerPixKey: _offerPixKey,
          offerDescription: _offerDescription,
          offerChurchName: _offerChurchName,
          offerCity: _offerCity,
          requiresRegistration: _requiresRegistration,
          registrationLink: registrationLink,
          createdByUid: uid,
          createdByName: profile?.shortName ?? '',
        );
      }
      if (!mounted) return;
      _dirty = false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Aviso salvo'),
          content: const Text('O aviso foi salvo com sucesso.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao salvar o aviso: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingImageUrl = widget.editing?.imageUrl ?? '';
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenTitle(_isEditing ? 'Editar aviso' : 'Novo aviso'),
                const SizedBox(height: 16),
                // Mesmo padrão do seletor de flyer de `EventFormPage`
                // (03/09/2026, pedido do usuário: "no mesmo padrão das
                // demais, igual nos posts e eventos") — `AspectRatio` 16:9 em
                // vez de altura fixa, ícone 40 e só o aviso de proporção
                // recomendada, sem "(opcional)" solto.
                GestureDetector(
                  onTap: _pickImage,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: _pickedImage != null
                          ? Image.file(_pickedImage!, fit: BoxFit.cover)
                          : existingImageUrl.isNotEmpty
                              ? Image.network(existingImageUrl, fit: BoxFit.cover)
                              : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, color: context.textSecondary, size: 40),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Proporção recomendada: 16:9',
                                        style: TextStyle(color: context.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ex.: Campanha de Missões',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Texto do aviso', alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                // Mesmo estilo Row+Switch de "Requer inscrição" em
                // `EventFormPage` (padronizado nos dois flags deste
                // formulário, 03/09/2026).
                Row(
                  children: [
                    Expanded(
                      child: Text('Este aviso precisa de oferta', style: TextStyle(color: context.textPrimary)),
                    ),
                    Switch(
                      value: _needsOffering,
                      onChanged: (value) => setState(() {
                        _needsOffering = value;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
                if (_needsOffering) ...[
                  if (_offerDescription.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Link de oferta selecionado: $_offerDescription',
                        style: TextStyle(color: context.textSecondary, fontSize: 13),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickOffer,
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: Text(_offerDescription.isEmpty ? 'Buscar link de oferta' : 'Trocar link de oferta'),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text('Requer inscrição', style: TextStyle(color: context.textPrimary)),
                    ),
                    Switch(
                      value: _requiresRegistration,
                      onChanged: (value) => setState(() {
                        _requiresRegistration = value;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
                if (_requiresRegistration) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _registrationLinkController,
                    decoration: const InputDecoration(labelText: 'Link de inscrição'),
                  ),
                ],
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
}
