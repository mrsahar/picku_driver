import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PulsingMarkerPainter extends CustomPainter {
  final double animationValue;
  final Color pulseColor;
  final double pulseOpacity;

  PulsingMarkerPainter({
    required this.animationValue,
    this.pulseColor = Colors.blue,
    this.pulseOpacity = 0.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Create pulsing circles
    final paint = Paint()
      ..color = pulseColor.withValues(alpha:pulseOpacity * (1 - animationValue))
      ..style = PaintingStyle.fill;

    // Draw multiple pulse rings
    for (int i = 0; i < 3; i++) {
      final radius = (size.width / 2) * animationValue * (1 + i * 0.3);
      final opacity = pulseOpacity * (1 - animationValue) * (1 - i * 0.2);

      paint.color = pulseColor.withValues(alpha:opacity.clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnimatedMarkerGenerator {
  static Future<BitmapDescriptor> createPulsingMarker({
    required String assetPath,
    required double animationValue,
    Color pulseColor = Colors.blue,
    double pulseOpacity = 0.3,
    Size markerSize = const Size(60, 60),
    Size iconSize = const Size(30, 30),
  }) async {
    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the pulsing background
    final pulsingPainter = PulsingMarkerPainter(
      animationValue: animationValue,
      pulseColor: pulseColor,
      pulseOpacity: pulseOpacity,
    );
    pulsingPainter.paint(canvas, markerSize);

    // Load and draw the taxi icon
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: iconSize.width.toInt(),
      targetHeight: iconSize.height.toInt(),
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    // Center the icon
    final iconOffset = Offset(
      (markerSize.width - iconSize.width) / 2,
      (markerSize.height - iconSize.height) / 2,
    );

    canvas.drawImage(image, iconOffset, Paint());

    // Convert to image
    final picture = recorder.endRecording();
    final ui.Image markerImage = await picture.toImage(
      markerSize.width.toInt(),
      markerSize.height.toInt(),
    );

    // Convert to bytes
    final ByteData? byteData = await markerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Failed to create marker image');
    }

    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }
}

class PulsingMarkerWidget extends StatefulWidget {
  final String assetPath;
  final Color pulseColor;
  final double pulseOpacity;
  final Size markerSize;
  final Size iconSize;
  final Duration animationDuration;
  final Function(BitmapDescriptor) onMarkerGenerated;

  const PulsingMarkerWidget({
    Key? key,
    required this.assetPath,
    required this.onMarkerGenerated,
    this.pulseColor = Colors.blue,
    this.pulseOpacity = 0.3,
    this.markerSize = const Size(60, 60),
    this.iconSize = const Size(30, 30),
    this.animationDuration = const Duration(milliseconds: 2000),
  }) : super(key: key);

  @override
  State<PulsingMarkerWidget> createState() => _PulsingMarkerWidgetState();
}

class _PulsingMarkerWidgetState extends State<PulsingMarkerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.repeat();

    // Generate initial marker
    _generateMarker();

    // Listen to animation changes and regenerate marker
    _animation.addListener(_generateMarker);
  }

  Future<void> _generateMarker() async {
    try {
      final marker = await AnimatedMarkerGenerator.createPulsingMarker(
        assetPath: widget.assetPath,
        animationValue: _animation.value,
        pulseColor: widget.pulseColor,
        pulseOpacity: widget.pulseOpacity,
        markerSize: widget.markerSize,
        iconSize: widget.iconSize,
      );

      widget.onMarkerGenerated(marker);
    } catch (e) {
      print('Error generating pulsing marker: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // This widget doesn't render anything
  }
}
