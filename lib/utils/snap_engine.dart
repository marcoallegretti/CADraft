import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../models/drawing_document.dart';
import 'geometry_utils.dart';
import 'snap_utils.dart';

/// Engine responsible for handling all snapping logic in the CAD system
class SnapEngine {
  final SnapSettings settings;
  final double scale;

  SnapEngine({
    required this.settings,
    this.scale = 1.0,
  });

  /// Find all possible snap points for a given cursor position
  List<SnapResult> findSnapPoints(
    Offset cursorPosition,
    DrawingDocument document,
  ) {
    if (!settings.enabled) {
      return [];
    }

    final results = <SnapResult>[];
    final entities = document.visibleEntities;
    final effectiveSnapDistance = settings.snapDistance / scale;

    // Grid snap
    if (settings.isTypeEnabled(SnapType.grid) && document.snapToGrid) {
      final gridSnap =
          GeometryUtils.snapToGrid(cursorPosition, document.gridSize);
      if ((gridSnap - cursorPosition).distance <= effectiveSnapDistance) {
        results.add(SnapResult(
          position: gridSnap,
          type: SnapType.grid,
          description: 'Grid',
        ));
      }
    }

    // Entity characteristic points
    for (final entity in entities) {
      // Skip the entity if it's too far away (optimization)
      if (!_isEntityInRange(
          entity, cursorPosition, effectiveSnapDistance * 2)) {
        continue;
      }

      // Get entity characteristic points
      final points = entity.getCharacteristicPoints();

      // Check each point for different snap types
      for (int i = 0; i < points.length; i++) {
        final point = points[i];
        final distance = (point - cursorPosition).distance;

        if (distance > effectiveSnapDistance) {
          continue;
        }

        // Determine snap type based on point index and entity type
        SnapType snapType;
        String description;

        if (entity is LineEntity) {
          if (i == 0 || i == 1) {
            // Endpoints
            if (settings.isTypeEnabled(SnapType.endpoint)) {
              snapType = SnapType.endpoint;
              description = 'Endpoint';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          } else if (i == 2) {
            // Midpoint
            if (settings.isTypeEnabled(SnapType.midpoint)) {
              snapType = SnapType.midpoint;
              description = 'Midpoint';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          }
        } else if (entity is CircleEntity) {
          if (i == 0) {
            // Center
            if (settings.isTypeEnabled(SnapType.center)) {
              snapType = SnapType.center;
              description = 'Center';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          } else {
            // Quadrant points
            if (settings.isTypeEnabled(SnapType.quadrant)) {
              snapType = SnapType.quadrant;
              description = 'Quadrant';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          }
        } else if (entity is RectangleEntity) {
          if (i < 4) {
            // Corners
            if (settings.isTypeEnabled(SnapType.endpoint)) {
              snapType = SnapType.endpoint;
              description = 'Corner';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          } else {
            // Center
            if (settings.isTypeEnabled(SnapType.center)) {
              snapType = SnapType.center;
              description = 'Center';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          }
        } else if (entity is ArcEntity) {
          if (i == 0) {
            // Center
            if (settings.isTypeEnabled(SnapType.center)) {
              snapType = SnapType.center;
              description = 'Center';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          } else if (i == 1 || i == 3) {
            // Endpoints
            if (settings.isTypeEnabled(SnapType.endpoint)) {
              snapType = SnapType.endpoint;
              description = 'Endpoint';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          } else {
            // Middle point
            if (settings.isTypeEnabled(SnapType.midpoint)) {
              snapType = SnapType.midpoint;
              description = 'Midpoint';
              results.add(SnapResult(
                position: point,
                type: snapType,
                description: description,
                sourceEntity: entity,
              ));
            }
          }
        }
      }

      // Perpendicular snaps (for lines)
      if (settings.isTypeEnabled(SnapType.perpendicular) &&
          entity is LineEntity) {
        final perpPoint = _findPerpendicularPoint(cursorPosition, entity);
        final distance = (perpPoint - cursorPosition).distance;

        if (distance <= effectiveSnapDistance) {
          results.add(SnapResult(
            position: perpPoint,
            type: SnapType.perpendicular,
            description: 'Perpendicular',
            sourceEntity: entity,
          ));
        }
      }

      // Tangent snaps (for circles and arcs)
      if (settings.isTypeEnabled(SnapType.tangent) &&
          (entity is CircleEntity || entity is ArcEntity)) {
        final center = entity is CircleEntity
            ? (entity).center
            : (entity as ArcEntity).center;
        final radius = entity is CircleEntity
            ? (entity).radius
            : (entity as ArcEntity).radius;

        final tangentPoints =
            _findTangentPoints(cursorPosition, center, radius);

        for (final tangentPoint in tangentPoints) {
          final distance = (tangentPoint - cursorPosition).distance;
          if (distance <= effectiveSnapDistance) {
            results.add(SnapResult(
              position: tangentPoint,
              type: SnapType.tangent,
              description: 'Tangent',
              sourceEntity: entity,
            ));
          }
        }
      }
    }

    // Intersection snaps
    if (settings.isTypeEnabled(SnapType.intersection)) {
      for (int i = 0; i < entities.length; i++) {
        for (int j = i + 1; j < entities.length; j++) {
          final intersections =
              GeometryUtils.findIntersections(entities[i], entities[j]);

          for (final intersection in intersections) {
            final distance = (intersection - cursorPosition).distance;

            if (distance <= effectiveSnapDistance) {
              results.add(SnapResult(
                position: intersection,
                type: SnapType.intersection,
                description: 'Intersection',
                sourceEntity: null, // Intersection belongs to two entities
              ));
            }
          }
        }
      }
    }

    // Nearest point snap (for lines, circles, arcs)
    if (settings.isTypeEnabled(SnapType.nearest)) {
      for (final entity in entities) {
        Offset? nearestPoint;

        if (entity is LineEntity) {
          nearestPoint =
              _findNearestPointOnLine(cursorPosition, entity.start, entity.end);
        } else if (entity is CircleEntity) {
          nearestPoint = _findNearestPointOnCircle(
              cursorPosition, entity.center, entity.radius);
        } else if (entity is ArcEntity) {
          nearestPoint = _findNearestPointOnArc(cursorPosition, entity.center,
              entity.radius, entity.startAngle, entity.endAngle);
        }

        if (nearestPoint != null) {
          final distance = (nearestPoint - cursorPosition).distance;

          if (distance <= effectiveSnapDistance) {
            results.add(SnapResult(
              position: nearestPoint,
              type: SnapType.nearest,
              description: 'Nearest',
              sourceEntity: entity,
            ));
          }
        }
      }
    }

    return results;
  }

  /// Find the best snap point from all possible snap points
  SnapResult? findBestSnapPoint(
    List<SnapResult> snapResults,
    Offset cursorPosition,
  ) {
    if (snapResults.isEmpty) {
      return null;
    }

    // Define snap type priorities (higher index = higher priority)
    final priorities = {
      SnapType.grid: 0,
      SnapType.nearest: 1,
      SnapType.midpoint: 2,
      SnapType.quadrant: 3,
      SnapType.center: 4,
      SnapType.tangent: 5,
      SnapType.perpendicular: 6,
      SnapType.endpoint: 7,
      SnapType.intersection: 8,
    };

    // Sort by priority and distance
    snapResults.sort((a, b) {
      // First compare by priority
      final priorityA = priorities[a.type] ?? 0;
      final priorityB = priorities[b.type] ?? 0;

      if (priorityB != priorityA) {
        return priorityB.compareTo(priorityA);
      }

      // If same priority, compare by distance to cursor
      final distanceA = (a.position - cursorPosition).distance;
      final distanceB = (b.position - cursorPosition).distance;
      return distanceA.compareTo(distanceB);
    });

    return snapResults.first;
  }

  // Helper methods

  /// Check if an entity is within range of the cursor
  bool _isEntityInRange(Entity entity, Offset cursor, double range) {
    if (entity is LineEntity) {
      return GeometryUtils.distanceToLineSegment(
              cursor, entity.start, entity.end) <=
          range;
    } else if (entity is CircleEntity) {
      final distToCenter = (cursor - entity.center).distance;
      return (distToCenter - entity.radius).abs() <= range;
    } else if (entity is RectangleEntity) {
      // Check if cursor is near any of the four sides
      final topLeft = entity.topLeft;
      final bottomRight = entity.bottomRight;
      final topRight = Offset(bottomRight.dx, topLeft.dy);
      final bottomLeft = Offset(topLeft.dx, bottomRight.dy);

      return GeometryUtils.distanceToLineSegment(cursor, topLeft, topRight) <=
              range ||
          GeometryUtils.distanceToLineSegment(cursor, topRight, bottomRight) <=
              range ||
          GeometryUtils.distanceToLineSegment(
                  cursor, bottomRight, bottomLeft) <=
              range ||
          GeometryUtils.distanceToLineSegment(cursor, bottomLeft, topLeft) <=
              range;
    } else if (entity is ArcEntity) {
      final distToCenter = (cursor - entity.center).distance;
      return (distToCenter - entity.radius).abs() <= range;
    }

    return false;
  }

  /// Find the perpendicular point on a line from a given point
  Offset _findPerpendicularPoint(Offset point, LineEntity line) {
    final start = line.start;
    final end = line.end;

    // Vector from start to end
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Length squared of the line
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared < 1e-10) {
      return start; // Line is too short, return start point
    }

    // Calculate projection parameter
    final t = ((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) /
        lengthSquared;

    // Calculate projection point
    final projection = Offset(
      start.dx + t * dx,
      start.dy + t * dy,
    );

    // Check if projection is on the line segment
    if (t >= 0 && t <= 1) {
      return projection;
    }

    // If not on segment, return the closest endpoint
    return (point - start).distanceSquared < (point - end).distanceSquared
        ? start
        : end;
  }

  /// Find tangent points from a point to a circle
  List<Offset> _findTangentPoints(Offset point, Offset center, double radius) {
    final results = <Offset>[];

    // Distance from point to center
    final distToCenter = (point - center).distance;

    // If point is inside the circle, there are no tangent points
    if (distToCenter < radius) {
      return results;
    }

    // If point is on the circle, the point itself is the only tangent point
    if ((distToCenter - radius).abs() < 1e-10) {
      results.add(point);
      return results;
    }

    // Calculate tangent points
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;

    // Angle from center to point
    final angle = math.atan2(dy, dx);

    // Angle between line from center to point and tangent line
    final tangentAngle = math.asin(radius / distToCenter);

    // Calculate tangent points
    final angle1 = angle + tangentAngle;
    final angle2 = angle - tangentAngle;

    results.add(Offset(
      center.dx + radius * math.cos(angle1),
      center.dy + radius * math.sin(angle1),
    ));

    results.add(Offset(
      center.dx + radius * math.cos(angle2),
      center.dy + radius * math.sin(angle2),
    ));

    return results;
  }

  /// Find the nearest point on a line segment from a given point
  Offset _findNearestPointOnLine(Offset point, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared < 1e-10) {
      return start; // Line is too short, return start point
    }

    // Calculate projection parameter
    final t = ((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) /
        lengthSquared;

    // Clamp t to [0, 1] to stay on the line segment
    final clampedT = math.max(0, math.min(1, t));

    // Calculate nearest point
    return Offset(
      start.dx + clampedT * dx,
      start.dy + clampedT * dy,
    );
  }

  /// Find the nearest point on a circle from a given point
  Offset _findNearestPointOnCircle(Offset point, Offset center, double radius) {
    // Vector from center to point
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;

    // Distance from center to point
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < 1e-10) {
      // Point is at center, return arbitrary point on circle
      return Offset(center.dx + radius, center.dy);
    }

    // Normalize vector and scale by radius
    final scale = radius / distance;

    return Offset(
      center.dx + dx * scale,
      center.dy + dy * scale,
    );
  }

  /// Find the nearest point on an arc from a given point
  Offset? _findNearestPointOnArc(
    Offset point,
    Offset center,
    double radius,
    double startAngle,
    double endAngle,
  ) {
    // Vector from center to point
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;

    // Calculate angle of the point relative to center
    var angle = math.atan2(dy, dx);

    // Normalize angles to ensure correct comparison
    if (endAngle < startAngle) {
      endAngle += 2 * math.pi;
    }

    if (angle < startAngle) {
      angle += 2 * math.pi;
    }

    // Check if angle is within arc range
    if (angle >= startAngle && angle <= endAngle) {
      // Point projects onto the arc, return the projection
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance < 1e-10) {
        // Point is at center, return start point of arc
        return Offset(
          center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle),
        );
      }

      // Normalize vector and scale by radius
      final scale = radius / distance;

      return Offset(
        center.dx + dx * scale,
        center.dy + dy * scale,
      );
    } else {
      // Point projects outside the arc, return the closest endpoint
      final startPoint = Offset(
        center.dx + radius * math.cos(startAngle),
        center.dy + radius * math.sin(startAngle),
      );

      final endPoint = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      final distToStart = (point - startPoint).distance;
      final distToEnd = (point - endPoint).distance;

      return distToStart < distToEnd ? startPoint : endPoint;
    }
  }
}
