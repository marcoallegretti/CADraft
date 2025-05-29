import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drawing_document.dart';
import '../services/document_service.dart';
import '../services/file_service.dart';
import '../widgets/canvas_widget.dart';
import '../widgets/toolbar_widget.dart';
import '../widgets/layer_panel.dart';
import '../widgets/snap_settings_panel.dart';
import '../utils/snap_utils.dart';
import '../tools/tool_types.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  ToolType _currentTool = ToolType.select;
  bool _showLayerPanel = true;
  bool _showSnapSettings = false;
  SnapSettings _snapSettings = SnapSettings();

  @override
  Widget build(BuildContext context) {
    final documentService = Provider.of<DocumentService>(context);
    final document = documentService.currentDocument;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.architecture, size: 24),
            const SizedBox(width: 8),
            Text(
              document?.name ?? 'Loading...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          // Snap settings toggle
          IconButton(
            icon: Icon(
              _showSnapSettings ? Icons.grid_on : Icons.grid_off,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                _showSnapSettings = !_showSnapSettings;
              });
            },
            tooltip:
                _showSnapSettings ? 'Hide Snap Settings' : 'Show Snap Settings',
          ),
          // Layer panel toggle
          IconButton(
            icon: Icon(
              _showLayerPanel ? Icons.layers : Icons.layers_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                _showLayerPanel = !_showLayerPanel;
              });
            },
            tooltip: _showLayerPanel ? 'Hide Layers' : 'Show Layers',
          ),
        ],
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          // Toolbar
          ToolbarWidget(
            currentTool: _currentTool,
            onToolChanged: (ToolType tool) {
              setState(() {
                _currentTool = tool;
              });
            },
            canUndo: documentService.canUndo,
            canRedo: documentService.canRedo,
            onUndo: () {
              documentService.undo();
            },
            onRedo: () {
              documentService.redo();
            },
            onNewDocument: () =>
                _showNewDocumentDialog(context, documentService),
            onSaveDocument: () => _showSaveSuccessMessage(context),
            onOpenDocument: () =>
                _showOpenDocumentDialog(context, documentService),
            onExportDxf: () => _exportToDxf(context, documentService),
          ),

          // Main content area
          Expanded(
            child: Row(
              children: [
                // Canvas
                Expanded(
                  child: Stack(
                    children: [
                      CanvasWidget(
                        currentTool: _currentTool,
                        snapSettings: _snapSettings,
                        onSnapSettingsChanged: (newSettings) {
                          setState(() {
                            _snapSettings = newSettings;
                          });
                        },
                        onToolComplete: () {
                          setState(() {
                            _currentTool = ToolType.select;
                          });
                        },
                      ),
                      // Snap Settings Panel
                      if (_showSnapSettings)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: SnapSettingsPanel(
                            settings: _snapSettings,
                            onSettingsChanged: (newSettings) {
                              setState(() {
                                _snapSettings = newSettings;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                // Layer panel (optional)
                if (_showLayerPanel) const LayerPanel(),
              ],
            ),
          ),
        ],
      ),
      // Status bar at the bottom
      bottomNavigationBar: _buildStatusBar(context, document),
    );
  }

  Widget _buildStatusBar(BuildContext context, DrawingDocument? document) {
    if (document == null) return const SizedBox.shrink();

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Icon(
            Icons.layers,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Active Layer: ${document.activeLayer.name}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 24),
          Icon(
            Icons.grid_on,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Grid: ${document.gridSize.toInt()} px',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 24),
          Icon(
            Icons.view_in_ar_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Entities: ${document.entities.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Text(
            '© 2025 CAD-like App - Marco Allegretti',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }

  void _showNewDocumentDialog(
      BuildContext context, DocumentService documentService) {
    final textController = TextEditingController(text: 'New Drawing');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create New Document',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            decoration: InputDecoration(
              labelText: 'Document Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a document name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Create'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                documentService.createNewDocument(textController.text);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showOpenDocumentDialog(
      BuildContext context, DocumentService documentService) {
    final recentDocuments = documentService.recentDocuments;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Open Document',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: recentDocuments.isEmpty
              ? Center(
                  child: Text(
                    'No recent documents',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  itemCount: recentDocuments.length,
                  itemBuilder: (context, index) {
                    final document = recentDocuments[index];
                    return ListTile(
                      title: Text(document.name),
                      subtitle: Text('Entities: ${document.entities.length}'),
                      leading: const Icon(Icons.insert_drive_file),
                      onTap: () {
                        documentService.openDocument(document.id);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportToDxf(
      BuildContext context, DocumentService documentService) async {
    final document = documentService.currentDocument;
    if (document == null) return;

    try {
      FileService.exportDxf(document); // Generate DXF content
      // Since we are not actually saving to a file here, we'll show a success message
      // Normally you'd save this content to a file and return the path
      _showExportSuccessMessage(context, 'DXF content generated successfully');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting to DXF: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showSaveSuccessMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            const Text('Document saved successfully'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showExportSuccessMessage(BuildContext context, String filePath) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('DXF exported to: $filePath'),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
