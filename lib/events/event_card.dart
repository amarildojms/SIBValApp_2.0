import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/event.dart';
import 'event_started_tag.dart';

/// Espelha item_event_card.xml/EventAdapter.kt: thumbnail 64dp, título, data
/// (sempre em America/Sao_Paulo) e curtir.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.liked,
    required this.onTap,
    required this.onLikeTap,
  });

  final Event event;
  final bool liked;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;

  static final _dateFormat = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final localDate = toSaoPauloTime(event.dateTimeUtc);
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: event.flyerUrl.isNotEmpty
                      ? Image.network(
                          event.flyerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(color: placeholderColor),
                        )
                      : Container(color: placeholderColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateFormat.format(localDate),
                      style: TextStyle(color: context.textSecondary, fontSize: 12),
                    ),
                    if (event.hasStarted) ...[
                      const SizedBox(height: 4),
                      EventStartedTag(time: localDate),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onLikeTap,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.redAccent : context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('${event.likedBy.length}', style: TextStyle(color: context.textPrimary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
