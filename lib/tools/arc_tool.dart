import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import 'base_tool.dart';

/// Arc drawing tool implementation
class ArcTool extends BaseTool {
  List<Offset> activeArcPoints = [];
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    activeArcPoints.add(point);
    if (activeArcPoints.length == 3) {
      // Finalize Arc: Start, Center, End
      finalizeEntity(document, documentService, context);
    } else {
      // First or second click
      drawStart = activeArcPoints.first; // Base point for current preview step
      drawCurrent = point; // Current interaction point
      updatePreviewEntity(document);
    }
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (activeArcPoints.isEmpty) return;
    
    // Update the current point for preview
    drawCurrent = point;
    
    // Update the preview entity with the new point
    // This will trigger a redraw with the updated preview
    updatePreviewEntity(document);
  }

  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // For ArcTool, finalization primarily happens on the 3rd click within onPointerDown
    // or when the tool is deactivated.
    // We override onPointerUp here to prevent BaseTool's default behavior
    // of finalizing and clearing state after every pointer up event, which is
    // not suitable for a multi-click tool like ArcTool until all points are collected.

    if (activeArcPoints.length < 3) {
      // If the arc is not yet complete (i.e., fewer than 3 points),
      // do nothing on pointer up. The state (activeArcPoints, previewEntity)
      // should be preserved for the next click.
      return;
    }
    
    // If onPointerUp is somehow called when 3 points are already set 
    // (though onPointerDown should have finalized it),
    // then proceed with the standard finalization.
    // This case might be redundant given current onPointerDown logic but is safe.
    super.onPointerUp(point, document, documentService, context);
  }
  
  @override
  void updatePreviewEntity(DrawingDocument document) {
    if (activeArcPoints.isEmpty || drawCurrent == null) {
      previewEntity = null;
      return;
    }
    
    final activeLayer = document.activeLayer;
    
    if (activeArcPoints.length == 1) {
      // Start point set, current mouse is tentative Center
      final startPoint = activeArcPoints[0];
      final tentativeCenter = drawCurrent!;
      
      // Preview: Line from Start to tentative Center
      previewEntity = LineEntity(
        start: startPoint,
        end: tentativeCenter,
        layer: activeLayer.id,
        color: activeLayer.color.withAlpha((0.7 * 255).round()), // Preview color
        lineWidth: 1.0,
        isSelected: false,
      );
    } else if (activeArcPoints.length == 2) {
      // Start & Center set, current mouse is tentative End
      final startPoint = activeArcPoints[0];
      final centerPoint = activeArcPoints[1];
      final tentativeEndPoint = drawCurrent!;

      final radius = (startPoint - centerPoint).distance;
      if (radius < 0.001) {
        // Avoid issues with zero or tiny radius
        // Preview as a line from start to center if radius is too small
        previewEntity = LineEntity(
          start: startPoint,
          end: centerPoint,
          layer: activeLayer.id,
          color: activeLayer.color.withAlpha((0.7 * 255).round()),
          lineWidth: 1.0,
          isSelected: false,
        );
        return;
      }

      // Calculate angles using the same approach as in finalizeEntity
      // to ensure consistency between preview and final entity
      double startAngle = math.atan2(
          startPoint.dy - centerPoint.dy, startPoint.dx - centerPoint.dx);
      double endAngle = math.atan2(tentativeEndPoint.dy - centerPoint.dy,
          tentativeEndPoint.dx - centerPoint.dx);
      
      // Create the preview arc entity with consistent angle calculations
      previewEntity = ArcEntity(
        center: centerPoint,
        radius: radius,
        startAngle: startAngle,
        endAngle: endAngle,
        layer: activeLayer.id,
        color: activeLayer.color.withAlpha((0.7 * 255).round()), // Use preview color
        lineWidth: 1.0,
        isSelected: false,
      );
    }
  }
  
  @override
  void finalizeEntity(DrawingDocument document, DocumentService documentService, BuildContext context) {
    // For 3-point arc, we need at least 2 points (start and center)
    // If we have 2 points, we can use the current mouse position as the end point
    if (activeArcPoints.length < 2) return;
    
    final activeLayer = document.activeLayer;
    
    // Get the start and center points
    final startPoint = activeArcPoints[0];
    final centerPoint = activeArcPoints[1];
    
    // If we have 3 points, use the third as the end point
    // Otherwise, if we only have 2 points but have a current draw position, use that
    Offset? endPoint;
    if (activeArcPoints.length >= 3) {
      endPoint = activeArcPoints[2];
    } else if (drawCurrent != null) {
      endPoint = drawCurrent;
    }
    
    // If we don't have an end point, we can't create the arc
    if (endPoint == null) {
      clearState();
      return;
    }
    
    final radius = (startPoint - centerPoint).distance;
    if (radius < 0.001) {
      // Avoid issues with zero or tiny radius
      clearState();
      return;
    }
    
    // Calculate angles consistently with how they're used in the preview
    double startAngle = math.atan2(
        startPoint.dy - centerPoint.dy, startPoint.dx - centerPoint.dx);
    double endAngle = math.atan2(
        endPoint.dy - centerPoint.dy, endPoint.dx - centerPoint.dx);
    
    // Create the final arc entity
    final arc = ArcEntity(
      center: centerPoint,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
      layer: activeLayer.id,
      color: activeLayer.color,
      lineWidth: 1.0,
      isSelected: false,
    );
    
    // Add to document
    documentService.addEntity(arc);
    
    // Clear state
    clearState();
  }
  
  @override
  void clearState() {
    super.clearState();
    activeArcPoints.clear();
  }
  
  @override
  void onDeactivate(DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Finalize the arc if we have enough points
    if (activeArcPoints.length >= 2) {
      finalizeEntity(document, documentService, context);
    } else {
      // Just clear the points if not enough to create a valid arc
      clearState();
    }
  }
}
