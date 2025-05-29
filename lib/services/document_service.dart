import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';

class DocumentService extends ChangeNotifier {
  DocumentService() {
    _initialize();
  }

  // Current document
  DrawingDocument? _currentDocument;
  DrawingDocument? get currentDocument => _currentDocument;

  // Document history for undo/redo
  final List<DrawingDocument> _undoStack = [];
  final List<DrawingDocument> _redoStack = [];
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // Recently opened documents
  List<DrawingDocument> _recentDocuments = [];
  List<DrawingDocument> get recentDocuments => _recentDocuments;

  // Constants
  static const _currentDocumentKey = 'current_document';
  static const _recentDocumentsKey = 'recent_documents';
  static const _maxUndoStackSize = 50;
  static const _maxRecentDocuments = 10;

  /// Initialize the service by loading saved data
  Future<void> _initialize() async {
    await _loadRecentDocuments();
    await _loadCurrentDocument();
    notifyListeners();
  }

  /// Load the most recently used document
  Future<void> _loadCurrentDocument() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_currentDocumentKey);
      
      if (jsonString != null) {
        _currentDocument = DrawingDocument.fromJsonString(jsonString);
      } else {
        _currentDocument = DrawingDocument.empty();
      }
    } catch (e) {
      // In case of error, create a new empty document
      _currentDocument = DrawingDocument.empty();
    }
  }

  /// Load the list of recently opened documents
  Future<void> _loadRecentDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_recentDocumentsKey);
      
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _recentDocuments = jsonList
            .map((json) => DrawingDocument.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _recentDocuments = [];
    }
  }

  /// Save the current document
  Future<void> _saveCurrentDocument() async {
    if (_currentDocument == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _currentDocumentKey, 
        _currentDocument!.toJsonString(),
      );
      
      // Update recent documents list
      _updateRecentDocuments(_currentDocument!);
      
    } catch (e) {
      debugPrint('Error saving document: $e');
    }
  }

  /// Update the list of recent documents
  Future<void> _updateRecentDocuments(DrawingDocument document) async {
    try {
      // Remove this document if it already exists in the list
      _recentDocuments.removeWhere((doc) => doc.id == document.id);
      
      // Add at the beginning
      _recentDocuments.insert(0, document);
      
      // Limit the number of recent documents
      if (_recentDocuments.length > _maxRecentDocuments) {
        _recentDocuments = _recentDocuments.sublist(0, _maxRecentDocuments);
      }
      
      // Save the updated list
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _recentDocuments.map((doc) => doc.toJson()).toList();
      await prefs.setString(_recentDocumentsKey, jsonEncode(jsonList));
      
    } catch (e) {
      debugPrint('Error updating recent documents: $e');
    }
  }

  /// Create a new document
  Future<void> createNewDocument(String name) async {
    // Save the current state to undo history
    if (_currentDocument != null) {
      _saveToUndoStack(_currentDocument!);
    }
    
    // Create a new document
    _currentDocument = DrawingDocument.empty().copyWith(name: name);
    _redoStack.clear();
    
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Open an existing document by ID
  Future<void> openDocument(String documentId) async {
    try {
      // Find the document in recent documents
      final document = _recentDocuments.firstWhere((doc) => doc.id == documentId);
      
      // Save the current state to undo history
      if (_currentDocument != null) {
        _saveToUndoStack(_currentDocument!);
      }
      
      _currentDocument = document;
      _redoStack.clear();
      
      await _saveCurrentDocument();
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error opening document: $e');
    }
  }

  /// Add an entity to the document
  Future<void> addEntity(Entity entity) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.addEntity(entity);
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Remove an entity from the document
  Future<void> removeEntity(String entityId) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.removeEntity(entityId);
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Update an entity in the document
  Future<void> updateEntity(Entity updatedEntity) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.updateEntity(updatedEntity);
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Add a layer to the document
  Future<void> addLayer(Layer layer) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.addLayer(layer);
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Remove a layer from the document
  Future<void> removeLayer(String layerId) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.removeLayer(layerId);
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Update a layer in the document
  Future<void> updateLayer(Layer updatedLayer) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.updateLayer(updatedLayer);
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Set the active layer
  Future<void> setActiveLayer(String layerId) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.setActiveLayer(layerId);
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Select an entity in the document
  Future<void> selectEntity(String entityId, {bool clearOthers = true}) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.selectEntity(entityId, clearOthers: clearOthers);
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Clear the selection of all entities
  Future<void> clearSelection() async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.clearSelection();
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Undo the last operation
  Future<void> undo() async {
    if (!canUndo || _currentDocument == null) return;
    
    // Save current state to redo stack
    _redoStack.add(_currentDocument!);
    
    // Restore previous state
    _currentDocument = _undoStack.removeLast();
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Redo the last undone operation
  Future<void> redo() async {
    if (!canRedo || _currentDocument == null) return;
    
    // Save current state to undo stack
    _undoStack.add(_currentDocument!);
    
    // Restore next state
    _currentDocument = _redoStack.removeLast();
    await _saveCurrentDocument();
    notifyListeners();
  }

  /// Save the document to the undo stack
  void _saveToUndoStack(DrawingDocument document) {
    _undoStack.add(document);
    
    // Limit the size of the undo stack
    if (_undoStack.length > _maxUndoStackSize) {
      _undoStack.removeAt(0);
    }
    
    // Clear the redo stack when a new action is performed
    _redoStack.clear();
  }

  /// Update document settings
  Future<void> updateSettings({
    bool? showGrid,
    bool? snapToGrid,
    double? gridSize,
  }) async {
    if (_currentDocument == null) return;
    
    _saveToUndoStack(_currentDocument!);
    
    _currentDocument = _currentDocument!.copyWith(
      showGrid: showGrid,
      snapToGrid: snapToGrid,
      gridSize: gridSize,
    );
    
    await _saveCurrentDocument();
    notifyListeners();
  }
}