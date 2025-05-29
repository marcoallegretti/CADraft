import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import 'base_tool.dart';

/// Polyline drawing tool implementation
class PolylineTool extends BaseTool {
  List<Offset> activePolylinePoints = [];
  DateTime? lastClickTime;
  bool showClosingIndicator = false;
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Check for double-click to finalize the polyline
    final now = DateTime.now();
    final isDoubleClick = lastClickTime != null &&
        now.difference(lastClickTime!).inMilliseconds < 300;

    // If it's a double-click and we have at least one point, finalize the polyline
    if (isDoubleClick && activePolylinePoints.isNotEmpty) {
      finalizeEntity(document, documentService, context);
      lastClickTime = null;
      return;
    }

    // Check if click is near the first point (to close the polyline)
    if (activePolylinePoints.isNotEmpty && activePolylinePoints.length > 2) {
      final firstPoint = activePolylinePoints.first;
      final distance = (firstPoint - point).distance;

      // If within closing distance, close the polyline
      if (distance < 15) {
        // Use the exact first point to ensure perfect closure
        activePolylinePoints.add(activePolylinePoints.first);
        finalizeEntity(document, documentService, context);
        lastClickTime = null;
        return;
      }
    }

    // Regular point addition
    activePolylinePoints.add(point);
    drawStart = activePolylinePoints.first;
    drawCurrent = point; // Current point for rubber-band
    lastClickTime = now;
    updatePreviewEntity(document);
  }
  
  /// Handle right-click to remove the last point
  void handleRightClick(DrawingDocument document) {
    if (activePolylinePoints.isEmpty) return;
    
    // Remove the last point
    activePolylinePoints.removeLast();

    if (activePolylinePoints.isNotEmpty) {
      // Update the current draw position to the new last point
      drawCurrent = activePolylinePoints.last;
      updatePreviewEntity(document);
    } else {
      // If no points left, reset the polyline state
      drawStart = null;
      drawCurrent = null;
      previewEntity = null;
    }
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (activePolylinePoints.isEmpty) return;
    
    // Check if cursor is near the first point (for closing indicator)
    showClosingIndicator = false;
    if (activePolylinePoints.length > 2) {
      final firstPoint = activePolylinePoints.first;
      final distance = (firstPoint - point).distance;

      // Show closing indicator when near the first point
      if (distance < 15) {
        showClosingIndicator = true;
      }
    }
    
    drawCurrent = point;
    updatePreviewEntity(document);
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // For polyline, we don't finalize on pointer up
    // Instead, we update the preview without the rubber-band segment
    updatePolylinePreviewWithoutRubberBand(document);
    drawCurrent = null;
  }
  
  @override
  void updatePreviewEntity(DrawingDocument document) {
    if (activePolylinePoints.isEmpty || drawCurrent == null) return;
    
    final activeLayer = document.activeLayer;
    
    // We have at least one fixed point, and the mouse is moving, forming the next segment.
    List<Offset> previewPoints = List.from(activePolylinePoints);
    
    // Add the current mouse position for the rubber-band segment
    if (showClosingIndicator && activePolylinePoints.length > 2) {
      // Use the exact first point in preview when showing closing indicator
      previewPoints.add(activePolylinePoints.first);
    } else {
      previewPoints.add(drawCurrent!);
    }
    
    // A PolylineEntity needs at least 2 points.
    previewEntity = PolylineEntity(
      points: previewPoints,
      layer: activeLayer.id,
      // Use a slightly transparent color for preview
      color: activeLayer.color.withAlpha((0.8 * 255).round()),
      lineWidth: 1.0,
      isSelected: false,
      showClosingIndicator: showClosingIndicator,
    );
  }
  
  /// Creates a preview of the polyline without the rubber-band segment that follows the cursor
  void updatePolylinePreviewWithoutRubberBand(DrawingDocument document) {
    if (activePolylinePoints.length < 2) {
      previewEntity = null;
      return;
    }

    final activeLayer = document.activeLayer;

    // Create a preview using only the fixed points (no rubber-band to cursor)
    previewEntity = PolylineEntity(
      points: List.from(activePolylinePoints),
      layer: activeLayer.id,
      color: activeLayer.color.withAlpha((0.8 * 255).round()),
      lineWidth: 1.0,
      isSelected: false,
      showClosingIndicator: false, // No closing indicator when paused
    );
  }
  
  @override
  void finalizeEntity(DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (activePolylinePoints.length < 2) return;

    final activeLayer = document.activeLayer;

    final polyline = PolylineEntity(
      points: List.from(activePolylinePoints),
      layer: activeLayer.id,
      color: activeLayer.color,
      lineWidth: 1.0,
      isSelected: false,
    );

    // Add to document
    documentService.addEntity(polyline);

    // Clear state
    clearState();
  }
  
  @override
  void clearState() {
    super.clearState();
    activePolylinePoints.clear();
    lastClickTime = null;
    showClosingIndicator = false;
  }
  
  @override
  void onDeactivate(DrawingDocument document, DocumentService documentService, BuildContext context) {
    finalizeEntity(document, documentService, context);
    clearState();
  }
}
