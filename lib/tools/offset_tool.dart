import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../utils/geometry_utils.dart';
import 'base_tool.dart';

/// Represents an offset transformation
class OffsetTransform {
  final double distance;
  final double angle;
  
  OffsetTransform(this.distance, this.angle);
  
  /// Offsets a point by the specified distance and angle
  Offset offsetPoint(Offset point) {
    return Offset(
      point.dx + distance * math.cos(angle),
      point.dy + distance * math.sin(angle),
    );
  }
  
  /// Gets the normal vector for this offset
  Offset getNormalVector() {
    return Offset(math.cos(angle), math.sin(angle));
  }
}

/// Offset tool implementation
class OffsetTool extends BaseTool {
  String? selectedEntityId;
  Entity? entityToOffset;
  Offset? offsetStart;
  double offsetDistance = 0.0;
  double offsetAngle = 0.0;
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (entityToOffset == null) {
      // First click: select the entity to offset
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
        
        // Store the entity to offset
        entityToOffset = document.visibleEntities
            .where((e) => e.id == hitEntityId)
            .firstOrNull;
            
        // Set the offset start point
        offsetStart = point;
      }
    } else {
      // Second click: finalize the offset
      if (offsetStart != null) {
        // Calculate the offset distance and angle
        _calculateOffset(point);
        
        // Create the offset entity
        final offsetEntity = _createOffsetEntity(entityToOffset!);
        
        // Add the offset entity to the document
        documentService.addEntity(offsetEntity);
        
        // Clear the state to start a new offset operation
        clearState();
      }
    }
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (entityToOffset != null && offsetStart != null) {
      // Calculate the offset distance and angle
      _calculateOffset(point);
      
      // Update the preview entity
      previewEntity = _createOffsetEntity(entityToOffset!);
    }
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // If we're in the offset phase (entity is selected and we're specifying the offset)
    if (entityToOffset != null && offsetStart != null) {
      // Calculate the offset distance and angle
      _calculateOffset(point);
      
      // Create the offset entity
      final offsetEntity = _createOffsetEntity(entityToOffset!);
      
      // Add the offset entity to the document
      documentService.addEntity(offsetEntity);
      
      // Clear the state to start a new offset operation
      clearState();
    }
  }
  
  @override
  void clearState() {
    super.clearState();
    selectedEntityId = null;
    entityToOffset = null;
    offsetStart = null;
    offsetDistance = 0.0;
    offsetAngle = 0.0;
    previewEntity = null;
  }
  
  void _calculateOffset(Offset currentPoint) {
    if (offsetStart == null) return;
    
    // Calculate the vector from the start point to the current point
    final dx = currentPoint.dx - offsetStart!.dx;
    final dy = currentPoint.dy - offsetStart!.dy;
    
    // Calculate the distance and angle
    offsetDistance = math.sqrt(dx * dx + dy * dy);
    offsetAngle = math.atan2(dy, dx);
  }
  
  Entity _createOffsetEntity(Entity entity) {
    if (offsetDistance == 0) return entity;
    
    // Create an offset transform to handle the offset calculations
    final transform = OffsetTransform(offsetDistance, offsetAngle);
    
    if (entity is LineEntity) {
      // For a line, we offset both endpoints by the same distance and angle
      return LineEntity(
        start: transform.offsetPoint(entity.start),
        end: transform.offsetPoint(entity.end),
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false, // The offset copy is not selected initially
      );
    } else if (entity is CircleEntity) {
      // For a circle, we offset the center and keep the radius the same
      return CircleEntity(
        center: transform.offsetPoint(entity.center),
        radius: entity.radius,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is RectangleEntity) {
      // For a rectangle, we offset both corner points
      return RectangleEntity(
        topLeft: transform.offsetPoint(entity.topLeft),
        bottomRight: transform.offsetPoint(entity.bottomRight),
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is ArcEntity) {
      // For an arc, we offset the center and keep the radius and angles the same
      return ArcEntity(
        center: transform.offsetPoint(entity.center),
        radius: entity.radius,
        startAngle: entity.startAngle,
        endAngle: entity.endAngle,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is EllipseEntity) {
      // For an ellipse, we offset the center and keep the radiuses the same
      return EllipseEntity(
        center: transform.offsetPoint(entity.center),
        radiusX: entity.radiusX,
        radiusY: entity.radiusY,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is PolylineEntity) {
      // For a polyline, we offset all points
      List<Offset> offsetPoints = entity.points.map((p) => 
        transform.offsetPoint(p)
      ).toList();
      
      return PolylineEntity(
        points: offsetPoints,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: false,
      );
    } else if (entity is SplineEntity) {
      // For a spline, we offset all control points
      List<Offset> offsetControlPoints = entity.controlPoints.map((p) => 
        transform.offsetPoint(p)
      ).toList();
      
      return SplineEntity(
        controlPoints: offsetControlPoints,
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
      print('Warning: Attempted to offset unsupported entity type: ${entity.runtimeType}');
      return entity;
    }
  }
  
  @override
  void updatePreviewEntity(DrawingDocument document) {
    if (entityToOffset != null && offsetStart != null && drawCurrent != null) {
      // Calculate the offset based on the current pointer position
      _calculateOffset(drawCurrent!);
      
      // Create the preview entity
      previewEntity = _createOffsetEntity(entityToOffset!);
    }
  }
  
  @override
  MouseCursor getCursor() {
    if (entityToOffset == null) {
      return SystemMouseCursors.precise;
    } else {
      return SystemMouseCursors.move;
    }
  }
  
  @override
  Entity? getPreviewEntity(DrawingDocument document) {
    return previewEntity;
  }
}
