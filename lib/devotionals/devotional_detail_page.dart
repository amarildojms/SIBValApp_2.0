import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/devotional_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/devotional.dart';
import '../theme/app_theme.dart';

const _fontSizeKey = 'devotional_font_size';
const _defaultFontSize = 16.0;
const _minFontSize = 12.0;
const _maxFontSize = 28.0;
const _fontSizeStep = 2.0;
const _appShareLink = 'https://play.google.com/store/apps/details?id=com.sibval.app';

/// Espelha DevotionalDetailFragment.kt: título, data, texto com fonte
/// ajustável (persistida), autor, compartilhar. Marca como lida ao abrir.
class DevotionalDetailPage extends ConsumerStatefulWidget {
  const DevotionalDetailPage({super.key, required this.devotionalId});

  final String devotionalId;

  @override
  ConsumerState<DevotionalDetailPage> createState() => _DevotionalDetailPageState();
}

class _DevotionalDetailPageState extends ConsumerState<DevotionalDetailPage> {
  Devotional? _devotional;
  bool _loading = true;
  double _fontSize = _defaultFontSize;

  static final _dateFormat = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final devotional = await ref.read(devotionalRepositoryProvider).getById(widget.devotionalId);
    final uid = ref.read(currentUidProvider);
    if (devotional != null && uid != null && !devotional.readBy.contains(uid)) {
      await ref.read(devotionalRepositoryProvider).markRead(widget.devotionalId, uid);
    }
    if (mounted) {
      setState(() {
        _devotional = devotional;
        _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
        _loading = false;
      });
    }
  }

  Future<void> _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newSize);
  }

  void _share(Devotional devotional) {
    final text = '${devotional.title}\n\n${devotional.text}\n\nPor ${devotional.author}\n\n'
        'Confira no app da SIB Val:\n$_appShareLink';
    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final devotional = _devotional;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devocional'),
        actions: [
          IconButton(onPressed: () => _changeFontSize(-_fontSizeStep), icon: const Icon(Icons.text_decrease)),
          IconButton(onPressed: () => _changeFontSize(_fontSizeStep), icon: const Icon(Icons.text_increase)),
          if (devotional != null)
            IconButton(onPressed: () => _share(devotional), icon: const Icon(Icons.share_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : devotional == null
              ? Center(child: Text('Devocional não encontrada.', style: TextStyle(color: context.textSecondary)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        devotional.title,
                        style: TextStyle(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(devotional.dateMillis)),
                        style: TextStyle(color: context.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        devotional.text,
                        style: TextStyle(color: context.textPrimary, fontSize: _fontSize, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Text('Por ${devotional.author}', style: TextStyle(color: context.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
    );
  }
}
