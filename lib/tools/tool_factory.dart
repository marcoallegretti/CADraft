import 'package:flutter/material.dart';
import 'basic_tools.dart';
import 'tool_interface.dart';
import 'tool_types.dart';
import 'polyline_tool.dart';
import 'arc_tool.dart';
import 'spline_tool.dart';
import 'move_tool.dart';
import 'copy_tool.dart';
import 'rotate_tool.dart';
import 'scale_tool.dart';
import 'mirror_tool.dart';
import 'offset_tool.dart';
import 'trim_tool.dart';
import 'extend_tool.dart';

/// Factory class for creating tool instances based on tool type
class ToolFactory {
  // Singleton pattern
  static final ToolFactory _instance = ToolFactory._internal();
  factory ToolFactory() => _instance;
  ToolFactory._internal();
  
  // Cache of tool instances to avoid recreating them
  final Map<ToolType, Tool> _toolCache = {};
  
  /// Get a tool instance for the specified tool type
  Tool getTool(ToolType toolType, {
    Function(Offset)? onPan,
    Function(double, Offset)? onScale,
    double currentScale = 1.0,
  }) {
    // Return cached instance if available
    if (_toolCache.containsKey(toolType)) {
      return _toolCache[toolType]!;
    }
    
    // Create a new instance based on tool type
    Tool tool;
    
    switch (toolType) {
      case ToolType.select:
        tool = SelectTool();
        break;
      case ToolType.pan:
        tool = PanTool(onPan: onPan, onScale: onScale);
        break;
      case ToolType.line:
        tool = LineTool();
        break;
      case ToolType.rectangle:
        tool = RectangleTool();
        break;
      case ToolType.circle:
        tool = CircleTool();
        break;
      case ToolType.arc:
        tool = ArcTool();
        break;
      case ToolType.polyline:
        tool = PolylineTool();
        break;
      case ToolType.ellipse:
        tool = EllipseTool();
        break;
      case ToolType.spline:
        tool = SplineTool();
        break;
      case ToolType.delete:
        tool = DeleteTool();
        break;
      case ToolType.move:
        tool = MoveTool();
        break;
      case ToolType.copy:
        tool = CopyTool();
        break;
      case ToolType.rotate:
        tool = RotateTool();
        break;
      case ToolType.scale:
        tool = ScaleTool();
        break;
      case ToolType.mirror:
        tool = MirrorTool();
        break;
      case ToolType.offset:
        tool = OffsetTool();
        break;
      case ToolType.trim:
        return TrimTool();
      case ToolType.extend:
        return ExtendTool();
    }
    
    // Cache the instance
    _toolCache[toolType] = tool;
    
    return tool;
  }
  
  /// Clear the tool cache
  void clearCache() {
    _toolCache.clear();
  }
}
