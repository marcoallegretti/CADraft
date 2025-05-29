import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../utils/geometry_utils.dart';
import 'base_tool.dart';

/// Represents a mirror transformation across a line
class MirrorTransform {
  final Offset point1;
  final Offset point2;
  
  MirrorTransform(this.point1, this.point2);
  
  /// Mirrors a point across the line defined by point1 and point2
  Offset mirrorPoint(Offset point) {
    // If the mirror line is just a point, return the point unchanged
    if (point1 == point2) return point;
    
    // Calculate the direction vector of the mirror line
    final dx = point2.dx - point1.dx;
    final dy = point2.dy - point1.dy;
    
    // Normalize the direction vector
    final length = math.sqrt(dx * dx + dy * dy);
    final nx = dx / length;
    final ny = dy / length;
    
    // Calculate the vector from point1 to the point
    final vx = point.dx - point1.dx;
    final vy = point.dy - point1.dy;
    
    // Calculate the projection of the vector onto the mirror line
    final projection = vx * nx + vy * ny;
    
    // Calculate the point on the mirror line closest to the point
    final closestX = point1.dx + projection * nx;
    final closestY = point1.dy + projection * ny;
    
    // Calculate the vector from the point to the closest point on the mirror line
    final perpX = point.dx - closestX;
    final perpY = point.dy - closestY;
    
    // Mirror the point by reflecting it across the mirror line
    return Offset(
      point.dx - 2 * perpX,
      point.dy - 2 * perpY,
    );
  }
}

/// Mirror tool implementation
class MirrorTool extends BaseTool {
  String? selectedEntityId;
  Entity? entityToMirror;
  Offset? mirrorPoint1;
  Offset? mirrorPoint2;
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (entityToMirror == null) {
      // First click: select the entity to mirror
      String? hitEntityId;
      double minDistance = double.infinity;

      for (final entity in document.visibleEntities) {
        if (entity.hitTest(point, Matrix4.identity(), 5.0)) {
          // For overlapping entities, select the one closest to the click point
          double distance = 0.0;

          if (entity is LineEntity) {
            distance = GeometryUtils.distanceToLineSegment(point, entity.start, entity.end);
          } else if (entity is CircleEntity) {
            distance = (GeometryUtils.distanceToCircle(point, entity.center, entity.radius)).abs();
          } else if (entity is EllipseEntity) {
            distance = GeometryUtils.distanceToEllipse(point, entity.center, entity.radiusX, entity.radiusY).abs();
          } else if (entity is RectangleEntity) {
            // For rectangles, use minimum distance to any edge
            final edges = [
              [entity.topLeft, Offset(entity.bottomRight.dx, entity.topLeft.dy)],
              [Offset(entity.bottomRight.dx, entity.topLeft.dy), entity.bottomRight],
              [entity.bottomRight, Offset(entity.topLeft.dx, entity.bottomRight.dy)],
              [Offset(entity.topLeft.dx, entity.bottomRight.dy), entity.topLeft],
            ];
            
            double minEdgeDist = double.infinity;
            for (final edge in edges) {
              final edgeDist = GeometryUtils.distanceToLineSegment(point, edge[0], edge[1]);
              minEdgeDist = math.min(minEdgeDist, edgeDist);
            }
            distance = minEdgeDist;
          } else {
            // For other entities like polylines, arcs, etc.
            distance = 1.0;
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
        
        // Store the entity to mirror
        entityToMirror = document.visibleEntities
            .where((e) => e.id == hitEntityId)
            .firstOrNull;
      }
    } else if (mirrorPoint1 == null) {
      // Second click: set the first point of the mirror line
      mirrorPoint1 = point;
    } else if (mirrorPoint2 == null) {
      // Third click: set the second point of the mirror line and create the mirrored entity
      mirrorPoint2 = point;
      
      if (entityToMirror != null) {
        // Create the mirrored entity
        final mirroredEntity = _createMirroredEntity(entityToMirror!);
        
        // Add the mirrored entity to the document
        documentService.addEntity(mirroredEntity);
        
        // Clear the state to start a new mirroring operation
        clearState();
      }
    }
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (entityToMirror != null && mirrorPoint1 != null && mirrorPoint2 == null) {
      // We're in the process of defining the mirror line
      // Show a preview of the mirror line and the mirrored entity
      mirrorPoint2 = point; // Temporary for preview
      
      // Update the preview entity
      previewEntity = _createMirroredEntity(entityToMirror!);
      
      // Reset the temporary point
      mirrorPoint2 = null;
    }
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // If we're in the process of defining the mirror line
    if (entityToMirror != null && mirrorPoint1 != null && mirrorPoint2 == null) {
      // Set the second point of the mirror line
      mirrorPoint2 = point;
      
      // Create the mirrored entity
      final mirroredEntity = _createMirroredEntity(entityToMirror!);
      
      // Add the mirrored entity to the document
      documentService.addEntity(mirroredEntity);
      
      // Clear the state to start a new mirroring operation
      clearState();
    }
  }
  
  @override
  void clearState() {
    super.clearState();
    selectedEntityId = null;
    entityToMirror = null;
    mirrorPoint1 = null;
    mirrorPoint2 = null;
    previewEntity = null;
  }
  
  Entity _createMirroredEntity(Entity entity) {
    if (mirrorPoint1 == null || mirrorPoint2 == null) {
      // If we don't have a mirror line yet, return the entity unchanged
      return entity;
    }
    
    // Create a mirror transform to handle the mirroring calculations
    final transform = MirrorTransform(mirrorPoint1!, mirrorPoint2!);
    
    if (entity is LineEntity) {
      return LineEntity(
        start: transform.mirrorPoint(entity.start),
        end: transform.mirrorPoint(entity.end),
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false, // The mirrored copy is not selected initially
      );
    } else if (entity is CircleEntity) {
      return CircleEntity(
        center: transform.mirrorPoint(entity.center),
        radius: entity.radius, // Radius doesn't change during mirroring
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is RectangleEntity) {
      // For rectangles, we need to mirror all four corners
      final topLeft = transform.mirrorPoint(entity.topLeft);
      final bottomRight = transform.mirrorPoint(entity.bottomRight);
      
      // We need to ensure that topLeft is actually the top-left after mirroring
      // and bottomRight is the bottom-right
      final newTopLeft = Offset(
        math.min(topLeft.dx, bottomRight.dx),
        math.min(topLeft.dy, bottomRight.dy),
      );
      final newBottomRight = Offset(
        math.max(topLeft.dx, bottomRight.dx),
        math.max(topLeft.dy, bottomRight.dy),
      );
      
      return RectangleEntity(
        topLeft: newTopLeft,
        bottomRight: newBottomRight,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is ArcEntity) {
      // For arcs, we need to mirror the center and adjust the start/end angles
      final mirroredCenter = transform.mirrorPoint(entity.center);
      
      // For a proper mirror of an arc, we need to flip the start and end angles
      // and adjust them based on the mirror line orientation
      // This is a simplified approach that works for horizontal/vertical mirrors
      final adjustedStartAngle = math.pi - entity.endAngle;
      final adjustedEndAngle = math.pi - entity.startAngle;
      
      return ArcEntity(
        center: mirroredCenter,
        radius: entity.radius,
        startAngle: adjustedStartAngle,
        endAngle: adjustedEndAngle,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is EllipseEntity) {
      return EllipseEntity(
        center: transform.mirrorPoint(entity.center),
        radiusX: entity.radiusX,
        radiusY: entity.radiusY,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is PolylineEntity) {
      // Mirror all points of the polyline
      List<Offset> mirroredPoints = entity.points.map((p) => 
        transform.mirrorPoint(p)
      ).toList();
      
      return PolylineEntity(
        points: mirroredPoints,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is SplineEntity) {
      // Mirror all control points of the spline
      List<Offset> mirroredControlPoints = entity.controlPoints.map((p) => 
        transform.mirrorPoint(p)
      ).toList();
      
      return SplineEntity(
        controlPoints: mirroredControlPoints,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
        showControlPoints: entity.showControlPoints,
        splineType: entity.splineType,
        tension: entity.tension,
      );
    } else {
      // Unknown entity type
      print('Warning: Attempted to mirror unsupported entity type: ${entity.runtimeType}');
      return entity;
    }
  }
  
  // Custom drawing for the mirror line is handled in the updatePreviewEntity method
  // We'll create a special preview entity that represents the mirror line
  @override
  void updatePreviewEntity(DrawingDocument document) {
    // If we have the first point of the mirror line but not the second,
    // create a preview entity for the mirror line
    if (mirrorPoint1 != null && mirrorPoint2 != null && entityToMirror != null) {
      // Create the mirrored entity as the preview
      previewEntity = _createMirroredEntity(entityToMirror!);
    } else if (mirrorPoint1 != null && drawCurrent != null) {
      // Create a temporary line entity to represent the mirror line
      previewEntity = LineEntity(
        start: mirrorPoint1!,
        end: drawCurrent!,
        layer: 'preview',
        color: Colors.purple,
        lineWidth: 1.0,
        isSelected: false,
      );
    }
  }
  
  // Method removed as it's no longer needed
  
  @override
  MouseCursor getCursor() {
    if (entityToMirror == null) {
      return SystemMouseCursors.precise;
    } else {
      return SystemMouseCursors.click;
    }
  }
  
  @override
  Entity? getPreviewEntity(DrawingDocument document) {
    return previewEntity;
  }
}
