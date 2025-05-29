import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drawing_document.dart';
import '../services/document_service.dart';

class LayerPanel extends StatefulWidget {
  const LayerPanel({super.key});

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  final _newLayerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _newLayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documentService = Provider.of<DocumentService>(context);
    final document = documentService.currentDocument;

    if (document == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      width: 250,
      height: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                'Layers',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => _showAddLayerDialog(context, documentService),
                tooltip: 'Add Layer',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Layer statistics
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${document.layers.length} ${document.layers.length == 1 ? 'layer' : 'layers'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${document.layers.where((l) => l.isVisible).length} visible',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                // Button to toggle all layers
                InkWell(
                  onTap: () {
                    final allVisible =
                        document.layers.every((layer) => layer.isVisible);
                    // If all are visible, hide all except active. If some are hidden, show all.
                    for (final layer in document.layers) {
                      if (allVisible) {
                        // Keep only active layer visible
                        if (layer.id != document.activeLayerId &&
                            layer.isVisible) {
                          documentService
                              .updateLayer(layer.copyWith(isVisible: false));
                        }
                      } else {
                        // Make all layers visible
                        if (!layer.isVisible) {
                          documentService
                              .updateLayer(layer.copyWith(isVisible: true));
                        }
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: [
                        Icon(
                          document.layers.every((layer) => layer.isVisible)
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          document.layers.every((layer) => layer.isVisible)
                              ? 'Hide All'
                              : 'Show All',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Layer list
          SizedBox(
            height: 300, // Fixed height for the layer list
            child: document.layers.isEmpty
                ? Center(
                    child: Text(
                      'No layers available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                  )
                : ListView.builder(
                    itemCount: document.layers.length,
                    itemBuilder: (context, index) {
                      final layer = document.layers[index];
                      final isActive = layer.id == document.activeLayerId;

                      return _buildLayerTile(
                        context,
                        layer,
                        isActive,
                        documentService,
                        document,
                      );
                    },
                  ),
          ),

          // Grid settings
          const SizedBox(height: 16),
          Text(
            'Grid Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(
              'Show Grid',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: document.showGrid,
            onChanged: (value) {
              documentService.updateSettings(showGrid: value);
            },
            dense: true,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          SwitchListTile(
            title: Text(
              'Snap to Grid',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            value: document.snapToGrid,
            onChanged: (value) {
              documentService.updateSettings(snapToGrid: value);
            },
            dense: true,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Grid Size:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Slider(
                  value: document.gridSize,
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: document.gridSize.round().toString(),
                  onChanged: (value) {
                    documentService.updateSettings(gridSize: value);
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildLayerTile(
    BuildContext context,
    Layer layer,
    bool isActive,
    DocumentService documentService,
    DrawingDocument document,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              layer.name,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color:
                        isActive ? colorScheme.primary : colorScheme.onSurface,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Color indicator
                Stack(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: layer.isVisible
                            ? layer.color
                            : layer.color.withOpacity(0.3),
                        border: Border.all(
                          color: colorScheme.onSurface.withOpacity(0.2),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    if (!layer.isVisible)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.visibility_off,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Visibility toggle
                IconButton(
                  icon: Icon(
                    layer.isVisible ? Icons.visibility : Icons.visibility_off,
                    color: layer.isVisible
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.4),
                    size: 20,
                  ),
                  onPressed: () {
                    final updatedLayer = layer.copyWith(
                      isVisible: !layer.isVisible,
                    );
                    documentService.updateLayer(updatedLayer);
                  },
                  tooltip: layer.isVisible ? 'Hide Layer' : 'Show Layer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                // Delete button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  onPressed: document.layers.length > 1
                      ? () =>
                          _confirmDeleteLayer(context, layer, documentService)
                      : null,
                  tooltip: 'Delete Layer',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            onTap: () {
              if (layer.id != document.activeLayerId) {
                documentService.setActiveLayer(layer.id);
              }
            },
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            dense: true,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          // Layer visibility indicator
          if (!layer.isVisible)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                'Layer Hidden',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _showAddLayerDialog(
      BuildContext context, DocumentService documentService) {
    _newLayerController.clear();
    Color selectedColor = Colors.white;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Add New Layer',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _newLayerController,
                    decoration: InputDecoration(
                      labelText: 'Layer Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a layer name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Layer Color:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          _showColorPicker(context, selectedColor, (color) {
                            setState(() {
                              selectedColor = color;
                            });
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                child: const Text('Add'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final layer = Layer(
                      name: _newLayerController.text,
                      color: selectedColor,
                      isVisible: true,
                    );
                    documentService.addLayer(layer);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color currentColor,
      Function(Color) onColorSelected) {
    // Simple color picker with predefined colors
    final colors = [
      Colors.white,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Color',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: Container(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              return GestureDetector(
                onTap: () {
                  onColorSelected(color);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: color == currentColor
                      ? Icon(
                          Icons.check,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteLayer(
      BuildContext context, Layer layer, DocumentService documentService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Layer',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Text(
          'Are you sure you want to delete the layer "${layer.name}"? All entities on this layer will be deleted.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
            onPressed: () {
              documentService.removeLayer(layer.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
