import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/sibval_app_bar.dart';

const _fontSizeKey = 'praise_lyrics_font_size';
const _defaultFontSize = 16.0;
const _minFontSize = 12.0;
const _maxFontSize = 26.0;
const _fontSizeStep = 2.0;

/// Sem equivalente no app nativo — feature nova (02/09/2026, pedido do
/// usuário). Mostra a letra salva de uma música do repertório mensal
/// (`PraiseSong.lyrics`) em tela cheia — zoom +/- no corpo da página (mesmo
/// padrão de `CifraViewPage`/`service_order_bible_text_page.dart`),
/// preferência própria (`praise_lyrics_font_size`, não compartilhada com
/// cifra/Bíblia/Hinário).
///
/// Não existe fonte gratuita de busca automática de letra completa
/// disponível hoje (Vagalume descontinuou a API pública; Genius/Musixmatch
/// só liberam trecho/metadados no plano gratuito) — a letra é colada
/// manualmente no cadastro da música (`_showSongDialog`,
/// `praise_ministry_page.dart`), que tem um botão "Buscar letra" abrindo
/// uma busca no navegador pra facilitar achar/copiar.
class PraiseLyricsPage extends StatefulWidget {
  const PraiseLyricsPage({
    super.key,
    required this.songName,
    required this.songArtist,
    required this.lyrics,
  });

  final String songName;
  final String songArtist;
  final String lyrics;

  @override
  State<PraiseLyricsPage> createState() => _PraiseLyricsPageState();
}

class _PraiseLyricsPageState extends State<PraiseLyricsPage> {
  double _fontSize = _defaultFontSize;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _fontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize);
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
    return Scaffold(
      appBar: const SibValAppBar(isHome: false),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenTitle(widget.songName),
            if (widget.songArtist.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  widget.songArtist,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.text_decrease),
                    onPressed: () => _changeFontSize(-_fontSizeStep),
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_increase),
                    onPressed: () => _changeFontSize(_fontSizeStep),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  widget.lyrics,
                  style: TextStyle(color: context.textPrimary, fontSize: _fontSize, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
