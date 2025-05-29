import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../utils/geometry_utils.dart';
import 'tool_interface.dart';

/// Enum representing the current state of the trim operation
enum TrimState {
  /// Selecting the cutting entity (first step)
  selectCuttingEntity,
  /// Selecting the entity to trim (second step)
  selectEntityToTrim,
  /// Selecting which portion of the entity to keep (third step)
  selectPortionToKeep,
}

/// Trim tool implementation for trimming entities at intersections
class TrimTool implements Tool {
  // State for the trim tool
  final String toolId = Uuid().v4(); // Unique ID for this instance for logging

  TrimState _state = TrimState.selectCuttingEntity;
  Entity? cuttingEntity;
  Entity? entityToTrim;
  Entity? previewEntity;
  Entity? trimPreview;
  List<Offset> intersectionPoints = [];
  String statusMessage = 'Select cutting entity';

  // Selected intersection point for trimming
  Offset? selectedIntersection;
  
  // List to store highlighted entities
  List<Entity> highlightedEntities = [];

  @override
  void onActivate() {
    print('[TrimTool ($toolId)] onActivate called');
    clearState();
  }

  @override
  void onDeactivate(DrawingDocument document, DocumentService documentService, BuildContext context) {
    print('[TrimTool ($toolId)] onDeactivate called');
    clearState();
  }

  @override
  void onScaleStart(ScaleStartDetails details) {}

  @override
  void onScaleUpdate(ScaleUpdateDetails details, Matrix4 transform) {}

  @override
  void onScaleEnd(ScaleEndDetails details) {}

  @override
  void handleRightClick(DrawingDocument document) {
    // Reset to the previous state or cancel the current operation
    switch (_state) {
      case TrimState.selectEntityToTrim:
        _state = TrimState.selectCuttingEntity;
        statusMessage = 'Select cutting entity';
        cuttingEntity = null;
        break;
      case TrimState.selectPortionToKeep:
        _state = TrimState.selectEntityToTrim;
        statusMessage = 'Select entity to trim';
        entityToTrim = null;
        intersectionPoints = [];
        break;
      default:
        break;
    }
  }

  /// Get additional preview entities for visualization
  List<Entity> getAdditionalPreviewEntities() {
    List<Entity> previews = [];

    // Add intersection point markers
    for (final point in intersectionPoints) {
      previews.add(
        CircleEntity(
          center: point,
          radius: 5.0,
          layer: 'preview',
          color: Colors.red,
          lineWidth: 2.0,
          isSelected: false,
        ),
      );
    }

    // Add cutting entity highlight if available
    if (cuttingEntity != null && cuttingEntity is LineEntity) {
      LineEntity line = cuttingEntity as LineEntity;
      previews.add(
        LineEntity(
          start: line.start,
          end: line.end,
          layer: 'preview',
          color: Colors.purple,
          lineWidth: line.lineWidth + 1.0,
          isSelected: true,
        ),
      );
    }

    // If we're in the selectPortionToKeep state and have an entity to trim,
    // add a preview of the portion that will be removed
    if (_state == TrimState.selectPortionToKeep && entityToTrim != null && selectedIntersection != null) {
      if (entityToTrim is LineEntity) {
        final line = entityToTrim as LineEntity;

        // Determine which segment to remove based on the current preview
        if (trimPreview != null && trimPreview is LineEntity) {
          final keptSegment = trimPreview as LineEntity;

          // Create a preview of the removed segment in red
          Offset start, end;

          if ((keptSegment.start - line.start).distance < 0.1) {
            // Kept segment starts at line.start
            start = selectedIntersection!;
            end = line.end;
          } else {
            // Kept segment ends at line.end
            start = line.start;
            end = selectedIntersection!;
          }

          previews.add(
            LineEntity(
              start: start,
              end: end,
              layer: 'preview',
              color: Colors.red,
              lineWidth: line.lineWidth,
              isSelected: false,
            ),
          );
        }
      }
    }

    return previews;
  }

  @override
  void onPointerDown(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    print('[TrimTool ($toolId)] onPointerDown: point = $point, state = $_state'); // Log entry point and current state

    switch (_state) {
      case TrimState.selectCuttingEntity:
        print('[TrimTool ($toolId)] State: selectCuttingEntity. Pointer: $point'); // Log specific state and pointer
        // Try to select an entity as the cutting entity
        bool cuttingEntitySelected = false;
        for (final entity in document.visibleEntities) {
          final isHit = entity.hitTest(point, Matrix4.identity(), 10.0);
          if (isHit) {
            print('[TrimTool ($toolId)] Cutting entity selected: ${entity.runtimeType} (ID: ${entity.id})'); // Log successful selection
            cuttingEntity = entity;
            _state = TrimState.selectEntityToTrim;
            statusMessage = 'Select entity to trim';
            previewEntity = null;
            cuttingEntitySelected = true;
            break;
          }
        }
        if (!cuttingEntitySelected) {
          print('[TrimTool ($toolId)] No cutting entity selected for point: $point'); // Log if no entity was selected
        }
        break;

      case TrimState.selectEntityToTrim:
        print('[TrimTool ($toolId)] State: selectEntityToTrim. Pointer: $point. Cutting entity: ${cuttingEntity?.id}');
        bool entityToTrimSelected = false;
        // Try to select an entity to trim
        for (final entity in document.visibleEntities) {
          final isHit = entity.hitTest(point, Matrix4.identity(), 10.0);
          if (isHit) {
            if (cuttingEntity == null) {
              print('[TrimTool ($toolId)]   Error: cuttingEntity is null.');
              break; // Should not happen if logic flows correctly
            }
            final isDifferentEntity = entity.id != cuttingEntity!.id;
            if (isDifferentEntity) {
              // Check if there are intersections between the cutting entity and the entity to trim
              final intersections = GeometryUtils.findIntersections(cuttingEntity!, entity);
              print('[TrimTool ($toolId)]   Intersection points found: ${intersections.length}');

              if (intersections.isNotEmpty) {
                entityToTrim = entity;
                intersectionPoints = intersections;
                _state = TrimState.selectPortionToKeep;
                statusMessage = 'Click on the portion to keep';
                entityToTrimSelected = true;
                print('[TrimTool ($toolId)]   Entity to trim selected: ${entity.runtimeType} (ID: ${entity.id}). New state: $_state');
                break;
              }
            }
          }
        }
        if (!entityToTrimSelected) {
          print('[TrimTool ($toolId)] No entity to trim selected or no intersections found for point: $point');
        }
        break;

      case TrimState.selectPortionToKeep:
        if (entityToTrim == null || cuttingEntity == null || intersectionPoints.isEmpty) {
          print('[TrimTool ($toolId)] Invalid state for selectPortionToKeep. Resetting.');
          clearState(); // General reset for a completely invalid state before attempting trim
        } else {
          // The 'point' here is the user's click point on the entity to trim,
          // indicating which portion to keep.
          _trimEntity(point, document, documentService); // 'point' is the clickPoint for trim logic

          // State clearing is now handled by _trimEntity via clearStateAfterTrim()
        }
        break;
    }
  }

  @override
  void onPointerUp(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    // Most of the logic is handled in onPointerDown
  }

  @override
  void onPointerMove(Offset point, DrawingDocument document, DocumentService documentService, BuildContext context) {
    switch (_state) {
      case TrimState.selectCuttingEntity:
        // Highlight the entity under the cursor
        previewEntity = null;
        for (final entity in document.visibleEntities) {
          if (entity.hitTest(point, Matrix4.identity(), 10.0)) {
            previewEntity = entity.copyWith(
              color: Colors.blue,
              lineWidth: entity.lineWidth + 1.0,
              isSelected: true,
            );
            break;
          }
        }
        break;

      case TrimState.selectEntityToTrim:
        // Highlight entities that intersect with the cutting entity
        previewEntity = null;
        intersectionPoints = [];
        
        for (final entity in document.visibleEntities) {
          if (entity.hitTest(point, Matrix4.identity(), 10.0) && entity.id != cuttingEntity!.id) {
            // Check for intersections
            final points = GeometryUtils.findIntersections(cuttingEntity!, entity);

            // Only highlight if there are intersections
            if (points.isNotEmpty) {
              previewEntity = entity.copyWith(
                color: Colors.green,
                lineWidth: entity.lineWidth + 1.0,
                isSelected: true,
              );

              // Store intersection points to draw them later
              intersectionPoints = points;
              break;
            }
          }
        }
        break;

      case TrimState.selectPortionToKeep:
        // Show a preview of the trim result based on which portion the user is hovering over
        if (entityToTrim != null && intersectionPoints.isNotEmpty) {
          // Find the closest intersection point
          Offset closestIntersection = intersectionPoints[0];
          double minDistance = (point - closestIntersection).distance;

          for (var intersection in intersectionPoints) {
            double distance = (point - intersection).distance;
            if (distance < minDistance) {
              minDistance = distance;
              closestIntersection = intersection;
            }
          }

          selectedIntersection = closestIntersection;

          // Create a preview of the trim result
          trimPreview = _createTrimPreview(closestIntersection, point);
        }
        break;
    }
  }

  Entity? _createTrimPreview(Offset intersection, Offset clickPoint) {
    if (entityToTrim is LineEntity) {
      final line = entityToTrim as LineEntity;

      // Determine which segment to keep based on which end is closer to the click point
      final distanceToStart = (clickPoint - line.start).distance;
      final distanceToEnd = (clickPoint - line.end).distance;

      // Create a preview of the kept segment in green
      final keptSegment = LineEntity(
        id: 'preview-kept',
        start: distanceToStart < distanceToEnd ? line.start : intersection,
        end: distanceToStart < distanceToEnd ? intersection : line.end,
        color: Colors.green,
        lineWidth: line.lineWidth + 1.0,
        layer: 'preview',
        isSelected: true,
      );

      // For now, we'll just return the kept segment as the preview
      return keptSegment;
    }

    // Return null for unsupported entity types
    return null;
  }

  // Helper method to perform the actual trim operation
  void _trimEntity(Offset clickPoint, DrawingDocument document, DocumentService documentService) {
    // Note: 'selectedIntersection' is used for LineEntity, 'intersectionPoints' for CircleEntity.
    // 'clickPoint' is the user's click on the entity to trim, indicating the portion to keep.
    if (entityToTrim == null || cuttingEntity == null || 
        ((entityToTrim is LineEntity && selectedIntersection == null) || (entityToTrim is CircleEntity && intersectionPoints.isEmpty))) {
      print('[TrimTool ($toolId)] _trimEntity: Missing entityToTrim, cuttingEntity, or necessary intersection information.');
      clearStateAfterTrim(); // Clear state even if trim fails due to missing info
      return;
    }

    List<Entity> newEntities = [];

    if (entityToTrim is LineEntity) {
      final line = entityToTrim as LineEntity;
      if (selectedIntersection != null) { // selectedIntersection is set by onPointerMove's preview logic
        final trimmedLine = line.trim(cuttingEntity!, selectedIntersection!, clickPoint);
        if (trimmedLine != null) {
          newEntities.add(trimmedLine);
        }
      } else {
         print('[TrimTool ($toolId)] _trimEntity: selectedIntersection is null for LineEntity trim.');
      }
    } else if (entityToTrim is CircleEntity) {
      final circle = entityToTrim as CircleEntity;
      // CircleEntity.trim expects the list of all intersection points.
      final trimmedParts = circle.trim(cuttingEntity!, intersectionPoints, clickPoint);
      newEntities.addAll(trimmedParts);
    }
    // TODO: Handle other entity types like ArcEntity, PolylineEntity, etc. CircleEntity is now handled.

    if (newEntities.isNotEmpty) {
      print('[TrimTool ($toolId)] _trimEntity: Original entity ${entityToTrim!.id} to be removed.');
      documentService.removeEntity(entityToTrim!.id);
      for (var newEntity in newEntities) {
        print('[TrimTool ($toolId)] _trimEntity: Adding new entity ${newEntity.id} of type ${newEntity.runtimeType}.');
        documentService.addEntity(newEntity);
      }
    } else {
      print('[TrimTool ($toolId)] _trimEntity: Trim operation resulted in no new entities for ${entityToTrim!.id}.');
    }

    clearStateAfterTrim(); // Reset state after the operation
  }

  void clearStateAfterTrim() {
    print('[TrimTool ($toolId)] clearStateAfterTrim called');
    _state = TrimState.selectCuttingEntity;
    statusMessage = 'Select cutting entity';
    cuttingEntity = null;
    entityToTrim = null;
    intersectionPoints = [];
    selectedIntersection = null;
    trimPreview = null; 
    previewEntity = null; 
  }

  /// Clears the current state of the trim tool, resetting all selections and messages.
  void clearState() {
    print('[TrimTool ($toolId)] clearState called'); // Log when state is cleared
    _state = TrimState.selectCuttingEntity;
    cuttingEntity = null;
    entityToTrim = null;
    previewEntity = null;
    trimPreview = null;
    intersectionPoints = [];
    statusMessage = 'Select cutting entity';
    selectedIntersection = null;
    highlightedEntities = [];
  }

  void updatePreviewEntity(DrawingDocument document) {
    // This is handled in the specific preview methods
  }

  @override
  Entity? getPreviewEntity(DrawingDocument document) {
    // Return the appropriate preview entity based on the current state
    if (trimPreview != null) {
      return trimPreview;
    }
    return previewEntity;
  }

  @override
  void finalizeEntity(DrawingDocument document, DocumentService documentService, BuildContext context) {
    // The trim tool doesn't create new entities directly
    // Instead, it modifies existing entities in the specific handler methods
  }

  /// Get the current status message to display to the user
  String getStatusMessage() {
    return statusMessage;
  }

  @override
  MouseCursor getCursor() {
    switch (_state) {
      case TrimState.selectCuttingEntity:
        return SystemMouseCursors.click;
      case TrimState.selectEntityToTrim:
        return SystemMouseCursors.click;
      case TrimState.selectPortionToKeep:
        return SystemMouseCursors.click;
    }
  }
}
