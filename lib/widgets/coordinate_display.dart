import 'package:flutter/material.dart';

/// A widget that displays the current cursor coordinates
class CoordinateDisplay extends StatelessWidget {
  /// The current X coordinate in document space
  final double x;
  
  /// The current Y coordinate in document space
  final double y;
  
  /// The number of decimal places to show
  final int precision;
  
  /// Background color for the coordinate display
  final Color backgroundColor;
  
  /// Text color for the coordinate display
  final Color textColor;
  
  const CoordinateDisplay({
    Key? key,
    required this.x,
    required this.y,
    this.precision = 2,
    this.backgroundColor = const Color.fromRGBO(0, 0, 0, 0.7),
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            color: textColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'X: ${x.toStringAsFixed(precision)} Y: ${y.toStringAsFixed(precision)}',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontFamily: 'Monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
