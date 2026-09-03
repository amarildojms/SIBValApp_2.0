import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/notice_repository.dart';
import '../models/notice.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'notice_detail_page.dart';
import 'notice_form_page.dart';

/// Gerenciamento do Quadro de Avisos (03/09/2026) — alcançado pelo ícone
/// "Quadro de Avisos" no menu Mais, visível só a quem tem
/// `canManagePublications` (papel Publicações ou admin, ver
/// `home_quick_tiles.dart`). Insere/edita/exclui — os demais usuários nunca
/// chegam aqui, só veem os avisos pelo painel rotativo da Início.
class NoticeManagementPage extends ConsumerWidget {
  const NoticeManagementPage({super.key});

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Notice notice,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir aviso'),
        content: Text(
          'Excluir "${notice.title}"? Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(noticeRepositoryProvider).delete(notice);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticesProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      floatingActionButton: FloatingActionButton(
        heroTag: 'notice_management_fab',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NoticeFormPage())),
        child: const Icon(Icons.add),
      ),
      // `SafeArea` no rodapé (03/09/2026, corrige conteúdo escondido atrás
      // dos botões de navegação do sistema, relatado pelo usuário) — mesmo
      // padrão já usado no resto do app.
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Quadro de Avisos'),
            Expanded(
              child: noticesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    'Falha ao carregar: $error',
                    style: TextStyle(color: context.textPrimary),
                  ),
                ),
                data: (notices) => notices.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum aviso cadastrado ainda.',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: notices.length,
                        itemBuilder: (context, index) {
                          final notice = notices[index];
                          return Card(
                            margin: const EdgeInsets.only(top: 12),
                            child: ListTile(
                              leading: notice.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        notice.imageUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.campaign_outlined,
                                      color: SibValColors.goldAccent,
                                    ),
                              title: Text(
                                notice.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                notice.createdAt != null
                                    ? _dateFormat.format(notice.createdAt!)
                                    : '',
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      NoticeDetailPage(notice: notice),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            NoticeFormPage(editing: notice),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        _confirmDelete(context, ref, notice),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
