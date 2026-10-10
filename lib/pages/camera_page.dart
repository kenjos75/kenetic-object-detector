
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_detector/detection.dart';
import 'package:object_detector/services/detector_service.dart';
import 'package:object_detector/widgets/custom_box_painter.dart';

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

  final _detector = DetectorService();
  final ValueNotifier<List<Detection>> _detections = ValueNotifier([]);
  bool _busy = false;


  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _zoomAtGestureStart = 1.0;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _initializeFuture = _initializeCamera();
  }
  Future<void> _initializeCamera() async {
    await _detector.load();
    await _controller.initialize();

    _minZoom = await _controller.getMinZoomLevel();
    _maxZoom = await _controller.getMaxZoomLevel();
    _currentZoom = _minZoom;

    await _controller.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) {
    if (_busy) return; // drop frames while the previous one is processing
    _busy = true;
    try {
      _detections.value =
          _detector.detect(image, widget.camera.sensorOrientation);
    } catch (e) {
      debugPrint('Detection failed: $e');
    } finally {
      _busy = false;
    }
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
    if (_controller.value.isStreamingImages) _controller.stopImageStream();
    _controller.dispose();
    _detector.close();
    _detections.dispose();
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
              child: CameraPreview(
                _controller,
                child: CustomPaint(painter: CustomBoxPainter(_detections)),
              ),
            ),
          );
        },
      ),
    );
  }
}