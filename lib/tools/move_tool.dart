import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../utils/geometry_utils.dart';
import 'base_tool.dart';

/// Move tool implementation
class MoveTool extends BaseTool {
  String? selectedEntityId;
  Offset? moveStart;
  
  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // When move tool is active and we click, try to select an entity and start moving it
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
        } else if (entity is EllipseEntity) {
          // For ellipses, use our new distance calculation
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
          // We use a standard small distance since hitTest already verified it's hittable
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
      moveStart = point;
    }
  }
  
  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    if (selectedEntityId == null || moveStart == null) return;
    
    // Calculate the move delta
    final delta = point - moveStart!;
    
    // Find the selected entity
    final selectedEntity = document.visibleEntities
        .where((e) => e.id == selectedEntityId)
        .firstOrNull;
    
    if (selectedEntity != null) {
      // Move the entity
      handleMoveEntity(selectedEntity, delta, documentService);
      // Update move start for the next move
      moveStart = point;
    }
  }
  
  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Clear move state
    moveStart = null;
    if (selectedEntityId == null) {
      // If no entity is selected, also clear selection
      documentService.clearSelection();
    }
  }
  
  void handleMoveEntity(Entity entity, Offset delta, DocumentService documentService) {
    Entity updatedEntity;

    if (entity is LineEntity) {
      updatedEntity = entity.copyWith(
        start: entity.start + delta,
        end: entity.end + delta,
      );
    } else if (entity is CircleEntity) {
      updatedEntity = entity.copyWith(
        center: entity.center + delta,
      );
    } else if (entity is RectangleEntity) {
      updatedEntity = entity.copyWith(
        topLeft: entity.topLeft + delta,
        bottomRight: entity.bottomRight + delta,
      );
    } else if (entity is ArcEntity) {
      updatedEntity = entity.copyWith(
        center: entity.center + delta,
      );
    } else if (entity is EllipseEntity) {
      updatedEntity = entity.copyWith(
        center: entity.center + delta,
      );
    } else if (entity is PolylineEntity) {
      // Move all points of the polyline by the delta
      List<Offset> newPoints = entity.points.map((p) => p + delta).toList();
      updatedEntity = entity.copyWith(
        points: newPoints,
      );
    } else if (entity is SplineEntity) {
      // Move all control points of the spline by the delta
      List<Offset> newControlPoints = entity.controlPoints.map((p) => p + delta).toList();
      updatedEntity = entity.copyWith(
        controlPoints: newControlPoints,
      );
    } else {
      // Unknown entity type
      print('Warning: Attempted to move unsupported entity type: ${entity.runtimeType}');
      return;
    }

    documentService.updateEntity(updatedEntity);
  }
  
  @override
  MouseCursor getCursor() {
    return SystemMouseCursors.move;
  }
  
  @override
  void clearState() {
    super.clearState();
    selectedEntityId = null;
    moveStart = null;
  }
}
