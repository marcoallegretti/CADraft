import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import 'base_tool.dart';

/// Spline drawing tool implementation
class SplineTool extends BaseTool {
  List<Offset> activeSplinePoints = [];
  DateTime? lastClickTime;
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Check for double-click to finalize the spline
    final now = DateTime.now();
    final isDoubleClick = lastClickTime != null && 
        now.difference(lastClickTime!).inMilliseconds < 300;
    
    // If it's a double-click and we have at least 2 points, finalize the spline
    if (isDoubleClick && activeSplinePoints.length >= 2) {
      finalizeEntity(document, documentService, context);
      lastClickTime = null;
      return;
    }
    
    // Add the point to the spline
    activeSplinePoints.add(point);
    drawStart = activeSplinePoints.first; // Use first point as anchor
    drawCurrent = point; // Current point for preview
    lastClickTime = now; // Reuse the polyline timer for double-click detection
    updatePreviewEntity(document);
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (activeSplinePoints.isEmpty) return;
    
    drawCurrent = point;
    updatePreviewEntity(document);
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // For spline, we don't finalize on pointer up
    // Instead, we update the preview without the trailing segment
    updateSplinePreviewWithoutRubberBand(document);
    drawCurrent = null;
  }
  
  @override
  void updatePreviewEntity(DrawingDocument document) {
    // Show preview for spline tool
    if (drawStart != null && drawCurrent != null) {
      // Create preview points that include the current mouse position for visual feedback
      List<Offset> previewPoints = List.from(activeSplinePoints);
      
      // If we have no active points yet but have a start point,
      // create a temporary preview with just the start point
      if (previewPoints.isEmpty && drawStart != null) {
        previewPoints.add(drawStart!);
      }
      
      // Only add the current mouse position if it's different from the last point
      // This prevents creating zero-length segments
      if (previewPoints.isEmpty || 
          (activeSplinePoints.isEmpty || (activeSplinePoints.last - drawCurrent!).distance > 1.0)) {
        previewPoints.add(drawCurrent!);
      }
      
      // Create a preview even with just one point by duplicating it
      // This gives visual feedback to the user that the tool is active
      if (previewPoints.length == 1) {
        // Add a temporary second point slightly offset from the first
        // to create a minimal preview
        previewPoints.add(drawCurrent!);
      }
      
      final activeLayer = document.activeLayer;
      
      // Only create a preview entity if we have enough points
      if (previewPoints.length >= 2) {
        // Create the spline preview entity
        previewEntity = SplineEntity(
          controlPoints: previewPoints,
          layer: activeLayer.id,
          color: activeLayer.color.withAlpha((0.8 * 255).round()),
          lineWidth: 1.0,
          isSelected: false,
          showControlPoints: true, // Show control points during creation
          splineType: SplineType.catmullRom, // Use Catmull-Rom for smoother curves
        );
      } else {
        previewEntity = null;
      }
    } else {
      // Not enough info to draw a spline preview
      previewEntity = null;
    }
  }
  
  /// Creates a preview of the spline without the segment that follows the cursor
  void updateSplinePreviewWithoutRubberBand(DrawingDocument document) {
    if (activeSplinePoints.length < 2) {
      previewEntity = null;
      return;
    }

    final activeLayer = document.activeLayer;

    // Create a preview using only the fixed points (no trailing segment to cursor)
    previewEntity = SplineEntity(
      controlPoints: List.from(activeSplinePoints),
      layer: activeLayer.id,
      color: activeLayer.color.withAlpha((0.8 * 255).round()),
      lineWidth: 1.0,
      isSelected: false,
      showControlPoints: true, // Show control points during creation
    );
  }
  
  @override
  void finalizeEntity(DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (activeSplinePoints.length >= 2) {
      final activeLayer = document.activeLayer;
      
      // Get the spline type from the preview entity if it exists
      SplineType splineType = SplineType.catmullRom; // Default
      if (previewEntity != null && previewEntity is SplineEntity) {
        splineType = (previewEntity as SplineEntity).splineType;
      }

      final spline = SplineEntity(
        controlPoints: List.from(activeSplinePoints),
        layer: activeLayer.id,
        color: activeLayer.color,
        lineWidth: 1.0,
        isSelected: false,
        // We don't show control points in the final entity
        // but they can be shown if the entity is selected
        showControlPoints: false,
        splineType: splineType, // Use the same spline type as the preview
      );

      // Add the spline to the document
      documentService.addEntity(spline);
    }

    // Clear the spline state so the user can start drawing a new spline
    clearState();
  }
  
  @override
  void clearState() {
    super.clearState();
    activeSplinePoints.clear();
    lastClickTime = null;
  }
  
  @override
  void onDeactivate(DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Finalize the spline if we have enough points
    if (activeSplinePoints.length >= 2) {
      finalizeEntity(document, documentService, context);
    } else {
      // Just clear the points if not enough to create a valid spline
      clearState();
    }
  }
}
