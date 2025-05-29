import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/entities.dart';

/// Extension methods for Matrix4 class
extension Matrix4Extensions on Matrix4 {
  /// Gets the X scale factor from the transformation matrix
  double getScaleX() {
    final row0 = getRow(0);
    return math.sqrt(row0.x * row0.x + row0.y * row0.y);
  }

  /// Gets the Y scale factor from the transformation matrix
  double getScaleY() {
    final row1 = getRow(1);
    return math.sqrt(row1.x * row1.x + row1.y * row1.y);
  }
}

/// Utility class for geometric calculations
class GeometryUtils {
  /// Transforms a point using a transformation matrix
  static Offset transformPoint(Offset point, Matrix4 transform) {
    final vector = Vector3(point.dx, point.dy, 0);
    final transformed = transform.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  /// Inverse transforms a point using a transformation matrix
  static Offset inverseTransformPoint(Offset point, Matrix4 transform) {
    final inverse = Matrix4.copy(transform);
    inverse.invert();
    final vector = Vector3(point.dx, point.dy, 0);
    final transformed = inverse.transform3(vector);
    return Offset(transformed.x, transformed.y);
  }

  /// Extracts the X scale factor from a transformation matrix
  static double getScaleX(Matrix4 transform) {
    // Extract the scale factor from the first column
    final x = Vector3(
        transform.storage[0], transform.storage[1], transform.storage[2]);
    return x.length;
  }

  /// Extracts the Y scale factor from a transformation matrix
  static double getScaleY(Matrix4 transform) {
    // Extract the scale factor from the second column
    final y = Vector3(
        transform.storage[4], transform.storage[5], transform.storage[6]);
    return y.length;
  }

  /// Distance from a point to a line segment
  static double distanceToLineSegment(Offset p, Offset a, Offset b) {
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

  /// Distance from a point to a circle
  static double distanceToCircle(Offset p, Offset center, double radius) {
    return (p - center).distance - radius;
  }

  /// Distance from a point to an ellipse
  /// Returns an approximate distance - positive if outside, negative if inside
  static double distanceToEllipse(
      Offset p, Offset center, double radiusX, double radiusY) {
    // Normalize the point to a unit circle coordinate system
    final normalized =
        Offset((p.dx - center.dx) / radiusX, (p.dy - center.dy) / radiusY);

    // Distance to unit circle
    final distance = normalized.distance;

    // Scale back to get approximate distance
    final averageRadius = (radiusX + radiusY) / 2;
    return averageRadius * (distance - 1.0);
  }

  /// Snaps a point to the grid
  static Offset snapToGrid(Offset point, double gridSize) {
    return Offset(
      (point.dx / gridSize).roundToDouble() * gridSize,
      (point.dy / gridSize).roundToDouble() * gridSize,
    );
  }

  /// Finds the closest snap point on entities
  static Offset? findClosestSnapPoint(
      Offset point, List<Entity> entities, double threshold) {
    Offset? closestPoint;
    double minDistance = double.infinity;

    for (final entity in entities) {
      final characteristicPoints = entity.getCharacteristicPoints();

      for (final snapPoint in characteristicPoints) {
        final distance = (snapPoint - point).distance;

        if (distance < threshold && distance < minDistance) {
          minDistance = distance;
          closestPoint = snapPoint;
        }
      }
    }

    return closestPoint;
  }

  /// Finds the closest intersection point between entities
  static Offset? findClosestIntersection(
      Offset point, List<Entity> entities, double threshold) {
    Offset? closestIntersection;
    double minDistance = double.infinity;

    // Check all pairs of entities for intersections
    for (var i = 0; i < entities.length; i++) {
      for (var j = i + 1; j < entities.length; j++) {
        final intersections = findIntersections(entities[i], entities[j]);

        for (final intersection in intersections) {
          final distance = (intersection - point).distance;

          if (distance < threshold && distance < minDistance) {
            minDistance = distance;
            closestIntersection = intersection;
          }
        }
      }
    }

    return closestIntersection;
  }

  /// Finds all intersections between two entities
  static List<Offset> findIntersections(Entity a, Entity b) {
    // Line-Line intersection
    if (a is LineEntity && b is LineEntity) {
      final intersection = lineLineIntersection(a.start, a.end, b.start, b.end);
      return intersection != null ? [intersection] : [];
    }

    // Line-Circle intersection
    else if (a is LineEntity && b is CircleEntity) {
      return lineCircleIntersection(a.start, a.end, b.center, b.radius);
    } else if (a is CircleEntity && b is LineEntity) {
      return lineCircleIntersection(b.start, b.end, a.center, a.radius);
    }

    // Circle-Circle intersection
    else if (a is CircleEntity && b is CircleEntity) {
      return circleCircleIntersection(a.center, a.radius, b.center, b.radius);
    }

    // Line-Rectangle intersection
    else if (a is LineEntity && b is RectangleEntity) {
      return lineRectangleIntersection(
          a.start, a.end, b.topLeft, b.bottomRight);
    } else if (a is RectangleEntity && b is LineEntity) {
      return lineRectangleIntersection(
          b.start, b.end, a.topLeft, a.bottomRight);
    }

    // Add more intersection types as needed

    return [];
  }

  /// Normalizes an angle to the range [0, 2*pi).
  static double normalizeAngle(double angle) {
    double twoPi = 2 * math.pi;
    while (angle < 0) {
      angle += twoPi;
    }
    while (angle >= twoPi) {
      angle -= twoPi;
    }
    return angle;
  }

  /// Calculates the counter-clockwise (CCW) sweep from startAngle to endAngle.
  /// Angles are in radians. Result is in (0, 2*pi].
  /// If startAngle and endAngle are effectively the same (within epsilon),
  /// it returns 2*pi (representing a full circle).
  static double calculateNormalizedCcwSweep(double fromAngle, double toAngle, {double epsilon = 1e-9}) {
    // Normalize angles to [0, 2*pi) to make comparison robust for identifying "sameness".
    double nFrom = normalizeAngle(fromAngle);
    double nTo = normalizeAngle(toAngle);

    // If normalized angles are effectively the same, it's a 2*pi sweep by convention.
    if ((nFrom - nTo).abs() < epsilon) {
        return 2 * math.pi;
    }

    // Calculate the raw sweep.
    double sweep = toAngle - fromAngle;

    // Adjust sweep to be CCW and in the (0, 2*pi] range.
    // First, ensure sweep is positive by adding 2*pi if it's zero or negative.
    // The (nFrom - nTo).abs() < epsilon check above handles cases where angles are truly identical.
    // This loop handles cases like from=PI/2, to=0, making sweep 3PI/2 instead of -PI/2.
    while (sweep <= 0) { // Use <=0 to ensure sweep becomes positive.
        sweep += 2 * math.pi;
    }

    // Then, ensure sweep is not greater than 2*pi by subtracting 2*pi if needed.
    // This handles cases like from=0, to=2.5*pi, making sweep 0.5*pi.
    while (sweep > 2 * math.pi) {
        sweep -= 2 * math.pi;
    }
    
    // After these adjustments, sweep should be in (0, 2*pi].
    // If it ended up extremely close to 2*pi, clamp it.
    if ((sweep - 2 * math.pi).abs() < epsilon) {
        return 2 * math.pi;
    }
    // If sweep is extremely close to 0, it means the original angles were k*2*pi apart
    // and not caught by the (nFrom - nTo).abs() < epsilon check. 
    // This path should ideally not be hit if normalizeAngle and the initial check are robust.
    // However, if it does, it implies the angles were effectively identical, so 2*pi is appropriate by convention.
    // BUT, if the angles were NOT identical initially, and the sweep is just very small (e.g. 0.00001 rad),
    // it should be returned as that small value. The initial (nFrom - nTo) check is the authority on 2*pi for identical angles.
    // The `newSweep < _epsilon` check in ArcEntity.extend will filter genuinely tiny resulting sweeps.
    // Thus, the `if (sweep.abs() < epsilon) return 2 * math.pi;` line is removed.

    return sweep;
  }

  /// Finds the intersection point between two line segments, if it exists
  static Offset? lineLineIntersection(
      Offset a1, Offset a2, Offset b1, Offset b2) {
    // Check if either line is actually a point (start and end are the same)
    final isLine1Point = (a1.dx == a2.dx && a1.dy == a2.dy);
    final isLine2Point = (b1.dx == b2.dx && b1.dy == b2.dy);

    // If both are points, check if they're the same point
    if (isLine1Point && isLine2Point) {
      if ((a1.dx == b1.dx && a1.dy == b1.dy)) {
        return a1; // Same point, return it
      } else {
        return null; // Different points, no intersection
      }
    }

    // If one is a point, check if it lies on the other line
    if (isLine1Point) {
      // Check if point a1 lies on line b1-b2
      return pointOnLineSegment(a1, b1, b2) ? a1 : null;
    }

    if (isLine2Point) {
      // Check if point b1 lies on line a1-a2
      return pointOnLineSegment(b1, a1, a2) ? b1 : null;
    }

    // Line 1 (a1, a2) represented as P = a1 + t * v1
    // Line 2 (b1, b2) represented as Q = b1 + u * v2
    final v1 = a2 - a1; // Direction vector of line 1
    final v2 = b2 - b1; // Direction vector of line 2

    debugPrint('[GeoUtils.lineLineIntersection] Inputs: a1=$a1, a2=$a2, b1=$b1, b2=$b2');
    debugPrint('[GeoUtils.lineLineIntersection] Vectors: v1=$v1, v2=$v2');

    // Denominator for the parametric equations
    // (v1.dx * v2.dy) - (v1.dy * v2.dx) is a common formulation for the 2D cross product magnitude v1 x v2
    final denominator = v1.dx * v2.dy - v1.dy * v2.dx;
    debugPrint('[GeoUtils.lineLineIntersection] Denominator: $denominator');

    if (denominator.abs() < 1e-10) {
      // Lines are parallel or collinear. For the purpose of finding a unique intersection point
      // of two infinite lines, this means no single intersection point exists (or infinitely many if collinear).
      // The `LineEntity.extend` method will handle cases where lines might be collinear and an extension is still valid.
      return null;
    }

    // Vector from a1 to b1
    final a1b1 = b1 - a1;

    // Calculate parameter 't' for line 1 (P = a1 + t*v1)
    // t = (a1b1.dx * v2.dy - a1b1.dy * v2.dx) / denominator
    final t = (a1b1.dx * v2.dy - a1b1.dy * v2.dx) / denominator;

    // Calculate parameter 'u' for line 2 (Q = b1 + u*v2) - useful for segment checks, but not strictly needed here
    // final u = (a1b1.dx * v1.dy - a1b1.dy * v1.dx) / denominator; 

    // The intersection point lies on the infinite line defined by a1 and a2.
    final intersectionPoint = Offset(
      a1.dx + t * v1.dx,
      a1.dy + t * v1.dy,
    );

    // LineEntity.extend will perform its own checks to see if this intersection point
    // is valid for extension (e.g., lies on the boundary *segment* and in the correct direction).
    return intersectionPoint;
  }

  /// Finds intersection points between a line segment and a circle
  static List<Offset> lineCircleIntersection(
      Offset lineStart, Offset lineEnd, Offset circleCenter, double radius) {
    final result = <Offset>[];
    final double Epsilon = 1e-9; // Tolerance for floating point comparisons

    final d = lineEnd - lineStart; // Direction vector of the segment
    final f = lineStart - circleCenter; // Vector from circle center to line start

    final a = d.dx * d.dx + d.dy * d.dy; // d.dot(d)
    final b = 2 * (f.dx * d.dx + f.dy * d.dy); // 2 * f.dot(d)
    final c = (f.dx * f.dx + f.dy * f.dy) - radius * radius; // f.dot(f) - r^2

    var discriminant = b * b - 4 * a * c;
    if (discriminant < -Epsilon) {
      // No real solution, no intersection or tangent
      return result;
    }
    // Ensure discriminant is not negative due to precision issues if it's very close to zero
    discriminant = math.max(0, discriminant);

    // Quadratic formula for t values
    // t = [-b ± sqrt(discriminant)] / (2a)
    final sqrtDiscriminant = math.sqrt(discriminant);

    final t1 = (-b - sqrtDiscriminant) / (2 * a);
    final t2 = (-b + sqrtDiscriminant) / (2 * a);

    // Check if t1 is within the segment [0, 1]
    if (t1 >= -Epsilon && t1 <= 1.0 + Epsilon) {
      result.add(lineStart + d * t1);
    }

    // Check if t2 is within the segment [0, 1] and distinct from t1
    if (discriminant.abs() > Epsilon) { // Only if t1 and t2 are distinct
      if (t2 >= -Epsilon && t2 <= 1.0 + Epsilon) {
        // Ensure we don't add the same point twice if t1 and t2 are extremely close due to precision
        if (result.isEmpty || (result.first - (lineStart + d * t2)).distanceSquared > Epsilon * Epsilon) {
            result.add(lineStart + d * t2);
        }
      }
    }
    return result;
  }

  /// Finds intersection points between two circles
  static List<Offset> circleCircleIntersection(
      Offset center1, double radius1, Offset center2, double radius2) {
    final result = <Offset>[];

    // Distance between circle centers
    final centerDist = (center2 - center1).distance;

    // Check for degenerate cases
    if (centerDist < 1e-10) {
      // Concentric circles
      return result;
    }

    if (centerDist > radius1 + radius2 + 1e-10) {
      // Circles are too far apart
      return result;
    }

    if (centerDist + math.min(radius1, radius2) <
        math.max(radius1, radius2) - 1e-10) {
      // One circle is contained within the other
      return result;
    }

    // Calculate intersection points
    final a =
        (radius1 * radius1 - radius2 * radius2 + centerDist * centerDist) /
            (2 * centerDist);

    // Find point on the line between centers that is 'a' distance from center1
    final dirX = (center2.dx - center1.dx) / centerDist;
    final dirY = (center2.dy - center1.dy) / centerDist;

    final midX = center1.dx + a * dirX;
    final midY = center1.dy + a * dirY;

    // Distance from this point to the intersection points
    final h = math.sqrt(radius1 * radius1 - a * a);

    // Calculate perpendicular direction
    final perpX = -dirY;
    final perpY = dirX;

    // Calculate intersection points
    result.add(Offset(
      midX + h * perpX,
      midY + h * perpY,
    ));

    // Add second intersection point if circles are not tangent
    if (h > 1e-10) {
      result.add(Offset(
        midX - h * perpX,
        midY - h * perpY,
      ));
    }

    return result;
  }

  /// Finds intersection points between a line segment and a rectangle
  static List<Offset> lineRectangleIntersection(Offset lineStart,
      Offset lineEnd, Offset rectTopLeft, Offset rectBottomRight) {
    final result = <Offset>[];

    // Rectangle corners
    final rectTopRight = Offset(rectBottomRight.dx, rectTopLeft.dy);
    final rectBottomLeft = Offset(rectTopLeft.dx, rectBottomRight.dy);

    // Check intersection with each edge of the rectangle
    final intersections = [
      // Top edge
      lineLineIntersection(lineStart, lineEnd, rectTopLeft, rectTopRight),
      // Right edge
      lineLineIntersection(lineStart, lineEnd, rectTopRight, rectBottomRight),
      // Bottom edge
      lineLineIntersection(lineStart, lineEnd, rectBottomLeft, rectBottomRight),
      // Left edge
      lineLineIntersection(lineStart, lineEnd, rectTopLeft, rectBottomLeft),
    ];

    // Add all non-null intersections
    for (final intersection in intersections) {
      if (intersection != null) {
        result.add(intersection);
      }
    }

    return result;
  }

  /// Rotates a point around a center point
  static Offset rotatePoint(Offset point, Offset center, double angleRadians) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;

    final cos = math.cos(angleRadians);
    final sin = math.sin(angleRadians);

    return Offset(
      center.dx + dx * cos - dy * sin,
      center.dy + dx * sin + dy * cos,
    );
  }

  /// Returns the angle in radians between two points
  static double angleBetweenPoints(Offset center, Offset point) {
    return math.atan2(point.dy - center.dy, point.dx - center.dx);
  }

  /// Rotates an entity around a specified point
  static Entity rotateEntity(
      Entity entity, Offset rotationCenter, double rotationAngle) {
    if (entity is LineEntity) {
      return LineEntity(
        start: rotatePoint(entity.start, rotationCenter, rotationAngle),
        end: rotatePoint(entity.end, rotationCenter, rotationAngle),
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is CircleEntity) {
      // For circles, only the center point needs to be rotated
      return CircleEntity(
        center: rotatePoint(entity.center, rotationCenter, rotationAngle),
        radius: entity.radius,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is RectangleEntity) {
      // Convert rectangle to four corner points, rotate each, then create a new bounding box
      final topLeft = entity.topLeft;
      final topRight = Offset(entity.bottomRight.dx, entity.topLeft.dy);
      final bottomLeft = Offset(entity.topLeft.dx, entity.bottomRight.dy);
      final bottomRight = entity.bottomRight;

      // Rotate all four corners
      final rotatedTopLeft =
          rotatePoint(topLeft, rotationCenter, rotationAngle);
      final rotatedTopRight =
          rotatePoint(topRight, rotationCenter, rotationAngle);
      final rotatedBottomLeft =
          rotatePoint(bottomLeft, rotationCenter, rotationAngle);
      final rotatedBottomRight =
          rotatePoint(bottomRight, rotationCenter, rotationAngle);

      // Find the new bounding box of the rotated points
      final minX = math.min(
        math.min(rotatedTopLeft.dx, rotatedTopRight.dx),
        math.min(rotatedBottomLeft.dx, rotatedBottomRight.dx),
      );
      final minY = math.min(
        math.min(rotatedTopLeft.dy, rotatedTopRight.dy),
        math.min(rotatedBottomLeft.dy, rotatedBottomRight.dy),
      );
      final maxX = math.max(
        math.max(rotatedTopLeft.dx, rotatedTopRight.dx),
        math.max(rotatedBottomLeft.dx, rotatedBottomRight.dx),
      );
      final maxY = math.max(
        math.max(rotatedTopLeft.dy, rotatedTopRight.dy),
        math.max(rotatedBottomLeft.dy, rotatedBottomRight.dy),
      );

      return RectangleEntity(
        topLeft: Offset(minX, minY),
        bottomRight: Offset(maxX, maxY),
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    } else if (entity is ArcEntity) {
      // For arcs, rotate the center and adjust the start/end angles
      final newCenter =
          rotatePoint(entity.center, rotationCenter, rotationAngle);
      final newStartAngle = entity.startAngle + rotationAngle;
      final newEndAngle = entity.endAngle + rotationAngle;

      return ArcEntity(
        center: newCenter,
        radius: entity.radius,
        startAngle: newStartAngle,
        endAngle: newEndAngle,
        layer: entity.layer,
        color: entity.color,
        lineWidth: entity.lineWidth,
        isSelected: entity.isSelected,
        id: entity.id,
      );
    }
    // Default case: return the original entity if other types are not handled explicitly
    return entity;
  } // Closing brace for rotateEntity method

  /// Checks if a point lies on a line segment within a small tolerance
  static bool pointOnLineSegment(Offset point, Offset lineStart, Offset lineEnd, {double epsilon = 1e-9}) {
    final double lineLength = (lineEnd - lineStart).distance;
    // If the line segment is essentially a point
    if (lineLength < epsilon) {
      return (point - lineStart).distance < epsilon;
    }
    
    // Calculate distances from point to lineStart and lineEnd
    final double d1 = (point - lineStart).distance;
    final double d2 = (point - lineEnd).distance;
    
    // Check if point is on the line segment (within tolerance)
    // A point is on segment if d1 + d2 is approximately equal to lineLength
    return (d1 + d2 - lineLength).abs() < epsilon;
  }

  /// - `arcStartAngle`: The start angle of the arc (in radians, CCW from positive x-axis).
  /// - `arcEndAngle`: The end angle of the arc (in radians, CCW from positive x-axis).
  /// - `epsilon`: Optional tolerance for distance and angular checks.
  static bool isPointOnArc(
      Offset point,
      Offset arcCenter,
      double arcRadius,
      double arcStartAngle,
      double arcEndAngle,
      {double epsilon = 1e-9}) {
    // 1. Check if the point is (approximately) on the arc's circumference
    final double distanceToCenter = (point - arcCenter).distance;
    if ((distanceToCenter - arcRadius).abs() > epsilon) {
      return false; // Point is not on the circle's path
    }

    // If the radius is very small (arc is effectively a point),
    // the distance check above is sufficient if the point is the center.
    if (arcRadius < epsilon) {
      return (point - arcCenter).distance < epsilon;
    }

    // 2. Calculate the angle of the test point relative to the arc's center
    double pointAngleRad = math.atan2(
      point.dy - arcCenter.dy,
      point.dx - arcCenter.dx,
    );

    // Normalize the point's angle to be in the range [0, 2*pi)
    while (pointAngleRad < 0) pointAngleRad += 2 * math.pi;
    while (pointAngleRad >= 2 * math.pi) pointAngleRad -= 2 * math.pi;

    // 3. Determine the arc's effective CCW sweep angle.
    // (Logic adapted from ArcEntity.hitTest)
    double effectiveSweepRad;
    // Check if startAngle and endAngle are effectively the same (implies a full circle if not a zero-radius point)
    if ((arcStartAngle - arcEndAngle).abs() < epsilon) {
      effectiveSweepRad = 2 * math.pi; // Full circle
    } else {
      effectiveSweepRad = arcEndAngle - arcStartAngle;
      // Normalize sweep to be positive CCW in (0, 2*pi]
      while (effectiveSweepRad <= 0) effectiveSweepRad += 2 * math.pi; // Ensure positive sweep
      while (effectiveSweepRad > 2 * math.pi) effectiveSweepRad -= 2 * math.pi; // Modulo 2*pi
      // The above normalization correctly calculates the sweep. Line 623 handles the case where startAngle ~= endAngle (conventional full circle).
      // A genuinely tiny sweep (e.g., 0.0001 rad) should remain tiny, not be converted to 2*pi.
      // Removed: if (effectiveSweepRad < epsilon && arcRadius >= epsilon) effectiveSweepRad = 2 * math.pi;
    }
    // Now, effectiveSweepRad is the CCW angular length of the arc, in (0, 2*pi] (or close to 0 for point arcs if startAngle ~= endAngle).

    // 4. Normalize the arc's start angle to [0, 2*pi)
    double normalizedArcStartAngleRad = arcStartAngle;
    while (normalizedArcStartAngleRad < 0) normalizedArcStartAngleRad += 2 * math.pi;
    while (normalizedArcStartAngleRad >= 2 * math.pi) normalizedArcStartAngleRad -= 2 * math.pi;

    // 5. Check if the point's angle lies within the arc's sweep
    // Calculate the point's angle relative to the (normalized) start of the arc, in CCW direction.
    double relativePointAngleRad = pointAngleRad - normalizedArcStartAngleRad;
    while (relativePointAngleRad < 0) relativePointAngleRad += 2 * math.pi;

    // The point is on the arc if its relative angle is less than or equal to the sweep.
    // Add a small epsilon for floating point comparisons at the end of the sweep.
    return relativePointAngleRad <= (effectiveSweepRad + epsilon);
  }
}
