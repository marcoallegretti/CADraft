import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../tools/tool_interface.dart';
import '../tools/tool_factory.dart';
import '../tools/tool_types.dart';
import '../tools/trim_tool.dart';
import '../utils/snap_engine.dart';
import '../utils/snap_utils.dart';

/// Controller class for managing canvas state and interactions
class CanvasController {
  // Canvas transformation state
  final TransformationController transformationController = TransformationController();
  Offset panStart = Offset.zero;
  double currentScale = 1.0;
  double lastScale = 1.0;

  // Drawing state
  Offset? drawStart;
  Offset? drawCurrent;
  Entity? previewEntity;

  // Selection state
  String? selectedEntityId;
  Offset? moveStart;

  // Snap positions
  SnapResult? snapResult;
  SnapSettings snapSettings = SnapSettings();
  
  // Current cursor position in document coordinates
  Offset cursorPosition = Offset.zero;
  late SnapEngine snapEngine;

  // Tool management
  ToolType currentToolType = ToolType.select;
  Tool? currentTool;
  final ToolFactory toolFactory = ToolFactory();

  // Callback for when a tool operation is complete
  final VoidCallback? onToolComplete;

  CanvasController({
    SnapSettings? initialSnapSettings,
    this.onToolComplete,
  }) {
    // Initialize with a view centered at the origin
    transformationController.value = Matrix4.identity()
      ..translate(500.0, 300.0) // Initial translation to center the view
      ..scale(1.0, 1.0); // Initial scale

    // Initialize snap settings
    if (initialSnapSettings != null) {
      snapSettings = initialSnapSettings;
    }

    // Initialize snap engine
    snapEngine = SnapEngine(
      settings: snapSettings,
      scale: currentScale,
    );
  }

  /// Set the current tool type
  void setToolType(ToolType toolType, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // If the tool is changing, finalize the current tool
    if (currentToolType != toolType && currentTool != null) {
      currentTool!.onDeactivate(document, documentService, context);
    }

    currentToolType = toolType;
    
    // Get the new tool instance
    currentTool = toolFactory.getTool(
      toolType,
      onPan: handlePan,
      onScale: handleScale,
      currentScale: currentScale,
    );
    
    // Activate the new tool
    currentTool?.onActivate();
  }

  /// Handle pan gesture
  void handlePan(Offset delta) {
    transformationController.value = Matrix4.copy(transformationController.value)
      ..translate(delta.dx / currentScale, delta.dy / currentScale);
  }

  /// Handle scale gesture
  void handleScale(double scaleFactor, Offset focalPoint) {
    // Apply the scale around the focal point
    if ((scaleFactor - 1.0).abs() > 0.01) {
      // Get focal point in local coordinates
      final Matrix4 inverseTransform = Matrix4.inverted(transformationController.value);
      final Vector3 focalPointLocal = inverseTransform
          .transform3(Vector3(focalPoint.dx, focalPoint.dy, 0.0));

      // Scale around the focal point
      transformationController.value = Matrix4.copy(transformationController.value)
        ..translate(focalPointLocal.x, focalPointLocal.y)
        ..scale(scaleFactor)
        ..translate(-focalPointLocal.x, -focalPointLocal.y);
        
      // Update current scale
      currentScale *= scaleFactor;
    }
  }
  
  /// Handle scale start event
  void handleScaleStart(ScaleStartDetails details) {
    // Delegate to the current tool
    currentTool?.onScaleStart(details);
  }
  
  /// Handle scale update event
  void handleScaleUpdate(ScaleUpdateDetails details) {
    // Delegate to the current tool
    currentTool?.onScaleUpdate(details, transformationController.value);
  }
  
  /// Handle scale end event
  void handleScaleEnd(ScaleEndDetails details) {
    // Delegate to the current tool
    currentTool?.onScaleEnd(details);
  }

  /// Update snap settings
  void updateSnapSettings(SnapSettings newSettings) {
    snapSettings = newSettings;
    snapEngine = SnapEngine(
      settings: snapSettings,
      scale: currentScale,
    );
  }

  /// Handle pointer down event
  void handlePointerDown(PointerDownEvent event, Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Update snap engine with current scale
    snapEngine = SnapEngine(
      settings: snapSettings,
      scale: currentScale,
    );

    // Find all possible snap points
    final snapResults = snapEngine.findSnapPoints(point, document);

    // Find the best snap point
    final bestSnap = snapEngine.findBestSnapPoint(snapResults, point);

    // Use the snapped point or the original point if no snap
    final snappedPoint = bestSnap?.position ?? point;
    snapResult = bestSnap;

    // Handle right-click for tools that need special handling
    if (event.buttons == 2) {
      if (currentTool != null) {
        currentTool!.handleRightClick(document);
        return;
      }
    }

    // Let the current tool handle the pointer down event
    currentTool?.onPointerDown(snappedPoint, document, documentService, context);
  }

  /// Handle pointer move event
  void handlePointerMove(PointerMoveEvent event, Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Update the current cursor position in document coordinates
    cursorPosition = point;
    
    // Update snap engine with current scale
    snapEngine = SnapEngine(
      settings: snapSettings,
      scale: currentScale,
    );

    // Find all possible snap points
    final snapResults = snapEngine.findSnapPoints(point, document);

    // Find the best snap point
    final bestSnap = snapEngine.findBestSnapPoint(snapResults, point);

    // Use the snapped point or the original point if no snap
    final snappedPoint = bestSnap?.position ?? point;
    snapResult = bestSnap;

    // Let the current tool handle the pointer move event
    currentTool?.onPointerMove(snappedPoint, document, documentService, context);
  }

  /// Handle pointer up event
  void handlePointerUp(PointerUpEvent event, Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Update snap engine with current scale
    snapEngine = SnapEngine(
      settings: snapSettings,
      scale: currentScale,
    );

    // Find all possible snap points
    final snapResults = snapEngine.findSnapPoints(point, document);

    // Find the best snap point
    final bestSnap = snapEngine.findBestSnapPoint(snapResults, point);

    // Use the snapped point or the original point if no snap
    final snappedPoint = bestSnap?.position ?? point;
    snapResult = bestSnap;

    // Let the current tool handle the pointer up event
    currentTool?.onPointerUp(snappedPoint, document, documentService, context);
  }

  /// Get the cursor for the current tool
  MouseCursor getCursorForCurrentTool() {
    return currentTool?.getCursor() ?? SystemMouseCursors.basic;
  }

  /// Get the preview entity from the current tool
  Entity? getPreviewEntity(DrawingDocument document) {
    return currentTool?.getPreviewEntity(document);
  }
  
  /// Get the status message from the current tool
  String? getStatusMessage() {
    if (currentTool is TrimTool) {
      return (currentTool as TrimTool).getStatusMessage();
    }
    return null;
  }
  
  /// Get additional preview entities from the current tool
  List<Entity> getAdditionalPreviewEntities(DrawingDocument document) {
    if (currentTool is TrimTool) {
      return (currentTool as TrimTool).getAdditionalPreviewEntities();
    }
    return [];
  }
  
  /// Get the current cursor position in document coordinates
  Offset getCursorPosition() {
    return cursorPosition;
  }
  
  /// Get the current zoom level as a percentage
  double getZoomPercentage() {
    return currentScale * 100;
  }
  
  /// Zoom in by a fixed increment
  void zoomIn() {
    // Use the center of the viewport as the focal point
    final viewportSize = Size(1000, 600); // Approximate viewport size
    final focalPoint = Offset(viewportSize.width / 2, viewportSize.height / 2);
    
    // Zoom in by 20%
    handleScale(1.2, focalPoint);
  }
  
  /// Zoom out by a fixed increment
  void zoomOut() {
    // Use the center of the viewport as the focal point
    final viewportSize = Size(1000, 600); // Approximate viewport size
    final focalPoint = Offset(viewportSize.width / 2, viewportSize.height / 2);
    
    // Zoom out by 20%
    handleScale(0.8, focalPoint);
  }
  
  /// Reset zoom to 100%
  void resetZoom() {
    // Calculate the scale factor needed to reset to 100%
    final resetFactor = 1.0 / currentScale;
    
    // Use the center of the viewport as the focal point
    final viewportSize = Size(1000, 600); // Approximate viewport size
    final focalPoint = Offset(viewportSize.width / 2, viewportSize.height / 2);
    
    // Apply the scale factor
    handleScale(resetFactor, focalPoint);
  }
}
