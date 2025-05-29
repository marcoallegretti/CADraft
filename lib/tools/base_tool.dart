import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import 'tool_interface.dart';

/// Base implementation of the Tool interface with common functionality
abstract class BaseTool implements Tool {
  // Common state that most tools need
  Offset? drawStart;
  Offset? drawCurrent;
  Entity? previewEntity;
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    drawStart = point;
    drawCurrent = point;
    updatePreviewEntity(document);
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (drawStart == null) return;
    
    drawCurrent = point;
    updatePreviewEntity(document);
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (drawStart == null || drawCurrent == null) return;
    
    finalizeEntity(document, documentService, context);
    clearState();
  }
  
  @override
  void onScaleStart(ScaleStartDetails details) {
    // Default implementation does nothing
    // Specific tools like PanTool will override this
  }
  
  @override
  void onScaleUpdate(ScaleUpdateDetails details, Matrix4 transform) {
    // Default implementation does nothing
    // Specific tools like PanTool will override this
  }
  
  @override
  void onScaleEnd(ScaleEndDetails details) {
    // Default implementation does nothing
    // Specific tools like PanTool will override this
  }
  
  @override
  Entity? getPreviewEntity(DrawingDocument document) {
    return previewEntity;
  }
  
  @override
  void onActivate() {
    // Default implementation does nothing
  }
  
  @override
  void onDeactivate(DrawingDocument document, DocumentService documentService, BuildContext context) {
    finalizeEntity(document, documentService, context);
    clearState();
  }
  
  @override
  MouseCursor getCursor() {
    return SystemMouseCursors.precise;
  }
  
  @override
  void handleRightClick(DrawingDocument document) {
    // Default implementation does nothing
  }
  
  @override
  void finalizeEntity(DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Default implementation adds the preview entity to the document if it exists
    if (previewEntity != null) {
      documentService.addEntity(previewEntity!);
    }
  }
  
  @override
  void clearState() {
    drawStart = null;
    drawCurrent = null;
    previewEntity = null;
  }
  
  /// Updates the preview entity based on the current state
  /// Subclasses should override this method to create their specific preview entities
  void updatePreviewEntity(DrawingDocument document) {
    // Default implementation does nothing
  }
}
