import 'package:flutter/material.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart' as cad_entities;
import '../services/document_service.dart';
import 'tool_interface.dart';

/// Enum for the different states of the Extend Tool
enum _ExtendToolState {
  selectingBoundary,
  selectingTarget,
}

/// Tool for extending entities to meet a boundary entity
class ExtendTool implements Tool {
  // State tracking
  _ExtendToolState _currentState = _ExtendToolState.selectingBoundary;
  cad_entities.Entity? _boundaryEntity;
  cad_entities.Entity? _previewEntity;

  // Status update callback
  final void Function(String)? onStatusUpdate;

  ExtendTool({this.onStatusUpdate});

  @override
  void onActivate() {
    _clearAndResetState();
    debugPrint('ExtendTool activated. Select boundary entity.');
  }

  @override
  void onDeactivate(DrawingDocument document, DocumentService documentService,
      BuildContext context) {
    // Clean up any state
    _clearAndResetState();
    // Clear any selections
    documentService.clearSelection();
  }

  /// Clears all state and resets to initial state
  void _clearAndResetState() {
    _currentState = _ExtendToolState.selectingBoundary;
    _boundaryEntity = null;
    _previewEntity = null;
  }

  /// Clears the state without resetting to initial state
  void clearState() {
    _boundaryEntity = null;
    _previewEntity = null;
  }

  @override
  void onPointerDown(Offset point, DrawingDocument document,
      DocumentService documentService, BuildContext context) {
    const double hitTestRadius = 5.0;

    if (_currentState == _ExtendToolState.selectingBoundary) {
      // First phase: Select boundary entity
      cad_entities.Entity? clickedBoundaryEntity;
      for (final entity in document.entities.reversed) {
        if (entity.hitTest(point, Matrix4.identity(), hitTestRadius)) {
          // For now, let's assume any entity can be a boundary.
          // Specific extend implementations will handle compatibility.
          clickedBoundaryEntity = entity;
          break;
        }
      }

      if (clickedBoundaryEntity != null) {
        _boundaryEntity = clickedBoundaryEntity;
        _currentState = _ExtendToolState.selectingTarget;
        // Update status message if callback is provided
        onStatusUpdate?.call('Boundary selected: ${_boundaryEntity?.runtimeType}. Select entity to extend.');
        debugPrint(
            'ExtendTool: Boundary entity selected (${_boundaryEntity?.id} - ${_boundaryEntity?.runtimeType}). Now select entity to extend.');
      } else {
        onStatusUpdate?.call('No boundary entity found. Select boundary entity.');
        debugPrint('ExtendTool: No boundary entity found at click point.');
      }
    } else if (_currentState == _ExtendToolState.selectingTarget) {
      // Second phase: Select target entity to extend
      if (_boundaryEntity == null) {
        _clearAndResetState();
        onStatusUpdate?.call('Error: No boundary selected. Resetting. Select boundary entity.');
        debugPrint('ExtendTool Error: No boundary selected. Resetting.');
        return;
      }

      // Find the target entity to extend
      cad_entities.Entity? targetEntity;
      for (final entity in document.entities.reversed) {
        // Skip the boundary entity itself
        if (entity.id == _boundaryEntity!.id) continue;

        if (entity.hitTest(point, Matrix4.identity(), hitTestRadius)) {
          targetEntity = entity;
          break;
        }
      }

      if (targetEntity != null) {
        final extendedEntity = targetEntity.extend([_boundaryEntity!], point);

        if (extendedEntity != null) {
          // Ensure the ID of the extended entity matches the original target entity's ID
          // The extend method in Entity subclasses should handle this (e.g., via copyWith)
          if (extendedEntity.id != targetEntity.id) {
            debugPrint(
                'ExtendTool ERROR: ID mismatch! Original: ${targetEntity.id}, Extended: ${extendedEntity.id}. Ensure copyWith preserves ID.');
            // Potentially revert or handle error, for now, we'll log and proceed cautiously
          }

          documentService.updateEntity(extendedEntity);
          _previewEntity = null; // Clear preview after successful extension
          onStatusUpdate?.call('Entity ${targetEntity.runtimeType} extended. Select entity to extend or right-click to change boundary.');
          debugPrint(
              'ExtendTool: Entity ${targetEntity.id} (${targetEntity.runtimeType}) extended successfully to boundary ${_boundaryEntity!.id} (${_boundaryEntity!.runtimeType}).');
        } else {
          onStatusUpdate?.call('Could not extend ${targetEntity.runtimeType}. No valid extension. Select entity or right-click.');
          debugPrint(
              'ExtendTool: Could not extend ${targetEntity.runtimeType} (ID: ${targetEntity.id}) to boundary ${_boundaryEntity!.id}. No valid extension found.');
        }
      } else {
        onStatusUpdate?.call('No target entity found at click. Select entity or right-click.');
        debugPrint('ExtendTool: No target entity to extend found at click point.');
      }
    }
  }

  @override
  void onPointerMove(Offset point, DrawingDocument document,
      DocumentService documentService, BuildContext context) {
    if (_currentState != _ExtendToolState.selectingTarget || _boundaryEntity == null) {
      _previewEntity = null;
      return;
    }

    const double hitTestRadius = 5.0;

    cad_entities.Entity? potentialTargetEntity;
    for (final entity in document.entities.reversed) {
      if (entity.id == _boundaryEntity!.id) continue; // Skip boundary entity itself

      if (entity.hitTest(point, Matrix4.identity(), hitTestRadius)) {
        potentialTargetEntity = entity;
        break;
      }
    }

    if (potentialTargetEntity != null) {
      // Try to generate a preview of the extension
      final previewExtendedEntity = potentialTargetEntity.extend([_boundaryEntity!], point);

      if (previewExtendedEntity != null) {
        // Apply a distinct style for the preview
        _previewEntity = previewExtendedEntity.copyWith(
          color: Colors.blue.withOpacity(0.7),
          lineWidth: (previewExtendedEntity.lineWidth) + 0.5, // Slightly thicker
        );
        // debugPrint('[ExtendTool.onPointerMove] Showing preview for ${potentialTargetEntity.runtimeType} to ${_boundaryEntity!.runtimeType}');
      } else {
        _previewEntity = null;
      }
    } else {
      _previewEntity = null;
    }
  }

  @override
  void onPointerUp(Offset point, DrawingDocument document,
      DocumentService documentService, BuildContext context) {
    // The extend operation is handled in onPointerDown, so we don't need to do anything here
  }

  @override
  cad_entities.Entity? getPreviewEntity(DrawingDocument document) {
    return _previewEntity;
  }

  @override
  MouseCursor getCursor() {
    return SystemMouseCursors.precise; // Precision cursor for CAD operations
  }

  @override
  void handleRightClick(DrawingDocument document) {
    // Reset tool state on right-click, allowing user to select a new boundary
    _clearAndResetState();
    onStatusUpdate?.call('Boundary selection reset. Select new boundary entity.');
    debugPrint(
        'ExtendTool: Right-click detected, resetting to boundary selection mode.');
  }

  @override
  void finalizeEntity(DrawingDocument document, DocumentService documentService,
      BuildContext context) {
    // The extend operation is handled in onPointerDown, no finalization needed
  }

  @override
  void onScaleEnd(ScaleEndDetails details) {
    // Not used for this tool
  }

  @override
  void onScaleStart(ScaleStartDetails details) {
    // Not used for this tool
  }

  @override
  void onScaleUpdate(ScaleUpdateDetails details, Matrix4 transform) {
    // Not used for this tool
  }
}
