import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/inventory_provider.dart';

class StockHistoryScreen extends StatefulWidget {
  const StockHistoryScreen({super.key});

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<InventoryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Harakatlar Tarixi')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: provider.getMovements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Xatolik: ${snapshot.error}'));
          }
          final movements = snapshot.data ?? [];
          if (movements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: theme.hintColor.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Harakatlar topilmadi',
                    style: TextStyle(color: theme.hintColor),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: movements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final mov = movements[index];
              final typeStr = mov['type'];
              final color = _getColorForType(typeStr);
              final date = DateTime.parse(mov['created_at']);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(
                      _getIconForType(typeStr),
                      color: color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    mov['ingredient_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${DateFormat('dd.MM.yyyy HH:mm').format(date)} • ${mov['reason'] ?? ''}',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                  trailing: Text(
                    '${_getPrefix(typeStr)}${mov['qty']} ${mov['base_unit']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'IN':
        return Colors.green;
      case 'OUT':
        return Colors.red;
      case 'ADJUST':
        return Colors.blue;
      case 'RETURN':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'IN':
        return Icons.add_circle_outline;
      case 'OUT':
        return Icons.remove_circle_outline;
      case 'ADJUST':
        return Icons.tune;
      case 'RETURN':
        return Icons.settings_backup_restore;
      default:
        return Icons.help_outline;
    }
  }

  String _getPrefix(String type) {
    if (type == 'IN') return '+';
    if (type == 'OUT') return '-';
    return '';
  }
}
