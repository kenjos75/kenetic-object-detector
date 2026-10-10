import 'dart:ui';

class Detection {
  final Rect box;
  final String label;
  final double score;
  Detection(this.box, this.label, this.score);
}