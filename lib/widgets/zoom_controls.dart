import 'package:flutter/material.dart';

/// A widget that displays zoom controls and current zoom level
class ZoomControls extends StatelessWidget {
  /// Current zoom level as a percentage (e.g., 100 for 100%)
  final double zoomLevel;
  
  /// Callback for zoom in button
  final VoidCallback onZoomIn;
  
  /// Callback for zoom out button
  final VoidCallback onZoomOut;
  
  /// Callback for reset zoom button
  final VoidCallback onResetZoom;
  
  /// Background color for the zoom controls
  final Color backgroundColor;
  
  /// Icon color for the zoom controls
  final Color iconColor;
  
  /// Text color for the zoom level display
  final Color textColor;
  
  const ZoomControls({
    Key? key,
    required this.zoomLevel,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    this.backgroundColor = const Color.fromRGBO(0, 0, 0, 0.7),
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom out button
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: iconColor, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            splashRadius: 20,
            onPressed: onZoomOut,
            tooltip: 'Zoom Out',
          ),
          
          // Current zoom level display
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${zoomLevel.toStringAsFixed(0)}%',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Zoom in button
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: iconColor, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            splashRadius: 20,
            onPressed: onZoomIn,
            tooltip: 'Zoom In',
          ),
          
          // Reset zoom button
          IconButton(
            icon: Icon(Icons.restart_alt, color: iconColor, size: 20),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            splashRadius: 20,
            onPressed: onResetZoom,
            tooltip: 'Reset Zoom',
          ),
        ],
      ),
    );
  }
}
