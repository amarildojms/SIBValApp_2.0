import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/devotional_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';
import 'devotional_detail_page.dart';

/// Espelha DevotionalListFragment.kt: lista de devocionais publicados, não lidos
/// em destaque (negrito/branco), lidos em cinza.
class DevotionalsListPage extends ConsumerWidget {
  const DevotionalsListPage({super.key});

  static final _dateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devotionalsAsync = ref.watch(devotionalsProvider);
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenTitle('Devocionais'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(devotionalsProvider.future),
              child: devotionalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
            ],
          ),
          data: (devotionals) {
            if (devotionals.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      'Nenhuma devocional publicada ainda.',
                      style: TextStyle(color: context.textSecondary),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: devotionals.length,
              itemBuilder: (context, index) {
                final devotional = devotionals[index];
                final isUnread = uid != null && !devotional.readBy.contains(uid);
                final color = isUnread ? context.textPrimary : context.textTertiary;
                return ListTile(
                  title: Text(
                    devotional.title,
                    style: TextStyle(color: color, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: Text(
                    _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(devotional.dateMillis)),
                    style: TextStyle(color: color),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DevotionalDetailPage(devotionalId: devotional.id)),
                  ),
                );
              },
            );
              },
            ),
          ),
        ),
      ],
      ),
    );
  }
}
