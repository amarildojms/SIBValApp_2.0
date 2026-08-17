import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/devotional_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
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
      appBar: AppBar(title: const Text('Devocionais')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(devotionalsProvider.future),
        child: devotionalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('Falha ao carregar: $error', style: const TextStyle(color: Colors.white))),
            ],
          ),
          data: (devotionals) {
            if (devotionals.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('Nenhuma devocional publicada ainda.', style: TextStyle(color: Colors.white70))),
                ],
              );
            }
            return ListView.builder(
              itemCount: devotionals.length,
              itemBuilder: (context, index) {
                final devotional = devotionals[index];
                final isUnread = uid != null && !devotional.readBy.contains(uid);
                final color = isUnread ? Colors.white : Colors.white38;
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
    );
  }
}
