import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../utils/geometry_utils.dart';
import 'base_tool.dart';

/// Represents a scaling transformation
class ScaleTransform {
  final Offset referencePoint;
  final double scaleX;
  final double scaleY;
  
  ScaleTransform(this.referencePoint, this.scaleX, this.scaleY);
  
  /// Scales a point relative to the reference point
  Offset scalePoint(Offset point) {
    // Translate point to origin
    final translatedX = point.dx - referencePoint.dx;
    final translatedY = point.dy - referencePoint.dy;
    
    // Scale
    final scaledX = translatedX * scaleX;
    final scaledY = translatedY * scaleY;
    
    // Translate back
    return Offset(
      scaledX + referencePoint.dx,
      scaledY + referencePoint.dy,
    );
  }
}

/// Scale tool implementation
class ScaleTool extends BaseTool {
  String? selectedEntityId;
  Entity? entityToScale;
  Offset? scaleReferencePoint;
  Offset? scaleStart;
  bool uniformScale = true; // Default to uniform scaling (maintain aspect ratio)
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (entityToScale == null) {
      // First click: select the entity to scale
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
        
        // Store the entity to scale
        entityToScale = document.visibleEntities
            .where((e) => e.id == hitEntityId)
            .firstOrNull;
            
        // Calculate the center of the entity as the default reference point
        if (entityToScale != null) {
          scaleReferencePoint = _calculateEntityCenter(entityToScale!);
        }
      }
    } else if (scaleStart == null) {
      // Second click: set the scale start point (reference for scaling)
      scaleStart = point;
    } else {
      // Third click: finalize the scaling
      final scaleFactors = _calculateScaleFactors(point);
      if (scaleFactors != null && entityToScale != null) {
        // Create the scaled entity
        final scaledEntity = _createScaledEntity(entityToScale!, scaleFactors[0], scaleFactors[1]);
        
        // Update the entity in the document
        documentService.updateEntity(scaledEntity);
        
        // Clear the state to start a new scaling operation
        clearState();
      }
    }
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (entityToScale != null && scaleReferencePoint != null && scaleStart != null) {
      // Calculate the scale factors
      final scaleFactors = _calculateScaleFactors(point);
      if (scaleFactors != null) {
        // Update the preview entity
        previewEntity = _createScaledEntity(entityToScale!, scaleFactors[0], scaleFactors[1]);
      }
    }
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // If we're in the scaling phase (entity and reference point are set)
    if (entityToScale != null && scaleReferencePoint != null && scaleStart != null) {
      final scaleFactors = _calculateScaleFactors(point);
      if (scaleFactors != null) {
        // Create the scaled entity
        final scaledEntity = _createScaledEntity(entityToScale!, scaleFactors[0], scaleFactors[1]);
        
        // Update the entity in the document
        documentService.updateEntity(scaledEntity);
        
        // Clear the state to start a new scaling operation
        clearState();
      }
    }
    // Otherwise, we're still in the selection phase, don't clear state
  }
  
  @override
  void clearState() {
    super.clearState();
    selectedEntityId = null;
    entityToScale = null;
    scaleReferencePoint = null;
    scaleStart = null;
    previewEntity = null;
  }
  
  /// Calculate the center point of an entity
  Offset _calculateEntityCenter(Entity entity) {
    if (entity is LineEntity) {
      // For a line, the center is the midpoint
      return Offset(
        (entity.start.dx + entity.end.dx) / 2,
        (entity.start.dy + entity.end.dy) / 2,
      );
    } else if (entity is CircleEntity) {
      return entity.center;
    } else if (entity is RectangleEntity) {
      // For a rectangle, the center is the midpoint of the diagonals
      return Offset(
        (entity.topLeft.dx + entity.bottomRight.dx) / 2,
        (entity.topLeft.dy + entity.bottomRight.dy) / 2,
      );
    } else if (entity is ArcEntity) {
      return entity.center;
    } else if (entity is EllipseEntity) {
      return entity.center;
    } else if (entity is PolylineEntity) {
      // For a polyline, calculate the centroid of all points
      double sumX = 0;
      double sumY = 0;
      for (final point in entity.points) {
        sumX += point.dx;
        sumY += point.dy;
      }
      return Offset(
        sumX / entity.points.length,
        sumY / entity.points.length,
      );
    } else if (entity is SplineEntity) {
      // For a spline, calculate the centroid of all control points
      double sumX = 0;
      double sumY = 0;
      for (final point in entity.controlPoints) {
        sumX += point.dx;
        sumY += point.dy;
      }
      return Offset(
        sumX / entity.controlPoints.length,
        sumY / entity.controlPoints.length,
      );
    } else {
      // Default to (0,0) for unknown entity types
      return Offset.zero;
    }
  }
  
  /// Calculate the scale factors based on the current point
  /// Returns a list with [scaleX, scaleY]
  List<double>? _calculateScaleFactors(Offset currentPoint) {
    if (scaleReferencePoint == null || scaleStart == null) return null;
    
    // Calculate the initial distance from reference point to start point
    final initialDx = scaleStart!.dx - scaleReferencePoint!.dx;
    final initialDy = scaleStart!.dy - scaleReferencePoint!.dy;
    final initialDistance = math.sqrt(initialDx * initialDx + initialDy * initialDy);
    
    // Calculate the current distance from reference point to current point
    final currentDx = currentPoint.dx - scaleReferencePoint!.dx;
    final currentDy = currentPoint.dy - scaleReferencePoint!.dy;
    final currentDistance = math.sqrt(currentDx * currentDx + currentDy * currentDy);
    
    if (initialDistance == 0) return [1.0, 1.0]; // Avoid division by zero
    
    // Calculate scale factors
    double scaleX = currentDx / initialDx;
    double scaleY = currentDy / initialDy;
    
    // Handle cases where the initial values are very small
    if (initialDx.abs() < 1) scaleX = currentDistance / initialDistance;
    if (initialDy.abs() < 1) scaleY = currentDistance / initialDistance;
    
    // For uniform scaling, use the distance ratio
    if (uniformScale) {
      final scale = currentDistance / initialDistance;
      return [scale, scale];
    } else {
      return [scaleX, scaleY];
    }
  }
  
  Entity _createScaledEntity(Entity entity, double scaleX, double scaleY) {
    if (scaleReferencePoint == null) return entity;
    
    // Create a scale transform to handle the scaling calculations
    final transform = ScaleTransform(scaleReferencePoint!, scaleX, scaleY);
    
    if (entity is LineEntity) {
      return LineEntity(
        start: transform.scalePoint(entity.start),
        end: transform.scalePoint(entity.end),
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is CircleEntity) {
      // For circles, we scale the radius and keep the center at the reference point
      // if the center is the reference point
      final newCenter = transform.scalePoint(entity.center);
      final newRadius = entity.radius * ((scaleX + scaleY) / 2); // Average scale for radius
      
      return CircleEntity(
        center: newCenter,
        radius: newRadius,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is RectangleEntity) {
      return RectangleEntity(
        topLeft: transform.scalePoint(entity.topLeft),
        bottomRight: transform.scalePoint(entity.bottomRight),
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is ArcEntity) {
      // For arcs, we scale the radius and center
      final newCenter = transform.scalePoint(entity.center);
      final newRadius = entity.radius * ((scaleX + scaleY) / 2); // Average scale for radius
      
      return ArcEntity(
        center: newCenter,
        radius: newRadius,
        startAngle: entity.startAngle,
        endAngle: entity.endAngle,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is EllipseEntity) {
      // For ellipses, we scale both radiuses independently
      final newCenter = transform.scalePoint(entity.center);
      final newRadiusX = entity.radiusX * scaleX.abs();
      final newRadiusY = entity.radiusY * scaleY.abs();
      
      return EllipseEntity(
        center: newCenter,
        radiusX: newRadiusX,
        radiusY: newRadiusY,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is PolylineEntity) {
      // Scale all points of the polyline
      List<Offset> scaledPoints = entity.points.map((p) => 
        transform.scalePoint(p)
      ).toList();
      
      return PolylineEntity(
        points: scaledPoints,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is SplineEntity) {
      // Scale all control points of the spline
      List<Offset> scaledControlPoints = entity.controlPoints.map((p) => 
        transform.scalePoint(p)
      ).toList();
      
      return SplineEntity(
        controlPoints: scaledControlPoints,
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
      print('Warning: Attempted to scale unsupported entity type: ${entity.runtimeType}');
      return entity;
    }
  }
  
  @override
  MouseCursor getCursor() {
    if (entityToScale == null) {
      return SystemMouseCursors.precise;
    } else if (scaleStart == null) {
      return SystemMouseCursors.click;
    } else {
      return SystemMouseCursors.resizeUpLeftDownRight;
    }
  }
  
  @override
  Entity? getPreviewEntity(DrawingDocument document) {
    return previewEntity;
  }
  
  /// Toggle between uniform and non-uniform scaling
  void toggleUniformScale() {
    uniformScale = !uniformScale;
  }
  
  @override
  void handleRightClick(DrawingDocument document) {
    // Toggle uniform/non-uniform scaling on right-click
    toggleUniformScale();
  }
}
