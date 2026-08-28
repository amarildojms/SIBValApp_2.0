import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/praise_repertoire_repository.dart';
import '../data/user_repository.dart';
import '../models/praise_repertoire.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'cifra_list_page.dart';
import 'weekly_repertoire_form_page.dart';

/// Sem equivalente no app nativo — feature nova (28/08/2026, pedido do
/// usuário). Ministério de Louvor: duas abas —
/// "Repertório Mensal" (catálogo mestre de músicas, `praiseSongs`) e
/// "Repertório Semanal" (escala de músicas por semana, com tom e momento —
/// `weeklyRepertoires`, `weekly_repertoire_form_page.dart`). O repertório
/// semanal alimenta automaticamente os momentos "Louvor" da Ordem de Culto
/// daquela semana (`ServiceOrderLivePage`, ver
/// `PraiseRepertoireRepository.getForDate`/`praiseSlotLabelFor`).
///
/// Menu (☰) ao lado do título (28/08/2026, pedido do usuário — "Cifras" saiu
/// de um tile próprio no menu Mais e entrou aqui, primeira opção de um menu
/// pensado pra crescer).
///
/// Acesso é só de quem tem o papel Louvor/admin (`canViewPraiseOrder`) —
/// **não** de Dirigentes (pedido explícito do usuário, revisão de
/// 28/08/2026: "Dirigente não deve ter acesso a nada em Ministério de
/// Louvor" / "Acesso a Ministério de Louvor deve ser a quem tem papel
/// Louvor" — antes `canManageServiceOrders`, o mesmo que gerencia Ordem de
/// Culto, também dava acesso aqui). Quem o admin selecionou individualmente
/// como editor de cifra (`canEditCifrasProvider` — não é um papel) também
/// entra, mas só pra ver o menu — as duas abas de gerenciar repertório
/// (`canManage`) continuam exclusivas de Louvor/admin.
class PraiseMinistryPage extends ConsumerWidget {
  const PraiseMinistryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final canManage = profile?.canViewPraiseOrder ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const SibValAppBar(isHome: false),
        body: SafeArea(
          bottom: true,
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ministério de Louvor',
                        style: TextStyle(
                          color: SibValColors.goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                    ),
                    const _PraiseMenuButton(),
                  ],
                ),
              ),
              if (canManage) ...[
                const TabBar(
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Repertório Mensal'),
                    Tab(text: 'Repertório Semanal'),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [_MonthlyRepertoireTab(), _WeeklyRepertoireTab()],
                  ),
                ),
              ] else
                Expanded(
                  child: Center(
                    child: Text(
                      'Use o menu ☰ acima para acessar as opções disponíveis.',
                      style: TextStyle(color: context.textSecondary),
                      textAlign: TextAlign.center,
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

/// Menu (3 barras) com as opções do Ministério de Louvor — só "Cifras" por
/// enquanto, pensado pra crescer sem precisar de mais tiles soltos no menu
/// Mais.
class _PraiseMenuButton extends StatelessWidget {
  const _PraiseMenuButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.menu, color: context.textPrimary),
      onSelected: (value) {
        if (value == 'cifras') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CifraListPage()),
          );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'cifras',
          // Mesmo ícone do tile solto que existia antes (28/08/2026, pedido
          // do usuário: "mantenha com o ícone que tinha antes").
          child: Row(
            children: [
              Icon(Icons.lyrics_outlined, size: 20),
              SizedBox(width: 12),
              Text('Cifras'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Aba "Repertório Mensal" — catálogo mestre de músicas (nome + cantor/banda),
/// de onde o repertório semanal escala. "Mensal" é só o nome da aba, não
/// particiona por mês — ver doc comment de `PraiseSong`.
class _MonthlyRepertoireTab extends ConsumerWidget {
  const _MonthlyRepertoireTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(praiseSongsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'praise_song_fab',
        onPressed: () => _showSongDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
        ),
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma música cadastrada ainda.',
                style: TextStyle(color: context.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                title: Text(song.name, style: TextStyle(color: context.textPrimary)),
                subtitle: song.artist.isEmpty
                    ? null
                    : Text(song.artist, style: TextStyle(color: context.textSecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar',
                      onPressed: () => _showSongDialog(context, ref, song: song),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Excluir',
                      onPressed: () => _confirmDelete(context, ref, song),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSongDialog(BuildContext context, WidgetRef ref, {PraiseSong? song}) {
    final nameController = TextEditingController(text: song?.name ?? '');
    final artistController = TextEditingController(text: song?.artist ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(song == null ? 'Adicionar música' : 'Editar música'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome da música'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: artistController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Cantor/Banda'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final artist = artistController.text.trim();
              Navigator.of(dialogContext).pop();
              final repo = ref.read(praiseRepertoireRepositoryProvider);
              try {
                if (song == null) {
                  await repo.createSong(name, artist);
                } else {
                  await repo.updateSong(song.id, name, artist);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Falha ao salvar: $e')));
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PraiseSong song) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir música'),
        content: Text('Tem certeza que deseja excluir "${song.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ref.read(praiseRepertoireRepositoryProvider).deleteSong(song.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Falha ao excluir: $e')));
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

/// Aba "Repertório Semanal" — lista as semanas já escaladas
/// (`weeklyRepertoires`), mais recente primeiro; "+" cria uma nova (data
/// padrão: próximo domingo sem repertório ainda).
class _WeeklyRepertoireTab extends ConsumerWidget {
  const _WeeklyRepertoireTab();

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repertoiresAsync = ref.watch(weeklyRepertoiresProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'weekly_repertoire_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WeeklyRepertoireFormPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nova Semana'),
      ),
      body: repertoiresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary)),
        ),
        data: (repertoires) {
          if (repertoires.isEmpty) {
            return Center(
              child: Text(
                'Nenhum repertório semanal cadastrado ainda.',
                style: TextStyle(color: context.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: repertoires.length,
            itemBuilder: (context, index) {
              final repertoire = repertoires[index];
              return ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(
                  _dateFormat.format(repertoire.weekDate),
                  style: TextStyle(color: context.textPrimary),
                ),
                subtitle: Text(
                  '${repertoire.assignments.length} música(s)',
                  style: TextStyle(color: context.textSecondary),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WeeklyRepertoireFormPage(editing: repertoire),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
