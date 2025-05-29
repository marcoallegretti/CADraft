import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../utils/geometry_utils.dart';
import 'base_tool.dart';

/// Represents a rotation transformation
class RotationTransform {
  final Offset center;
  final double angle;
  
  RotationTransform(this.center, this.angle);
  
  /// Rotates a point around the center by the specified angle
  Offset rotatePoint(Offset point) {
    // Translate point to origin
    final translatedX = point.dx - center.dx;
    final translatedY = point.dy - center.dy;
    
    // Rotate
    final rotatedX = translatedX * math.cos(angle) - translatedY * math.sin(angle);
    final rotatedY = translatedX * math.sin(angle) + translatedY * math.cos(angle);
    
    // Translate back
    return Offset(
      rotatedX + center.dx,
      rotatedY + center.dy,
    );
  }
}

/// Rotate tool implementation
class RotateTool extends BaseTool {
  String? selectedEntityId;
  Entity? entityToRotate;
  Offset? rotationCenter;
  Offset? rotationStart;
  double? startAngle;
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (entityToRotate == null) {
      // First click: select the entity to rotate
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
        
        // Store the entity to rotate
        entityToRotate = document.visibleEntities
            .where((e) => e.id == hitEntityId)
            .firstOrNull;
      }
    } else if (rotationCenter == null) {
      // Second click: set the rotation center point
      rotationCenter = point;
      rotationStart = point;
      
      // Calculate the start angle (will be used as reference)
      if (entityToRotate != null) {
        startAngle = math.atan2(
          rotationStart!.dy - rotationCenter!.dy,
          rotationStart!.dx - rotationCenter!.dx
        );
      }
    } else {
      // Third click: finalize the rotation
      final angle = _calculateRotationAngle(point);
      if (angle != null && entityToRotate != null) {
        // Create the rotated entity
        final rotatedEntity = _createRotatedEntity(entityToRotate!, angle);
        
        // Update the entity in the document
        documentService.updateEntity(rotatedEntity);
        
        // Clear the state to start a new rotation
        clearState();
      }
    }
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (entityToRotate != null && rotationCenter != null) {
      // Calculate the current angle
      final angle = _calculateRotationAngle(point);
      if (angle != null) {
        // Update the preview entity
        previewEntity = _createRotatedEntity(entityToRotate!, angle);
      }
    }
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // If we're in the rotation phase (entity and center are selected)
    if (entityToRotate != null && rotationCenter != null) {
      final angle = _calculateRotationAngle(point);
      if (angle != null) {
        // Create the rotated entity
        final rotatedEntity = _createRotatedEntity(entityToRotate!, angle);
        
        // Update the entity in the document
        documentService.updateEntity(rotatedEntity);
        
        // Clear the state to start a new rotation
        clearState();
      }
    }
    // Otherwise, we're still in the selection phase, don't clear state
  }
  

  
  @override
  void clearState() {
    super.clearState();
    selectedEntityId = null;
    entityToRotate = null;
    rotationCenter = null;
    rotationStart = null;
    startAngle = null;
    previewEntity = null;
  }
  
  double? _calculateRotationAngle(Offset currentPoint) {
    if (rotationCenter == null || startAngle == null) return null;
    
    // Calculate the current angle
    final currentAngle = math.atan2(
      currentPoint.dy - rotationCenter!.dy,
      currentPoint.dx - rotationCenter!.dx
    );
    
    // Calculate the angle difference
    return currentAngle - startAngle!;
  }
  
  // This method is no longer needed as rotation is handled directly in onPointerDown and onPointerUp
  
  Entity _createRotatedEntity(Entity entity, double angle) {
    if (rotationCenter == null) return entity;
    
    // Create a rotation transform to handle the rotation calculations
    final transform = RotationTransform(rotationCenter!, angle);
    
    if (entity is LineEntity) {
      return LineEntity(
        start: transform.rotatePoint(entity.start),
        end: transform.rotatePoint(entity.end),
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is CircleEntity) {
      return CircleEntity(
        center: transform.rotatePoint(entity.center),
        radius: entity.radius, // Radius doesn't change during rotation
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is RectangleEntity) {
      // For rectangles, we need to rotate all four corners to maintain the shape
      // This approach preserves the rectangle's dimensions but rotates it in space
      final topLeft = entity.topLeft;
      final topRight = Offset(entity.bottomRight.dx, entity.topLeft.dy);
      final bottomLeft = Offset(entity.topLeft.dx, entity.bottomRight.dy);
      final bottomRight = entity.bottomRight;
      
      // Rotate all four corners
      final rotatedTopLeft = transform.rotatePoint(topLeft);
      final rotatedTopRight = transform.rotatePoint(topRight);
      final rotatedBottomLeft = transform.rotatePoint(bottomLeft);
      final rotatedBottomRight = transform.rotatePoint(bottomRight);
      
      // Create a polyline entity with the rotated corners to represent the rotated rectangle
      // This is a workaround since our RectangleEntity only supports axis-aligned rectangles
      return PolylineEntity(
        points: [
          rotatedTopLeft,
          rotatedTopRight,
          rotatedBottomRight,
          rotatedBottomLeft,
          rotatedTopLeft, // Close the shape
        ],
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is ArcEntity) {
      return ArcEntity(
        center: transform.rotatePoint(entity.center),
        radius: entity.radius, // Radius doesn't change during rotation
        startAngle: entity.startAngle + angle, // Adjust the angles
        endAngle: entity.endAngle + angle,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is EllipseEntity) {
      // For ellipses, we need a more complex approach to handle rotation properly
      // This implementation rotates the center but doesn't handle orientation change
      // For a complete solution, we would need to add rotation angle to the EllipseEntity class
      return EllipseEntity(
        center: transform.rotatePoint(entity.center),
        radiusX: entity.radiusX,
        radiusY: entity.radiusY,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is PolylineEntity) {
      // Rotate all points of the polyline
      List<Offset> rotatedPoints = entity.points.map((p) => 
        transform.rotatePoint(p)
      ).toList();
      
      return PolylineEntity(
        points: rotatedPoints,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is SplineEntity) {
      // Rotate all control points of the spline
      List<Offset> rotatedControlPoints = entity.controlPoints.map((p) => 
        transform.rotatePoint(p)
      ).toList();
      
      return SplineEntity(
        controlPoints: rotatedControlPoints,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        showControlPoints: entity.showControlPoints,
        splineType: entity.splineType,
        tension: entity.tension,
        id: entity.id,
      );
    } else {
      // Unknown entity type
      print('Warning: Attempted to rotate unsupported entity type: ${entity.runtimeType}');
      return entity;
    }
  }
  
  // This method is replaced by the RotationTransform class
  
  // Note: This method was removed as it's not currently used in the implementation
  // If needed in the future, it can be re-added to calculate entity centers
  
  @override
  MouseCursor getCursor() {
    if (entityToRotate == null) {
      return SystemMouseCursors.precise;
    } else if (rotationCenter == null) {
      return SystemMouseCursors.click;
    } else {
      return SystemMouseCursors.grab;
    }
  }
  
  @override
  Entity? getPreviewEntity(DrawingDocument document) {
    return previewEntity;
  }
  
  @override
  void finalizeEntity(DrawingDocument document, DocumentService documentService, BuildContext context) {
    clearState();
  }
}
