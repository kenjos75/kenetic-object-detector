
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPage extends StatefulWidget {
  final CameraDescription camera;

  const CameraPage({
    super.key,
    required this.camera,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final CameraController _controller;
  late final Future<void> _initializeFuture;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _zoomAtGestureStart = 1.0;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _controller.initialize();

    _minZoom = await _controller.getMinZoomLevel();
    _maxZoom = await _controller.getMaxZoomLevel();
    _currentZoom = _minZoom;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _currentZoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    if (!_controller.value.isInitialized) return;

    final double zoom = (_zoomAtGestureStart * details.scale)
        .clamp(_minZoom, _maxZoom)
        .toDouble();

    if ((zoom - _currentZoom).abs() < 0.05) return;

    _currentZoom = zoom;

    try {
      await _controller.setZoomLevel(zoom);
    } catch (e) {
      debugPrint('Failed to set zoom: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to initialize camera: ${snapshot.error}',
              ),
            );
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: SizedBox.expand(
              child: CameraPreview(_controller),
            ),
          );
        },
      ),
    );
  }
}