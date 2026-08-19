import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bible_repository.dart';
import '../models/bible.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'bible_reader_page.dart';

/// Espelha BibleSearchFragment.kt: busca por trecho de texto em toda a bíblia.
class BibleSearchPage extends ConsumerStatefulWidget {
  const BibleSearchPage({super.key});

  @override
  ConsumerState<BibleSearchPage> createState() => _BibleSearchPageState();
}

class _BibleSearchPageState extends ConsumerState<BibleSearchPage> {
  final _queryController = TextEditingController();
  List<BibleVerseRef>? _results;
  bool _loading = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _loading = true);
    final results = await ref.read(bibleRepositoryProvider).search(trimmed);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
