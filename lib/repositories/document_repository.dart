import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drawing_document.dart';

/// Repository for document-related data operations
/// This class handles the persistence and retrieval of drawing documents
class DocumentRepository {
  // Constants
  static const _currentDocumentKey = 'current_document';
  static const _recentDocumentsKey = 'recent_documents';
  static const _maxRecentDocuments = 10;

  /// Load the current document from persistent storage
  Future<DrawingDocument?> loadCurrentDocument() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_currentDocumentKey);
      
      if (jsonString != null) {
        return DrawingDocument.fromJsonString(jsonString);
      } else {
        // Return an empty document if none exists
        return DrawingDocument.empty();
      }
    } catch (e) {
      debugPrint('Error loading current document: $e');
      // In case of error, create a new empty document
      return DrawingDocument.empty();
    }
  }

  /// Load the list of recently opened documents
  Future<List<DrawingDocument>> loadRecentDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recentDocumentsKey);
      
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        return jsonList
            .map((json) => DrawingDocument.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading recent documents: $e');
    }
    return [];
  }

  /// Save the current document to persistent storage
  Future<void> saveCurrentDocument(DrawingDocument document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _currentDocumentKey, 
        document.toJsonString(),
      );
      
      // Update recent documents list
      await updateRecentDocuments(document);
      
    } catch (e) {
      debugPrint('Error saving document: $e');
    }
  }

  /// Update the list of recent documents
  Future<void> updateRecentDocuments(DrawingDocument document) async {
    try {
      // Load current recent documents
      final recentDocs = await loadRecentDocuments();
      
      // Remove this document if it already exists in the list
      recentDocs.removeWhere((doc) => doc.id == document.id);
      
      // Add at the beginning
      recentDocs.insert(0, document);
      
      // Limit the number of recent documents
      final limitedDocs = recentDocs.length > _maxRecentDocuments 
          ? recentDocs.sublist(0, _maxRecentDocuments) 
          : recentDocs;
      
      // Save the updated list
      final prefs = await SharedPreferences.getInstance();
      final jsonList = limitedDocs.map((doc) => doc.toJson()).toList();
      await prefs.setString(_recentDocumentsKey, jsonEncode(jsonList));
      
    } catch (e) {
      debugPrint('Error updating recent documents: $e');
    }
  }
}
