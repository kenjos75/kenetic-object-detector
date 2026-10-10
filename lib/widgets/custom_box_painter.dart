import 'package:flutter/material.dart';
import 'package:object_detector/detection.dart';

class CustomBoxPainter extends CustomPainter {
  final ValueNotifier<List<Detection>> detections;

  CustomBoxPainter(this.detections) : super(repaint: detections);

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.greenAccent;

    for (final d in detections.value) {
      final rect = Rect.fromLTRB(
        d.box.left * size.width,
        d.box.top * size.height,
        d.box.right * size.width,
        d.box.bottom * size.height,
      );
      canvas.drawRect(rect, boxPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '${d.label} ${(d.score * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
              color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelTop = (rect.top - tp.height - 4).clamp(0.0, size.height);
      canvas.drawRect(
        Rect.fromLTWH(rect.left, labelTop, tp.width + 8, tp.height + 4),
        Paint()..color = Colors.greenAccent,
      );
      tp.paint(canvas, Offset(rect.left + 4, labelTop + 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomBoxPainter old) => false; // repaints via the notifier
}