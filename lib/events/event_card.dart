import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/event.dart';

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
    return Card(
      color: SibValColors.navyBlueLight,
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
                          errorBuilder: (context, error, stack) => Container(color: SibValColors.navyBlueLight),
                        )
                      : Container(color: SibValColors.navyBlueLight),
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateFormat.format(localDate),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onLikeTap,
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.redAccent : Colors.white70,
                    ),
                  ),
                  Text('${event.likedBy.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
