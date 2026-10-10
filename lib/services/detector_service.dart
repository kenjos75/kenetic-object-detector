import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart' hide Detection;
import 'package:object_detector/detection.dart';

class DetectorService {

  static const String modelAsset = 'assets/detect.tflite';
  static const String labelsAsset = 'assets/labelmap.txt';

  static const int labelOffset = 1;

  static const double threshold = 0.5;

  late final Interpreter _interpreter;
  late final List<String> _labels;

  late final int _inputSize;
  late final int _numDet;

  int _boxesIdx = -1;
  int _countIdx = -1;
  int _classesIdx = -1;
  int _scoresIdx = -1;
  bool _classScoreKnown = false;

  late final Map<int, Object> _outputs;

  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset(
      modelAsset,
      options: InterpreterOptions()..threads = 4,
    );

    final raw = await rootBundle.loadString(labelsAsset);
    _labels = raw.split('\n').map((e) => e.trim()).toList();

    // Input is [1, height, width, 3]
    final inShape = _interpreter.getInputTensor(0).shape;
    _inputSize = inShape[1];

    // Work out which output tensor is which, from shapes and names
    final outs = _interpreter.getOutputTensors();
    final flat = <int>[]; // [1, N] tensors: classes and scores
    for (var i = 0; i < outs.length; i++) {
      final s = outs[i].shape;
      debugPrint('Output $i: name=${outs[i].name} shape=$s');
      if (s.length == 3 && s.last == 4) {
        _boxesIdx = i;
        _numDet = s[1];
      } else if (s.length == 1) {
        _countIdx = i;
      } else if (s.length == 2) {
        flat.add(i);
      }
    }

    if (_boxesIdx == -1 || flat.length != 2) {
      throw StateError('Unexpected model outputs. Check the debug log above.');
    }

    // Try to identify classes/scores by tensor name
    for (final i in flat) {
      final name = outs[i].name.toLowerCase();
      if (name.contains('score')) _scoresIdx = i;
      if (name.contains('class')) _classesIdx = i;
    }
    if (_scoresIdx != -1 && _classesIdx != -1 && _scoresIdx != _classesIdx) {
      _classScoreKnown = true;
    } else {
      // Decide from the values on each frame instead (see detect()).
      _classesIdx = flat[0];
      _scoresIdx = flat[1];
    }

    // Allocate output buffers once and reuse them every frame
    _outputs = {
      for (var i = 0; i < outs.length; i++) i: _alloc(outs[i].shape),
    };
  }

  List _alloc(List<int> shape, [int d = 0]) {
    if (d == shape.length - 1) return List<double>.filled(shape[d], 0.0);
    return List.generate(shape[d], (_) => _alloc(shape, d + 1));
  }

  double _at2(int outIdx, int i) =>
      ((_outputs[outIdx]! as List)[0] as List)[i].toDouble();

  List<Detection> detect(CameraImage image, int sensorOrientation) {
    final rgb = _yuvToRgb(image, sensorOrientation);

    _interpreter.runForMultipleInputs([rgb], _outputs);

    // If names didn't tell us which is which: class ids go above 1, scores don't
    if (!_classScoreKnown) {
      var maxA = 0.0, maxB = 0.0;
      for (var i = 0; i < _numDet; i++) {
        final a = _at2(_classesIdx, i);
        final b = _at2(_scoresIdx, i);
        if (a > maxA) maxA = a;
        if (b > maxB) maxB = b;
      }
      if (maxB > 1.0 && maxA <= 1.0) {
        final tmp = _classesIdx;
        _classesIdx = _scoresIdx;
        _scoresIdx = tmp;
      }
    }

    var n = _numDet;
    if (_countIdx != -1) {
      final c = ((_outputs[_countIdx]! as List)[0] as num).toInt();
      n = c.clamp(0, _numDet).toInt();
    }

    final boxes = (_outputs[_boxesIdx]! as List)[0] as List;
    final results = <Detection>[];

    for (var i = 0; i < n; i++) {
      final score = _at2(_scoresIdx, i);
      if (score < threshold) continue;

      final b = boxes[i] as List; // [ymin, xmin, ymax, xmax], normalized
      final ymin = (b[0] as num).toDouble().clamp(0.0, 1.0).toDouble();
      final xmin = (b[1] as num).toDouble().clamp(0.0, 1.0).toDouble();
      final ymax = (b[2] as num).toDouble().clamp(0.0, 1.0).toDouble();
      final xmax = (b[3] as num).toDouble().clamp(0.0, 1.0).toDouble();

      final idx = _at2(_classesIdx, i).toInt() + labelOffset;
      final label = (idx >= 0 && idx < _labels.length) ? _labels[idx] : 'unknown';

      results.add(Detection(Rect.fromLTRB(xmin, ymin, xmax, ymax), label, score));
    }
    return results;
  }

  /// YUV420 camera frame -> upright RGB, resized to _inputSize x _inputSize.
  Uint8List _yuvToRgb(CameraImage img, int rotation) {
    final w = img.width, h = img.height;
    final yP = img.planes[0], uP = img.planes[1], vP = img.planes[2];
    final uvPixelStride = uP.bytesPerPixel ?? 1;
    final out = Uint8List(_inputSize * _inputSize * 3);

    // Upright image size depends on the sensor rotation
    final upW = (rotation == 90 || rotation == 270) ? h : w;
    final upH = (rotation == 90 || rotation == 270) ? w : h;

    var o = 0;
    for (var oy = 0; oy < _inputSize; oy++) {
      final uy = oy * upH ~/ _inputSize;
      for (var ox = 0; ox < _inputSize; ox++) {
        final ux = ox * upW ~/ _inputSize;

        int rx, ry;
        switch (rotation) {
          case 90:
            rx = uy;
            ry = h - 1 - ux;
            break;
          case 270:
            rx = w - 1 - uy;
            ry = ux;
            break;
          default:
            rx = ux;
            ry = uy;
        }

        final yv = yP.bytes[ry * yP.bytesPerRow + rx];
        final uvIdx = (ry >> 1) * uP.bytesPerRow + (rx >> 1) * uvPixelStride;
        final u = uP.bytes[uvIdx] - 128;
        final v = vP.bytes[uvIdx] - 128;

        out[o++] = (yv + 1.402 * v).round().clamp(0, 255).toInt();
        out[o++] = (yv - 0.344136 * u - 0.714136 * v).round().clamp(0, 255).toInt();
        out[o++] = (yv + 1.772 * u).round().clamp(0, 255).toInt();
      }
    }
    return out;
  }

  void close() => _interpreter.close();
}