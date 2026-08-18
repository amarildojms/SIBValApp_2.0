import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/event_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/event.dart';
import '../theme/app_theme.dart';
import '../util/weekday_format.dart';
import '../widgets/sibval_app_bar.dart';

const _appShareLink = 'https://sibval-app-project.web.app/eventos';

/// Espelha EventDetailFragment.kt: flyer 16:9, título, curtir/compartilhar,
/// descrição, local, data/hora sempre em America/Sao_Paulo, botão de inscrição.
class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  Event? _event;
  bool _loading = true;

  static final _dateTimeFormat = DateFormat("d 'de' MMMM 'de' yyyy 'às' HH:mm", 'pt_BR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
    if (mounted) {
      setState(() {
        _event = doc.exists ? Event.fromFirestore(doc) : null;
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final event = _event;
    final uid = ref.read(currentUidProvider);
    if (event == null || uid == null) return;
    final liked = event.likedBy.contains(uid);
    await ref.read(eventRepositoryProvider).toggleLike(event.id, uid, !liked);
    await _load();
  }

  void _share(Event event, DateTime localDate) {
    final text = '${event.title}\n\n${event.description}\n\n'
        '📍 ${event.location}\n🗓️ ${_dateTimeFormat.format(localDate)}\n\n'
        'Confira no app da SIB Val:\n$_appShareLink';
    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : event == null
              ? Center(child: Text('Evento não encontrado.', style: TextStyle(color: context.textSecondary)))
              : _buildContent(context, event, uid),
    );
  }

  Widget _buildContent(BuildContext context, Event event, String? uid) {
    final localDate = toSaoPauloTime(event.dateTimeUtc);
    final liked = uid != null && event.likedBy.contains(uid);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: event.flyerUrl.isNotEmpty
                ? Image.network(event.flyerUrl, fit: BoxFit.cover)
                : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _share(event, localDate),
                      icon: Icon(Icons.share_outlined, color: context.textSecondary),
                    ),
                    IconButton(
                      onPressed: uid == null ? null : _toggleLike,
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.redAccent : context.textSecondary,
                      ),
                    ),
                    Text('${event.likedBy.length}', style: TextStyle(color: context.textPrimary)),
                  ],
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(event.description, style: TextStyle(color: context.textPrimary, fontSize: 16, height: 1.4)),
                ],
                const SizedBox(height: 16),
                Text('Local: ${event.location}', style: TextStyle(color: context.textSecondary, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '${WeekdayFormat.full(localDate)}, ${_dateTimeFormat.format(localDate)}',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
                if (event.requiresRegistration && event.registrationLink.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => launchUrl(Uri.parse(event.registrationLink), mode: LaunchMode.externalApplication),
                      child: const Text('Inscreva-se'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
