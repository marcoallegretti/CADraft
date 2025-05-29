import 'package:flutter/material.dart';
import '../models/entities.dart';

/// Represents different types of snaps available in the CAD system
enum SnapType {
  grid,
  endpoint,
  midpoint,
  center,
  quadrant,
  intersection,
  perpendicular,
  tangent,
  nearest,
}

/// Represents a snap result with position and type information
class SnapResult {
  final Offset position;
  final SnapType type;
  final String? description;
  final Entity? sourceEntity;

  SnapResult({
    required this.position,
    required this.type,
    this.description,
    this.sourceEntity,
  });

  /// Get the appropriate color for this snap type
  Color get color {
    switch (type) {
      case SnapType.grid:
        return Colors.grey;
      case SnapType.endpoint:
        return Colors.red;
      case SnapType.midpoint:
        return Colors.green;
      case SnapType.center:
        return Colors.blue;
      case SnapType.quadrant:
        return Colors.purple;
      case SnapType.intersection:
        return Colors.orange;
      case SnapType.perpendicular:
        return Colors.teal;
      case SnapType.tangent:
        return Colors.amber;
      case SnapType.nearest:
        return Colors.cyan;
    }
  }

  /// Get the appropriate icon for this snap type
  IconData get icon {
    switch (type) {
      case SnapType.grid:
        return Icons.grid_on;
      case SnapType.endpoint:
        return Icons.adjust;
      case SnapType.midpoint:
        return Icons.linear_scale;
      case SnapType.center:
        return Icons.radio_button_unchecked;
      case SnapType.quadrant:
        return Icons.crop_free;
      case SnapType.intersection:
        return Icons.add;
      case SnapType.perpendicular:
        return Icons.show_chart;
      case SnapType.tangent:
        return Icons.timeline;
      case SnapType.nearest:
        return Icons.near_me;
    }
  }
}

/// Represents user snap preferences
class SnapSettings {
  final bool enabled;
  final Map<SnapType, bool> enabledTypes;
  final double snapDistance;

  SnapSettings({
    this.enabled = true,
    Map<SnapType, bool>? enabledTypes,
    this.snapDistance = 10.0,
  }) : enabledTypes = enabledTypes ??
            {
              for (var type in SnapType.values) type: true,
            };

  /// Create a copy with modified properties
  SnapSettings copyWith({
    bool? enabled,
    Map<SnapType, bool>? enabledTypes,
    double? snapDistance,
  }) {
    return SnapSettings(
      enabled: enabled ?? this.enabled,
      enabledTypes: enabledTypes ?? Map.from(this.enabledTypes),
      snapDistance: snapDistance ?? this.snapDistance,
    );
  }

  /// Toggle a specific snap type
  SnapSettings toggleSnapType(SnapType type) {
    final newEnabledTypes = Map<SnapType, bool>.from(enabledTypes);
    newEnabledTypes[type] = !(newEnabledTypes[type] ?? false);
    return copyWith(enabledTypes: newEnabledTypes);
  }

  /// Check if a specific snap type is enabled
  bool isTypeEnabled(SnapType type) {
    return enabled && (enabledTypes[type] ?? false);
  }
}
