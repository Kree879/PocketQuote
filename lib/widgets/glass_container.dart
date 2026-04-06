import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress; // Added this line

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.onTap,
    this.onLongPress, // Added this line
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: isDark 
          ? Colors.white.withAlpha(12) 
          : Colors.black.withAlpha(8), // approx 0.05 white in dark, 0.03 black in light
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark 
            ? Colors.white.withAlpha(25) 
            : Colors.black.withAlpha(20), // approx 0.1 border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
              ? Colors.black.withAlpha(51) 
              : Colors.black.withAlpha(25), // softer shadow in light mode
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 10 : 5, 
            sigmaY: isDark ? 10 : 5, // reduce blur in light mode for cleaner look
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ),
    );

    // Updated check to wrap in GestureDetector if either callback is provided
    if (onTap != null || onLongPress != null) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress, // Pass the long press here
        behavior: HitTestBehavior.opaque, // Ensures the whole area is tappable
        child: container,
      );
    }

    return container;
  }
}