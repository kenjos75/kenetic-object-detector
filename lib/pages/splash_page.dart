import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:object_detector/pages/camera_page.dart';

class SplashPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SplashPage({
    super.key,
    required this.cameras,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const Color _bg = Color(0xFF0B0F14);
  static const Color _accent = Colors.greenAccent;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.forward().whenComplete(_goToCamera);
  }

  void _goToCamera() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          if (widget.cameras.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Text('No cameras available'),
              ),
            );
          }

          return CameraPage(camera: widget.cameras.first);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Maps the controller value to 0..1 between [begin] and [end].
  double _step(double begin, double end, Curve curve) {
    return Interval(begin, end, curve: curve).transform(_controller.value);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B0F14), Color(0xFF111B24)],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final frame = _step(0.0, 0.4, Curves.easeOutCubic);
                final title = _step(0.25, 0.65, Curves.easeOut);
                final subtitle = _step(0.45, 0.8, Curves.easeOut);
                final scan = (_controller.value * 2) % 1.0;

                return Column(
                  children: [
                    const Spacer(flex: 3),
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CustomPaint(
                        painter: _ViewfinderPainter(
                          reveal: frame,
                          scan: scan,
                          color: _accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - title)),
                        child: const Text(
                          'KENETIC\nOBJECT DETECTOR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: subtitle,
                      child: const Text(
                        'REAL-TIME  •  ON-DEVICE',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          minHeight: 2,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(_accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws four corner brackets and a horizontal scan line.
class _ViewfinderPainter extends CustomPainter {
  final double reveal; // 0..1, corners expand into place
  final double scan; // 0..1, scan line position
  final Color color;

  _ViewfinderPainter({
    required this.reveal,
    required this.scan,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = (1 - reveal) * size.width * 0.2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final len = size.width * 0.26;

    final bracket = Paint()
      ..color = color.withValues(alpha: reveal)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      // top-left
      ..moveTo(rect.left, rect.top + len)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + len, rect.top)
      // top-right
      ..moveTo(rect.right - len, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + len)
      // bottom-right
      ..moveTo(rect.right, rect.bottom - len)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - len, rect.bottom)
      // bottom-left
      ..moveTo(rect.left + len, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - len);

    canvas.drawPath(path, bracket);

    // Scan line, only visible once the frame has mostly appeared
    if (reveal > 0.6) {
      final y = rect.top + rect.height * scan;
      final line = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(rect.left + 10, y),
        Offset(rect.right - 10, y),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) =>
      old.reveal != reveal || old.scan != scan || old.color != color;
}