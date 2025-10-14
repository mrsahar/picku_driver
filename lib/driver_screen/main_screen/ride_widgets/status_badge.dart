import 'package:flutter/material.dart';

class RippleStatusBadge extends StatefulWidget {
  final String status;
  final Color statusColor;
  final IconData statusIcon;

  const RippleStatusBadge({
    Key? key,
    required this.status,
    required this.statusColor,
    required this.statusIcon,
  }) : super(key: key);

  @override
  State<RippleStatusBadge> createState() => _RippleStatusBadgeState();
}

class _RippleStatusBadgeState extends State<RippleStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple animation
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(200, 60),
                painter: _RipplePainter(
                  progress: _controller.value,
                  color: widget.statusColor,
                ),
              );
            },
          ),
          // Actual badge content
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: widget.statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.statusIcon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${widget.status} ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final ripplePaint = Paint()
      ..color = color.withValues(alpha:0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw 3 ripples with phase shift
    for (int i = 0; i < 3; i++) {
      final rippleProgress = (progress + i * 0.33) % 1.0;
      final radius = rippleProgress * 60;
      final opacity = (1 - rippleProgress).clamp(0.0, 1.0);
      ripplePaint.color = color.withValues(alpha:0.2 * opacity);
      canvas.drawCircle(center, radius, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) => true;
}









