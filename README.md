# CADraft Studio - Flutter App

A sophisticated drawing application built with Flutter, featuring an infinite canvas, CAD-like functionality, and a comprehensive set of drawing tools.

## Features

### Drawing Tools
- Line tool: Create straight lines
- Rectangle tool: Create rectangles
- Circle tool: Create circles
- Arc tool: Create arcs with various methods (3-point, start-center-end)
- Polyline tool: Create connected line segments with multiple points
- Ellipse tool: Create ellipses by dragging from corner to corner
- Spline tool: Create smooth curves through control points using Catmull-Rom interpolation

### Selection and Manipulation
- Select tool: Select entities for editing
- Move tool: Move selected entities
- Delete tool: Remove entities from the canvas
- Trim tool: Trim entities at intersection points (supports lines, circles, arcs, ellipses, and splines)
- Extend tool: Extend entities to meet others (partially implemented)

### Layer Management
- Create, rename, and delete layers
- Set layer colors for visual organization
- Toggle layer visibility to hide/show specific entities
- Quickly show/hide all layers at once

### View Controls
- Pan and zoom around an infinite canvas
- Adjustable grid with snap-to-grid functionality
- Coordinate display for precise drawing
- Real-time preview of entities being drawn

### File Operations
- Save and load drawings
- Export to industry-standard DXF format

## Usage Tips

### Drawing Tools
- **Polyline**: 
  - Click to add points
  - Double-click to finalize
  - Right-click to remove last point
  - Auto-closes when clicking near the start point
  
- **Ellipse**:
  - Click and drag from one corner to the opposite corner
  - Hold Shift while dragging to create a perfect circle
  
- **Spline**:
  - Click to add control points
  - Double-click to finalize
  - Creates smooth curves through all control points
  
- **Trim/Extend**:
  - Select the trim/extend tool
  - Click on the entity to trim/extend
  - Click on the boundary entity
  
### Layer Visibility
The layer panel allows you to control which layers are visible in your drawing:
- Click the eye icon to toggle visibility for individual layers
- Use the "Show All"/"Hide All" buttons to quickly change all layers at once
- Hidden layers are indicated with a "Layer Hidden" label
- The canvas shows a notification when layers are hidden

### Grid Settings
- Toggle the grid on/off with the "Show Grid" switch
- Enable "Snap to Grid" to help with precise placement
- Adjust the grid size slider to change the grid spacing

### Tools
- Use the toolbar to select your active drawing or editing tool
- The current tool is highlighted in the toolbar
- Press the Escape key to cancel the current operation

## Development Status

### Implemented Features
- Basic drawing tools (line, rectangle, circle, arc)
- Advanced drawing tools (polyline, ellipse, spline)
- Selection and basic manipulation (move, delete)
- Trimming functionality for all entity types
- Partial implementation of extend tool
- Layer management system
- Infinite canvas with pan/zoom

### In Progress
- Extend tool completion
- Additional modification tools (rotate, scale, mirror, offset)
- Improved entity snapping
- More precise coordinate input
- DXF export

### Known Issues
- Some edge cases in trim/extend operations may need refinement
- Performance optimization needed for complex drawings
- Limited undo/redo functionality

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
