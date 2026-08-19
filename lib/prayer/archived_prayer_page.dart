import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/prayer_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

/// Espelha ArchivedPrayerFragment.kt/ArchivedPrayerViewModel.kt: lista somente
/// leitura dos pedidos já arquivados. Só quem tem [canViewPrayerRequests]
/// chega aqui (ver botão em PrayerPage).
class ArchivedPrayerPage extends ConsumerWidget {
  const ArchivedPrayerPage({super.key});

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(archivedPrayerRequestsProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenTitle('Pedidos arquivados'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(archivedPrayerRequestsProvider.future),
                child: requestsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text('Falha ao carregar: $error', style: TextStyle(color: context.textPrimary))),
                    ],
                  ),
                  data: (requests) {
                    if (requests.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Nenhum pedido de oração arquivado.',
                              style: TextStyle(color: context.textSecondary),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              request.isAnonymous || request.authorName.isEmpty ? 'Anônimo' : request.authorName,
                            ),
                            subtitle: Text(request.text),
                            trailing: request.createdAt != null
                                ? Text(_dateFormat.format(request.createdAt!), style: const TextStyle(fontSize: 11))
                                : null,
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
      ),
    );
  }
}
