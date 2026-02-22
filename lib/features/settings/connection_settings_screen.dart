import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connectivity_provider.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _urlController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final connectivity = context.read<ConnectivityProvider>();
    _urlController.text = connectivity.clientBaseUrl ?? 'http://';
    _portController.text = connectivity.port.toString();
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ulanish sozlamalari'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tarmoq rejimi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(
                          0xFF1E293B,
                        ), // This color is not changed in the instruction
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.light
                            ? const Color(0xFFF8FAFC)
                            : theme.colorScheme.onSurface.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildModeOption(
                            context,
                            ConnectivityMode.server,
                            'Server (Kassa)',
                            'Ushbu kompyuter asosiy server sifatida ishlaydi',
                            Icons.computer,
                            connectivity,
                          ),
                          const Divider(height: 1),
                          _buildModeOption(
                            context,
                            ConnectivityMode.client,
                            'Client (Ofitsiant)',
                            'Boshqa qurilmadagi serverga ulanish',
                            Icons.smartphone,
                            connectivity,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (connectivity.mode == ConnectivityMode.client) ...[
                      const Text(
                        'Server manzili',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'http://192.168.1.XX:8080',
                          filled: true,
                          fillColor: theme.brightness == Brightness.light
                              ? const Color(0xFFF8FAFC)
                              : theme.colorScheme.onSurface.withOpacity(0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],

                    if (connectivity.mode == ConnectivityMode.server) ...[
                      const Text(
                        'Port',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.brightness == Brightness.light
                              ? const Color(0xFFF8FAFC)
                              : theme.colorScheme.onSurface.withOpacity(0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          final p = int.tryParse(val);
                          if (p != null) connectivity.setPort(p);
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Ulanish uchun IP:',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              '${connectivity.serverIp ?? "Qidirilmoqda..."}:${connectivity.port}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    if (connectivity.connectionStatus.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Text(
                          connectivity.connectionStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: connectivity.isSuccess
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => connectivity.testConnection(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Tekshirish'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (connectivity.mode ==
                                  ConnectivityMode.client) {
                                connectivity.setClientBaseUrl(
                                  _urlController.text,
                                );
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sozlamalar saqlandi'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Saqlash'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    ConnectivityMode mode,
    String title,
    String subtitle,
    IconData icon,
    ConnectivityProvider connectivity,
  ) {
    final theme = Theme.of(context);
    final isSelected = connectivity.mode == mode;

    return ListTile(
      onTap: () => connectivity.setMode(mode),
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
