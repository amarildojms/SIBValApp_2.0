import 'package:flutter/material.dart';

/// Espelha ImageViewerActivity.kt/ImagePagerAdapter.kt: visualizador de foto
/// em tela cheia, deslizável entre as fotos do álbum, fundo preto sempre
/// (independente do tema claro/escuro — padrão comum de visualizador de
/// imagem). Tocar na foto fecha, igual ao original.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final _controller = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    widget.urls[index],
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stack) =>
                        const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
