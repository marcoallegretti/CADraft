import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'entities.dart';

/// Represents a layer in the drawing document
class Layer {
  Layer({
    required this.name,
    required this.color,
    required this.isVisible,
    String? id,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final Color color;
  final bool isVisible;

  Layer copyWith({
    String? name,
    Color? color,
    bool? isVisible,
  }) {
    return Layer(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'isVisible': isVisible,
    };
  }

  factory Layer.fromJson(Map<String, dynamic> json) {
    return Layer(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      isVisible: json['isVisible'] as bool,
    );
  }
}

/// Represents a complete drawing document including entities and layers
class DrawingDocument {
  DrawingDocument({
    required this.name,
    required this.entities,
    required this.layers,
    required this.activeLayerId,
    String? id,
    this.gridSize = 10.0,
    this.showGrid = true,
    this.snapToGrid = true,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final List<Entity> entities;
  final List<Layer> layers;
  final String activeLayerId;
  final double gridSize;
  final bool showGrid;
  final bool snapToGrid;

  /// Creates a default empty document
  factory DrawingDocument.empty() {
    final defaultLayer = Layer(
      name: 'Default',
      color: Colors.white,
      isVisible: true,
    );

    return DrawingDocument(
      name: 'Untitled Drawing',
      entities: [],
      layers: [defaultLayer],
      activeLayerId: defaultLayer.id,
    );
  }

  /// Get the currently active layer
  Layer get activeLayer {
    return layers.firstWhere(
      (layer) => layer.id == activeLayerId,
      orElse: () => layers.first,
    );
  }

  /// Get all visible entities
  List<Entity> get visibleEntities {
    final visibleLayerIds = layers
        .where((layer) => layer.isVisible)
        .map((layer) => layer.id)
        .toSet();

    return entities
        .where((entity) => visibleLayerIds.contains(entity.layer))
        .toList();
  }

  /// Get the entity with the given ID, if it exists
  Entity? getEntityById(String id) {
    try {
      return entities.firstWhere((entity) => entity.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Add an entity to the document
  DrawingDocument addEntity(Entity entity) {
    return copyWith(entities: [...entities, entity]);
  }

  /// Remove an entity from the document
  DrawingDocument removeEntity(String entityId) {
    return copyWith(
      entities: entities.where((entity) => entity.id != entityId).toList(),
    );
  }

  /// Update an entity in the document
  DrawingDocument updateEntity(Entity updatedEntity) {
    return copyWith(
      entities: entities.map((entity) {
        if (entity.id == updatedEntity.id) {
          return updatedEntity;
        }
        return entity;
      }).toList(),
    );
  }

  /// Add a new layer to the document
  DrawingDocument addLayer(Layer layer) {
    return copyWith(layers: [...layers, layer]);
  }

  /// Remove a layer from the document
  DrawingDocument removeLayer(String layerId) {
    // Don't remove the last layer
    if (layers.length <= 1) {
      return this;
    }

    // Remove all entities on this layer
    final updatedEntities = entities.where(
      (entity) => entity.layer != layerId,
    ).toList();

    // Update active layer if needed
    String newActiveLayerId = activeLayerId;
    if (activeLayerId == layerId) {
      newActiveLayerId = layers
          .where((layer) => layer.id != layerId)
          .first
          .id;
    }

    return copyWith(
      layers: layers.where((layer) => layer.id != layerId).toList(),
      entities: updatedEntities,
      activeLayerId: newActiveLayerId,
    );
  }

  /// Update a layer in the document
  DrawingDocument updateLayer(Layer updatedLayer) {
    return copyWith(
      layers: layers.map((layer) {
        if (layer.id == updatedLayer.id) {
          return updatedLayer;
        }
        return layer;
      }).toList(),
    );
  }

  /// Set the active layer
  DrawingDocument setActiveLayer(String layerId) {
    return copyWith(activeLayerId: layerId);
  }

  /// Clear the selection of all entities
  DrawingDocument clearSelection() {
    return copyWith(
      entities: entities.map((entity) {
        if (entity.isSelected) {
          return entity.copyWith(isSelected: false);
        }
        return entity;
      }).toList(),
    );
  }

  /// Select an entity by ID
  DrawingDocument selectEntity(String entityId, {bool clearOthers = true}) {
    return copyWith(
      entities: entities.map((entity) {
        if (entity.id == entityId) {
          return entity.copyWith(isSelected: true);
        } else if (clearOthers && entity.isSelected) {
          return entity.copyWith(isSelected: false);
        }
        return entity;
      }).toList(),
    );
  }

  /// Select multiple entities by IDs
  DrawingDocument selectEntities(List<String> entityIds, {bool clearOthers = true}) {
    return copyWith(
      entities: entities.map((entity) {
        if (entityIds.contains(entity.id)) {
          return entity.copyWith(isSelected: true);
        } else if (clearOthers && entity.isSelected) {
          return entity.copyWith(isSelected: false);
        }
        return entity;
      }).toList(),
    );
  }

  /// Get all currently selected entities
  List<Entity> get selectedEntities {
    return entities.where((entity) => entity.isSelected).toList();
  }

  /// Create a copy with updated properties
  DrawingDocument copyWith({
    String? name,
    List<Entity>? entities,
    List<Layer>? layers,
    String? activeLayerId,
    double? gridSize,
    bool? showGrid,
    bool? snapToGrid,
  }) {
    return DrawingDocument(
      id: id,
      name: name ?? this.name,
      entities: entities ?? this.entities,
      layers: layers ?? this.layers,
      activeLayerId: activeLayerId ?? this.activeLayerId,
      gridSize: gridSize ?? this.gridSize,
      showGrid: showGrid ?? this.showGrid,
      snapToGrid: snapToGrid ?? this.snapToGrid,
    );
  }

  /// Convert the document to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'entities': entities.map((entity) => entity.toJson()).toList(),
      'layers': layers.map((layer) => layer.toJson()).toList(),
      'activeLayerId': activeLayerId,
      'gridSize': gridSize,
      'showGrid': showGrid,
      'snapToGrid': snapToGrid,
    };
  }

  /// Create a document from JSON
  factory DrawingDocument.fromJson(Map<String, dynamic> json) {
    return DrawingDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      entities: (json['entities'] as List).map((e) => 
        Entity.fromJson(e as Map<String, dynamic>)
      ).toList(),
      layers: (json['layers'] as List).map((e) => 
        Layer.fromJson(e as Map<String, dynamic>)
      ).toList(),
      activeLayerId: json['activeLayerId'] as String,
      gridSize: json['gridSize'] as double,
      showGrid: json['showGrid'] as bool,
      snapToGrid: json['snapToGrid'] as bool,
    );
  }

  /// Serialize document to string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Create document from serialized string
  factory DrawingDocument.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return DrawingDocument.fromJson(json);
  }
}