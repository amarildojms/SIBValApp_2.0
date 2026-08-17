import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/hymnal_repository.dart';
import '../models/hymn.dart';

const _fontSizeKey = 'hymn_font_size';
const _defaultFontSize = 16.0;
const _minFontSize = 12.0;
const _maxFontSize = 26.0;
const _fontSizeStep = 2.0;

/// Espelha HymnDetailFragment.kt: título (já sem prefixo/número), letra
/// (extraída do XML), fonte ajustável e persistida. Favoritar fica pra depois.
class HymnDetailPage extends ConsumerStatefulWidget {
  const HymnDetailPage({super.key, required this.hymnal, required this.songId});

  final Hymnal hymnal;
  final int songId;

  @override
  ConsumerState<HymnDetailPage> createState() => _HymnDetailPageState();
}

class _HymnDetailPageState extends ConsumerState<HymnDetailPage> {
  double _fontSize = _defaultFontSize;
  bool _loadingFontSize = true;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
        _loadingFontSize = false;
      });
    }
  }

  Future<void> _changeFontSize(double delta) async {
    final newSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    setState(() => _fontSize = newSize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, newSize);
  }

  @override
  Widget build(BuildContext context) {
    final hymnAsync = ref.watch(hymnDetailProvider((hymnal: widget.hymnal, songId: widget.songId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hino'),
        actions: [
          IconButton(onPressed: () => _changeFontSize(-_fontSizeStep), icon: const Icon(Icons.text_decrease)),
          IconButton(onPressed: () => _changeFontSize(_fontSizeStep), icon: const Icon(Icons.text_increase)),
        ],
      ),
      body: _loadingFontSize
          ? const Center(child: CircularProgressIndicator())
          : hymnAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Falha ao carregar: $error', style: const TextStyle(color: Colors.white))),
              data: (hymn) {
                if (hymn == null) {
                  return const Center(child: Text('Hino não encontrado.', style: TextStyle(color: Colors.white70)));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${hymn.number} — ${hymn.title}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(hymn.lyrics, style: TextStyle(color: Colors.white, fontSize: _fontSize, height: 1.5)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
