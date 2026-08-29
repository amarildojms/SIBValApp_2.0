import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_repository.dart';
import '../data/bible_source_repository.dart';
import '../models/bible.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'bible_reader_page.dart';

/// Espelha BibleSearchFragment.kt: busca por trecho de texto com escopo
/// (Toda a Bíblia / Antigo Testamento / Novo Testamento / livro específico).
/// Busca na versão escolhida em `BibleBookListPage`
/// (`bibleVersionProvider`) — ver `BibleSourceRepository.search`.
class BibleSearchPage extends ConsumerStatefulWidget {
  const BibleSearchPage({super.key});

  @override
  ConsumerState<BibleSearchPage> createState() => _BibleSearchPageState();
}

class _BibleSearchPageState extends ConsumerState<BibleSearchPage> {
  final _queryController = TextEditingController();
  List<BibleVerseRef>? _results;
  bool _resultsFromBlivre = false;
  bool _loading = false;
  BibleSearchScopeKind _scopeKind = BibleSearchScopeKind.allBible;
  int? _selectedBookId;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  BibleSearchScope get _scope {
    switch (_scopeKind) {
      case BibleSearchScopeKind.allBible:
        return const BibleSearchScope.allBible();
      case BibleSearchScopeKind.oldTestament:
        return const BibleSearchScope.oldTestament();
      case BibleSearchScopeKind.newTestament:
        return const BibleSearchScope.newTestament();
      case BibleSearchScopeKind.specificBook:
        return BibleSearchScope.specificBook(_selectedBookId ?? BibleRepository.firstBookId);
    }
  }

  void _setScope(BibleSearchScopeKind kind) {
    setState(() => _scopeKind = kind);
    if (_queryController.text.trim().isNotEmpty) _search(_queryController.text);
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _loading = true);
    final version = ref.read(bibleVersionProvider);
    final resolved = await ref
        .read(bibleSourceRepositoryProvider)
        .search(version, trimmed, scope: _scope);
    if (!mounted) return;
    setState(() {
      _results = resolved.results;
      _resultsFromBlivre = resolved.fromBlivre;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bibleBooksProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Buscar na Bíblia'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'Buscar palavra ou trecho...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _queryController.clear();
                      setState(() => _results = null);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Toda a Bíblia'),
                    selected: _scopeKind == BibleSearchScopeKind.allBible,
                    onSelected: (_) => _setScope(BibleSearchScopeKind.allBible),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Antigo Testamento'),
                    selected: _scopeKind == BibleSearchScopeKind.oldTestament,
                    onSelected: (_) => _setScope(BibleSearchScopeKind.oldTestament),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Novo Testamento'),
                    selected: _scopeKind == BibleSearchScopeKind.newTestament,
                    onSelected: (_) => _setScope(BibleSearchScopeKind.newTestament),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Livro específico'),
                    selected: _scopeKind == BibleSearchScopeKind.specificBook,
                    onSelected: (_) => _setScope(BibleSearchScopeKind.specificBook),
                  ),
                ],
              ),
            ),
            if (_scopeKind == BibleSearchScopeKind.specificBook)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: booksAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (books) => DropdownButtonFormField<int>(
                    initialValue: _selectedBookId ?? books.first.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Livro'),
                    items: [
                      for (final book in books) DropdownMenuItem(value: book.id, child: Text(book.name)),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedBookId = value);
                      if (_queryController.text.trim().isNotEmpty) _search(_queryController.text);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Crédito da fonte (28/08/2026, pedido do usuário) — só aparece
            // quando os resultados vieram da BLIVRE.
            if (_results != null && _results!.isNotEmpty && _resultsFromBlivre)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Fonte: Bíblia Livre (BLIVRE), licença CC BY 4.0',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results == null
                      ? Center(
                          child: Text('Digite algo e toque em buscar.',
                              style: TextStyle(color: context.textSecondary)),
                        )
                      : _results!.isEmpty
                          ? Center(
                              child: Text('Nenhum resultado encontrado.',
                                  style: TextStyle(color: context.textSecondary)),
                            )
                          : ListView.builder(
                              itemCount: _results!.length,
                              itemBuilder: (context, index) {
                                final result = _results![index];
                                return ListTile(
                                  title: Text(result.reference,
                                      style: TextStyle(
                                          color: SibValColors.goldAccent, fontWeight: FontWeight.bold)),
                                  subtitle: Text(result.text, style: TextStyle(color: context.textPrimary)),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BibleReaderPage(
                                        bookId: result.bookId,
                                        bookName: result.bookName,
                                        chapter: result.chapter,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
