import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:pick_u_driver/utils/theme/mcolors.dart';

class PulsingMarkerGenerator {
  static Future<BitmapDescriptor> createPulsingTaxiMarker({
    required double pulseRadius,
    Color? pulseColor,
    double pulseOpacity = 0.5,
  }) async {
    const double markerSize = 200; // Increased from 180 to 200
    const double iconWidth = 25;
    const double iconHeight = 48;

    // Use primaryNavy as default color
    final Color activeColor = pulseColor ?? MColor.primaryNavy;

    // Create a picture recorder to draw the custom marker
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final center = Offset(markerSize / 2, markerSize / 2);

    // Calculate wave properties - water ripples expand and fade
    double waveOpacity = 1.0 - ((pulseRadius - 15.0) / 25.0);
    waveOpacity = waveOpacity.clamp(0.3, 1.0); // Changed from 0.0 to 0.3 for more visibility

    // Draw water wave ripples - expanding concentric circles like water
    // Wave 1 - Outermost ripple (most faded but still visible)
    if (pulseRadius > 15) {
      final wave1Paint = Paint()
        ..color = activeColor.withValues(alpha: waveOpacity * 0.4) // Increased from 0.15 to 0.4
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3; // Increased from 1.5 to 3
      canvas.drawCircle(center, pulseRadius, wave1Paint);
    }

    // Wave 2 - Second ripple
    if (pulseRadius > 20) {
      final wave2Radius = pulseRadius * 0.75;
      final wave2Paint = Paint()
        ..color = activeColor.withValues(alpha: waveOpacity * 0.5) // Increased from 0.25 to 0.5
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5; // Increased from 1.5 to 3.5
      canvas.drawCircle(center, wave2Radius, wave2Paint);
    }

    // Wave 3 - Third ripple
    if (pulseRadius > 25) {
      final wave3Radius = pulseRadius * 0.5;
      final wave3Paint = Paint()
        ..color = activeColor.withValues(alpha: waveOpacity * 0.6) // Increased from 0.35 to 0.6
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4; // Increased from 2 to 4
      canvas.drawCircle(center, wave3Radius, wave3Paint);
    }

    // Wave 4 - Innermost ripple (most visible)
    if (pulseRadius > 30) {
      final wave4Radius = pulseRadius * 0.25;
      final wave4Paint = Paint()
        ..color = activeColor.withValues(alpha: waveOpacity * 0.7) // Increased from 0.45 to 0.7
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5; // Increased from 2 to 4.5
      canvas.drawCircle(center, wave4Radius, wave4Paint);
    }

    // Load and draw the taxi icon directly (no background circle)
    try {
      final ByteData data = await rootBundle.load('assets/img/taxi.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: iconWidth.toInt(),
        targetHeight: iconHeight.toInt(),
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image taxiImage = frameInfo.image;

      // Center the taxi icon
      final iconOffset = Offset(
        (markerSize - iconWidth) / 2,
        (markerSize - iconHeight) / 2,
      );

      canvas.drawImage(taxiImage, iconOffset, Paint());
    } catch (e) {
      // If taxi image fails to load, draw a simple navy circle
      final fallbackPaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 15, fallbackPaint);

      // Add white dot in center
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 5, dotPaint);
    }

    // Convert to image
    final picture = recorder.endRecording();
    final ui.Image markerImage = await picture.toImage(
      markerSize.toInt(),
      markerSize.toInt(),
    );

    // Convert to bytes
    final ByteData? byteData = await markerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Failed to create pulsing marker image');
    }

    return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
  }
}
