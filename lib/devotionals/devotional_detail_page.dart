import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/devotional_repository.dart';
import '../data/post_repository.dart' show currentUidProvider;
import '../models/devotional.dart';
import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

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
      appBar: const SibValAppBar(isHome: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : devotional == null
              ? Center(child: Text('Devocional não encontrada.', style: TextStyle(color: context.textSecondary)))
              : Column(
                  children: [
                    _DevotionalHeader(
                      title: devotional.title,
                      onDecreaseFont: () => _changeFontSize(-_fontSizeStep),
                      onIncreaseFont: () => _changeFontSize(_fontSizeStep),
                      onShare: () => _share(devotional),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DEVOCIONAL DIÁRIO',
                              style: TextStyle(
                                color: SibValColors.goldAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(devotional.dateMillis)),
                              style: TextStyle(color: context.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              devotional.text,
                              style: TextStyle(color: context.textPrimary, fontSize: _fontSize, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Por ${devotional.author}',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Cabeçalho fixo (não rola com o texto): título da devocional e, próximo a
/// ele, os botões de zoom da fonte e compartilhar — espelha o
/// `devotionalHeader` de fragment_devotional_detail.xml no app nativo.
class _DevotionalHeader extends StatelessWidget {
  const _DevotionalHeader({
    required this.title,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
    required this.onShare,
  });

  final String title;
  final VoidCallback onDecreaseFont;
  final VoidCallback onIncreaseFont;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: onDecreaseFont,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.text_decrease),
            ),
            IconButton(
              onPressed: onIncreaseFont,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.text_increase),
            ),
            IconButton(onPressed: onShare, icon: const Icon(Icons.share_outlined)),
          ],
        ),
      ),
    );
  }
}
