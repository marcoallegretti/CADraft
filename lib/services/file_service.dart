import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';

/// Handles file operations for the CAD application
class FileService {
  /// Saves a document to shared preferences
  static Future<void> saveDocument(DrawingDocument document,
      [String? name]) async {
    final prefs = await SharedPreferences.getInstance();

    // Generate a filename if not provided
    final filename = name ?? document.name;
    document = document.copyWith(name: filename);

    // Convert document to JSON and save
    final json = jsonEncode(document.toJson());
    await prefs.setString('drawing_$filename', json);

    // Update recent files list
    final recentFiles = prefs.getStringList('recent_files') ?? <String>[];
    if (!recentFiles.contains(filename)) {
      recentFiles.insert(0, filename);
      // Keep only the most recent 10 files
      if (recentFiles.length > 10) {
        recentFiles.removeLast();
      }
      await prefs.setStringList('recent_files', recentFiles);
    }
  }

  /// Loads a document from shared preferences
  static Future<DrawingDocument?> loadDocument(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('drawing_$name');

    if (json == null) {
      return null;
    }

    try {
      final Map<String, dynamic> data = jsonDecode(json);
      return DrawingDocument.fromJson(data);
    } catch (e) {
      debugPrint('Error loading document: $e');
      return null;
    }
  }

  /// Gets a list of recent files
  static Future<List<String>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recent_files') ?? <String>[];
  }

  /// Deletes a document from shared preferences
  static Future<void> deleteDocument(String name) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove the document
    await prefs.remove('drawing_$name');

    // Update recent files list
    final recentFiles = prefs.getStringList('recent_files') ?? <String>[];
    recentFiles.remove(name);
    await prefs.setStringList('recent_files', recentFiles);
  }

  /// Exports a document to DXF format
  static String exportDxf(DrawingDocument document) {
    final buffer = StringBuffer();

    // DXF header
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('HEADER');
    buffer.writeln('0');
    buffer.writeln('ENDSEC');

    // Tables section (layers)
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('TABLES');
    buffer.writeln('0');
    buffer.writeln('TABLE');
    buffer.writeln('2');
    buffer.writeln('LAYER');
    buffer.writeln('0');

    // Define layers
    for (final layer in document.layers) {
      buffer.writeln('LAYER');
      buffer.writeln('2');
      buffer.writeln(layer.name);
      buffer.writeln('70');
      buffer.writeln('0');
      buffer.writeln('62');

      // Convert Flutter color to AutoCAD color index (approximate)
      final colorIndex = (layer.color.red ~/ 32) * 36 +
          (layer.color.green ~/ 32) * 6 +
          (layer.color.blue ~/ 32) +
          1;
      buffer.writeln(colorIndex.toString());

      buffer.writeln('6');
      buffer.writeln('CONTINUOUS');
      buffer.writeln('0');
    }

    buffer.writeln('ENDTAB');
    buffer.writeln('0');
    buffer.writeln('ENDSEC');

    // Entities section
    buffer.writeln('0');
    buffer.writeln('SECTION');
    buffer.writeln('2');
    buffer.writeln('ENTITIES');

    // Write each entity
    for (final entity in document.entities) {
      if (entity is LineEntity) {
        _writeDxfLine(buffer, entity, document);
      } else if (entity is CircleEntity) {
        _writeDxfCircle(buffer, entity, document);
      } else if (entity is RectangleEntity) {
        _writeDxfRectangle(buffer, entity, document);
      } else if (entity is ArcEntity) {
        _writeDxfArc(buffer, entity, document);
      }
    }

    buffer.writeln('0');
    buffer.writeln('ENDSEC');

    // End of file
    buffer.writeln('0');
    buffer.writeln('EOF');

    return buffer.toString();
  }

  /// Write a line entity to the DXF buffer
  static void _writeDxfLine(
      StringBuffer buffer, LineEntity line, DrawingDocument document) {
    // Find the layer for this entity
    final layer = document.layers.firstWhere(
      (layer) => layer.id == line.layer,
      orElse: () => document.layers.first,
    );

    buffer.writeln('0');
    buffer.writeln('LINE');
    buffer.writeln('8');
    buffer.writeln(layer.name); // Layer name
    buffer.writeln('10');
    buffer.writeln(line.start.dx.toString()); // Start X
    buffer.writeln('20');
    buffer.writeln(line.start.dy.toString()); // Start Y
    buffer.writeln('30');
    buffer.writeln('0.0'); // Start Z
    buffer.writeln('11');
    buffer.writeln(line.end.dx.toString()); // End X
    buffer.writeln('21');
    buffer.writeln(line.end.dy.toString()); // End Y
    buffer.writeln('31');
    buffer.writeln('0.0'); // End Z
  }

  /// Write a circle entity to the DXF buffer
  static void _writeDxfCircle(
      StringBuffer buffer, CircleEntity circle, DrawingDocument document) {
    // Find the layer for this entity
    final layer = document.layers.firstWhere(
      (layer) => layer.id == circle.layer,
      orElse: () => document.layers.first,
    );

    buffer.writeln('0');
    buffer.writeln('CIRCLE');
    buffer.writeln('8');
    buffer.writeln(layer.name); // Layer name
    buffer.writeln('10');
    buffer.writeln(circle.center.dx.toString()); // Center X
    buffer.writeln('20');
    buffer.writeln(circle.center.dy.toString()); // Center Y
    buffer.writeln('30');
    buffer.writeln('0.0'); // Center Z
    buffer.writeln('40');
    buffer.writeln(circle.radius.toString()); // Radius
  }

  /// Write a rectangle entity to the DXF buffer
  static void _writeDxfRectangle(
      StringBuffer buffer, RectangleEntity rect, DrawingDocument document) {
    // Find the layer for this entity
    final layer = document.layers.firstWhere(
      (layer) => layer.id == rect.layer,
      orElse: () => document.layers.first,
    );

    // A rectangle in DXF is typically represented as a polyline with 4 vertices
    buffer.writeln('0');
    buffer.writeln('POLYLINE');
    buffer.writeln('8');
    buffer.writeln(layer.name); // Layer name
    buffer.writeln('66');
    buffer.writeln('1'); // Vertices follow
    buffer.writeln('70');
    buffer.writeln('1'); // Closed polyline

    // Top-left vertex
    buffer.writeln('0');
    buffer.writeln('VERTEX');
    buffer.writeln('8');
    buffer.writeln(layer.name);
    buffer.writeln('10');
    buffer.writeln(rect.topLeft.dx.toString());
    buffer.writeln('20');
    buffer.writeln(rect.topLeft.dy.toString());
    buffer.writeln('30');
    buffer.writeln('0.0');

    // Top-right vertex
    buffer.writeln('0');
    buffer.writeln('VERTEX');
    buffer.writeln('8');
    buffer.writeln(layer.name);
    buffer.writeln('10');
    buffer.writeln(rect.bottomRight.dx.toString());
    buffer.writeln('20');
    buffer.writeln(rect.topLeft.dy.toString());
    buffer.writeln('30');
    buffer.writeln('0.0');

    // Bottom-right vertex
    buffer.writeln('0');
    buffer.writeln('VERTEX');
    buffer.writeln('8');
    buffer.writeln(layer.name);
    buffer.writeln('10');
    buffer.writeln(rect.bottomRight.dx.toString());
    buffer.writeln('20');
    buffer.writeln(rect.bottomRight.dy.toString());
    buffer.writeln('30');
    buffer.writeln('0.0');

    // Bottom-left vertex
    buffer.writeln('0');
    buffer.writeln('VERTEX');
    buffer.writeln('8');
    buffer.writeln(layer.name);
    buffer.writeln('10');
    buffer.writeln(rect.topLeft.dx.toString());
    buffer.writeln('20');
    buffer.writeln(rect.bottomRight.dy.toString());
    buffer.writeln('30');
    buffer.writeln('0.0');

    // End polyline
    buffer.writeln('0');
    buffer.writeln('SEQEND');
  }

  /// Write an arc entity to the DXF buffer
  static void _writeDxfArc(
      StringBuffer buffer, ArcEntity arc, DrawingDocument document) {
    // Find the layer for this entity
    final layer = document.layers.firstWhere(
      (layer) => layer.id == arc.layer,
      orElse: () => document.layers.first,
    );

    buffer.writeln('0');
    buffer.writeln('ARC');
    buffer.writeln('8');
    buffer.writeln(layer.name); // Layer name
    buffer.writeln('10');
    buffer.writeln(arc.center.dx.toString()); // Center X
    buffer.writeln('20');
    buffer.writeln(arc.center.dy.toString()); // Center Y
    buffer.writeln('30');
    buffer.writeln('0.0'); // Center Z
    buffer.writeln('40');
    buffer.writeln(arc.radius.toString()); // Radius

    // Convert radians to degrees for DXF format
    final startAngleDeg = (arc.startAngle * 180 / pi) % 360;
    final endAngleDeg = (arc.endAngle * 180 / pi) % 360;

    buffer.writeln('50');
    buffer.writeln(startAngleDeg.toString()); // Start angle in degrees
    buffer.writeln('51');
    buffer.writeln(endAngleDeg.toString()); // End angle in degrees
  }
}
