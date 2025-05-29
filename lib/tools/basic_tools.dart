import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../utils/geometry_utils.dart';
import 'base_tool.dart';

/// Line drawing tool implementation
class LineTool extends BaseTool {
  @override
  void updatePreviewEntity(DrawingDocument document) {
    if (drawStart == null || drawCurrent == null) return;
    
    final activeLayer = document.activeLayer;
    
    previewEntity = LineEntity(
      start: drawStart!,
      end: drawCurrent!,
      layer: activeLayer.id,
      color: activeLayer.color,
      lineWidth: 1.0,
      isSelected: false,
    );
  }
}

/// Rectangle drawing tool implementation
class RectangleTool extends BaseTool {
  @override
  void updatePreviewEntity(DrawingDocument document) {
    if (drawStart == null || drawCurrent == null) return;
    
    final activeLayer = document.activeLayer;
    
    previewEntity = RectangleEntity(
      topLeft: Offset(
        math.min(drawStart!.dx, drawCurrent!.dx),
        math.min(drawStart!.dy, drawCurrent!.dy),
      ),
      bottomRight: Offset(
        math.max(drawStart!.dx, drawCurrent!.dx),
        math.max(drawStart!.dy, drawCurrent!.dy),
      ),
      layer: activeLayer.id,
      color: activeLayer.color,
      lineWidth: 1.0,
      isSelected: false,
    );
  }
}

/// Circle drawing tool implementation
class CircleTool extends BaseTool {
  @override
  void updatePreviewEntity(DrawingDocument document) {
    if (drawStart == null || drawCurrent == null) return;
    
    final activeLayer = document.activeLayer;
    final center = drawStart!;
    final radius = (drawCurrent! - center).distance;
    
    previewEntity = CircleEntity(
      center: center,
      radius: radius,
      layer: activeLayer.id,
      color: activeLayer.color,
      lineWidth: 1.0,
      isSelected: false,
    );
  }
}

/// Ellipse drawing tool implementation
class EllipseTool extends BaseTool {
  @override
  void updatePreviewEntity(DrawingDocument document) {
    if (drawStart == null || drawCurrent == null) return;
    
    final activeLayer = document.activeLayer;
    
    // Calculate the bounding box
    final topLeft = Offset(
      math.min(drawStart!.dx, drawCurrent!.dx),
      math.min(drawStart!.dy, drawCurrent!.dy),
    );
    final bottomRight = Offset(
      math.max(drawStart!.dx, drawCurrent!.dx),
      math.max(drawStart!.dy, drawCurrent!.dy),
    );

    // Calculate center of the ellipse
    final center = Offset(
      (topLeft.dx + bottomRight.dx) / 2,
      (topLeft.dy + bottomRight.dy) / 2,
    );

    // Calculate radiusX and radiusY (half width and half height)
    final radiusX = (bottomRight.dx - topLeft.dx) / 2;
    final radiusY = (bottomRight.dy - topLeft.dy) / 2;

    // Only create a preview if we have non-zero radii
    if (radiusX > 0 && radiusY > 0) {
      previewEntity = EllipseEntity(
        center: center,
        radiusX: radiusX,
        radiusY: radiusY,
        layer: activeLayer.id,
        color: activeLayer.color,
        lineWidth: 1.0,
        isSelected: false,
      );
    }
  }
}

/// Selection tool implementation
class SelectTool extends BaseTool {
  String? selectedEntityId;
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Find the entity under the cursor
    String? hitEntityId;
    double minDistance = double.infinity;
    // Use a consistent hit distance regardless of scale

    for (final entity in document.visibleEntities) {
      if (entity.hitTest(point, Matrix4.identity(), 5.0)) {
        // For overlapping entities, select the one closest to the click point
        double distance = 0.0;

        if (entity is LineEntity) {
          distance = GeometryUtils.distanceToLineSegment(point, entity.start, entity.end);
        } else if (entity is CircleEntity) {
          distance = (GeometryUtils.distanceToCircle(point, entity.center, entity.radius)).abs();
        }

        if (distance < minDistance) {
          minDistance = distance;
          hitEntityId = entity.id;
        }
      }
    }

    if (hitEntityId != null) {
      documentService.selectEntity(hitEntityId);
      selectedEntityId = hitEntityId;
    } else {
      documentService.clearSelection();
      selectedEntityId = null;
    }
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Selection tool doesn't do anything on pointer move
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Selection tool doesn't do anything on pointer up
  }
  
  @override
  MouseCursor getCursor() {
    return SystemMouseCursors.precise;
  }
  
  @override
  void clearState() {
    super.clearState();
    selectedEntityId = null;
  }
}

/// Pan tool implementation
class PanTool extends BaseTool {
  Offset panStart = Offset.zero;
  double lastScale = 1.0;
  
  // These callbacks should be provided by the canvas widget
  Function(Offset)? onPan;
  Function(double, Offset)? onScale;
  
  PanTool({this.onPan, this.onScale});
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Pan tool now uses scale gestures instead of pointer events
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Pan tool now uses scale gestures instead of pointer events
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Pan tool now uses scale gestures instead of pointer events
  }
  
  @override
  void onScaleStart(ScaleStartDetails details) {
    panStart = details.focalPoint;
    lastScale = 1.0;
  }
  
  @override
  void onScaleUpdate(ScaleUpdateDetails details, Matrix4 transform) {
    final scaleDiff = details.scale / lastScale;
    lastScale = details.scale;
    
    // Handle scaling through the callback
    if (onScale != null && (scaleDiff - 1.0).abs() > 0.01) {
      onScale!(scaleDiff, details.focalPoint);
    }
    
    // Handle panning through the callback
    if (onPan != null) {
      final delta = details.focalPoint - panStart;
      panStart = details.focalPoint;
      onPan!(delta);
    }
  }
  
  @override
  void onScaleEnd(ScaleEndDetails details) {
    // Optional: could add inertia for panning here
  }
  
  @override
  Entity? getPreviewEntity(DrawingDocument document) {
    // Pan tool doesn't create preview entities
    return null;
  }
  
  @override
  MouseCursor getCursor() {
    return SystemMouseCursors.grab;
  }
  
  @override
  void clearState() {
    panStart = Offset.zero;
    lastScale = 1.0;
  }
}

/// Delete tool implementation
class DeleteTool extends BaseTool {
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Find the entity under the cursor
    String? hitEntityId;
    double minDistance = double.infinity;
    // Use a consistent hit distance regardless of scale

    for (final entity in document.visibleEntities) {
      if (entity.hitTest(point, Matrix4.identity(), 5.0)) {
        // For overlapping entities, select the one closest to the click point
        double distance = 0.0;

        if (entity is LineEntity) {
          distance = GeometryUtils.distanceToLineSegment(point, entity.start, entity.end);
        } else if (entity is CircleEntity) {
          distance = (GeometryUtils.distanceToCircle(point, entity.center, entity.radius)).abs();
        }

        if (distance < minDistance) {
          minDistance = distance;
          hitEntityId = entity.id;
        }
      }
    }

    if (hitEntityId != null) {
      documentService.removeEntity(hitEntityId);
    }
  }
  
  @override
  MouseCursor getCursor() {
    return SystemMouseCursors.forbidden;
  }
}

