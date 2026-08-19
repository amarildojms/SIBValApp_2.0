import 'package:flutter/material.dart';

/// Selo "G" nas cores da marca Google, pros botões "Entrar com Google" —
/// o app nativo não usa a logo (só texto), mas dá pra deixar mais parecido
/// com o botão oficial sem precisar de um asset de imagem.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * strokeWidth * 2
      ..strokeCap = StrokeCap.butt;

    // Quatro arcos aproximando o "G" oficial: azul (direita/topo), verde
    // (base), amarelo (esquerda), vermelho (topo/esquerda) — com um corte
    // branco no meio-direita imitando a barra horizontal do G.
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.35, 1.85, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.5, 1.15, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.65, 0.95, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.6, 1.35, false, paint);

    // Barra horizontal do G, saindo do centro pra direita.
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * strokeWidth * 2
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(center, Offset(center.dx + radius, center.dy), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
