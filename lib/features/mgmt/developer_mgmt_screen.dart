import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/developer_provider.dart';

class DeveloperMgmtScreen extends StatefulWidget {
  const DeveloperMgmtScreen({super.key});

  @override
  State<DeveloperMgmtScreen> createState() => _DeveloperMgmtScreenState();
}

class _DeveloperMgmtScreenState extends State<DeveloperMgmtScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeveloperProvider>().loadTables();
    });
  }

  @override
  Widget build(BuildContext context) {
    final devProvider = context.watch<DeveloperProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer - Database Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => devProvider.loadTables(),
          ),
        ],
      ),
      body: devProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: devProvider.tables.length,
              itemBuilder: (context, index) {
                final tableName = devProvider.tables[index];
                return ListTile(
                  leading: const Icon(Icons.table_view),
                  title: Text(tableName),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TableDetailScreen(tableName: tableName),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class TableDetailScreen extends StatefulWidget {
  final String tableName;
  const TableDetailScreen({super.key, required this.tableName});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await context.read<DeveloperProvider>().getTableData(
      widget.tableName,
    );
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Table: ${widget.tableName}'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _addRow()),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
          ? const Center(child: Text('Ma\'lumot yo\'q'))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns:
                      _data.first.keys
                          .map((key) => DataColumn(label: Text(key)))
                          .toList()
                        ..add(const DataColumn(label: Text('Amallar'))),
                  rows: _data.map((row) {
                    return DataRow(
                      cells: [
                        ...row.values
                            .map((value) => DataCell(Text(value.toString())))
                            .toList(),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _editRow(row),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteRow(row),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }

  void _deleteRow(Map<String, dynamic> row) async {
    final idColumn = row.containsKey('id') ? 'id' : row.keys.first;
    final idValue = row[idColumn];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('O\'chirish'),
        content: const Text('Ushbu qatorni o\'chirishga aminmisiz?'),
        actions: [
          TextButton(
            child: const Text('Bekor qilish'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text(
              'O\'chirish',
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await context.read<DeveloperProvider>().deleteRow(
        widget.tableName,
        idColumn,
        idValue,
      );
      if (success) {
        _loadData();
      }
    }
  }

  void _editRow(Map<String, dynamic> row) async {
    final idColumn = row.containsKey('id') ? 'id' : row.keys.first;
    final Map<String, dynamic> editedData = Map.from(row);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Qatorni tahrirlash: $idColumn=${row[idColumn]}'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: row.entries.map((entry) {
                if (entry.key == idColumn) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextFormField(
                    initialValue: entry.value?.toString() ?? '',
                    decoration: InputDecoration(labelText: entry.key),
                    onChanged: (val) {
                      // Try to parse as num if it looks like one
                      final numericValue = num.tryParse(val);
                      editedData[entry.key] = numericValue ?? val;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Bekor qilish'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Saqlash'),
            onPressed: () async {
              final success = await context.read<DeveloperProvider>().updateRow(
                widget.tableName,
                idColumn,
                row[idColumn],
                editedData,
              );
              if (success) {
                Navigator.pop(context);
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  void _addRow() async {
    if (_data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadval bo\'sh, ustunlarni aniqlab bo\'lmadi'),
        ),
      );
      return;
    }

    final Map<String, dynamic> newData = {};
    for (var key in _data.first.keys) {
      if (key == 'id') continue;
      newData[key] = '';
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Yangi qator qo\'shish: ${widget.tableName}'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: newData.keys.map((key) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextFormField(
                    decoration: InputDecoration(labelText: key),
                    onChanged: (val) {
                      final numericValue = num.tryParse(val);
                      newData[key] = numericValue ?? val;
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Bekor qilish'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Qo\'shish'),
            onPressed: () async {
              final success = await context.read<DeveloperProvider>().addRow(
                widget.tableName,
                newData,
              );
              if (success) {
                Navigator.pop(context);
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }
}
