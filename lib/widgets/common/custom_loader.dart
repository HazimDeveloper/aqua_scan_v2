// lib/widgets/common/custom_loader.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../config/theme.dart';

class WaterDropLoader extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final String message;

  const WaterDropLoader({
    Key? key,
    this.size = 100.0,
    this.color = AppTheme.primaryColor,
    this.duration = const Duration(milliseconds: 1500),
    this.message = 'Loading...',
  }) : super(key: key);

  @override
  _WaterDropLoaderState createState() => _WaterDropLoaderState();
}

class _WaterDropLoaderState extends State<WaterDropLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dropAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _dropAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.75, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Water pool
                  Positioned(
                    bottom: 0,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size / 4),
                      painter: WaterPoolPainter(
                        color: widget.color,
                        waveProgress: _waveAnimation.value,
                      ),
                    ),
                  ),
                  
                  // Water drop
                  Transform.translate(
                    offset: Offset(0, _dropAnimation.value * widget.size / 2),
                    child: Transform.scale(
                      scale: _dropAnimation.value < 0.9 ? 1.0 : (1.0 - (_dropAnimation.value - 0.9) * 10),
                      child: CustomPaint(
                        size: Size(widget.size / 3, widget.size / 2),
                        painter: WaterDropPainter(
                          color: widget.color,
                        ),
                      ),
                    ),
                  ),
                  
                  // Ripple effect
                  if (_dropAnimation.value > 0.95)
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: widget.size / 2,
                        height: widget.size / 10,
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          widget.message,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Water Drop Painter
class WaterDropPainter extends CustomPainter {
  final Color color;
  
  WaterDropPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.quadraticBezierTo(0, size.height * 0.6, size.width / 2, size.height);
    path.quadraticBezierTo(size.width, size.height * 0.6, size.width / 2, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Water Pool Painter
class WaterPoolPainter extends CustomPainter {
  final Color color;
  final double waveProgress;
  
  WaterPoolPainter({
    required this.color,
    required this.waveProgress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, size.height);
    
    // Create wave effect
    for (double i = 0; i < size.width; i++) {
      path.lineTo(
        i, 
        size.height / 2 * (1 + math.sin((i / size.width * 4 * math.pi) + (waveProgress * 2 * math.pi)) * 0.3),
      );
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Alternative progress animation: Water filling container
class WaterFillLoader extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final String message;

  const WaterFillLoader({
    Key? key,
    this.size = 100.0,
    this.color = AppTheme.primaryColor,
    this.duration = const Duration(seconds: 2),
    this.message = 'Loading...',
  }) : super(key: key);

  @override
  _WaterFillLoaderState createState() => _WaterFillLoaderState();
}

class _WaterFillLoaderState extends State<WaterFillLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _fillAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            border: Border.all(color: widget.color, width: 3),
            borderRadius: BorderRadius.circular(widget.size / 8),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(widget.size / 8 - 3),
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: WaterFillPainter(
                    fillLevel: _fillAnimation.value,
                    waveProgress: _waveAnimation.value,
                    color: widget.color,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.message,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class WaterFillPainter extends CustomPainter {
  final double fillLevel;
  final double waveProgress;
  final Color color;
  
  WaterFillPainter({
    required this.fillLevel,
    required this.waveProgress,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final double waterHeight = size.height * (1 - fillLevel);
    final path = Path();
    
    path.moveTo(0, size.height);
    path.lineTo(0, waterHeight);
    
    // Create wave effect
    for (double i = 0; i < size.width; i++) {
      path.lineTo(
        i, 
        waterHeight + (math.sin((i / size.width * 4 * math.pi) + (waveProgress * 2 * math.pi)) * 10),
      );
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}