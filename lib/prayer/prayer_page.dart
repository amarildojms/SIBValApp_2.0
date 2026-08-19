import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/prayer_repository.dart';
import '../data/settings_repository.dart';
import '../data/user_repository.dart';
import '../models/prayer_request.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'archived_prayer_page.dart';

/// Espelha PrayerFragment.kt/PrayerViewModel.kt: formulário de envio (anônimo
/// ou identificado) sempre visível, lista só pra quem tem permissão
/// (admin/intercessão). Encaminhar ao responsável (`sendToResponsible`) abre o
/// WhatsApp com a mensagem formatada e arquiva o pedido como efeito colateral,
/// igual ao nativo; o telefone do responsável é editável só por admin
/// (`showResponsiblePhoneDialog`), via `SettingsRepository.setPrayerResponsiblePhone`.
class PrayerPage extends ConsumerStatefulWidget {
  const PrayerPage({super.key});

  @override
  ConsumerState<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends ConsumerState<PrayerPage> {
  final _textController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isAnonymous = false;
  bool _sending = false;
  String? _nameError;
  bool _prefilled = false;

  @override
  void dispose() {
    _textController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _prefillIfNeeded(CurrentUserProfile? profile) {
    if (_prefilled || profile == null) return;
    _prefilled = true;
    _nameController.text = profile.name;
    _emailController.text = profile.email;
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (!_isAnonymous && _nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Informe seu nome ou marque como anônimo.');
      return;
    }

    setState(() {
      _sending = true;
      _nameError = null;
    });
    try {
      await ref.read(prayerRepositoryProvider).submit(PrayerRequest(
            id: '',
            authorName: _isAnonymous ? '' : _nameController.text.trim(),
            authorPhone: _isAnonymous ? '' : _phoneController.text.trim(),
            authorEmail: _isAnonymous ? '' : _emailController.text.trim(),
            isAnonymous: _isAnonymous,
            text: text,
            createdAt: null,
          ));
      _textController.clear();
      _phoneController.clear();
      setState(() => _isAnonymous = false);
      ref.invalidate(prayerRequestsProvider);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pedido enviado'),
            content: const Text('Obrigado por compartilhar! Vamos orar por você.'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _archive(String id) async {
    await ref.read(prayerRepositoryProvider).archive(id);
    ref.invalidate(prayerRequestsProvider);
  }

  Future<void> _delete(String id) async {
    await ref.read(prayerRepositoryProvider).delete(id);
    ref.invalidate(prayerRequestsProvider);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendToResponsible(PrayerRequest request) async {
    String responsiblePhone = '';
    try {
      responsiblePhone = await ref.read(prayerResponsiblePhoneProvider.future);
    } catch (_) {
      responsiblePhone = '';
    }
    if (responsiblePhone.trim().isEmpty) {
      if (mounted) _showMessage('Configure o número do responsável antes de encaminhar pedidos.');
      return;
    }

    final digits = responsiblePhone.replaceAll(RegExp(r'\D'), '');
    final fullNumber = digits.startsWith('55') ? digits : '55$digits';

    final isAnonymous = request.isAnonymous || request.authorName.isEmpty;
    final dateLabel = request.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(request.createdAt!)
        : '';

    final buffer = StringBuffer('Pedido de oração\n\n')
      ..write('Nome: ${isAnonymous ? 'Anônimo' : request.authorName}');
    if (!isAnonymous) {
      if (request.authorPhone.isNotEmpty) buffer.write('\nTelefone: ${request.authorPhone}');
      if (request.authorEmail.isNotEmpty) buffer.write('\nE-mail: ${request.authorEmail}');
    }
    if (dateLabel.isNotEmpty) buffer.write('\nData: $dateLabel');
    buffer.write('\n\nMensagem:\n${request.text}');

    final uri = Uri.https('wa.me', '/$fullNumber', {'text': buffer.toString()});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    await _archive(request.id);
  }

  Future<void> _editResponsiblePhone() async {
    String currentPhone = '';
    try {
      currentPhone = await ref.read(prayerResponsiblePhoneProvider.future);
    } catch (_) {
      currentPhone = '';
    }
    if (!mounted) return;

    final controller = TextEditingController(text: currentPhone);
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Número do responsável'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o número de WhatsApp (com DDD) que receberá os pedidos de oração encaminhados.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Ex: 11912345678'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(dialogContext).unfocus();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              FocusScope.of(dialogContext).unfocus();
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (phone == null) return;

    await ref.read(settingsRepositoryProvider).setPrayerResponsiblePhone(phone);
    ref.invalidate(prayerResponsiblePhoneProvider);
    if (mounted) _showMessage('Número atualizado com sucesso.');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.asData?.value;
    _prefillIfNeeded(profile);
    final canView = profile?.canViewPrayerRequests ?? false;

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ScreenTitle('Pedido de Oração'),
          TextField(
            controller: _textController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Seu pedido de oração'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _isAnonymous,
            onChanged: (value) => setState(() => _isAnonymous = value ?? false),
            title: Text('Enviar de forma anônima', style: TextStyle(color: context.textPrimary)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _nameController,
            enabled: !_isAnonymous,
            decoration: InputDecoration(labelText: 'Nome', errorText: _nameError),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            enabled: !_isAnonymous,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            enabled: !_isAnonymous,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail (opcional)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enviar'),
          ),
          const SizedBox(height: 24),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 8),
          if (!canView)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: Text(
                  'Os pedidos enviados são privados — só a equipe de intercessão pode vê-los.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (profile?.isAdmin ?? false)
                  IconButton(
                    tooltip: 'Número do responsável',
                    onPressed: _editResponsiblePhone,
                    icon: const Icon(Icons.settings_outlined),
                  )
                else
                  const SizedBox.shrink(),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchivedPrayerPage())),
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  label: const Text('Pedidos arquivados'),
                ),
              ],
            ),
            _PrayerList(onArchive: _archive, onDelete: _delete, onSend: _sendToResponsible),
          ],
        ],
        ),
      ),
    );
  }
}

class _PrayerList extends ConsumerWidget {
  const _PrayerList({required this.onArchive, required this.onDelete, required this.onSend});

  final void Function(String id) onArchive;
  final void Function(String id) onDelete;
  final void Function(PrayerRequest request) onSend;

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(prayerRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('Nenhum pedido de oração no momento.', style: TextStyle(color: context.textSecondary)),
            ),
          );
        }
        return Column(
          children: [
            for (final request in requests)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(request.isAnonymous || request.authorName.isEmpty ? 'Anônimo' : request.authorName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.text),
                      if (request.createdAt != null)
                        Text(_dateFormat.format(request.createdAt!), style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: 'Encaminhar ao responsável',
                    icon: const Icon(Icons.send_outlined),
                    onPressed: () => onSend(request),
                  ),
                  onLongPress: () => _showActions(context, request.id),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showActions(BuildContext context, String id) async {
    final choice = await showDialog<_PrayerAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pedido de oração'),
        content: const Text('O que deseja fazer com este pedido?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_PrayerAction.archive),
            child: const Text('Arquivar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_PrayerAction.delete),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    switch (choice) {
      case _PrayerAction.archive:
        onArchive(id);
      case _PrayerAction.delete:
        await _confirmDelete(context, id);
      case null:
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir pedido'),
        content: const Text('Tem certeza que deseja excluir este pedido de oração? Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed == true) onDelete(id);
  }
}

enum _PrayerAction { archive, delete }
