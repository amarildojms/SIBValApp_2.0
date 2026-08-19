import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/prayer_repository.dart';
import '../data/user_repository.dart';
import '../models/prayer_request.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha PrayerFragment.kt/PrayerViewModel.kt: formulário de envio (anônimo
/// ou identificado) sempre visível, lista só pra quem tem permissão
/// (admin/intercessão). Arquivados e telefone do responsável ficam de fora
/// desta passada.
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

  Future<void> _delete(String id) async {
    await ref.read(prayerRepositoryProvider).delete(id);
    ref.invalidate(prayerRequestsProvider);
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
          else
            _PrayerList(onDelete: _delete),
        ],
        ),
      ),
    );
  }
}

class _PrayerList extends ConsumerWidget {
  const _PrayerList({required this.onDelete});

  final void Function(String id) onDelete;

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
                  subtitle: Text(request.text),
                  trailing: request.createdAt != null
                      ? Text(_dateFormat.format(request.createdAt!), style: const TextStyle(fontSize: 11))
                      : null,
                  onLongPress: () => _confirmDelete(context, request.id),
                ),
              ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir pedido'),
        content: const Text('Tem certeza que deseja excluir este pedido de oração?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete(id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
