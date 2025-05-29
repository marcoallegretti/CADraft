import 'package:flutter/material.dart';
import '../utils/snap_utils.dart';

class SnapSettingsPanel extends StatelessWidget {
  final SnapSettings settings;
  final Function(SnapSettings) onSettingsChanged;

  const SnapSettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Snap Settings',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Switch(
                value: settings.enabled,
                onChanged: (value) {
                  onSettingsChanged(settings.copyWith(enabled: value));
                },
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Snap Distance',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Slider(
            value: settings.snapDistance,
            min: 5,
            max: 20,
            divisions: 15,
            label: settings.snapDistance.round().toString(),
            onChanged: settings.enabled
                ? (value) {
                    onSettingsChanged(
                        settings.copyWith(snapDistance: value));
                  }
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            'Snap Types',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SnapType.values.map((type) {
              return _buildSnapTypeChip(context, type);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapTypeChip(BuildContext context, SnapType type) {
    final isEnabled = settings.enabledTypes[type] ?? false;
    final canToggle = settings.enabled;

    return FilterChip(
      selected: isEnabled,
      onSelected: canToggle
          ? (selected) {
              final newEnabledTypes = Map<SnapType, bool>.from(settings.enabledTypes);
              newEnabledTypes[type] = selected;
              onSettingsChanged(settings.copyWith(enabledTypes: newEnabledTypes));
            }
          : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIconForSnapType(type),
            size: 16,
            color: isEnabled
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 4),
          Text(_getNameForSnapType(type)),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primary,
      disabledColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  String _getNameForSnapType(SnapType type) {
    switch (type) {
      case SnapType.grid:
        return 'Grid';
      case SnapType.endpoint:
        return 'Endpoint';
      case SnapType.midpoint:
        return 'Midpoint';
      case SnapType.center:
        return 'Center';
      case SnapType.quadrant:
        return 'Quadrant';
      case SnapType.intersection:
        return 'Intersection';
      case SnapType.perpendicular:
        return 'Perpendicular';
      case SnapType.tangent:
        return 'Tangent';
      case SnapType.nearest:
        return 'Nearest';
    }
  }

  IconData _getIconForSnapType(SnapType type) {
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
