// Canvas widget implementation
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/canvas_controller.dart';
import '../models/drawing_document.dart';
import '../models/entities.dart';
import '../services/document_service.dart';
import '../tools/tool_types.dart';
import '../utils/geometry_utils.dart';
import '../utils/snap_utils.dart';
import 'coordinate_display.dart';
import 'zoom_controls.dart';

class CanvasWidget extends StatefulWidget {
  const CanvasWidget({
    super.key,
    required this.currentTool,
    required this.onToolComplete,
    this.snapSettings,
    this.onSnapSettingsChanged,
  });

  final ToolType currentTool;
  final VoidCallback onToolComplete;
  final SnapSettings? snapSettings;
  final Function(SnapSettings)? onSnapSettingsChanged;

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
  // Canvas controller to manage state and interactions
  late CanvasController _controller;

  // State for tracking mouse position for coordinate display
  bool _showCoordinates = true;

  @override
  void initState() {
    super.initState();

    // Initialize the canvas controller
    _controller = CanvasController(
      initialSnapSettings: widget.snapSettings,
      onToolComplete: widget.onToolComplete,
    );
  }

  @override
  void didUpdateWidget(CanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update the controller when the tool changes
    if (oldWidget.currentTool != widget.currentTool) {
      final document =
          Provider.of<DocumentService>(context, listen: false).currentDocument;
      if (document != null) {
        _controller.setToolType(widget.currentTool, document,
            Provider.of<DocumentService>(context, listen: false), context);
      }
    }

    // Update snap settings if provided from outside
    if (widget.snapSettings != null &&
        widget.snapSettings != _controller.snapSettings) {
      _controller.updateSnapSettings(widget.snapSettings!);

      // Notify parent widget if callback is provided
      if (widget.onSnapSettingsChanged != null) {
        widget.onSnapSettingsChanged!(_controller.snapSettings);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentService>(builder: (context, documentService, _) {
      final document = documentService.currentDocument;
      if (document == null) {
        return const Center(child: CircularProgressIndicator());
      }

      // The tool type is set in the controller via didUpdateWidget when widget.currentTool changes.
      // Calling it here on every build causes the tool's onActivate to be called repeatedly.

      // Check if there are any hidden layers
      final hasHiddenLayers = document.layers.any((layer) => !layer.isVisible);
      final hiddenLayerCount =
          document.layers.where((layer) => !layer.isVisible).length;
      // Calculate hidden entity count - being careful about layers that might not exist
      final hiddenEntityCount = document.entities.where((entity) {
        final layerForEntity =
            document.layers.where((layer) => layer.id == entity.layer).toList();
        if (layerForEntity.isEmpty) return false; // Layer doesn't exist
        return !layerForEntity.first.isVisible; // Check if the layer is hidden
      }).length;

      return Focus(
          autofocus: true,
          onKey: (FocusNode node, RawKeyEvent event) {
            // Handle keyboard shortcuts for zoom
            if (event is RawKeyDownEvent) {
              if (event.isControlPressed) {
                if (event.logicalKey.keyLabel == '+' ||
                    event.logicalKey.keyLabel == '=') {
                  setState(() => _controller.zoomIn());
                  return KeyEventResult.handled;
                } else if (event.logicalKey.keyLabel == '-') {
                  setState(() => _controller.zoomOut());
                  return KeyEventResult.handled;
                } else if (event.logicalKey.keyLabel == '0') {
                  setState(() => _controller.resetZoom());
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerDown: (event) =>
                _handlePointerDown(event, document, documentService),
            onPointerMove: (event) =>
                _handlePointerMove(event, document, documentService),
            onPointerUp: (event) =>
                _handlePointerUp(event, document, documentService),
            child: MouseRegion(
              cursor: _controller.getCursorForCurrentTool(),
              onHover: _handleMouseHover,
              child: Stack(
                children: [
                  GestureDetector(
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onScaleEnd: _handleScaleEnd,
                    child: CustomPaint(
                      painter: _CanvasPainter(
                        document: document,
                        transform: _controller.transformationController.value,
                        previewEntity: _controller.getPreviewEntity(document),
                        snapResult: _controller.snapResult,
                        additionalPreviewEntities: _controller.getAdditionalPreviewEntities(document),
                      ),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Show visual indicator for hidden layers
                  if (hasHiddenLayers)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(0, 0, 0, 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility_off,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$hiddenLayerCount ${hiddenLayerCount == 1 ? 'layer' : 'layers'} hidden ($hiddenEntityCount ${hiddenEntityCount == 1 ? 'entity' : 'entities'})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Coordinate display
                  if (_showCoordinates)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: CoordinateDisplay(
                        x: _controller.getCursorPosition().dx,
                        y: _controller.getCursorPosition().dy,
                        precision: 2,
                      ),
                    ),

                  // Status message display
                  if (_controller.getStatusMessage() != null)
                    Positioned(
                      top: 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _controller.getStatusMessage()!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                  // Zoom controls
                  Positioned(
                    top: 16,
                    left: 16,
                    child: ZoomControls(
                      zoomLevel: _controller.getZoomPercentage(),
                      onZoomIn: () => setState(() => _controller.zoomIn()),
                      onZoomOut: () => setState(() => _controller.zoomOut()),
                      onResetZoom: () =>
                          setState(() => _controller.resetZoom()),
                    ),
                  ),

                  // Snap settings panel
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(0, 0, 0, 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Main snap toggle
                          Row(
                            children: [
                              Icon(
                                Icons.attractions,
                                color: _controller.snapSettings.enabled
                                    ? Colors.blue
                                    : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Snap',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: _controller.snapSettings.enabled,
                                onChanged: (value) {
                                  _updateSnapSettings(
                                      _controller.snapSettings.copyWith(
                                    enabled: value,
                                  ));
                                },
                                activeColor: Colors.blue,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),

                          // Only show snap options if enabled
                          if (_controller.snapSettings.enabled) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                _buildSnapTypeChip(SnapType.grid, 'Grid'),
                                _buildSnapTypeChip(
                                    SnapType.endpoint, 'Endpoint'),
                                _buildSnapTypeChip(
                                    SnapType.midpoint, 'Midpoint'),
                                _buildSnapTypeChip(SnapType.center, 'Center'),
                                _buildSnapTypeChip(
                                    SnapType.perpendicular, 'Perp'),
                                _buildSnapTypeChip(SnapType.tangent, 'Tangent'),
                              ],
                            ),

                            // Snap distance slider
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Distance:',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                Slider(
                                  value: _controller.snapSettings.snapDistance,
                                  min: 5.0,
                                  max: 20.0,
                                  divisions: 3,
                                  label: _controller.snapSettings.snapDistance
                                      .round()
                                      .toString(),
                                  onChanged: (value) {
                                    _updateSnapSettings(
                                        _controller.snapSettings.copyWith(
                                      snapDistance: value,
                                    ));
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ));
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    // Delegate to the controller, which will delegate to the current tool
    _controller.handleScaleStart(details);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Delegate to the controller, which will delegate to the current tool
    _controller.handleScaleUpdate(details);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // Delegate to the controller, which will delegate to the current tool
    _controller.handleScaleEnd(details);
  }

  /// Handle mouse hover events to update coordinate display
  void _handleMouseHover(PointerHoverEvent event) {
    // Convert screen coordinates to document coordinates
    final localPoint = GeometryUtils.inverseTransformPoint(
      event.localPosition,
      _controller.transformationController.value,
    );

    // Update the controller with the current cursor position
    setState(() {
      // Update the cursor position in the controller
      final document =
          Provider.of<DocumentService>(context, listen: false).currentDocument;
      if (document != null) {
        // We're just updating the cursor position, not triggering a full pointer move event
        _controller.cursorPosition = localPoint;
      }
    });
  }

  /// Updates the snap settings and notifies the parent widget if a callback is provided
  void _updateSnapSettings(SnapSettings newSettings) {
    setState(() {
      _controller.updateSnapSettings(newSettings);
    });

    // Notify parent widget if callback is provided
    if (widget.onSnapSettingsChanged != null) {
      widget.onSnapSettingsChanged!(_controller.snapSettings);
    }
  }

  /// Build a chip for toggling a specific snap type
  Widget _buildSnapTypeChip(SnapType type, String label) {
    final isEnabled = _controller.snapSettings.isTypeEnabled(type);
    final snapColor = SnapResult(position: Offset.zero, type: type).color;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isEnabled ? Colors.white : Colors.grey[400],
          fontSize: 11,
          fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isEnabled,
      onSelected: (selected) {
        _updateSnapSettings(_controller.snapSettings.toggleSnapType(type));
      },
      backgroundColor: Color.fromRGBO(50, 50, 50, 0.7),
      selectedColor: snapColor.withAlpha(150),
      checkmarkColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  void _handlePointerDown(PointerDownEvent event, DrawingDocument document,
      DocumentService documentService) {
    // Convert screen coordinates to document coordinates
    final localPoint = GeometryUtils.inverseTransformPoint(
      event.localPosition,
      _controller.transformationController.value,
    );

    // Let the controller handle the pointer down event
    setState(() {
      _controller.handlePointerDown(
          event, localPoint, document, documentService, context);
    });
  }

  void _handlePointerMove(PointerMoveEvent event, DrawingDocument document,
      DocumentService documentService) {
    // Convert screen coordinates to document coordinates
    final localPoint = GeometryUtils.inverseTransformPoint(
      event.localPosition,
      _controller.transformationController.value,
    );

    // Let the controller handle the pointer move event
    setState(() {
      _controller.handlePointerMove(
          event, localPoint, document, documentService, context);
    });
  }

  void _handlePointerUp(PointerUpEvent event, DrawingDocument document,
      DocumentService documentService) {
    // Convert screen coordinates to document coordinates
    final localPoint = GeometryUtils.inverseTransformPoint(
      event.localPosition,
      _controller.transformationController.value,
    );

    // Let the controller handle the pointer up event
    setState(() {
      _controller.handlePointerUp(
          event, localPoint, document, documentService, context);
    });
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.document,
    required this.transform,
    this.previewEntity,
    this.snapResult,
    this.additionalPreviewEntities = const [],
  });

  final DrawingDocument document;
  final Matrix4 transform;
  final Entity? previewEntity;
  final SnapResult? snapResult;
  final List<Entity> additionalPreviewEntities;

  @override
  void paint(Canvas canvas, Size size) {
    // Save the canvas state
    canvas.save();

    // Draw the grid if enabled
    if (document.showGrid) {
      _drawGrid(canvas, size);
    }

    // Draw coordinate axes
    _drawAxes(canvas, size);

    // Draw all visible entities
    for (final entity in document.visibleEntities) {
      entity.draw(canvas, transform);
    }

    // Draw the preview entity if it exists
    if (previewEntity != null) {
      previewEntity!.draw(canvas, transform);
    }
    
    // Draw additional preview entities
    for (final entity in additionalPreviewEntities) {
      entity.draw(canvas, transform);
    }

    // Draw snap position indicator if available
    if (snapResult != null) {
      final snapPaint = Paint()
        ..color = snapResult!.color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final transformedSnapPos =
          GeometryUtils.transformPoint(snapResult!.position, transform);

      // Draw a crosshair
      canvas.drawCircle(transformedSnapPos, 5, snapPaint);
      canvas.drawLine(
        Offset(transformedSnapPos.dx - 10, transformedSnapPos.dy),
        Offset(transformedSnapPos.dx + 10, transformedSnapPos.dy),
        snapPaint,
      );
      canvas.drawLine(
        Offset(transformedSnapPos.dx, transformedSnapPos.dy - 10),
        Offset(transformedSnapPos.dx, transformedSnapPos.dy + 10),
        snapPaint,
      );

      // Draw snap type indicator
      final textPainter = TextPainter(
        text: TextSpan(
          text: snapResult!.description,
          style: TextStyle(
            color: snapResult!.color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(transformedSnapPos.dx + 10, transformedSnapPos.dy + 10),
      );
    }

    // Restore the canvas state
    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withAlpha((0.3 * 255).round())
      ..strokeWidth = 0.5;

    // Calculate grid bounds in document space
    final topLeft = GeometryUtils.inverseTransformPoint(Offset.zero, transform);
    final bottomRight = GeometryUtils.inverseTransformPoint(
        Offset(size.width, size.height), transform);

    // Calculate grid line intervals in document space
    final gridSize = document.gridSize;

    // Adjust the starting positions to be a multiple of gridSize
    final startX = (topLeft.dx ~/ gridSize) * gridSize;
    final startY = (topLeft.dy ~/ gridSize) * gridSize;
    final endX = (bottomRight.dx ~/ gridSize + 1) * gridSize;
    final endY = (bottomRight.dy ~/ gridSize + 1) * gridSize;

    // Draw vertical grid lines
    for (double x = startX; x <= endX; x += gridSize) {
      final p1 = GeometryUtils.transformPoint(Offset(x, topLeft.dy), transform);
      final p2 =
          GeometryUtils.transformPoint(Offset(x, bottomRight.dy), transform);
      canvas.drawLine(p1, p2, paint);
    }

    // Draw horizontal grid lines
    for (double y = startY; y <= endY; y += gridSize) {
      final p1 = GeometryUtils.transformPoint(Offset(topLeft.dx, y), transform);
      final p2 =
          GeometryUtils.transformPoint(Offset(bottomRight.dx, y), transform);
      canvas.drawLine(p1, p2, paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final xAxisPaint = Paint()
      ..color = Colors.red.withAlpha((0.7 * 255).round())
      ..strokeWidth = 1.0;

    final yAxisPaint = Paint()
      ..color = Colors.green.withAlpha((0.7 * 255).round())
      ..strokeWidth = 1.0;

    // Draw X axis
    final xStart = GeometryUtils.transformPoint(Offset(-1000, 0), transform);
    final xEnd = GeometryUtils.transformPoint(Offset(1000, 0), transform);
    canvas.drawLine(xStart, xEnd, xAxisPaint);

    // Draw Y axis
    final yStart = GeometryUtils.transformPoint(Offset(0, -1000), transform);
    final yEnd = GeometryUtils.transformPoint(Offset(0, 1000), transform);
    canvas.drawLine(yStart, yEnd, yAxisPaint);

    // Draw origin
    final origin = GeometryUtils.transformPoint(Offset.zero, transform);
    canvas.drawCircle(origin, 3, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.transform != transform ||
        oldDelegate.previewEntity != previewEntity ||
        oldDelegate.snapResult != snapResult;
  }
}
