import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';

/// Interface for all drawing tools in the application
abstract class Tool {
  /// Called when the tool is activated (selected)
  void onActivate() {}
  
  /// Called when the tool is deactivated (another tool is selected)
  void onDeactivate(DrawingDocument document, DocumentService documentService, BuildContext context) {}
  
  /// Handle pointer down event
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context);
  
  /// Handle pointer move event
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context);
  
  /// Handle pointer up event
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context);
  
  /// Handle scale start event
  void onScaleStart(ScaleStartDetails details) {}
  
  /// Handle scale update event
  void onScaleUpdate(ScaleUpdateDetails details, Matrix4 transform) {}
  
  /// Handle scale end event
  void onScaleEnd(ScaleEndDetails details) {}
  
  /// Get the preview entity for the current tool state
  Entity? getPreviewEntity(DrawingDocument document);
  
  /// Get the cursor for the current tool
  MouseCursor getCursor() {
    return SystemMouseCursors.precise;
  }
  
  /// Handle right-click event (for tools that need special right-click handling)
  void handleRightClick(DrawingDocument document) {}
  
  /// Finalize the current drawing operation
  void finalizeEntity(DrawingDocument document, DocumentService documentService, BuildContext context) {}
  
  /// Clear the tool state
  void clearState() {}
}
