import 'package:flutter/material.dart';
import '../../../models/table.dart';

class FloorPlanViewer extends StatelessWidget {
  final List<TableModel> tables;
  final Function(TableModel) onTableTap;
  final TableModel? selectedTable;
  final Map<String, List<TableModel>>? joinGroups;

  const FloorPlanViewer({
    super.key,
    required this.tables,
    required this.onTableTap,
    this.selectedTable,
    this.joinGroups,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            children: [
              // 1. Draw connecting lines between joined tables
              if (joinGroups != null && joinGroups!.isNotEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: JoinLinesPainter(
                      tables: tables,
                      joinGroups: joinGroups!,
                      totalWidth: totalWidth,
                      totalHeight: totalHeight,
                    ),
                  ),
                ),

              // 2. Draw tables
              ...tables.map((table) {
                // Convert normalized to pixels
                double left = table.x * totalWidth;
                double top = table.y * totalHeight;
                double width = table.width * totalWidth;
                double height = table.height * totalHeight;

                final isCurrentTable = selectedTable?.id == table.id;
                final bool isJoined =
                    table.activeOrderId != null &&
                    (joinGroups?[table.activeOrderId!]?.length ?? 0) > 1;

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: GestureDetector(
                    onTap: () => onTableTap(table),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: table.status == 1
                                ? Colors.red.withOpacity(0.9)
                                : Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(
                              table.shape == 1 ? 100 : 8,
                            ),
                            border: Border.all(
                              color: isCurrentTable
                                  ? Colors.yellow
                                  : (isJoined
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.white),
                              width: isCurrentTable ? 3 : (isJoined ? 2 : 1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.table_bar,
                                  size: (width + height) / 6,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    table.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: (width + height) / 12,
                                    ),
                                  ),
                                ),
                                if (table.activeOrder != null)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${table.activeOrder!.totalAmount.toInt()} sum',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // 🔗 Joined Badge
                        if (isJoined)
                          Positioned(
                            top: -8,
                            right: -8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.link,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class JoinLinesPainter extends CustomPainter {
  final List<TableModel> tables;
  final Map<String, List<TableModel>> joinGroups;
  final double totalWidth;
  final double totalHeight;

  JoinLinesPainter({
    required this.tables,
    required this.joinGroups,
    required this.totalWidth,
    required this.totalHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var entry in joinGroups.entries) {
      final members = entry.value;
      if (members.length < 2) continue;

      // Group tables by location (just in case)
      // We only draw lines between tables VISIBLE in current list (already filtered by location)
      final visibleMembers = members
          .where((m) => tables.any((t) => t.id == m.id))
          .toList();
      if (visibleMembers.length < 2) continue;

      // Draw lines between sequential visible members
      for (int i = 0; i < visibleMembers.length - 1; i++) {
        final t1 = visibleMembers[i];
        final t2 = visibleMembers[i + 1];

        final start = Offset(
          (t1.x + t1.width / 2) * totalWidth,
          (t1.y + t1.height / 2) * totalHeight,
        );
        final end = Offset(
          (t2.x + t2.width / 2) * totalWidth,
          (t2.y + t2.height / 2) * totalHeight,
        );

        _drawDashedLine(canvas, start, end, dashPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    double distance = (p2 - p1).distance;
    final direction = (p2 - p1) / distance;
    double currentDist = 0;

    Path path = Path();
    while (currentDist < distance) {
      path.moveTo(
        p1.dx + direction.dx * currentDist,
        p1.dy + direction.dy * currentDist,
      );
      currentDist += dashWidth;
      if (currentDist > distance) currentDist = distance;
      path.lineTo(
        p1.dx + direction.dx * currentDist,
        p1.dy + direction.dy * currentDist,
      );
      currentDist += dashSpace;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant JoinLinesPainter oldDelegate) {
    return oldDelegate.tables != tables || oldDelegate.joinGroups != joinGroups;
  }
}
