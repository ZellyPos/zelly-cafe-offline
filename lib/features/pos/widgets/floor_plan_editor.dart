import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/table.dart';
import '../../../providers/table_provider.dart';
import '../../../providers/connectivity_provider.dart';

class FloorPlanEditor extends StatefulWidget {
  final List<TableModel> tables;
  final int locationId;

  const FloorPlanEditor({
    super.key,
    required this.tables,
    required this.locationId,
  });

  @override
  State<FloorPlanEditor> createState() => _FloorPlanEditorState();
}

class _FloorPlanEditorState extends State<FloorPlanEditor> {
  int? _selectedTableId;
  final bool _isEditing = true;
  bool _showGrid = true;
  final double _snapStep = 0.02; // Snap to 2% grid

  @override
  void initState() {
    super.initState();
    _staggerInitialTables();
  }

  void _staggerInitialTables() {
    // If multiple tables are at (0,0), stagger them so they are visible
    for (int i = 0; i < widget.tables.length; i++) {
      if (widget.tables[i].x == 0 && widget.tables[i].y == 0) {
        double offset = (i * 0.05) % 0.8;
        _updateLocalTable(
          widget.tables[i].id!,
          x: 0.05 + offset,
          y: 0.05 + offset,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;

        // Ensure we have dimensions
        if (totalWidth <= 0 || totalHeight <= 0) return const SizedBox();

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Grid background
              if (_showGrid) _buildGrid(totalWidth, totalHeight),

              // Interactive Stage
              Positioned.fill(
                child: Stack(
                  children: widget.tables.map((table) {
                    return _buildDraggableTable(table, totalWidth, totalHeight);
                  }).toList(),
                ),
              ),

              // Controls overlay
              _buildControls(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(double maxWidth, double maxHeight) {
    return CustomPaint(
      size: Size(maxWidth, maxHeight),
      painter: GridPainter(step: _snapStep),
    );
  }

  Widget _buildDraggableTable(
    TableModel table,
    double maxWidth,
    double maxHeight,
  ) {
    final isSelected = _selectedTableId == table.id;

    // Convert normalized to pixels
    double left = table.x * maxWidth;
    double top = table.y * maxHeight;
    double width = table.width * maxWidth;
    double height = table.height * maxHeight;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _selectedTableId = table.id),
        onPanUpdate: (details) {
          if (!_isEditing) return;

          setState(() {
            _selectedTableId = table.id;

            // Calculate movement in normalized units
            double deltaX = details.delta.dx / maxWidth;
            double deltaY = details.delta.dy / maxHeight;

            double newX = table.x + deltaX;
            double newY = table.y + deltaY;

            // Constrain and Snap
            newX = _snapValue(newX.clamp(0.0, 1.0 - table.width));
            newY = _snapValue(newY.clamp(0.0, 1.0 - table.height));

            _updateLocalTable(table.id!, x: newX, y: newY);
          });
        },
        onPanEnd: (_) => _saveTableLayout(table.id!),
        onTap: () => setState(() => _selectedTableId = table.id),
        child: Container(
          decoration: BoxDecoration(
            color: table.status == 1 ? Colors.red.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(table.shape == 1 ? 100 : 8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade400,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.table_bar,
                      size: (width + height) / 8,
                      color: table.status == 1 ? Colors.red : Colors.green,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        table.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: (width + height) / 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Resize handle (bottom right)
              if (isSelected && _isEditing)
                Positioned(
                  right: -12,
                  bottom: -12,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        // Calculate growth in normalized units
                        double deltaW = details.delta.dx / maxWidth;
                        double deltaH = details.delta.dy / maxHeight;

                        double newWidth = table.width + deltaW;
                        double newHeight = table.height + deltaH;

                        newWidth = _snapValue(newWidth.clamp(0.05, 0.4));
                        newHeight = _snapValue(newHeight.clamp(0.05, 0.4));

                        _updateLocalTable(
                          table.id!,
                          width: newWidth,
                          height: newHeight,
                        );
                      });
                    },
                    onPanEnd: (_) => _saveTableLayout(table.id!),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _snapValue(double value) {
    if (_showGrid) {
      return (value / _snapStep).round() * _snapStep;
    }
    return value;
  }

  void _updateLocalTable(
    int id, {
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    final index = widget.tables.indexWhere((t) => t.id == id);
    if (index != -1) {
      widget.tables[index] = widget.tables[index].copyWith(
        x: x,
        y: y,
        width: width,
        height: height,
      );
    }
  }

  void _saveTableLayout(int id) {
    final table = widget.tables.firstWhere((t) => t.id == id);
    final provider = context.read<TableProvider>();
    final connectivity = context.read<ConnectivityProvider>();

    provider.updateTableLayout(
      id,
      table.x,
      table.y,
      table.width,
      table.height,
      connectivity: connectivity,
    );
  }

  Widget _buildControls() {
    return Positioned(
      top: 10,
      right: 10,
      child: Column(
        children: [
          _buildActionButton(
            icon: _showGrid ? Icons.grid_on : Icons.grid_off,
            tooltip: 'Snap-to-grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          const SizedBox(height: 8),
          _buildActionButton(
            icon: Icons.add,
            tooltip: 'Yangi stol',
            onPressed: _addNewTable,
          ),
          if (_selectedTableId != null) ...[
            const SizedBox(height: 8),
            _buildActionButton(
              icon: Icons.delete,
              color: Colors.red,
              tooltip: 'O\'chirish',
              onPressed: _deleteSelectedTable,
            ),
            const SizedBox(height: 8),
            _buildActionButton(
              icon: Icons.circle,
              tooltip: 'Shakl o\'zgartirish',
              onPressed: _toggleShape,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.blue),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  void _addNewTable() async {
    final nameController = TextEditingController();
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yangi stol qo\'shish'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Stol nomi'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Qo\'shish'),
          ),
        ],
      ),
    );

    if (confirmed == true &&
        nameController.text.isNotEmpty &&
        context.mounted) {
      final provider = context.read<TableProvider>();
      final connectivity = context.read<ConnectivityProvider>();

      // Default relative size: 10% of stage
      await provider.addTable(
        TableModel(
          locationId: widget.locationId,
          name: nameController.text,
          x: 0.1,
          y: 0.1,
          width: 0.1,
          height: 0.1,
        ),
        connectivity: connectivity,
      );
    }
  }

  void _deleteSelectedTable() async {
    if (_selectedTableId == null) return;

    final bool confirmed =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tasdiqlash'),
            content: const Text('Ushbu stolni o\'chirishni xohlaysizmi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Yo\'q'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ha'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && context.mounted) {
      final provider = context.read<TableProvider>();
      final connectivity = context.read<ConnectivityProvider>();
      final success = await provider.deleteTable(
        _selectedTableId!,
        connectivity: connectivity,
      );

      if (success) {
        setState(() => _selectedTableId = null);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xatolik: Stol band bo\'lishi mumkin')),
        );
      }
    }
  }

  void _toggleShape() async {
    if (_selectedTableId == null) return;
    final index = widget.tables.indexWhere((t) => t.id == _selectedTableId);
    if (index != -1) {
      final table = widget.tables[index];
      final newShape = table.shape == 0 ? 1 : 0;

      final provider = context.read<TableProvider>();
      final connectivity = context.read<ConnectivityProvider>();

      await provider.updateTable(
        table.copyWith(shape: newShape),
        connectivity: connectivity,
      );
    }
  }
}

class GridPainter extends CustomPainter {
  final double step;

  GridPainter({required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    for (double i = 0; i <= 1.0; i += step) {
      // Vertical lines
      canvas.drawLine(
        Offset(i * size.width, 0),
        Offset(i * size.width, size.height),
        paint,
      );
      // Horizontal lines
      canvas.drawLine(
        Offset(0, i * size.height),
        Offset(size.width, i * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
