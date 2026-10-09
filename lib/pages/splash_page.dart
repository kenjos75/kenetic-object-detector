
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 3), () {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 254, 254, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'KENETIC OBJECT DETECTOR',
              style: const TextStyle(fontSize: 20)
            )
          ],
        ),
      ),
    );
  }
}