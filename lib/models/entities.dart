import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../utils/geometry_utils.dart';

/// Enum defining different types of spline curves
enum SplineType {
  /// Cubic Bezier splines with explicit control points
  bezier,
  
  /// Catmull-Rom splines that pass through all control points
  catmullRom
}

/// Base class for all drawable entities in the CAD system
abstract class Entity {
  Entity({
    required this.layer,
    required this.color,
    required this.lineWidth,
    required this.isSelected,
    String? id,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String layer;
  final Color color;
  final double lineWidth;
  final bool isSelected;

  /// Factory constructor from JSON
  static Entity fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'polyline':
        return PolylineEntity.fromJson(json);
      case 'line':
        return LineEntity.fromJson(json);
      case 'circle':
        return CircleEntity.fromJson(json);
      case 'rectangle':
        return RectangleEntity.fromJson(json);
      case 'arc':
        return ArcEntity.fromJson(json);
      case 'ellipse':
        return EllipseEntity.fromJson(json);
      case 'spline':
        return SplineEntity.fromJson(json);
      default:
        throw Exception('Unknown entity type: $type');
    }
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson();

  /// Draws the entity on the canvas
  void draw(Canvas canvas, Matrix4 transform);

  /// Returns a copy of this entity with modified properties
  Entity copyWith({
    String? layer,
    Color? color,
    double? lineWidth,
    bool? isSelected,
  });

  /// Tests if the given point is within the hit-test range of this entity
  bool hitTest(Offset point, Matrix4 transform, double hitDistance);

  /// Gets characteristic points for this entity (endpoints, center, etc.)
  List<Offset> getCharacteristicPoints();

  /// Extends this entity to meet one of the boundary entities.
  ///
  /// - `boundaryEntities`: A list of entities to extend to.
  /// - `clickPointOnEntity`: The user's click point on this entity, indicating which part/end to extend.
  ///
  /// Returns a new `Entity` representing the extended entity, or `null` if extension is not possible.
  Entity? extend(List<Entity> boundaryEntities, Offset clickPointOnEntity) {
    // Default implementation returns null, to be overridden by subclasses
    // This allows tools to call extend on any entity without needing to know its specific type upfront.
    debugPrint('[Entity.extend] Extend called on base Entity class for ${this.runtimeType}. Subclass should override this.');
    return null;
  }
}

/// Represents a straight line segment
class LineEntity extends Entity {
  LineEntity({
    required this.start,
    required this.end,
    required super.layer,
    required super.color,
    required super.lineWidth,
    required super.isSelected,
    super.id,
  });

  final Offset start;
  final Offset end;

  @override
  void draw(Canvas canvas, Matrix4 transform) {
    final paint = Paint()
      ..color = isSelected ? Colors.blue : color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Transform points
    final startPoint = GeometryUtils.transformPoint(start, transform);
    final endPoint = GeometryUtils.transformPoint(end, transform);

    canvas.drawLine(startPoint, endPoint, paint);

    // Draw selection handles if selected
    if (isSelected) {
      _drawSelectionHandles(canvas, [startPoint, endPoint]);
    }
  }

  @override
  bool hitTest(Offset point, Matrix4 transform, double hitDistance) {
    final startPoint = GeometryUtils.transformPoint(start, transform);
    final endPoint = GeometryUtils.transformPoint(end, transform);

    // Calculate distance from point to line segment
    return _distanceToLineSegment(point, startPoint, endPoint) <= hitDistance;
  }

  @override
  LineEntity copyWith({
    Offset? start,
    Offset? end,
    String? layer,
    Color? color,
    double? lineWidth,
    bool? isSelected,
  }) {
    return LineEntity(
      start: start ?? this.start,
      end: end ?? this.end,
      layer: layer ?? this.layer,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'line',
      'layer': layer,
      'color': color.value,
      'lineWidth': lineWidth,
      'start': {'x': start.dx, 'y': start.dy},
      'end': {'x': end.dx, 'y': end.dy},
      'isSelected': isSelected,
    };
  }

  factory LineEntity.fromJson(Map<String, dynamic> json) {
    return LineEntity(
      id: json['id'] as String,
      layer: json['layer'] as String,
      color: Color(json['color'] as int),
      lineWidth: json['lineWidth'] as double,
      start: Offset(
        json['start']['x'] as double,
        json['start']['y'] as double,
      ),
      end: Offset(
        json['end']['x'] as double,
        json['end']['y'] as double,
      ),
      isSelected: json['isSelected'] as bool,
    );
  }

  @override
  List<Offset> getCharacteristicPoints() {
    return [
      start,
      end,
      Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2)
    ];
  }

  /// Extends this line entity to meet one of the boundary entities.
  ///
  /// - `boundaryEntities`: A list of entities to extend to. Currently, only the first `LineEntity` in the list is considered.
  /// - `clickPointOnLine`: The user's click point on this line, indicating which part/end to extend.
  ///
  /// Returns a new `LineEntity` representing the extended portion, or `null` if the extension
  /// is not valid, results in no change, or the boundary is not a LineEntity or ArcEntity (for now).
  @override
  LineEntity? extend(List<Entity> boundaryEntities, Offset clickPointOnLine) {
    if (boundaryEntities.isEmpty) {
      debugPrint('[LineEntity.extend] No boundary entities provided.');
      return null;
    }

    final primaryBoundary = boundaryEntities.first;

    // Determine which end of this line to extend based on clickPointOnLine
    final distToStart = (clickPointOnLine - start).distanceSquared;
    final distToEnd = (clickPointOnLine - end).distanceSquared;

    Offset pointToExtend;
    Offset otherEndPoint;
    bool extendingStartPoint;

    if (distToStart < distToEnd) {
      pointToExtend = start;
      otherEndPoint = end;
      extendingStartPoint = true;
    } else {
      pointToExtend = end;
      otherEndPoint = start;
      extendingStartPoint = false;
    }

    if (primaryBoundary is LineEntity) {
      final boundaryLine = primaryBoundary;
      debugPrint('[LineEntity.extend-Line] Calculating intersection for line (${this.start}, ${this.end}) and boundary line (${boundaryLine.start}, ${boundaryLine.end})');

      final intersection = GeometryUtils.lineLineIntersection(
          this.start, this.end, boundaryLine.start, boundaryLine.end);

      if (intersection == null) {
        debugPrint('[LineEntity.extend-Line] Lines are parallel or no intersection found.');
        return null;
      }

      // Check if the intersection point represents an actual extension
      // Vector from the pointToExtend to the intersection
      final vecToIntersection = intersection - pointToExtend;
      // Vector from the pointToExtend to the otherEndPoint of this line
      final vecAlongLine = otherEndPoint - pointToExtend;

      // For extension, intersection must be "beyond" pointToExtend along the line's direction.
      // Dot product of (intersection - pointToExtend) and (otherEndPoint - pointToExtend) should be negative.
      if (vecToIntersection.dx * vecAlongLine.dx + vecToIntersection.dy * vecAlongLine.dy > -1e-9) { 
          debugPrint('[LineEntity.extend-Line] Intersection $intersection does not extend the line segment from $pointToExtend towards boundary.');
          return null;
      }
      
      if (vecToIntersection.distanceSquared < 1e-8) {
        debugPrint('[LineEntity.extend-Line] Extension is too small.');
        return null;
      }

      debugPrint('[LineEntity.extend-Line] Intersection point: $intersection. Extending $pointToExtend');
      if (extendingStartPoint) {
        return copyWith(start: intersection);
      } else {
        return copyWith(end: intersection);
      }
    } else if (primaryBoundary is ArcEntity) {
      final boundaryArc = primaryBoundary;
      debugPrint('[LineEntity.extend-Arc] Extending line to arc ${boundaryArc.id}');

      List<Offset> potentialIntersections = [];
      final d = this.end - this.start; // Direction vector of this line

      if (d.distanceSquared < 1e-12) { // Line is effectively a point
          debugPrint('[LineEntity.extend-Arc] Line is a point, cannot extend.');
          return null;
      }

      final f = this.start - boundaryArc.center;
      final a = d.dx * d.dx + d.dy * d.dy; // d.dot(d)
      final b_val = 2 * (f.dx * d.dx + f.dy * d.dy); // 2 * f.dot(d) - Renamed to b_val to avoid conflict with BuildContext b
      final cVal = (f.dx * f.dx + f.dy * f.dy) - boundaryArc.radius * boundaryArc.radius; // f.dot(f) - r^2

      var discriminant = b_val * b_val - 4 * a * cVal;

      if (discriminant >= -1e-9) { // Allow for small negative due to precision
        discriminant = math.max(0, discriminant); // Clamp to 0 if slightly negative
        final sqrtDiscriminant = math.sqrt(discriminant);
        
        // Calculate t values for P(t) = this.start + t * d
        final t1 = (-b_val - sqrtDiscriminant) / (2 * a);
        potentialIntersections.add(this.start + d * t1);

        if (discriminant.abs() > 1e-9) { // If t1 and t2 are distinct
          final t2 = (-b_val + sqrtDiscriminant) / (2 * a);
          potentialIntersections.add(this.start + d * t2);
        }
      }
      
      if (potentialIntersections.isEmpty) {
        debugPrint('[LineEntity.extend-Arc] No geometric intersection of infinite line with boundary arc circle.');
        return null;
      }

      List<Offset> validExtensionPoints = [];
      for (final pIntersect in potentialIntersections) {
        // 1. Check if intersection is on the arc path
        if (!GeometryUtils.isPointOnArc(pIntersect, boundaryArc.center, boundaryArc.radius,
                                        boundaryArc.startAngle, boundaryArc.endAngle)) {
          debugPrint('[LineEntity.extend-Arc] Intersection $pIntersect is not on arc path.');
          continue;
        }

        // 2. Check if it's a valid extension for the line segment
        final vecToIntersection = pIntersect - pointToExtend;
        final vecAlongLine = otherEndPoint - pointToExtend;

        if (vecToIntersection.dx * vecAlongLine.dx + vecToIntersection.dy * vecAlongLine.dy > -1e-9) {
            debugPrint('[LineEntity.extend-Arc] Intersection $pIntersect does not extend line segment from $pointToExtend.');
            continue;
        }
        
        if (vecToIntersection.distanceSquared < 1e-8) {
          debugPrint('[LineEntity.extend-Arc] Extension to $pIntersect is too small.');
          continue;
        }
        
        validExtensionPoints.add(pIntersect);
      }

      if (validExtensionPoints.isEmpty) {
        debugPrint('[LineEntity.extend-Arc] No valid extension point found on arc path that extends the line.');
        return null;
      }

      Offset bestExtensionPoint = validExtensionPoints.first;
      double minDistanceSq = (bestExtensionPoint - pointToExtend).distanceSquared;

      for (int i = 1; i < validExtensionPoints.length; i++) {
        final distSq = (validExtensionPoints[i] - pointToExtend).distanceSquared;
        if (distSq < minDistanceSq) {
          minDistanceSq = distSq;
          bestExtensionPoint = validExtensionPoints[i];
        }
      }
      
      debugPrint('[LineEntity.extend-Arc] Best extension point: $bestExtensionPoint. Extending $pointToExtend');
      if (extendingStartPoint) {
        return copyWith(start: bestExtensionPoint);
      } else {
        return copyWith(end: bestExtensionPoint);
      }

    } else {
      debugPrint('[LineEntity.extend] Boundary entity type ${primaryBoundary.runtimeType} not supported for line extension.');
      return null;
    }
  }

  /// Trims this line entity against a cutting entity.
  ///
  /// - `cuttingEntity`: The entity used as the cutting boundary (parameter for future use, e.g. complex curves).
  /// - `intersectionPoint`: The specific point of intersection to trim at.
  /// - `clickPoint`: The user's click point on this line, indicating which part to keep.
  ///
  /// Returns a new `LineEntity` representing the trimmed portion, or `null` if the trim
  /// operation is not valid, results in no change, or creates a zero-length line.
  LineEntity? trim(Entity cuttingEntity, Offset intersectionPoint, Offset clickPoint) {
    // 1. Validate intersectionPoint is effectively on the line segment
    // A point P is on segment AB if dist(A,P) + dist(P,B) is very close to dist(A,B)
    double distAP = (intersectionPoint - start).distance;
    double distPB = (end - intersectionPoint).distance;
    double distAB = (end - start).distance;

    // Using .abs() for floating point comparison
    if ((distAP + distPB - distAB).abs() > 1e-6) {
      // print('[LineEntity.trim] Intersection point $intersectionPoint is not on the line segment $start-$end.');
      return null; 
    }

    // 2. Determine the new start and end points of the trimmed line
    // The user clicks on the portion of the line they want to keep.
    // This portion is bounded by one of the original endpoints and the intersectionPoint.
    
    Offset newStartPt, newEndPt;

    // If the clickPoint is closer to 'start' than 'end' (of the original line),
    // it implies the segment connected to 'start' is part of what's kept.
    final distClickToOriginalStart = (clickPoint - start).distanceSquared;
    final distClickToOriginalEnd = (clickPoint - end).distanceSquared;

    if (distClickToOriginalStart < distClickToOriginalEnd) {
      // User wants to keep the part of the line connected to 'start'.
      // So, the new line is from 'start' to 'intersectionPoint'.
      newStartPt = start;
      newEndPt = intersectionPoint;
    } else {
      // User wants to keep the part of the line connected to 'end'.
      // So, the new line is from 'intersectionPoint' to 'end'.
      newStartPt = intersectionPoint;
      newEndPt = end;
    }

    // 3. Validate the new line segment
    // Check for zero-length
    if ((newStartPt - newEndPt).distanceSquared < 1e-10) {
      // print('[LineEntity.trim] Trim results in a zero-length line.');
      return null;
    }

    // Check if the line is unchanged.
    // This can happen if intersectionPoint is one of the original endpoints,
    // and the click implies keeping the entire original line.
    // e.g., line S-E, intersection at S. Click closer to E. New line is S-E.
    if (newStartPt == start && newEndPt == end) {
      // print('[LineEntity.trim] Trim results in no change to the line.');
      return null;
    }

    return copyWith(start: newStartPt, end: newEndPt);
  }
}

/// Represents a circle entity
class CircleEntity extends Entity {
  CircleEntity({
    required this.center,
    required this.radius,
    required super.layer,
    required super.color,
    required super.lineWidth,
    required super.isSelected,
    super.id,
  });

  final Offset center;
  final double radius;

  @override
  void draw(Canvas canvas, Matrix4 transform) {
    final paint = Paint()
      ..color = isSelected ? Colors.blue : color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    final centerPoint = GeometryUtils.transformPoint(center, transform);

    // Calculate the transformed radius
    final radiusPoint =
        GeometryUtils.transformPoint(Offset(center.dx + radius, center.dy), transform);
    final transformedRadius = (radiusPoint - centerPoint).distance;

    canvas.drawCircle(centerPoint, transformedRadius, paint);

    if (isSelected) {
      // Draw center point and radius point
      _drawSelectionHandles(canvas, [
        centerPoint,
        Offset(centerPoint.dx + transformedRadius, centerPoint.dy),
      ]);
    }
  }

  @override
  bool hitTest(Offset point, Matrix4 transform, double hitDistance) {
    final centerPoint = GeometryUtils.transformPoint(center, transform);

    // Calculate the transformed radius
    final radiusPoint =
        GeometryUtils.transformPoint(Offset(center.dx + radius, center.dy), transform);
    final transformedRadius = (radiusPoint - centerPoint).distance;

    final distance = (point - centerPoint).distance;
    return (distance - transformedRadius).abs() <= hitDistance;
  }

  @override
  CircleEntity copyWith({
    Offset? center,
    double? radius,
    String? layer,
    Color? color,
    double? lineWidth,
    bool? isSelected,
  }) {
    return CircleEntity(
      center: center ?? this.center,
      radius: radius ?? this.radius,
      layer: layer ?? this.layer,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'circle',
      'layer': layer,
      'color': color.value,
      'lineWidth': lineWidth,
      'center': {'x': center.dx, 'y': center.dy},
      'radius': radius,
      'isSelected': isSelected,
    };
  }

  factory CircleEntity.fromJson(Map<String, dynamic> json) {
    return CircleEntity(
      id: json['id'] as String,
      layer: json['layer'] as String,
      color: Color(json['color'] as int),
      lineWidth: json['lineWidth'] as double,
      center: Offset(
        json['center']['x'] as double,
        json['center']['y'] as double,
      ),
      radius: json['radius'] as double,
      isSelected: json['isSelected'] as bool,
    );
  }

  @override
  List<Offset> getCharacteristicPoints() {
    return [
      center,
      Offset(center.dx + radius, center.dy), // Point on right
      Offset(center.dx - radius, center.dy), // Point on left
      Offset(center.dx, center.dy + radius), // Point on bottom
      Offset(center.dx, center.dy - radius), // Point on top
    ];
  }

  /// Trims this circle entity against a cutting entity (typically a line).
  ///
  /// - `cuttingEntity`: The entity used as the cutting boundary.
  /// - `intersectionPoints`: A list of intersection points between this circle and the cutting entity.
  /// - `clickPoint`: The user's click point on this circle, indicating which arc segment to keep.
  ///
  /// Returns a list containing a new `ArcEntity` representing the trimmed portion,
  /// or an empty list if the trim operation is not valid (e.g., not enough intersection points).
  List<Entity> trim(Entity cuttingEntity, List<Offset> intersectionPoints, Offset clickPoint) {
    if (intersectionPoints.length < 2) {
      // print('[CircleEntity.trim] Not enough intersection points to define an arc.');
      return []; // Cannot form an arc with less than 2 points
    }

    // For simplicity, we'll use the first two intersection points.
    // More complex scenarios might involve selecting which two if there are more.
    Offset p1 = intersectionPoints[0];
    Offset p2 = intersectionPoints[1];

    // Calculate angles of intersection points and click point relative to the circle's center
    double angleP1 = GeometryUtils.angleBetweenPoints(center, p1);
    double angleP2 = GeometryUtils.angleBetweenPoints(center, p2);
    double angleClick = GeometryUtils.angleBetweenPoints(center, clickPoint);

    // Normalize angles to be [0, 2*pi)
    angleP1 = (angleP1 + 2 * math.pi) % (2 * math.pi);
    angleP2 = (angleP2 + 2 * math.pi) % (2 * math.pi);
    angleClick = (angleClick + 2 * math.pi) % (2 * math.pi);

    // Determine the arc segment to keep.
    // The arc should sweep from a startAngle to an endAngle counter-clockwise.
    // The clickPoint's angle should fall within this sweep.

    double startAngle, endAngle;

    // Consider the two possible arcs: (angleP1 to angleP2) and (angleP2 to angleP1)
    // Check if clickAngle is between angleP1 and angleP2 (counter-clockwise)
    bool clickBetweenP1P2 = false;
    if (angleP1 < angleP2) {
      clickBetweenP1P2 = angleClick > angleP1 && angleClick < angleP2;
    } else { // angleP1 > angleP2, meaning the arc crosses the 0-angle line
      clickBetweenP1P2 = angleClick > angleP1 || angleClick < angleP2;
    }

    if (clickBetweenP1P2) {
      startAngle = angleP1;
      endAngle = angleP2;
    } else {
      startAngle = angleP2;
      endAngle = angleP1;
    }
    
    // Check if the resulting arc has a valid (non-zero) sweep.
    double sweepAngle = endAngle - startAngle;
    if (sweepAngle < 0) sweepAngle += 2 * math.pi; // Normalize sweep to be positive
    if (sweepAngle.abs() < 1e-6 || (2 * math.pi - sweepAngle).abs() < 1e-6) {
        // print('[CircleEntity.trim] Trim results in a zero-length or full-circle arc.');
        return []; // Effectively no change or invalid arc
    }

    final newArc = ArcEntity(
      id: const Uuid().v4(),
      center: center,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
      layer: layer,
      color: color,
      lineWidth: lineWidth,
      isSelected: false,
    );

    return [newArc];
  }
}

/// Represents a rectangle entity
class RectangleEntity extends Entity {
  RectangleEntity({
    required this.topLeft,
    required this.bottomRight,
    required super.layer,
    required super.color,
    required super.lineWidth,
    required super.isSelected,
    super.id,
  });

  final Offset topLeft;
  final Offset bottomRight;

  @override
  void draw(Canvas canvas, Matrix4 transform) {
    final paint = Paint()
      ..color = isSelected ? Colors.blue : color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Transform the corner points
    final transformedTopLeft = GeometryUtils.transformPoint(topLeft, transform);
    final transformedBottomRight = GeometryUtils.transformPoint(bottomRight, transform);

    // Create the rectangle
    final rect = Rect.fromPoints(transformedTopLeft, transformedBottomRight);

    // Draw the rectangle
    canvas.drawRect(rect, paint);

    // Draw selection handles if selected
    if (isSelected) {
      _drawSelectionHandles(canvas, [
        transformedTopLeft,
        Offset(transformedBottomRight.dx, transformedTopLeft.dy),
        transformedBottomRight,
        Offset(transformedTopLeft.dx, transformedBottomRight.dy),
      ]);
    }
  }

  @override
  bool hitTest(Offset point, Matrix4 transform, double hitDistance) {
    final transformedTopLeft = GeometryUtils.transformPoint(topLeft, transform);
    final transformedBottomRight = GeometryUtils.transformPoint(bottomRight, transform);

    // Create the four lines of the rectangle
    final topLeftPoint = transformedTopLeft;
    final topRightPoint =
        Offset(transformedBottomRight.dx, transformedTopLeft.dy);
    final bottomLeftPoint =
        Offset(transformedTopLeft.dx, transformedBottomRight.dy);
    final bottomRightPoint = transformedBottomRight;

    // Check distance to each edge
    return _distanceToLineSegment(point, topLeftPoint, topRightPoint) <=
            hitDistance ||
        _distanceToLineSegment(point, topRightPoint, bottomRightPoint) <=
            hitDistance ||
        _distanceToLineSegment(point, bottomRightPoint, bottomLeftPoint) <=
            hitDistance ||
        _distanceToLineSegment(point, bottomLeftPoint, topLeftPoint) <=
            hitDistance;
  }

  @override
  RectangleEntity copyWith({
    Offset? topLeft,
    Offset? bottomRight,
    String? layer,
    Color? color,
    double? lineWidth,
    bool? isSelected,
  }) {
    return RectangleEntity(
      topLeft: topLeft ?? this.topLeft,
      bottomRight: bottomRight ?? this.bottomRight,
      layer: layer ?? this.layer,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'rectangle',
      'layer': layer,
      'color': color.value,
      'lineWidth': lineWidth,
      'topLeft': {'x': topLeft.dx, 'y': topLeft.dy},
      'bottomRight': {'x': bottomRight.dx, 'y': bottomRight.dy},
      'isSelected': isSelected,
    };
  }

  factory RectangleEntity.fromJson(Map<String, dynamic> json) {
    return RectangleEntity(
      id: json['id'] as String,
      layer: json['layer'] as String,
      color: Color(json['color'] as int),
      lineWidth: json['lineWidth'] as double,
      topLeft: Offset(
        json['topLeft']['x'] as double,
        json['topLeft']['y'] as double,
      ),
      bottomRight: Offset(
        json['bottomRight']['x'] as double,
        json['bottomRight']['y'] as double,
      ),
      isSelected: json['isSelected'] as bool,
    );
  }

  @override
  List<Offset> getCharacteristicPoints() {
    return [
      topLeft,
      Offset(bottomRight.dx, topLeft.dy),
      bottomRight,
      Offset(topLeft.dx, bottomRight.dy),
      Offset(
          (topLeft.dx + bottomRight.dx) / 2, (topLeft.dy + bottomRight.dy) / 2),
    ];
  }
}

/// Represents an arc entity
class ArcEntity extends Entity {
  ArcEntity({
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
    required super.layer,
    required super.color,
    required super.lineWidth,
    required super.isSelected,
    super.id,
  });

  final Offset center;
  final double radius;
  final double startAngle; // in radians
  final double endAngle; // in radians

  @override
  void draw(Canvas canvas, Matrix4 transform) {
    final paintStyle = Paint() // Renamed variable to avoid confusion
      ..color = isSelected ? Colors.blueAccent : color // Slightly different blue for selection
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;

    final transformedCenter = GeometryUtils.transformPoint(center, transform);
    final transformedRadius = transform.getMaxScaleOnAxis() * radius;

    final rect = Rect.fromCircle(
      center: transformedCenter,
      radius: transformedRadius,
    );

    // --- Calculate angles for canvas.drawArc (which expects CW angles) ---
    // Flutter's drawArc startAngle is CW from positive x-axis.
    // Our stored startAngle (this.startAngle) is CCW. So, negate it.
    double cwDrawStartAngle = -this.startAngle;

    // Calculate effective CCW sweep using logic similar to getCharacteristicPoints
    double s_ccw_norm = this.startAngle;
    while (s_ccw_norm < 0) s_ccw_norm += 2 * math.pi;
    while (s_ccw_norm >= 2 * math.pi) s_ccw_norm -= 2 * math.pi;

    double e_ccw_norm = this.endAngle;
    while (e_ccw_norm < 0) e_ccw_norm += 2 * math.pi;
    while (e_ccw_norm >= 2 * math.pi) e_ccw_norm -= 2 * math.pi;
    
    double effectiveCcwSweep;
    if (this.radius < 0.00001) { // Point-like arc
      effectiveCcwSweep = 0;
    } else if ((s_ccw_norm - e_ccw_norm).abs() < 0.00001) { // Normalized start and end angles are the same
      effectiveCcwSweep = 2 * math.pi; // Full circle
    } else {
      double temp_e_for_sweep = e_ccw_norm;
      if (temp_e_for_sweep < s_ccw_norm) { // Ensure e_norm is "after" s_norm for CCW sweep calculation
        temp_e_for_sweep += 2 * math.pi;
      }
      effectiveCcwSweep = temp_e_for_sweep - s_ccw_norm;

      // Final check: if sweep is effectively 0 or 2pi (e.g., from original 0 and 2pi),
      // and it's a non-point arc, it should be a full 2pi sweep.
      if ((effectiveCcwSweep.abs() < 0.00001 || (effectiveCcwSweep - 2 * math.pi).abs() < 0.00001) && this.radius > 0.00001) {
          effectiveCcwSweep = 2 * math.pi;
      }
    }
    
    // Sweep angle for drawArc is CW, so negate the CCW sweep.
    double cwDrawSweepAngle = -effectiveCcwSweep;
    // --- End angle calculation ---

    if (effectiveCcwSweep.abs() > 0.00001 || this.radius < 0.00001) { // Draw if there's a sweep, or if it's a point (drawArc handles 0 sweep for points ok)
      canvas.drawArc(rect, cwDrawStartAngle, cwDrawSweepAngle, false, paintStyle);
    }

    if (isSelected) {
      final characteristicPointsModelSpace = getCharacteristicPoints();
      final transformedCharacteristicPoints = characteristicPointsModelSpace
          .map((p) => GeometryUtils.transformPoint(p, transform))
          .toList();
      // _drawSelectionHandles is assumed to be defined in a base class (e.g., Entity)
      // or as a utility function that takes already transformed points.
      _drawSelectionHandles(canvas, transformedCharacteristicPoints);
    }
  }

  @override
  bool hitTest(Offset point, Matrix4 transform, double hitDistance) {
    // Transform the test point from world to local coordinates of the arc
    final transformedPoint = GeometryUtils.inverseTransformPoint(point, transform);

    // 1. Check if the point is within the radial tolerance of the arc's circumference
    final double distanceToCenter = (transformedPoint - center).distance;
    if ((distanceToCenter - radius).abs() > hitDistance) {
      // Point is too far from (or too far inside, if hitDistance is large) the circle's path
      return false;
    }

    // If the radius is very small (arc is effectively a point),
    // the distance check above is sufficient.
    if (radius < 0.00001) { // Use a small epsilon for "point-like" radius
      return true; // Already passed distance check to the center point
    }

    // 2. Calculate the angle of the test point relative to the arc's center
    // math.atan2 returns an angle in the range [-pi, pi]
    double pointAngleRad = math.atan2(
      transformedPoint.dy - center.dy,
      transformedPoint.dx - center.dx,
    );

    // Normalize the point's angle to be in the range [0, 2*pi)
    while (pointAngleRad < 0) pointAngleRad += 2 * math.pi;
    while (pointAngleRad >= 2 * math.pi) pointAngleRad -= 2 * math.pi; // Should not happen if atan2 is [-pi,pi] and then one += 2pi

    // 3. Determine the arc's effective CCW sweep angle.
    // ArcEntity's startAngle and endAngle are the raw properties.
    double arcStartAngleRad = this.startAngle;
    double arcEndAngleRad = this.endAngle;

    double effectiveSweepRad;
    // Check if startAngle and endAngle are effectively the same (implies a full circle if not a zero-radius point)
    if ((arcStartAngleRad - arcEndAngleRad).abs() < 0.00001) {
      effectiveSweepRad = 2 * math.pi; // Full circle
    } else {
      effectiveSweepRad = arcEndAngleRad - arcStartAngleRad;
      // Normalize sweep to be positive CCW in (0, 2*pi]
      while (effectiveSweepRad <= 0) effectiveSweepRad += 2 * math.pi; // Ensure positive sweep
      while (effectiveSweepRad > 2 * math.pi) effectiveSweepRad -= 2 * math.pi; // Modulo 2*pi
      // If after normalization, sweep is effectively 0 (e.g. start=0, end=2*pi), treat as full circle.
      if (effectiveSweepRad < 0.00001) effectiveSweepRad = 2 * math.pi;
    }
    // Now, effectiveSweepRad is the CCW angular length of the arc, in (0, 2*pi].

    // 4. Normalize the arc's start angle to [0, 2*pi)
    double normalizedArcStartAngleRad = arcStartAngleRad;
    while (normalizedArcStartAngleRad < 0) normalizedArcStartAngleRad += 2 * math.pi;
    while (normalizedArcStartAngleRad >= 2 * math.pi) normalizedArcStartAngleRad -= 2 * math.pi;

    // 5. Check if the point's angle lies within the arc's sweep
    // Calculate the point's angle relative to the (normalized) start of the arc, in CCW direction.
    double relativePointAngleRad = pointAngleRad - normalizedArcStartAngleRad;
    while (relativePointAngleRad < 0) relativePointAngleRad += 2 * math.pi;

    // The point is on the arc if its relative angle is less than or equal to the sweep.
    // Add a small epsilon for floating point comparisons at the end of the sweep.
    return relativePointAngleRad <= (effectiveSweepRad + 0.00001);
  }

  @override
  ArcEntity copyWith({
    Offset? center,
    double? radius,
    double? startAngle,
    double? endAngle,
    String? layer,
    Color? color,
    double? lineWidth,
    bool? isSelected,
  }) {
    return ArcEntity(
      center: center ?? this.center,
      radius: radius ?? this.radius,
      startAngle: startAngle ?? this.startAngle,
      endAngle: endAngle ?? this.endAngle,
      layer: layer ?? this.layer,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'arc',
      'id': id,
      'layer': layer,
      'color': color.value,
      'lineWidth': lineWidth,
      'isSelected': isSelected,
      'center': {'x': center.dx, 'y': center.dy},
      'radius': radius,
      'startAngle': startAngle,
      'endAngle': endAngle,
    };
  }

  factory ArcEntity.fromJson(Map<String, dynamic> json) {
    return ArcEntity(
      id: json['id'],
      layer: json['layer'],
      color: Color(json['color']),
      lineWidth: json['lineWidth'].toDouble(),
      isSelected: json['isSelected'],
      center: Offset(
        json['center']['x'].toDouble(),
        json['center']['y'].toDouble(),
      ),
      radius: json['radius'].toDouble(),
      startAngle: json['startAngle'].toDouble(),
      endAngle: json['endAngle'].toDouble(),
    );
  }

  @override
  List<Offset> getCharacteristicPoints() {
    // Return center, start point, end point, and middle point of arc
    final startPoint = Offset(
      center.dx + radius * math.cos(startAngle),
      center.dy + radius * math.sin(startAngle),
    );

    final endPoint = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );

    // Refined calculation for middleAngle
    double s = this.startAngle;
    double e = this.endAngle;

    // Normalize s to [0, 2*pi)
    while (s < 0) s += 2 * math.pi;
    while (s >= 2 * math.pi) s -= 2 * math.pi;

    // Normalize e to [0, 2*pi)
    while (e < 0) e += 2 * math.pi;
    while (e >= 2 * math.pi) e -= 2 * math.pi;
  
    double sweep;
    // If angles are effectively the same and it's a non-point arc, it's a full circle.
    if ((s - e).abs() < 0.00001 && radius > 0.00001) {
      sweep = 2 * math.pi;
    } else if (radius < 0.00001) {
      sweep = 0; // Point arc, midpoint is same as start/end
    } else {
      // Adjust e to ensure CCW sweep from s
      // If e is 'behind' s (e.g., s=315 deg, e=45 deg), add 2*pi to e
      // so that sweep is calculated in the CCW direction along the shorter arc path.
      if (e < s) { 
          e += 2 * math.pi;
      }
      sweep = e - s;
      
      // If sweep is still effectively zero (e.g. s=0, e=0 was not caught by full circle check due to precision)
      // or if it became 2*pi (e.g. s=0, e=0 initially, then e becomes 2pi), treat as full circle for non-point arc.
      if ((sweep.abs() < 0.00001 || (sweep - 2 * math.pi).abs() < 0.00001) && radius > 0.00001) {
          sweep = 2 * math.pi;
      }
    }

    // The middleAngle is the normalized start angle (s) plus half the sweep.
    final middleAngle = s + sweep / 2.0;
  
    final middlePoint = Offset(
      center.dx + radius * math.cos(middleAngle),
      center.dy + radius * math.sin(middleAngle),
    );

    return [center, startPoint, middlePoint, endPoint];
  }

  @override
  ArcEntity? extend(List<Entity> boundaryEntities, Offset clickPointOnEntity) {
    const double _epsilon = 0.00001;
    if (radius < _epsilon) return null; // Cannot extend a point-like arc

    if (boundaryEntities.isEmpty) return null;
    // For now, process the first compatible boundary, similar to LineEntity.extend
    // A more robust solution might iterate and find the 'best' extension among all boundaries.
    Entity? primaryBoundary;
    for (final boundary in boundaryEntities) {
      if (boundary is LineEntity || boundary is ArcEntity) {
        primaryBoundary = boundary;
        break;
      }
    }
    if (primaryBoundary == null) return null; // No compatible boundary found

    final arcStartPoint = Offset(
      center.dx + radius * math.cos(startAngle),
      center.dy + radius * math.sin(startAngle),
    );
    final arcEndPoint = Offset(
      center.dx + radius * math.cos(endAngle),
      center.dy + radius * math.sin(endAngle),
    );

    final distToStart = (clickPointOnEntity - arcStartPoint).distance;
    final distToEnd = (clickPointOnEntity - arcEndPoint).distance;

    bool extendStart = distToStart < distToEnd;
    
    List<double> candidateNewAngles = [];

    if (primaryBoundary is LineEntity) {
      final boundaryLine = primaryBoundary;
      final circleIntersections = GeometryUtils.lineCircleIntersection(
        boundaryLine.start,
        boundaryLine.end,
        center,
        radius
      );
      for (final p in circleIntersections) {
        final newAngle = math.atan2(p.dy - center.dy, p.dx - center.dx);
        candidateNewAngles.add(newAngle);
      }
    } else if (primaryBoundary is ArcEntity) {
      final boundaryArc = primaryBoundary;
      final distCenters = (center - boundaryArc.center).distance;

      if (distCenters < _epsilon && (radius - boundaryArc.radius).abs() < _epsilon) {
        // Case 1: Co-circular arcs (same center, same radius)
        // The "intersections" are conceptually the endpoints of the boundary arc.
        // Their angles on the common circle are direct candidates for the extending arc.
        candidateNewAngles.add(GeometryUtils.normalizeAngle(boundaryArc.startAngle));
        candidateNewAngles.add(GeometryUtils.normalizeAngle(boundaryArc.endAngle));
      } else if (distCenters > radius + boundaryArc.radius + _epsilon ||
                 distCenters < (radius - boundaryArc.radius).abs() - _epsilon) {
        // Case 2: Circles are too far apart or one is contained within the other without touching.
        // No intersection points, so candidateNewAngles remains empty.
      } else {
        // Case 3: Standard intersection of two distinct (possibly different radii or non-concentric) circles.
        final List<Offset> intersectionPoints = GeometryUtils.circleCircleIntersection(
          center,
          radius,
          boundaryArc.center,
          boundaryArc.radius,
        );

        for (final p in intersectionPoints) {
          if (GeometryUtils.isPointOnArc(p, boundaryArc.center, boundaryArc.radius, boundaryArc.startAngle, boundaryArc.endAngle, epsilon: _epsilon)) {
            final newAngle = math.atan2(p.dy - center.dy, p.dx - center.dx);
            candidateNewAngles.add(newAngle);
          }
        }
      }
    } else if (primaryBoundary is CircleEntity) { // Handles CircleEntity that is not an ArcEntity
      final boundaryCircle = primaryBoundary;
      final intersectionPoints = GeometryUtils.circleCircleIntersection(
        center,
        radius,
        boundaryCircle.center,
        boundaryCircle.radius,
      );
      for (final p in intersectionPoints) {
        // For a full circle boundary, all intersection points are valid candidates on it
        final newAngle = math.atan2(p.dy - center.dy, p.dx - center.dx);
        candidateNewAngles.add(newAngle);
      }
    } else {
      // This case should not be reached if primaryBoundary was set correctly
      return null; 
    }

    if (candidateNewAngles.isEmpty) return null;

    double bestNewAngle = -1;
    double minAngleChange = double.infinity; // Reverted to minAngleChange

    final currentAngleToExtend = extendStart ? startAngle : endAngle;
    final fixedAngle = extendStart ? endAngle : startAngle;
    final nCurrentAngleToExtend = GeometryUtils.normalizeAngle(currentAngleToExtend);

    for (final newAngleCandidate in candidateNewAngles) {
      // Validate the extension: new sweep must be valid and generally larger
      double newSweep;
      if (extendStart) {
        newSweep = GeometryUtils.calculateNormalizedCcwSweep(newAngleCandidate, fixedAngle, epsilon: _epsilon);
      } else {
        newSweep = GeometryUtils.calculateNormalizedCcwSweep(fixedAngle, newAngleCandidate, epsilon: _epsilon);
      }
      // if (newSweep >= 2 * math.pi - _epsilon) newSweep = 2 * math.pi; // Treat as full circle (handled by calculateNormalizedCcwSweep)

      // Basic validation: new angle should be different, new sweep should not be zero (unless it's becoming a point)
      if ((newAngleCandidate - currentAngleToExtend).abs() < _epsilon) continue; // No change
      if (newSweep < _epsilon && radius > _epsilon) continue; // Results in a zero-sweep arc (not a point)
      
      // If we've passed the initial checks (no change, not zero sweep for non-point arc),
      // the candidate angle leads to a geometrically possible new arc configuration.
      // The previous condition `newSweep > oldSweep - _epsilon` was too restrictive
      // and prevented arcs from shortening to meet a boundary.
      // We now consider any such candidate valid at this stage, and let the
      // `minExtensionSweep` logic choose the most direct extension.
      bool isValidExtension = true; 

      if (isValidExtension) {
        double nNewAngleCandidate = GeometryUtils.normalizeAngle(newAngleCandidate);
        double angleDiff = (nNewAngleCandidate - nCurrentAngleToExtend).abs();
        double angularChange = math.min(angleDiff, 2 * math.pi - angleDiff); // Shortest angle

        // The (newAngleCandidate - currentAngleToExtend).abs() < _epsilon check earlier
        // handles cases where the candidate is identical to the current endpoint.
        // So, angularChange here should be meaningfully positive if an extension is to occur.
        if (angularChange < minAngleChange) {
          minAngleChange = angularChange;
          bestNewAngle = newAngleCandidate;
        }
      }
    }

    if (minAngleChange == double.infinity) return null; // No valid extension found

    if (extendStart) {
      // The check `if (newSweep < _epsilon && radius > _epsilon) continue;` in the loop
      // should prevent selection of an angle that results in an invalid zero-sweep arc
      // for a non-point-radius entity. This final check is likely redundant.
      // final finalSweep = GeometryUtils.calculateNormalizedCcwSweep(bestNewAngle, fixedAngle, epsilon: _epsilon);
      // if (finalSweep < _epsilon && radius > _epsilon && (fixedAngle - bestNewAngle).abs() > _epsilon) return null;
      return copyWith(startAngle: bestNewAngle, isSelected: isSelected); // Preserve selection state
    } else {
      // The check `if (newSweep < _epsilon && radius > _epsilon) continue;` in the loop
      // should prevent selection of an angle that results in an invalid zero-sweep arc
      // for a non-point-radius entity. This final check is likely redundant.
      // final finalSweep = GeometryUtils.calculateNormalizedCcwSweep(fixedAngle, bestNewAngle, epsilon: _epsilon);
      // if (finalSweep < _epsilon && radius > _epsilon && (bestNewAngle - fixedAngle).abs() > _epsilon) return null;
      return copyWith(endAngle: bestNewAngle, isSelected: isSelected); // Preserve selection state
    }
  }
}

/// Represents a polyline entity (a series of connected line segments)
class PolylineEntity extends Entity {
  PolylineEntity({
    required this.points,
    required super.layer,
    required super.color,
    required super.lineWidth,
    required super.isSelected,
    this.showClosingIndicator = false,
    super.id,
  }) : assert(points.length >= 2, 'Polyline must have at least two points');

  final List<Offset> points;
  final bool showClosingIndicator;

  @override
  void draw(Canvas canvas, Matrix4 transform) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = isSelected ? Colors.blue : color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Draw all line segments
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = GeometryUtils.transformPoint(points[i], transform);
      final p2 = GeometryUtils.transformPoint(points[i + 1], transform);
      canvas.drawLine(p1, p2, paint);
    }
    
    // Draw point indicators (small circles at each vertex)
    final pointPaint = Paint()
      ..color = isSelected ? Colors.blue : color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < points.length; i++) {
      final p = GeometryUtils.transformPoint(points[i], transform);
      // Highlight the first point differently to indicate it's the starting point
      if (i == 0) {
        // Green circle for the first point
        canvas.drawCircle(p, 4, Paint()..color = Colors.green);
        // White inner circle for contrast
        canvas.drawCircle(p, 2, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(p, 3, pointPaint);
      }
    }
    
    // Show closing indicator when near the first point
    if (showClosingIndicator && points.length > 2) {
      final firstPoint = GeometryUtils.transformPoint(points.first, transform);
      final lastPoint = GeometryUtils.transformPoint(points.last, transform);
      
      // Draw a special indicator at the first point
      final closingPaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      // Draw a dashed line from last point to first point
      // Simple dash implementation directly in the method
      final double dashWidth = 5.0;
      final double dashSpace = 3.0;
      final double distance = (firstPoint - lastPoint).distance;
      
      double distanceTraveled = 0.0;
      bool drawDash = true;
      
      while (distanceTraveled < distance) {
        final double dashLength = drawDash ? dashWidth : dashSpace;
        final double ratio1 = distanceTraveled / distance;
        distanceTraveled += dashLength;
        final double ratio2 = math.min(distanceTraveled / distance, 1.0);
        
        if (drawDash) {
          final Offset dashStart = Offset.lerp(lastPoint, firstPoint, ratio1)!;
          final Offset dashEnd = Offset.lerp(lastPoint, firstPoint, ratio2)!;
          canvas.drawLine(dashStart, dashEnd, closingPaint);
        }
        
        drawDash = !drawDash;
      }
      
      // Draw a closing symbol (X) at the first point
      canvas.drawCircle(firstPoint, 6, closingPaint);
      canvas.drawLine(
        Offset(firstPoint.dx - 5, firstPoint.dy - 5),
        Offset(firstPoint.dx + 5, firstPoint.dy + 5),
        closingPaint..strokeWidth = 1.5,
      );
      canvas.drawLine(
        Offset(firstPoint.dx - 5, firstPoint.dy + 5),
        Offset(firstPoint.dx + 5, firstPoint.dy - 5),
        closingPaint,
      );
    }

    if (isSelected) {
      final transformedPoints = points.map((p) => GeometryUtils.transformPoint(p, transform)).toList();
      _drawSelectionHandles(canvas, transformedPoints);
    }
  }

  @override
  bool hitTest(Offset point, Matrix4 transform, double hitDistance) {
    if (points.length < 2) return false;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = GeometryUtils.transformPoint(points[i], transform);
      final p2 = GeometryUtils.transformPoint(points[i + 1], transform);
      if (_distanceToLineSegment(point, p1, p2) <= hitDistance) {
        return true;
      }
    }
    return false;
  }

  @override
  PolylineEntity copyWith({
    List<Offset>? points,
    String? layer,
    Color? color,
    double? lineWidth,
    bool? isSelected,
  }) {
    return PolylineEntity(
      points: points ?? this.points,
      layer: layer ?? this.layer,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'polyline',
      'layer': layer,
      'color': color.value,
      'lineWidth': lineWidth,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'isSelected': isSelected,
    };
  }

  factory PolylineEntity.fromJson(Map<String, dynamic> json) {
    return PolylineEntity(
      id: json['id'] as String,
      layer: json['layer'] as String,
      color: Color(json['color'] as int),
      lineWidth: json['lineWidth'] as double,
      points: (json['points'] as List<dynamic>)
          .map((p) => Offset(p['x'] as double, p['y'] as double))
          .toList(),
      isSelected: json['isSelected'] as bool,
    );
  }

  @override
  List<Offset> getCharacteristicPoints() {
    return List.from(points); // Return a copy
  }
}

/// Represents a spline entity (a smooth curve through control points)
class SplineEntity extends Entity {
  SplineEntity({
    required this.controlPoints,
    required super.layer,
    required super.color,
    required super.lineWidth,
    required super.isSelected,
    this.showControlPoints = false,
    this.splineType = SplineType.bezier,
    this.tension = 0.5, // Controls how "tight" the curve is for Catmull-Rom
    super.id,
  }) : assert(controlPoints.length >= 2, 'Spline must have at least two control points');

  final List<Offset> controlPoints;
  final bool showControlPoints;
  final SplineType splineType;
  final double tension; // Value between 0 and 1 for Catmull-Rom

  @override
  void draw(Canvas canvas, Matrix4 transform) {
    if (controlPoints.length < 2) return;

    final paint = Paint()
      ..color = isSelected ? Colors.blue : color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Create path for the spline
    final path = Path();
    final transformedPoints = controlPoints.map((p) => GeometryUtils.transformPoint(p, transform)).toList();
    
    // Draw the spline based on the selected type
    switch (splineType) {
      case SplineType.bezier:
        _drawBezierSpline(path, transformedPoints);
        break;
      case SplineType.catmullRom:
        _drawCatmullRomSpline(path, transformedPoints, tension);
        break;
    }
    
    // Draw the spline path
    canvas.drawPath(path, paint);
    
    // Draw control points if selected or if showControlPoints is true
    if (isSelected || showControlPoints) {
      // Draw control point connections with dashed lines if bezier
      if (splineType == SplineType.bezier && transformedPoints.length > 2) {
        final connectionPaint = Paint()
          ..color = Colors.grey.withOpacity(0.7)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        
        // Draw dashed lines connecting control points
        for (int i = 0; i < transformedPoints.length - 1; i++) {
          _drawDashedLine(canvas, transformedPoints[i], transformedPoints[i + 1], connectionPaint);
        }
      }
      
      // Draw the control points
      for (int i = 0; i < transformedPoints.length; i++) {
        final point = transformedPoints[i];
        
        // Different colors for different types of control points in Bezier
        Color pointColor;
        double pointSize;
        
        if (splineType == SplineType.bezier) {
          // For Bezier, alternate between anchor points and control handles
          if (i % 3 == 0) { // Anchor points
            pointColor = Colors.green;
            pointSize = 5.0;
          } else { // Control handles
            pointColor = Colors.red;
            pointSize = 4.0;
          }
        } else {
          // For Catmull-Rom, all points are the same
          pointColor = Colors.red;
          pointSize = 4.0;
        }
        
        final controlPointPaint = Paint()
          ..color = pointColor
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        
        final controlPointFillPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(point, pointSize, controlPointFillPaint);
        canvas.drawCircle(point, pointSize, controlPointPaint);
      }
    }
    
    // Draw selection handles if selected
    if (isSelected) {
      _drawSelectionHandles(canvas, transformedPoints);
    }
  }
  
  /// Draw a cubic Bezier spline through the control points
  void _drawBezierSpline(Path path, List<Offset> points) {
    if (points.length < 2) return;
    
    // Move to the first point
    path.moveTo(points[0].dx, points[0].dy);
    
    if (points.length == 2) {
      // Only two points - just draw a line
      path.lineTo(points[1].dx, points[1].dy);
      return;
    }
    
    // For cubic Bezier curves, we need sets of 4 points:
    // Starting point, two control points, and end point
    if (points.length == 3) {
      // With 3 points, use the middle point as a control point
      path.quadraticBezierTo(
        points[1].dx, points[1].dy,
        points[2].dx, points[2].dy
      );
      return;
    }
    
    // For 4 or more points, use cubic Bezier curves
    // In a proper Bezier spline, points should be arranged as:
    // Anchor, Control, Control, Anchor, Control, Control, Anchor, etc.
    
    // If we have exactly 4 points, use them as a single cubic Bezier
    if (points.length == 4) {
      path.cubicTo(
        points[1].dx, points[1].dy,
        points[2].dx, points[2].dy,
        points[3].dx, points[3].dy
      );
      return;
    }
    
    // For more points, create a smooth curve through multiple cubic Beziers
    // For a proper Bezier spline, we should have 3n+1 points where n is the number of segments
    // If we don't have the right number, we'll adapt
    
    int i = 0;
    while (i < points.length - 1) {
      if (i + 3 < points.length) {
        // We have enough points for a cubic Bezier
        path.cubicTo(
          points[i+1].dx, points[i+1].dy,
          points[i+2].dx, points[i+2].dy,
          points[i+3].dx, points[i+3].dy
        );
        i += 3; // Move to the next anchor point
      } else if (i + 2 < points.length) {
        // We have enough points for a quadratic Bezier
        path.quadraticBezierTo(
          points[i+1].dx, points[i+1].dy,
          points[i+2].dx, points[i+2].dy
        );
        i += 2;
      } else {
        // Just draw a line to the last point
        path.lineTo(points[i+1].dx, points[i+1].dy);
        i += 1;
      }
    }
  }
  
  /// Draw a Catmull-Rom spline through the given points
  void _drawCatmullRomSpline(Path path, List<Offset> points, double tension) {
    // A Catmull-Rom spline passes through all control points
    // and creates a smooth curve
    
    // Need at least 3 points for a spline
    if (points.length < 3) {
      if (points.length == 2) {
        // Just draw a line for 2 points
        path.moveTo(points[0].dx, points[0].dy);
        path.lineTo(points[1].dx, points[1].dy);
      }
      return;
    }
    
    // Move to the first point
    path.moveTo(points[0].dx, points[0].dy);
    
    // Alpha value affects the "tightness" of the curve
    // 0.5 is a common value for Catmull-Rom
    final alpha = tension;
    
    // For each segment between points[i] and points[i+1]
    for (int i = 0; i < points.length - 1; i++) {
      // Get the four points needed for this segment
      final p0 = i > 0 ? points[i - 1] : points[i]; // If first point, duplicate it
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : points[i + 1]; // If last point, duplicate it
      
      // Convert Catmull-Rom to Bezier (this is more efficient than many small line segments)
      // Formula from: https://pomax.github.io/bezierinfo/#catmullconv
      
      // Calculate Bezier control points
      final c1 = Offset(
        p1.dx + (alpha * (p2.dx - p0.dx) / 6),
        p1.dy + (alpha * (p2.dy - p0.dy) / 6)
      );
      
      final c2 = Offset(
        p2.dx - (alpha * (p3.dx - p1.dx) / 6),
        p2.dy - (alpha * (p3.dy - p1.dy) / 6)
      );
      
      // Add a cubic Bezier curve to the path
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
  }
  
  /// Draw a dashed line between two points
  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final double dashWidth = 5.0;
    final double dashSpace = 3.0;
    
    // Calculate distance and unit vector
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    final double unitX = dx / distance;
    final double unitY = dy / distance;
    
    double currentDistance = 0.0;
    bool isDash = true;
    Offset startPoint = p1;
    
    while (currentDistance < distance) {
      double segmentLength = isDash ? dashWidth : dashSpace;
      if (currentDistance + segmentLength > distance) {
        segmentLength = distance - currentDistance;
      }
      
      final Offset endPoint = Offset(
        p1.dx + unitX * (currentDistance + segmentLength),
        p1.dy + unitY * (currentDistance + segmentLength)
      );
      
      if (isDash) {
        canvas.drawLine(startPoint, endPoint, paint);
      }
      
      startPoint = endPoint;
      currentDistance += segmentLength;
      isDash = !isDash;
    }
  }

  @override
  bool hitTest(Offset point, Matrix4 transform, double hitDistance) {
    if (controlPoints.length < 2) return false;
    
    // First check if point is near any control point
    for (final controlPoint in controlPoints) {
      final transformedPoint = GeometryUtils.transformPoint(controlPoint, transform);
      if ((transformedPoint - point).distance <= hitDistance) {
        return true;
      }
    }
    
    // Then check if point is near the spline curve
    // This is an approximation using line segments between many points along the curve
    final path = Path();
    final transformedPoints = controlPoints.map((p) => GeometryUtils.transformPoint(p, transform)).toList();
    
    // Move to the first point
    path.moveTo(transformedPoints[0].dx, transformedPoints[0].dy);
    
    if (controlPoints.length == 2) {
      // Only two points - just check distance to line segment
      return GeometryUtils.distanceToLineSegment(
        point, transformedPoints[0], transformedPoints[1]) <= hitDistance;
    }
    
    // Generate many points along the spline and check distance to each segment
    List<Offset> curvePoints = [];
    curvePoints.add(transformedPoints[0]);
    
    // Create a temporary path to calculate points
    final tempPath = Path();
    tempPath.moveTo(transformedPoints[0].dx, transformedPoints[0].dy);
    _drawCatmullRomSpline(tempPath, transformedPoints, tension);
    
    // Approximate by checking a bunch of small line segments
    // (This is simplified - a proper implementation would sample the actual path)
    for (int i = 0; i < transformedPoints.length - 1; i++) {
      final p0 = i > 0 ? transformedPoints[i - 1] : transformedPoints[i];
      final p1 = transformedPoints[i];
      final p2 = transformedPoints[i + 1];
      final p3 = i < transformedPoints.length - 2 ? transformedPoints[i + 2] : transformedPoints[i + 1];
      
      final distance = (p2 - p1).distance;
      final steps = math.max(10, (distance / 5).ceil());
      
      for (int step = 1; step <= steps; step++) {
        final t = step / steps;
        final t2 = t * t;
        final t3 = t2 * t;
        
        final h1 = 2 * t3 - 3 * t2 + 1;
        final h2 = -2 * t3 + 3 * t2;
        final h3 = t3 - 2 * t2 + t;
        final h4 = t3 - t2;
        
        final alpha = tension;
        final m1 = Offset(
          alpha * (p2.dx - p0.dx),
          alpha * (p2.dy - p0.dy)
        );
        final m2 = Offset(
          alpha * (p3.dx - p1.dx),
          alpha * (p3.dy - p1.dy)
        );
        
        final x = h1 * p1.dx + h2 * p2.dx + h3 * m1.dx + h4 * m2.dx;
        final y = h1 * p1.dy + h2 * p2.dy + h3 * m1.dy + h4 * m2.dy;
        
        curvePoints.add(Offset(x, y));
      }
    }
    
    // Check distance to each line segment in the approximated curve
    for (int i = 0; i < curvePoints.length - 1; i++) {
      if (GeometryUtils.distanceToLineSegment(
          point, curvePoints[i], curvePoints[i + 1]) <= hitDistance) {
        return true;
      }
    }
    
    return false;
  }

  @override
  SplineEntity copyWith({
    List<Offset>? controlPoints,
    String? layer,
    Color? color,
    double? lineWidth,
    bool? isSelected,
    bool? showControlPoints,
    SplineType? splineType,
    double? tension,
  }) {
    return SplineEntity(
      controlPoints: controlPoints ?? this.controlPoints,
      layer: layer ?? this.layer,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      isSelected: isSelected ?? this.isSelected,
      showControlPoints: showControlPoints ?? this.showControlPoints,
      splineType: splineType ?? this.splineType,
      tension: tension ?? this.tension,
      id: id,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'spline',
      'id': id,
      'layer': layer,
      'color': color.value,
      'lineWidth': lineWidth,
      'isSelected': isSelected,
      'controlPoints': controlPoints.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'splineType': splineType.index, // Store as integer index
      'tension': tension,
    };
  }

  factory SplineEntity.fromJson(Map<String, dynamic> json) {
    final pointsJson = json['controlPoints'] as List;
    final controlPoints = pointsJson.map((p) =>
        Offset(p['x'].toDouble(), p['y'].toDouble())).toList();
    
    // Convert the stored index back to enum value, default to bezier if not found
    SplineType splineType = SplineType.bezier;
    if (json.containsKey('splineType')) {
      final typeIndex = json['splineType'] as int;
      if (typeIndex < SplineType.values.length) {
        splineType = SplineType.values[typeIndex];
      }
    }

    return SplineEntity(
      id: json['id'],
      layer: json['layer'],
      color: Color(json['color']),
      lineWidth: json['lineWidth'].toDouble(),
      isSelected: json['isSelected'],
      controlPoints: controlPoints,
      splineType: splineType,
      tension: json['tension']?.toDouble() ?? 0.5,
    );
  }

  @override
  List<Offset> getCharacteristicPoints() {
    // Return all control points as characteristic points for snapping
    return List.from(controlPoints);
  }
}

/// Represents an ellipse entity
class EllipseEntity extends Entity {
  EllipseEntity({
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required super.layer,
    required super.color,
    required super.lineWidth,
    required super.isSelected,
    super.id,
  });

  final Offset center;
  final double radiusX;
  final double radiusY;

  @override
  void draw(Canvas canvas, Matrix4 transform) {
    final paint = Paint()
      ..color = isSelected ? Colors.blue : color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Transform the center point
    final transformedCenter = GeometryUtils.transformPoint(center, transform);
    
    // Scale is the average of the x and y scale factors in the transform
    final scaleX = GeometryUtils.getScaleX(transform);
    final scaleY = GeometryUtils.getScaleY(transform);
    
    // Scale the radii according to the transform
    final transformedRadiusX = radiusX * scaleX;
    final transformedRadiusY = radiusY * scaleY;
    
    // Create the rectangle that bounds the ellipse
    final rect = Rect.fromCenter(
      center: transformedCenter,
      width: transformedRadiusX * 2,
      height: transformedRadiusY * 2,
    );
    
    // Draw the ellipse
    canvas.drawOval(rect, paint);
    
    // Draw selection handles if selected
    if (isSelected) {
      final handlePoints = [
        // Center point
        transformedCenter,
        // Points at the ends of the major and minor axes
        Offset(transformedCenter.dx + transformedRadiusX, transformedCenter.dy),
        Offset(transformedCenter.dx, transformedCenter.dy + transformedRadiusY),
        Offset(transformedCenter.dx - transformedRadiusX, transformedCenter.dy),
        Offset(transformedCenter.dx, transformedCenter.dy - transformedRadiusY),
      ];
      _drawSelectionHandles(canvas, handlePoints);
    }
  }

  @override
  bool hitTest(Offset point, Matrix4 transform, double hitDistance) {
    final transformedCenter = GeometryUtils.transformPoint(center, transform);
    final scaleX = GeometryUtils.getScaleX(transform);
    final scaleY = GeometryUtils.getScaleY(transform);
    
    // Transform the point to the ellipse's coordinate system
    final dx = (point.dx - transformedCenter.dx) / (radiusX * scaleX);
    final dy = (point.dy - transformedCenter.dy) / (radiusY * scaleY);
    
    // For an ellipse, a point is on the ellipse if (x/a)² + (y/b)² = 1
    // We use a range to allow for hit detection within hitDistance
    final distance = math.sqrt(dx * dx + dy * dy);
    
    // If distance is close to 1, the point is close to the ellipse's perimeter
    return (distance - 1).abs() * math.min(radiusX * scaleX, radiusY * scaleY) <= hitDistance;
  }

  @override
  EllipseEntity copyWith({
    Offset? center,
    double? radiusX,
    double? radiusY,
    String? layer,
    Color? color,
    double? lineWidth,
    bool? isSelected,
  }) {
    return EllipseEntity(
      center: center ?? this.center,
      radiusX: radiusX ?? this.radiusX,
      radiusY: radiusY ?? this.radiusY,
      layer: layer ?? this.layer,
      color: color ?? this.color,
      lineWidth: lineWidth ?? this.lineWidth,
      isSelected: isSelected ?? this.isSelected,
      id: id,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'ellipse',
      'id': id,
      'layer': layer,
      'color': color.value,
      'lineWidth': lineWidth,
      'isSelected': isSelected,
      'center': {'x': center.dx, 'y': center.dy},
      'radiusX': radiusX,
      'radiusY': radiusY,
    };
  }

  factory EllipseEntity.fromJson(Map<String, dynamic> json) {
    return EllipseEntity(
      id: json['id'],
      layer: json['layer'],
      color: Color(json['color']),
      lineWidth: json['lineWidth'].toDouble(),
      isSelected: json['isSelected'],
      center: Offset(
        json['center']['x'].toDouble(),
        json['center']['y'].toDouble(),
      ),
      radiusX: json['radiusX'].toDouble(),
      radiusY: json['radiusY'].toDouble(),
    );
  }

  @override
  List<Offset> getCharacteristicPoints() {
    // Return center and the four points at the ends of the axes
    return [
      center,
      Offset(center.dx + radiusX, center.dy),
      Offset(center.dx, center.dy + radiusY),
      Offset(center.dx - radiusX, center.dy),
      Offset(center.dx, center.dy - radiusY),
    ];
  }
}

// Helper functions

// Removed redundant _transformPoint function - using GeometryUtils.transformPoint instead

/// Calculates the distance from a point to a line segment
double _distanceToLineSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lengthSquared = dx * dx + dy * dy;

  if (lengthSquared == 0) {
    // Line segment is actually a point
    return (p - a).distance;
  }

  // Calculate projection parameter
  final t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared;

  if (t < 0) {
    // Beyond the 'a' end of the segment
    return (p - a).distance;
  } else if (t > 1) {
    // Beyond the 'b' end of the segment
    return (p - b).distance;
  }

  // Projection falls on the segment
  final projection = Offset(
    a.dx + t * dx,
    a.dy + t * dy,
  );

  return (p - projection).distance;
}

/// Draws selection handles at the specified points
void _drawSelectionHandles(Canvas canvas, List<Offset> points) {
  final paint = Paint()
    ..color = Colors.blue
    ..strokeWidth = 1
    ..style = PaintingStyle.fill;

  for (final point in points) {
    canvas.drawCircle(point, 5, paint);
  }
}

