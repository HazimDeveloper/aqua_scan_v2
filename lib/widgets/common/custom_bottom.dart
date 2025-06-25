// lib/widgets/common/custom_button.dart
import 'package:flutter/material.dart';
import '../../config/theme.dart';

enum CustomButtonType {
  primary,
  secondary,
  success,
  warning,
  error,
  outline,
  text
}

enum CustomButtonSize {
  small,
  medium,
  large
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonType type;
  final CustomButtonSize size;
  final IconData? icon;
  final bool isIconLeading;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;
  final double? height;
  final double borderRadius;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = CustomButtonType.primary,
    this.size = CustomButtonSize.medium,
    this.icon,
    this.isIconLeading = true,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
    this.height,
    this.borderRadius = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine colors based on button type
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    Color splashColor;

    switch (type) {
      case CustomButtonType.primary:
        backgroundColor = AppTheme.primaryColor;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        splashColor = Colors.white.withOpacity(0.2);
        break;
      case CustomButtonType.secondary:
        backgroundColor = AppTheme.primaryLightColor;
        textColor = AppTheme.primaryDarkColor;
        borderColor = Colors.transparent;
        splashColor = AppTheme.primaryColor.withOpacity(0.2);
        break;
      case CustomButtonType.success:
        backgroundColor = AppTheme.successColor;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        splashColor = Colors.white.withOpacity(0.2);
        break;
      case CustomButtonType.warning:
        backgroundColor = AppTheme.warningColor;
        textColor = Colors.black87;
        borderColor = Colors.transparent;
        splashColor = Colors.black.withOpacity(0.1);
        break;
      case CustomButtonType.error:
        backgroundColor = AppTheme.errorColor;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        splashColor = Colors.white.withOpacity(0.2);
        break;
      case CustomButtonType.outline:
        backgroundColor = Colors.transparent;
        textColor = AppTheme.primaryColor;
        borderColor = AppTheme.primaryColor;
        splashColor = AppTheme.primaryColor.withOpacity(0.1);
        break;
      case CustomButtonType.text:
        backgroundColor = Colors.transparent;
        textColor = AppTheme.primaryColor;
        borderColor = Colors.transparent;
        splashColor = AppTheme.primaryColor.withOpacity(0.1);
        break;
    }

    // Set disabled colors if button is disabled
    if (onPressed == null) {
      backgroundColor = type == CustomButtonType.outline || type == CustomButtonType.text 
          ? Colors.transparent 
          : Colors.grey[300]!;
      textColor = Colors.grey[500]!;
      borderColor = type == CustomButtonType.outline ? Colors.grey[300]! : Colors.transparent;
    }

    // Determine padding and font size based on button size
    double verticalPadding;
    double horizontalPadding;
    double fontSize;
    double iconSize;
    double buttonHeight;

    switch (size) {
      case CustomButtonSize.small:
        verticalPadding = 8.0;
        horizontalPadding = 16.0;
        fontSize = 12.0;
        iconSize = 16.0;
        buttonHeight = height ?? 32.0;
        break;
      case CustomButtonSize.medium:
        verticalPadding = 12.0;
        horizontalPadding = 20.0;
        fontSize = 14.0;
        iconSize = 18.0;
        buttonHeight = height ?? 44.0;
        break;
      case CustomButtonSize.large:
        verticalPadding = 16.0;
        horizontalPadding = 24.0;
        fontSize = 16.0;
        iconSize = 20.0;
        buttonHeight = height ?? 56.0;
        break;
    }

    // Create the button content
    Widget buttonContent;

    if (isLoading) {
      // Loading spinner
      buttonContent = SizedBox(
        height: buttonHeight,
        child: Center(
          child: SizedBox(
            height: fontSize + 8,
            width: fontSize + 8,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
        ),
      );
    } else if (icon != null) {
      // Button with text and icon
      Widget iconWidget = Icon(
        icon,
        size: iconSize,
        color: textColor,
      );
      
      Widget textWidget = Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      );
      
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: isIconLeading
            ? [
                iconWidget,
                SizedBox(width: 8.0),
                textWidget,
              ]
            : [
                textWidget,
                SizedBox(width: 8.0),
                iconWidget,
              ],
      );
    } else {
      // Text-only button
      buttonContent = Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // Create the main button widget
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: buttonHeight,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: splashColor,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding,
              horizontal: horizontalPadding,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Center(child: buttonContent),
          ),
        ),
      ),
    );
  }
}

// Extension Button Types for Different Purposes

// Water Button - Special themed button with a water drop ripple effect
class WaterButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final double? width;

  const WaterButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.size = CustomButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.width,
  }) : super(key: key);

  @override
  _WaterButtonState createState() => _WaterButtonState();
}

class _WaterButtonState extends State<WaterButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<Ripple> _ripples = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _createRipple(Offset localPosition, Size size) {
    final ripple = Ripple(
      x: localPosition.dx,
      y: localPosition.dy,
      size: 10.0,
      opacity: 1.0,
    );
    
    setState(() {
      _ripples.add(ripple);
    });
    
    _animationController.reset();
    _animationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _ripples.remove(ripple);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine button properties based on size
    double fontSize;
    double buttonHeight;

    switch (widget.size) {
      case CustomButtonSize.small:
        fontSize = 12.0;
        buttonHeight = 32.0;
        break;
      case CustomButtonSize.medium:
        fontSize = 14.0;
        buttonHeight = 44.0;
        break;
      case CustomButtonSize.large:
        fontSize = 16.0;
        buttonHeight = 56.0;
        break;
    }

    return SizedBox(
      width: widget.isFullWidth ? double.infinity : widget.width,
      height: buttonHeight,
      child: GestureDetector(
        onTapDown: widget.onPressed == null || widget.isLoading 
            ? null 
            : (details) => _createRipple(details.localPosition, Size(widget.width ?? 200, buttonHeight)),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              painter: WaterRipplePainter(
                ripples: _ripples,
                progress: _animationController.value,
              ),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.onPressed == null
                    ? [Colors.grey[300]!, Colors.grey[400]!]
                    : [AppTheme.primaryLightColor, AppTheme.primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  offset: const Offset(0, 3),
                  blurRadius: 5.0,
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      height: fontSize + 8,
                      width: fontSize + 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.water_drop,
                          color: Colors.white,
                          size: fontSize + 4,
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          widget.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// Ripple effect model
class Ripple {
  final double x;
  final double y;
  double size;
  double opacity;

  Ripple({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
  });
}

// Water ripple painter
class WaterRipplePainter extends CustomPainter {
  final List<Ripple> ripples;
  final double progress;

  WaterRipplePainter({
    required this.ripples,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(ripple.opacity * (1 - progress))
        ..style = PaintingStyle.fill;
      
      // Update ripple properties based on animation progress
      final currentSize = ripple.size + (size.width * 0.5 * progress);
      
      canvas.drawCircle(
        Offset(ripple.x, ripple.y),
        currentSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaterRipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ripples != ripples;
  }
}