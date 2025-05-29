import 'package:flutter/material.dart';
import '../tools/tool_types.dart';

class ToolbarWidget extends StatelessWidget {
  const ToolbarWidget({
    super.key,
    required this.currentTool,
    required this.onToolChanged,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onNewDocument,
    required this.onSaveDocument,
    required this.onOpenDocument,
    required this.onExportDxf,
  });

  final ToolType currentTool;
  final Function(ToolType) onToolChanged;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onNewDocument;
  final VoidCallback onSaveDocument;
  final VoidCallback onOpenDocument;
  final VoidCallback onExportDxf;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // File operations
              _buildFileOperations(context),
              const SizedBox(width: 16),
              // Undo/redo
              _buildUndoRedo(context),
            ],
          ),
          const SizedBox(height: 16),
          // Drawing tools
          Text(
            'Drawing Tools', 
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 2,
            runSpacing: 8,
            children: [
              _buildToolButton(
                context,
                ToolType.select,
                'Select',
                Icons.touch_app,
              ),
              _buildToolButton(
                context,
                ToolType.pan,
                'Pan',
                Icons.pan_tool,
              ),
              _buildToolButton(
                context,
                ToolType.line,
                'Line',
                Icons.show_chart,
              ),
              _buildToolButton(
                context,
                ToolType.rectangle,
                'Rectangle',
                Icons.crop_square,
              ),
              _buildToolButton(
                context,
                ToolType.circle,
                'Circle',
                Icons.circle_outlined,
              ),
              _buildToolButton(
                context,
                ToolType.arc,
                'Arc',
                Icons.architecture,
              ),
              // New tools: Polyline, Ellipse, Spline
              _buildToolButton(
                context,
                ToolType.polyline,
                'Polyline',
                Icons.show_chart, // Line with multiple segments
              ),
              _buildToolButton(
                context,
                ToolType.ellipse,
                'Ellipse',
                Icons.crop_portrait, // Oval-like shape for ellipse
              ),
              _buildToolButton(
                context,
                ToolType.spline,
                'Spline',
                Icons.design_services, // Curved shape representing spline
              ),
              // Editing tools
              _buildToolButton(
                context,
                ToolType.move,
                'Move',
                Icons.open_with,
              ),
              _buildToolButton(
                context,
                ToolType.copy,
                'Copy',
                Icons.content_copy,
              ),
              _buildToolButton(
                context,
                ToolType.rotate,
                'Rotate',
                Icons.rotate_right,
              ),
              _buildToolButton(
                context,
                ToolType.scale,
                'Scale',
                Icons.zoom_out_map,
              ),
              _buildToolButton(
                context,
                ToolType.mirror,
                'Mirror',
                Icons.flip,
              ),
              _buildToolButton(
                context,
                ToolType.offset,
                'Offset',
                Icons.line_weight,
              ),
              _buildToolButton(
                context,
                ToolType.trim,
                'Trim',
                Icons.content_cut,
              ),
              _buildToolButton(
                context,
                ToolType.extend,
                'Extend',
                Icons.expand_more,
              ),
              _buildToolButton(
                context,
                ToolType.delete,
                'Delete',
                Icons.delete_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileOperations(BuildContext context) {
    return Row(
      children: [
        _buildActionButton(
          context,
          'New',
          Icons.add,
          onNewDocument,
        ),
        _buildActionButton(
          context,
          'Open',
          Icons.folder_open,
          onOpenDocument,
        ),
        _buildActionButton(
          context,
          'Save',
          Icons.save,
          onSaveDocument,
        ),
        _buildActionButton(
          context,
          'Export DXF',
          Icons.download,
          onExportDxf,
        ),
      ],
    );
  }

  Widget _buildUndoRedo(BuildContext context) {
    return Row(
      children: [
        _buildActionButton(
          context,
          'Undo',
          Icons.undo,
          onUndo,
          enabled: canUndo,
        ),
        _buildActionButton(
          context,
          'Redo',
          Icons.redo,
          onRedo,
          enabled: canRedo,
        ),
      ],
    );
  }

  Widget _buildToolButton(BuildContext context, ToolType tool, String tooltip, IconData icon) {
    final isSelected = currentTool == tool;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onToolChanged(tool),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                size: 24,
                color: isSelected 
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, 
    String tooltip, 
    IconData icon, 
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: enabled ? colorScheme.surface : colorScheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                size: 24,
                color: enabled 
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}